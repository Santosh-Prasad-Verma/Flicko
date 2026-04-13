// Package abuse implements real-time message abuse detection and mitigation.
//
// It detects spam, flooding, and abusive behaviour patterns using Redis
// pipelines (single round-trip per check) and provides automated actions
// such as muting, shadow-muting, kicking, and banning.
//
// Checks performed:
//
//  1. Duplicate message spam   — same content ≥3× in 10 s
//  2. High-frequency flooding  — ≥50 messages in 30 s (backup to rate-limiter)
//  3. Cross-channel spam       — posting in ≥15 channels in 60 s
//  4. Mass DM detection        — DMing ≥10 unique users in 60 s
//  5. Invite/link spam         — >5 messages with links in 5 min
//
// All thresholds are configurable via [Thresholds].
package abuse

import (
	"context"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/cespare/xxhash/v2"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// ─────────────────────────────────────────────────────────────────────────────
// Actions
// ─────────────────────────────────────────────────────────────────────────────

// Action describes what to do when abuse is detected.
type Action int

const (
	ActionNone       Action = iota // No action — not flagged.
	ActionWarn                     // Warn the user (logged, no enforcement).
	ActionMute                     // Mute: messages silently dropped for duration.
	ActionShadowMute               // Shadow-mute: user sees own msgs, others don't.
	ActionKick                     // Kick from guild.
	ActionBan                      // Ban from guild.
)

// String returns a human-readable label for the action.
func (a Action) String() string {
	switch a {
	case ActionNone:
		return "none"
	case ActionWarn:
		return "warn"
	case ActionMute:
		return "mute"
	case ActionShadowMute:
		return "shadow_mute"
	case ActionKick:
		return "kick"
	case ActionBan:
		return "ban"
	default:
		return "unknown"
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// Violation reasons
// ─────────────────────────────────────────────────────────────────────────────

// Reason describes why a message was flagged.
type Reason string

const (
	ReasonDuplicateSpam  Reason = "duplicate_message_spam"
	ReasonHighFrequency  Reason = "high_frequency_flood"
	ReasonCrossChannel   Reason = "cross_channel_spam"
	ReasonMassDM         Reason = "mass_dm_spam"
	ReasonInviteLinkSpam Reason = "invite_link_spam"
)

// ─────────────────────────────────────────────────────────────────────────────
// Thresholds (configurable)
// ─────────────────────────────────────────────────────────────────────────────

// Thresholds defines the limits for each abuse check.
type Thresholds struct {
	// Duplicate: flag if ≥ DupeMaxCount identical messages in DupeWindow.
	DupeMaxCount int64
	DupeWindow   time.Duration

	// HighFreq: flag if ≥ FreqMaxCount messages in FreqWindow.
	FreqMaxCount int64
	FreqWindow   time.Duration

	// CrossChannel: flag if posting in ≥ CrossChanMax channels in CrossChanWindow.
	CrossChanMax    int64
	CrossChanWindow time.Duration

	// MassDM: flag if DMing ≥ MassDMMax unique recipients in MassDMWindow.
	MassDMMax    int64
	MassDMWindow time.Duration

	// LinkSpam: flag if > LinkMax messages containing links in LinkWindow.
	LinkMax    int64
	LinkWindow time.Duration
}

// DefaultThresholds returns the production defaults from the spec.
func DefaultThresholds() Thresholds {
	return Thresholds{
		DupeMaxCount:    3,
		DupeWindow:      10 * time.Second,
		FreqMaxCount:    50,
		FreqWindow:      30 * time.Second,
		CrossChanMax:    15,
		CrossChanWindow: 60 * time.Second,
		MassDMMax:       10,
		MassDMWindow:    60 * time.Second,
		LinkMax:         5,
		LinkWindow:      5 * time.Minute,
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// CheckInput / CheckResult
// ─────────────────────────────────────────────────────────────────────────────

// CheckInput carries the data needed for a single abuse check.
type CheckInput struct {
	UserID    string
	ChannelID string
	Content   string

	// IsDM is true when the message targets a DM channel.
	IsDM bool
	// RecipientID is set when IsDM is true (the other user in the DM).
	RecipientID string
}

// CheckResult is returned by Detector.Check.
type CheckResult struct {
	// Flagged is true when at least one check tripped.
	Flagged bool

	// Action is the recommended enforcement action.
	Action Action

	// Reason describes which check(s) fired.
	Reason Reason

	// Details is a human-readable explanation for logging/admin review.
	Details string

	// MuteDuration is set when Action is Mute or ShadowMute.
	MuteDuration time.Duration
}

// ─────────────────────────────────────────────────────────────────────────────
// Link detection regex
// ─────────────────────────────────────────────────────────────────────────────

// linkPattern matches URLs and common invite link domains.
var linkPattern = regexp.MustCompile(
	`(?i)` + // case-insensitive
		`(?:` +
		`https?://` + // http:// or https://
		`|discord\.gg/` +
		`|discord(?:app)?\.com/invite/` +
		`|t\.me/` +
		`|telegram\.me/` +
		`)` +
		`\S+`, // rest of the URL
)

// containsLinks returns true if the content contains any URLs or invite links.
func containsLinks(content string) bool {
	return linkPattern.MatchString(content)
}

// ─────────────────────────────────────────────────────────────────────────────
// Detector
// ─────────────────────────────────────────────────────────────────────────────

// Detector performs abuse checks using Redis for state tracking.
// All checks run in a single Redis pipeline (one round-trip).
type Detector struct {
	rdb        redis.Cmdable
	thresholds Thresholds
	log        *zap.Logger
}

// NewDetector creates an abuse Detector.
func NewDetector(rdb redis.Cmdable, thresholds Thresholds, log *zap.Logger) *Detector {
	return &Detector{
		rdb:        rdb,
		thresholds: thresholds,
		log:        log.Named("abuse.detector"),
	}
}

// Check evaluates all abuse signals for a pending message.
// Every Redis command is batched into a single pipeline (one network round-trip).
//
// On Redis failure the method logs a warning and returns a non-flagged result
// (availability > enforcement).
func (d *Detector) Check(ctx context.Context, in CheckInput) CheckResult {
	// ── Build Redis pipeline ────────────────────────────────
	pipe := d.rdb.Pipeline()
	th := d.thresholds

	// ① Duplicate message spam — INCR + EXPIRE
	contentHash := hashContent(in.Content)
	dupeKey := fmt.Sprintf("flicko:abuse:dupe:%s:%s", in.UserID, contentHash)
	dupeIncr := pipe.Incr(ctx, dupeKey)
	pipe.Expire(ctx, dupeKey, th.DupeWindow)

	// ② High-frequency flooding — INCR + EXPIRE
	freqKey := fmt.Sprintf("flicko:abuse:freq:%s", in.UserID)
	freqIncr := pipe.Incr(ctx, freqKey)
	pipe.Expire(ctx, freqKey, th.FreqWindow)

	// ③ Cross-channel spam — SADD + EXPIRE + SCARD
	crossKey := fmt.Sprintf("flicko:abuse:channels:%s", in.UserID)
	pipe.SAdd(ctx, crossKey, in.ChannelID)
	pipe.Expire(ctx, crossKey, th.CrossChanWindow)
	crossCard := pipe.SCard(ctx, crossKey)

	// ④ Mass DM detection — SADD + EXPIRE + SCARD (only when DM)
	var dmCard *redis.IntCmd
	dmKey := fmt.Sprintf("flicko:abuse:dm:%s", in.UserID)
	if in.IsDM && in.RecipientID != "" {
		pipe.SAdd(ctx, dmKey, in.RecipientID)
		pipe.Expire(ctx, dmKey, th.MassDMWindow)
		dmCard = pipe.SCard(ctx, dmKey)
	}

	// ⑤ Invite/link spam — INCR + EXPIRE (only when content has links)
	var linkIncr *redis.IntCmd
	linkKey := fmt.Sprintf("flicko:abuse:links:%s", in.UserID)
	hasLinks := containsLinks(in.Content)
	if hasLinks {
		linkIncr = pipe.Incr(ctx, linkKey)
		pipe.Expire(ctx, linkKey, th.LinkWindow)
	}

	// ── Execute pipeline ────────────────────────────────────
	if _, err := pipe.Exec(ctx); err != nil && err != redis.Nil {
		d.log.Warn("abuse check pipeline failed, skipping enforcement",
			zap.String("user_id", in.UserID),
			zap.Error(err),
		)
		return CheckResult{}
	}

	// ── Evaluate results (highest-severity first) ───────────

	// ② High frequency → mute 5 min
	if freqCount := freqIncr.Val(); freqCount >= th.FreqMaxCount {
		return CheckResult{
			Flagged:      true,
			Action:       ActionMute,
			Reason:       ReasonHighFrequency,
			Details:      fmt.Sprintf("%d messages in %s (limit %d)", freqCount, th.FreqWindow, th.FreqMaxCount),
			MuteDuration: 5 * time.Minute,
		}
	}

	// ③ Cross-channel spam → mute 10 min
	if crossCount := crossCard.Val(); crossCount >= th.CrossChanMax {
		return CheckResult{
			Flagged:      true,
			Action:       ActionMute,
			Reason:       ReasonCrossChannel,
			Details:      fmt.Sprintf("posted in %d channels in %s (limit %d)", crossCount, th.CrossChanWindow, th.CrossChanMax),
			MuteDuration: 10 * time.Minute,
		}
	}

	// ④ Mass DM → shadow mute 30 min
	if dmCard != nil {
		if dmCount := dmCard.Val(); dmCount >= th.MassDMMax {
			return CheckResult{
				Flagged:      true,
				Action:       ActionShadowMute,
				Reason:       ReasonMassDM,
				Details:      fmt.Sprintf("DMed %d unique users in %s (limit %d)", dmCount, th.MassDMWindow, th.MassDMMax),
				MuteDuration: 30 * time.Minute,
			}
		}
	}

	// ① Duplicate spam → shadow mute 2 min
	if dupeCount := dupeIncr.Val(); dupeCount >= th.DupeMaxCount {
		return CheckResult{
			Flagged:      true,
			Action:       ActionShadowMute,
			Reason:       ReasonDuplicateSpam,
			Details:      fmt.Sprintf("%d identical messages in %s (limit %d)", dupeCount, th.DupeWindow, th.DupeMaxCount),
			MuteDuration: 2 * time.Minute,
		}
	}

	// ⑤ Link spam → warn (first offense), mute on repeat
	if linkIncr != nil {
		if linkCount := linkIncr.Val(); linkCount > th.LinkMax {
			return CheckResult{
				Flagged:      true,
				Action:       ActionShadowMute,
				Reason:       ReasonInviteLinkSpam,
				Details:      fmt.Sprintf("%d messages with links in %s (limit %d)", linkCount, th.LinkWindow, th.LinkMax),
				MuteDuration: 5 * time.Minute,
			}
		}
	}

	return CheckResult{}
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

// hashContent returns a hex-encoded xxhash digest of the normalised content.
// Normalisation: lowercase + collapse whitespace.
func hashContent(s string) string {
	normalised := strings.Join(strings.Fields(strings.ToLower(s)), " ")
	h := xxhash.Sum64String(normalised)
	return strconv.FormatUint(h, 16)
}
