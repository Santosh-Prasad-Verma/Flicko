package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
)

// ValidationError describes a single field validation failure.
type ValidationError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
	Code    string `json:"code"`
}

// Validatable interface must be implemented by request DTOs.
type Validatable interface {
	Validate() []ValidationError
}

// ValidationErrors wraps a slice of ValidationError into an error type.
type ValidationErrors []ValidationError

func (ve ValidationErrors) Error() string {
	if len(ve) == 0 {
		return "validation error"
	}
	var parts []string
	for _, err := range ve {
		parts = append(parts, fmt.Sprintf("%s: %s", err.Field, err.Message))
	}
	return "validation failed: " + strings.Join(parts, "; ")
}

// DecodeAndValidate decodes the request JSON body into type T and executes its Validate method.
func DecodeAndValidate[T Validatable](r *http.Request) (T, error) {
	var v T
	if r == nil || r.Body == nil {
		return v, errors.New("request body is empty")
	}
	defer r.Body.Close()

	decoder := json.NewDecoder(r.Body)
	if err := decoder.Decode(&v); err != nil {
		if errors.Is(err, io.EOF) {
			return v, errors.New("request body is empty")
		}
		return v, fmt.Errorf("malformed JSON body: %w", err)
	}

	errs := v.Validate()
	if len(errs) > 0 {
		return v, ValidationErrors(errs)
	}

	return v, nil
}
