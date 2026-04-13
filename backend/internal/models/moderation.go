package models

import "time"

// ─── Custom Moderation Error Types ───────────────────────────────────────────

type ModerationError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func (e *ModerationError) Error() string { return e.Code + ": " + e.Message }

var (
	ErrAutoModViolation        = &ModerationError{Code: "AUTO_MOD_VIOLATION", Message: "message blocked by auto-moderation rule"}
	ErrReportDescriptionLength = &ModerationError{Code: "REPORT_DESC_SHORT", Message: "report description must be at least 10 characters"}
	ErrWarningEscalation       = &ModerationError{Code: "WARNING_ESCALATION", Message: "user has exceeded warning threshold"}
	ErrInvalidSeverity         = &ModerationError{Code: "INVALID_SEVERITY", Message: "severity must be one of: low, medium, high, critical"}
	ErrDuplicateReport         = &ModerationError{Code: "DUPLICATE_REPORT", Message: "you have already reported this target"}
)

// ─── Auto-Moderation Models ─────────────────────────────────────────────────

type RuleType string

const (
	RuleTypeSpam      RuleType = "spam"
	RuleTypeProfanity RuleType = "profanity"
	RuleTypeMentions  RuleType = "mentions"
	RuleTypeLinks     RuleType = "links"
	RuleTypeKeywords  RuleType = "keywords"
)

type ActionType string

const (
	ActionBlock   ActionType = "block"
	ActionTimeout ActionType = "timeout"
	ActionKick    ActionType = "kick"
	ActionBan     ActionType = "ban"
)

// SpamConfig represents trigger_config for spam rules
type SpamConfig struct {
	MaxDuplicates     int `json:"max_duplicates"`      // max identical messages in window
	WindowSeconds     int `json:"window_seconds"`      // time window for spam detection
	MaxCapPercentage  int `json:"max_cap_percentage"`  // max % of caps in a message (0-100)
	MaxMentionsInline int `json:"max_mentions_inline"` // max @mentions per message
}

// ProfanityConfig represents trigger_config for profanity rules
type ProfanityConfig struct {
	Patterns      []string `json:"patterns"` // regex patterns to match
	CaseSensitive bool     `json:"case_sensitive"`
	WholeWordOnly bool     `json:"whole_word_only"`
}

// MentionConfig represents trigger_config for mention rules
type MentionConfig struct {
	MaxMentions          int  `json:"max_mentions"`           // max @mentions per message
	CountRoleMentions    bool `json:"count_role_mentions"`    // include @role mentions
	CountEveryoneMention bool `json:"count_everyone_mention"` // include @everyone/@here
}

// LinkConfig represents trigger_config for link rules
type LinkConfig struct {
	AllowLinks     bool     `json:"allow_links"`
	AllowedDomains []string `json:"allowed_domains"` // whitelist
	BlockedDomains []string `json:"blocked_domains"` // blacklist
}

// KeywordConfig represents trigger_config for keyword rules
type KeywordConfig struct {
	Keywords      []string `json:"keywords"`
	CaseSensitive bool     `json:"case_sensitive"`
}

// TimeoutActionConfig represents action_config for timeout actions
type TimeoutActionConfig struct {
	DurationSeconds int    `json:"duration_seconds"`
	Reason          string `json:"reason"`
}

type AutoModRule struct {
	ID             string     `json:"id" db:"id"`
	ServerID       string     `json:"server_id" db:"server_id"`
	Name           string     `json:"name" db:"name"`
	RuleType       RuleType   `json:"rule_type" db:"trigger_type"`
	TriggerConfig  any        `json:"trigger_config" db:"trigger_metadata"`
	ActionType     ActionType `json:"action_type" db:"action_type"`
	ActionConfig   any        `json:"action_config" db:"action_config"`
	ExemptRoles    []string   `json:"exempt_roles" db:"exempt_roles"`
	ExemptChannels []string   `json:"exempt_channels" db:"exempt_channels"`
	IsEnabled      bool       `json:"is_enabled" db:"enabled"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at" db:"updated_at"`
}

// ─── User Reporting Models ──────────────────────────────────────────────────

type ReportType string

const (
	ReportHarassment           ReportType = "harassment"
	ReportSpam                 ReportType = "spam"
	ReportInappropriateContent ReportType = "inappropriate_content"
	ReportOther                ReportType = "other"
)

type ReportTargetType string

const (
	ReportTargetMessage ReportTargetType = "message"
	ReportTargetUser    ReportTargetType = "user"
	ReportTargetServer  ReportTargetType = "server"
)

type ReportStatus string

const (
	ReportStatusPending     ReportStatus = "pending"
	ReportStatusUnderReview ReportStatus = "under_review"
	ReportStatusResolved    ReportStatus = "resolved"
	ReportStatusDismissed   ReportStatus = "dismissed"
)

type Report struct {
	ID          string           `json:"id" db:"id"`
	ServerID    *string          `json:"server_id,omitempty" db:"server_id"`
	ReporterID  string           `json:"reporter_id" db:"reporter_id"`
	ReportType  ReportType       `json:"report_type" db:"report_type"`
	TargetType  ReportTargetType `json:"target_type" db:"target_type"`
	TargetID    string           `json:"target_id" db:"target_id"`
	Description string           `json:"description" db:"description"`
	Evidence    any              `json:"evidence,omitempty" db:"evidence"`
	Status      ReportStatus     `json:"status" db:"status"`
	ReviewedBy  *string          `json:"reviewed_by,omitempty" db:"reviewed_by"`
	ReviewedAt  *time.Time       `json:"reviewed_at,omitempty" db:"reviewed_at"`
	CreatedAt   time.Time        `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time        `json:"updated_at" db:"updated_at"`
}

// ─── Warning System Models ──────────────────────────────────────────────────

type WarningSeverity string

const (
	SeverityLow      WarningSeverity = "low"
	SeverityMedium   WarningSeverity = "medium"
	SeverityHigh     WarningSeverity = "high"
	SeverityCritical WarningSeverity = "critical"
)

type Warning struct {
	ID          string          `json:"id" db:"id"`
	ServerID    string          `json:"server_id" db:"server_id"`
	UserID      string          `json:"user_id" db:"user_id"`
	ModeratorID *string         `json:"moderator_id,omitempty" db:"moderator_id"`
	Reason      string          `json:"reason" db:"reason"`
	Severity    WarningSeverity `json:"severity" db:"severity"`
	CreatedAt   time.Time       `json:"created_at" db:"created_at"`
}

// EscalationThresholds defines at what warning counts automatic moderation kicks in
type EscalationThresholds struct {
	TimeoutAt int // 3 warnings → timeout
	KickAt    int // 5 warnings → kick
}

var DefaultEscalation = EscalationThresholds{TimeoutAt: 3, KickAt: 5}
