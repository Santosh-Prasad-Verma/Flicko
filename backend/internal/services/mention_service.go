package services

import (
	"context"
	"log"
	"regexp"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type MentionService interface {
	ProcessMentions(ctx context.Context, messageID string, content string, authorID string, serverID *string) error
}

type mentionService struct {
	db            *pgxpool.Pool
	userRegex     *regexp.Regexp
	roleRegex     *regexp.Regexp
	channelRegex  *regexp.Regexp
	everyoneRegex *regexp.Regexp
	hereRegex     *regexp.Regexp
}

func NewMentionService(db *pgxpool.Pool) MentionService {
	return &mentionService{
		db: db,
		// Discord-style markdown for mentions
		userRegex:     regexp.MustCompile(`<@!?([0-9a-fA-F-]+)>`),
		roleRegex:     regexp.MustCompile(`<@&([0-9a-fA-F-]+)>`),
		channelRegex:  regexp.MustCompile(`<#([0-9a-fA-F-]+)>`),
		everyoneRegex: regexp.MustCompile(`@everyone`),
		hereRegex:     regexp.MustCompile(`@here`),
	}
}

func (s *mentionService) ProcessMentions(ctx context.Context, messageID string, content string, authorID string, serverID *string) error {
	// Parse all
	userMatches := s.userRegex.FindAllStringSubmatch(content, -1)
	roleMatches := s.roleRegex.FindAllStringSubmatch(content, -1)
	channelMatches := s.channelRegex.FindAllStringSubmatch(content, -1)
	hasEveryone := s.everyoneRegex.MatchString(content)
	hasHere := s.hereRegex.MatchString(content)

	// Keep track of unique targets to avoid duplicate mention records per message
	processedUsers := make(map[string]bool)
	processedRoles := make(map[string]bool)
	processedChannels := make(map[string]bool)

	// Batch insert array
	type mentionInsert struct {
		targetID string
		mType    string
	}
	var inserts []mentionInsert

	// @everyone
	if hasEveryone {
		// Validating permission to mention everyone should be done *before* sending the message,
		// in the MessageService. By the time it's here, we assume it's allowed.
		inserts = append(inserts, mentionInsert{targetID: "", mType: "everyone"})
	}

	// @here
	if hasHere && !hasEveryone { // everyone supersedes here usually
		inserts = append(inserts, mentionInsert{targetID: "", mType: "here"})
	}

	// @users
	for _, match := range userMatches {
		if len(match) < 2 {
			continue
		}
		targetIDStr := match[1]
		if processedUsers[targetIDStr] {
			continue
		}
		processedUsers[targetIDStr] = true

		targetUUID, err := uuid.Parse(targetIDStr)
		if err != nil {
			continue // ignore invalid UUIDs
		}

		// Validate user exists in server ONLY if message is in a server context
		if serverID != nil {
			var exists bool
			err := s.db.QueryRow(ctx, "SELECT exists(SELECT 1 FROM public.server_members WHERE server_id = $1 AND user_id = $2)", *serverID, targetUUID).Scan(&exists)
			if err != nil || !exists {
				continue // skip if not member
			}
		}

		inserts = append(inserts, mentionInsert{targetID: targetUUID.String(), mType: "user"})
	}

	// @roles
	if serverID != nil {
		for _, match := range roleMatches {
			if len(match) < 2 {
				continue
			}
			roleIDStr := match[1]
			if processedRoles[roleIDStr] {
				continue
			}
			processedRoles[roleIDStr] = true

			roleUUID, err := uuid.Parse(roleIDStr)
			if err != nil {
				continue
			}

			// Validate role exists in server
			var exists bool
			err = s.db.QueryRow(ctx, "SELECT exists(SELECT 1 FROM public.roles WHERE server_id = $1 AND id = $2)", *serverID, roleUUID).Scan(&exists)
			if err != nil || !exists {
				continue
			}

			inserts = append(inserts, mentionInsert{targetID: roleUUID.String(), mType: "role"})
		}
	}

	// #channels
	if serverID != nil {
		for _, match := range channelMatches {
			if len(match) < 2 {
				continue
			}
			channelIDStr := match[1]
			if processedChannels[channelIDStr] {
				continue
			}
			processedChannels[channelIDStr] = true

			channelUUID, err := uuid.Parse(channelIDStr)
			if err != nil {
				continue
			}

			// Validate channel exists in server
			var exists bool
			err = s.db.QueryRow(ctx, "SELECT exists(SELECT 1 FROM public.channels WHERE server_id = $1 AND id = $2)", *serverID, channelUUID).Scan(&exists)
			if err != nil || !exists {
				continue
			}

			inserts = append(inserts, mentionInsert{targetID: channelUUID.String(), mType: "channel"})
		}
	}

	// Insert into DB
	for _, ins := range inserts {
		mentionID := uuid.New().String()

		var err error
		if ins.targetID == "" {
			_, err = s.db.Exec(ctx, "INSERT INTO public.mentions (id, message_id, mention_type) VALUES ($1, $2, $3)", mentionID, messageID, ins.mType)
		} else {
			_, err = s.db.Exec(ctx, "INSERT INTO public.mentions (id, message_id, mention_type, target_id) VALUES ($1, $2, $3, $4)", mentionID, messageID, ins.mType, ins.targetID)
		}

		if err != nil {
			log.Printf("[Mentions] Failed to insert mention %s for msg %s: %v", ins.mType, messageID, err)
		}
	}

	return nil
}
