package services

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"unicode"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ─── AutoMod Service Interface ──────────────────────────────────────────────

type AutoModService interface {
	// CRUD
	CreateRule(ctx context.Context, serverID, executorID string, rule *models.AutoModRule) (*models.AutoModRule, error)
	GetRules(ctx context.Context, serverID string) ([]*models.AutoModRule, error)
	UpdateRule(ctx context.Context, serverID, ruleID, executorID string, updates map[string]interface{}) (*models.AutoModRule, error)
	DeleteRule(ctx context.Context, serverID, ruleID, executorID string) error

	// Evaluation Engine
	EvaluateMessage(ctx context.Context, serverID, channelID, authorID, content string, authorRoles []string) (*AutoModResult, error)
}

// AutoModResult contains the outcome of evaluating a message against all server rules.
type AutoModResult struct {
	Blocked    bool              `json:"blocked"`
	RuleName   string            `json:"rule_name,omitempty"`
	RuleType   models.RuleType   `json:"rule_type,omitempty"`
	ActionType models.ActionType `json:"action_type,omitempty"`
	Reason     string            `json:"reason,omitempty"`
}

// ─── Implementation ─────────────────────────────────────────────────────────

type autoModService struct {
	db          *pgxpool.Pool
	permService PermissionService
	auditSvc    AuditLogService
}

func NewAutoModService(db *pgxpool.Pool, permService PermissionService, auditSvc AuditLogService) AutoModService {
	return &autoModService{
		db:          db,
		permService: permService,
		auditSvc:    auditSvc,
	}
}

// ─── CRUD Operations ────────────────────────────────────────────────────────

func (s *autoModService) CreateRule(ctx context.Context, serverID, executorID string, rule *models.AutoModRule) (*models.AutoModRule, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	executorUUID, err2 := uuid.Parse(executorID)
	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "MANAGE_GUILD")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, fmt.Errorf("unauthorized: requires MANAGE_GUILD permission")
	}

	if err := validateRuleType(rule.RuleType); err != nil {
		return nil, err
	}
	if err := validateActionType(rule.ActionType); err != nil {
		return nil, err
	}

	triggerJSON, err := json.Marshal(rule.TriggerConfig)
	if err != nil {
		return nil, fmt.Errorf("invalid trigger config: %w", err)
	}
	actionJSON, err := json.Marshal(rule.ActionConfig)
	if err != nil {
		return nil, fmt.Errorf("invalid action config: %w", err)
	}

	query := `
		INSERT INTO public.automod_rules (server_id, name, trigger_type, trigger_metadata, action_type, action_config, exempt_roles, exempt_channels, enabled)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true)
		RETURNING id, server_id, name, trigger_type, trigger_metadata, action_type, action_config, exempt_roles, exempt_channels, enabled, created_at, updated_at
	`

	var created models.AutoModRule
	err = s.db.QueryRow(ctx, query,
		serverUUID, rule.Name, rule.RuleType, triggerJSON, rule.ActionType, actionJSON, rule.ExemptRoles, rule.ExemptChannels,
	).Scan(
		&created.ID, &created.ServerID, &created.Name, &created.RuleType, &created.TriggerConfig,
		&created.ActionType, &created.ActionConfig, &created.ExemptRoles, &created.ExemptChannels,
		&created.IsEnabled, &created.CreatedAt, &created.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create auto-mod rule: %w", err)
	}

	// Audit
	_ = s.auditSvc.CreateLog(ctx, serverID, &executorID, models.AuditLogAction("auto_mod_rule_create"), "auto_mod_rule", &created.ID, nil, nil)

	return &created, nil
}

func (s *autoModService) GetRules(ctx context.Context, serverID string) ([]*models.AutoModRule, error) {
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return nil, fmt.Errorf("invalid server uuid")
	}

	rows, err := s.db.Query(ctx, `
		SELECT id, server_id, name, trigger_type, trigger_metadata, action_type, action_config, exempt_roles, exempt_channels, enabled, created_at, updated_at
		FROM public.automod_rules WHERE server_id = $1 ORDER BY created_at ASC
	`, serverUUID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var rules []*models.AutoModRule
	for rows.Next() {
		r := &models.AutoModRule{}
		if err := rows.Scan(
			&r.ID, &r.ServerID, &r.Name, &r.RuleType, &r.TriggerConfig,
			&r.ActionType, &r.ActionConfig, &r.ExemptRoles, &r.ExemptChannels,
			&r.IsEnabled, &r.CreatedAt, &r.UpdatedAt,
		); err != nil {
			return nil, err
		}
		rules = append(rules, r)
	}
	return rules, nil
}

func (s *autoModService) UpdateRule(ctx context.Context, serverID, ruleID, executorID string, updates map[string]interface{}) (*models.AutoModRule, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	executorUUID, err2 := uuid.Parse(executorID)
	ruleUUID, err3 := uuid.Parse(ruleID)
	if err1 != nil || err2 != nil || err3 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "MANAGE_GUILD")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, fmt.Errorf("unauthorized: requires MANAGE_GUILD permission")
	}

	setClauses := []string{"updated_at = NOW()"}
	args := []interface{}{ruleUUID, serverUUID}
	argID := 3

	for key, val := range updates {
		switch key {
		case "name", "trigger_type", "action_type", "enabled":
			setClauses = append(setClauses, fmt.Sprintf("%s = $%d", key, argID))
			args = append(args, val)
			argID++
		case "trigger_metadata", "action_config":
			jsonBytes, err := json.Marshal(val)
			if err != nil {
				return nil, fmt.Errorf("invalid %s: %w", key, err)
			}
			setClauses = append(setClauses, fmt.Sprintf("%s = $%d", key, argID))
			args = append(args, jsonBytes)
			argID++
		case "exempt_roles", "exempt_channels":
			setClauses = append(setClauses, fmt.Sprintf("%s = $%d", key, argID))
			args = append(args, val)
			argID++
		}
	}

	query := fmt.Sprintf(`
		UPDATE public.automod_rules SET %s WHERE id = $1 AND server_id = $2
		RETURNING id, server_id, name, trigger_type, trigger_metadata, action_type, action_config, exempt_roles, exempt_channels, enabled, created_at, updated_at
	`, strings.Join(setClauses, ", "))

	var rule models.AutoModRule
	err = s.db.QueryRow(ctx, query, args...).Scan(
		&rule.ID, &rule.ServerID, &rule.Name, &rule.RuleType, &rule.TriggerConfig,
		&rule.ActionType, &rule.ActionConfig, &rule.ExemptRoles, &rule.ExemptChannels,
		&rule.IsEnabled, &rule.CreatedAt, &rule.UpdatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("auto-mod rule not found")
		}
		return nil, fmt.Errorf("failed to update rule: %w", err)
	}

	return &rule, nil
}

func (s *autoModService) DeleteRule(ctx context.Context, serverID, ruleID, executorID string) error {
	serverUUID, err1 := uuid.Parse(serverID)
	executorUUID, err2 := uuid.Parse(executorID)
	ruleUUID, err3 := uuid.Parse(ruleID)
	if err1 != nil || err2 != nil || err3 != nil {
		return fmt.Errorf("invalid uuid")
	}

	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "MANAGE_GUILD")
	if err != nil {
		return err
	}
	if !hasPerm {
		return fmt.Errorf("unauthorized: requires MANAGE_GUILD permission")
	}

	res, err := s.db.Exec(ctx, "DELETE FROM public.automod_rules WHERE id = $1 AND server_id = $2", ruleUUID, serverUUID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("auto-mod rule not found")
	}

	_ = s.auditSvc.CreateLog(ctx, serverID, &executorID, models.AuditLogAction("auto_mod_rule_delete"), "auto_mod_rule", &ruleID, nil, nil)
	return nil
}

// ─── Message Evaluation Engine (Strategy Pattern) ───────────────────────────

func (s *autoModService) EvaluateMessage(ctx context.Context, serverID, channelID, authorID, content string, authorRoles []string) (*AutoModResult, error) {
	rules, err := s.GetRules(ctx, serverID)
	if err != nil {
		return &AutoModResult{Blocked: false}, err
	}

	for _, rule := range rules {
		if !rule.IsEnabled {
			continue
		}

		// Check exemptions
		if isExempt(channelID, authorRoles, rule.ExemptChannels, rule.ExemptRoles) {
			continue
		}

		violated := evaluateRule(rule, content)
		if violated {
			return &AutoModResult{
				Blocked:    true,
				RuleName:   rule.Name,
				RuleType:   rule.RuleType,
				ActionType: rule.ActionType,
				Reason:     fmt.Sprintf("Auto-mod rule '%s' triggered (%s)", rule.Name, rule.RuleType),
			}, nil
		}
	}

	return &AutoModResult{Blocked: false}, nil
}

// evaluateRule dispatches to the correct strategy based on rule type.
func evaluateRule(rule *models.AutoModRule, content string) bool {
	rawJSON, _ := json.Marshal(rule.TriggerConfig)

	switch rule.RuleType {
	case models.RuleTypeSpam:
		var cfg models.SpamConfig
		if json.Unmarshal(rawJSON, &cfg) == nil {
			return evaluateSpam(content, cfg)
		}
	case models.RuleTypeProfanity:
		var cfg models.ProfanityConfig
		if json.Unmarshal(rawJSON, &cfg) == nil {
			return evaluateProfanity(content, cfg)
		}
	case models.RuleTypeMentions:
		var cfg models.MentionConfig
		if json.Unmarshal(rawJSON, &cfg) == nil {
			return evaluateMentions(content, cfg)
		}
	case models.RuleTypeLinks:
		var cfg models.LinkConfig
		if json.Unmarshal(rawJSON, &cfg) == nil {
			return evaluateLinks(content, cfg)
		}
	case models.RuleTypeKeywords:
		var cfg models.KeywordConfig
		if json.Unmarshal(rawJSON, &cfg) == nil {
			return evaluateKeywords(content, cfg)
		}
	}
	return false
}

// ─── Individual Rule Evaluators ─────────────────────────────────────────────

func evaluateSpam(content string, cfg models.SpamConfig) bool {
	// Check excessive caps
	if cfg.MaxCapPercentage > 0 && len(content) > 5 {
		capsCount := 0
		for _, r := range content {
			if unicode.IsUpper(r) {
				capsCount++
			}
		}
		capsPct := (capsCount * 100) / len([]rune(content))
		if capsPct > cfg.MaxCapPercentage {
			return true
		}
	}

	// Check excessive inline mentions
	if cfg.MaxMentionsInline > 0 {
		mentionCount := strings.Count(content, "<@")
		if mentionCount > cfg.MaxMentionsInline {
			return true
		}
	}

	return false
}

func evaluateProfanity(content string, cfg models.ProfanityConfig) bool {
	checkContent := content
	if !cfg.CaseSensitive {
		checkContent = strings.ToLower(content)
	}

	for _, pattern := range cfg.Patterns {
		if !cfg.CaseSensitive {
			pattern = strings.ToLower(pattern)
		}
		if cfg.WholeWordOnly {
			pattern = `\b` + regexp.QuoteMeta(pattern) + `\b`
		}
		re, err := regexp.Compile(pattern)
		if err != nil {
			continue
		}
		if re.MatchString(checkContent) {
			return true
		}
	}
	return false
}

func evaluateMentions(content string, cfg models.MentionConfig) bool {
	mentionCount := strings.Count(content, "<@")

	if cfg.CountEveryoneMention {
		mentionCount += strings.Count(content, "@everyone")
		mentionCount += strings.Count(content, "@here")
	}
	if cfg.CountRoleMentions {
		mentionCount += strings.Count(content, "<@&")
	}

	return cfg.MaxMentions > 0 && mentionCount > cfg.MaxMentions
}

func evaluateLinks(content string, cfg models.LinkConfig) bool {
	urlRegex := regexp.MustCompile(`https?://[^\s<]+`)
	urls := urlRegex.FindAllString(content, -1)

	if len(urls) == 0 {
		return false
	}

	if !cfg.AllowLinks {
		return true
	}

	for _, u := range urls {
		domain := extractDomain(u)
		// Check blacklist first
		for _, blocked := range cfg.BlockedDomains {
			if strings.Contains(domain, blocked) {
				return true
			}
		}
		// If whitelist exists, domain must be in it
		if len(cfg.AllowedDomains) > 0 {
			allowed := false
			for _, a := range cfg.AllowedDomains {
				if strings.Contains(domain, a) {
					allowed = true
					break
				}
			}
			if !allowed {
				return true
			}
		}
	}
	return false
}

func evaluateKeywords(content string, cfg models.KeywordConfig) bool {
	checkContent := content
	if !cfg.CaseSensitive {
		checkContent = strings.ToLower(content)
	}

	for _, kw := range cfg.Keywords {
		check := kw
		if !cfg.CaseSensitive {
			check = strings.ToLower(kw)
		}
		if strings.Contains(checkContent, check) {
			return true
		}
	}
	return false
}

// ─── Helpers ────────────────────────────────────────────────────────────────

func isExempt(channelID string, authorRoles, exemptChannels, exemptRoles []string) bool {
	for _, ch := range exemptChannels {
		if ch == channelID {
			return true
		}
	}
	for _, role := range authorRoles {
		for _, exempt := range exemptRoles {
			if role == exempt {
				return true
			}
		}
	}
	return false
}

func extractDomain(rawURL string) string {
	u := strings.TrimPrefix(rawURL, "https://")
	u = strings.TrimPrefix(u, "http://")
	parts := strings.Split(u, "/")
	return parts[0]
}

func validateRuleType(rt models.RuleType) error {
	switch rt {
	case models.RuleTypeSpam, models.RuleTypeProfanity, models.RuleTypeMentions, models.RuleTypeLinks, models.RuleTypeKeywords:
		return nil
	}
	return fmt.Errorf("invalid rule_type: %s", rt)
}

func validateActionType(at models.ActionType) error {
	switch at {
	case models.ActionBlock, models.ActionTimeout, models.ActionKick, models.ActionBan:
		return nil
	}
	return fmt.Errorf("invalid action_type: %s", at)
}

// IsExemptExported provides a test-accessible wrapper for the isExempt logic.
func IsExemptExported(channelID string, authorRoles, exemptChannels, exemptRoles []string) bool {
	return isExempt(channelID, authorRoles, exemptChannels, exemptRoles)
}
