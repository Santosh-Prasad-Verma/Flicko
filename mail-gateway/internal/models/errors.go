// Package models — error definitions for validation.
package models

import "errors"

var (
	// ErrMissingType is returned when the webhook payload has no type field.
	ErrMissingType = errors.New("missing required field: type")

	// ErrMissingEmail is returned when the webhook payload has no user email.
	ErrMissingEmail = errors.New("missing required field: user.email")

	// ErrMissingToken is returned when neither token nor token_hash is present.
	ErrMissingToken = errors.New("missing required field: data.token or data.token_hash")
)
