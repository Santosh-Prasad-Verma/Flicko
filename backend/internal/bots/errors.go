package bots

import "errors"

// ErrPanic is returned by recovery wrappers to signal that the wrapped
// function panicked rather than returned an error normally.
var ErrPanic = errors.New("bot panicked")

// ErrInsufficientPermission is returned by command handlers when the caller
// does not have the required permission bit. It maps to a user-facing
// "permission denied" message; never log the bare value as an error.
var ErrInsufficientPermission = errors.New("insufficient permission")
