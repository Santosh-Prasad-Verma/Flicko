# Forms & Validation
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Validation Library
File: `shared/utils/validation.utils.ts` (6.2 KB)

### Available Validators
- `validateEmail(email)` — RFC-compliant email validation
- `validateUsername(username)` — Length, character rules
- `validatePassword(password)` — Strength requirements
- `validateServerName(name)` — Server name rules
- `validateChannelName(name)` — Channel name rules
- `validateMessageContent(content)` — Length limits (4000 chars)

### Password Validation
File: `backend/internal/services/password_validator.go` (4.7 KB)

Server-side password validation with entropy checks.

## Form Patterns
Forms use controlled components with Riverpod state:
1. Local component state for input values
2. Validation on submit
3. Error display inline
4. Loading state during API calls
