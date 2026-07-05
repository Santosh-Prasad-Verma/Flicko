package handlers

import (
	"strings"
)

// CreateMessageRequest represents a request to create a new channel message.
type CreateMessageRequest struct {
	Content string `json:"content"`
	Nonce   string `json:"nonce,omitempty"`
	TTS     bool   `json:"tts,omitempty"`
}

func (r CreateMessageRequest) Validate() []ValidationError {
	var errs []ValidationError
	trimmed := strings.TrimSpace(r.Content)
	if trimmed == "" {
		errs = append(errs, ValidationError{
			Field:   "content",
			Message: "content is required and cannot be empty",
			Code:    CodeValidationError,
		})
	} else if len(r.Content) > 2000 {
		errs = append(errs, ValidationError{
			Field:   "content",
			Message: "content cannot exceed 2000 characters",
			Code:    CodeValidationError,
		})
	}
	return errs
}

// UpdateServerRequest represents a request to update server settings.
type UpdateServerRequest struct {
	Name        *string `json:"name,omitempty"`
	Description *string `json:"description,omitempty"`
	Icon        *string `json:"icon,omitempty"`
}

func (r UpdateServerRequest) Validate() []ValidationError {
	var errs []ValidationError
	if r.Name == nil && r.Description == nil && r.Icon == nil {
		errs = append(errs, ValidationError{
			Field:   "body",
			Message: "at least one field (name, description, icon) must be provided for update",
			Code:    CodeValidationError,
		})
		return errs
	}
	if r.Name != nil {
		trimmed := strings.TrimSpace(*r.Name)
		if len(trimmed) < 2 || len(trimmed) > 100 {
			errs = append(errs, ValidationError{
				Field:   "name",
				Message: "server name must be between 2 and 100 characters",
				Code:    CodeValidationError,
			})
		}
	}
	if r.Description != nil && len(*r.Description) > 1000 {
		errs = append(errs, ValidationError{
			Field:   "description",
			Message: "description cannot exceed 1000 characters",
			Code:    CodeValidationError,
		})
	}
	return errs
}

// CreateChannelRequest represents a request to create a channel in a server.
type CreateChannelRequest struct {
	Name  string `json:"name"`
	Type  string `json:"type"`
	Topic string `json:"topic,omitempty"`
}

func (r CreateChannelRequest) Validate() []ValidationError {
	var errs []ValidationError
	trimmedName := strings.TrimSpace(r.Name)
	if trimmedName == "" {
		errs = append(errs, ValidationError{
			Field:   "name",
			Message: "channel name is required",
			Code:    CodeValidationError,
		})
	} else if len(trimmedName) < 1 || len(trimmedName) > 100 {
		errs = append(errs, ValidationError{
			Field:   "name",
			Message: "channel name must be between 1 and 100 characters",
			Code:    CodeValidationError,
		})
	}

	trimmedType := strings.TrimSpace(r.Type)
	if trimmedType == "" {
		errs = append(errs, ValidationError{
			Field:   "type",
			Message: "channel type is required",
			Code:    CodeValidationError,
		})
	} else {
		validTypes := map[string]bool{
			"text":         true,
			"voice":        true,
			"stage":        true,
			"forum":        true,
			"announcement": true,
		}
		if !validTypes[strings.ToLower(trimmedType)] {
			errs = append(errs, ValidationError{
				Field:   "type",
				Message: "invalid channel type (supported: text, voice, stage, forum, announcement)",
				Code:    CodeValidationError,
			})
		}
	}
	return errs
}

// UpdateProfileRequest represents a request to update user profile details.
type UpdateProfileRequest struct {
	Username    *string `json:"username,omitempty"`
	DisplayName *string `json:"display_name,omitempty"`
	Bio         *string `json:"bio,omitempty"`
	AvatarURL   *string `json:"avatar_url,omitempty"`
}

func (r UpdateProfileRequest) Validate() []ValidationError {
	var errs []ValidationError
	if r.Username == nil && r.DisplayName == nil && r.Bio == nil && r.AvatarURL == nil {
		errs = append(errs, ValidationError{
			Field:   "body",
			Message: "at least one field must be provided for update",
			Code:    CodeValidationError,
		})
		return errs
	}
	if r.Username != nil {
		trimmed := strings.TrimSpace(*r.Username)
		if len(trimmed) < 3 || len(trimmed) > 32 {
			errs = append(errs, ValidationError{
				Field:   "username",
				Message: "username must be between 3 and 32 characters",
				Code:    CodeValidationError,
			})
		}
	}
	if r.Bio != nil && len(*r.Bio) > 190 {
		errs = append(errs, ValidationError{
			Field:   "bio",
			Message: "bio cannot exceed 190 characters",
			Code:    CodeValidationError,
		})
	}
	return errs
}

// RedeemCodeRequest represents a request to redeem a gift or promo code.
type RedeemCodeRequest struct {
	Code string `json:"code"`
}

func (r RedeemCodeRequest) Validate() []ValidationError {
	var errs []ValidationError
	trimmed := strings.TrimSpace(r.Code)
	if trimmed == "" {
		errs = append(errs, ValidationError{
			Field:   "code",
			Message: "redemption code is required",
			Code:    CodeValidationError,
		})
	} else if len(trimmed) < 4 || len(trimmed) > 64 {
		errs = append(errs, ValidationError{
			Field:   "code",
			Message: "code length must be between 4 and 64 characters",
			Code:    CodeValidationError,
		})
	}
	return errs
}

// DataExportRequest represents a request to export user privacy data.
type DataExportRequest struct {
	Format             string `json:"format"`
	IncludeAttachments bool   `json:"include_attachments,omitempty"`
}

func (r DataExportRequest) Validate() []ValidationError {
	var errs []ValidationError
	fmtLower := strings.ToLower(strings.TrimSpace(r.Format))
	if fmtLower == "" {
		errs = append(errs, ValidationError{
			Field:   "format",
			Message: "export format is required",
			Code:    CodeValidationError,
		})
	} else if fmtLower != "json" && fmtLower != "csv" && fmtLower != "zip" {
		errs = append(errs, ValidationError{
			Field:   "format",
			Message: "invalid export format (must be json, csv, or zip)",
			Code:    CodeValidationError,
		})
	}
	return errs
}
