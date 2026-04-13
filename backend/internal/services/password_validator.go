// HIGH-004: Strong Password Validation
// Enforces minimum password requirements including length, complexity,
// and checks against common password lists
package services

import (
	"fmt"
	"regexp"
	"strings"
	"unicode"
)

// PasswordRequirements defines minimum password complexity requirements
type PasswordRequirements struct {
	MinLength           int
	RequireUppercase    bool
	RequireLowercase    bool
	RequireDigits       bool
	RequireSpecialChars bool
	DisallowCommonWords bool
}

// DefaultPasswordRequirements represents strong production requirements
var DefaultPasswordRequirements = PasswordRequirements{
	MinLength:           12,
	RequireUppercase:    true,
	RequireLowercase:    true,
	RequireDigits:       true,
	RequireSpecialChars: true,
	DisallowCommonWords: true,
}

// CommonWeakPasswords contains frequently used weak passwords to block
var CommonWeakPasswords = map[string]bool{
	"password":    true,
	"123456":      true,
	"qwerty":      true,
	"abc123":      true,
	"password123": true,
	"admin":       true,
	"letmein":     true,
	"welcome":     true,
	"monkey":      true,
	"dragon":      true,
	"1234567890":  true,
	"qwertyuiop":  true,
	"111111":      true,
	"000000":      true,
	"iloveyou":    true,
	"trustno1":    true,
	"123456789":   true,
	"sunshine":    true,
	"master":      true,
	"azerty":      true,
}

// ValidatePassword checks if password meets all requirements
func ValidatePassword(password string, requirements PasswordRequirements) error {
	if len(password) < requirements.MinLength {
		return fmt.Errorf("password must be at least %d characters long", requirements.MinLength)
	}

	if requirements.RequireUppercase && !containsUppercase(password) {
		return fmt.Errorf("password must contain at least one uppercase letter")
	}

	if requirements.RequireLowercase && !containsLowercase(password) {
		return fmt.Errorf("password must contain at least one lowercase letter")
	}

	if requirements.RequireDigits && !containsDigit(password) {
		return fmt.Errorf("password must contain at least one digit")
	}

	if requirements.RequireSpecialChars && !containsSpecialChar(password) {
		return fmt.Errorf("password must contain at least one special character (!@#$%%^&*)")
	}

	if requirements.DisallowCommonWords && isCommonPassword(password) {
		return fmt.Errorf("password is too common; please choose a stronger password")
	}

	return nil
}

// containsUppercase checks if string has at least one uppercase letter
func containsUppercase(s string) bool {
	for _, r := range s {
		if unicode.IsUpper(r) {
			return true
		}
	}
	return false
}

// containsLowercase checks if string has at least one lowercase letter
func containsLowercase(s string) bool {
	for _, r := range s {
		if unicode.IsLower(r) {
			return true
		}
	}
	return false
}

// containsDigit checks if string has at least one digit
func containsDigit(s string) bool {
	for _, r := range s {
		if unicode.IsDigit(r) {
			return true
		}
	}
	return false
}

// containsSpecialChar checks if string has special characters
func containsSpecialChar(s string) bool {
	specialChars := "!@#$%^&*()-_=+[]{}|;':\",./<>?"
	for _, char := range s {
		if strings.ContainsRune(specialChars, char) {
			return true
		}
	}
	return false
}

// isCommonPassword checks if password is in the common passwords list
func isCommonPassword(password string) bool {
	lowerPassword := strings.ToLower(password)

	// Direct match
	if CommonWeakPasswords[lowerPassword] {
		return true
	}

	// Check for trivial variations
	if isVariantOfCommon(lowerPassword) {
		return true
	}

	return false
}

// isVariantOfCommon checks for simple variations of common passwords
func isVariantOfCommon(password string) bool {
	// Remove common transformations and check
	stripped := stripNumbers(password)
	if CommonWeakPasswords[stripped] {
		return true
	}

	// Check if password starts with a common word
	for common := range CommonWeakPasswords {
		if strings.HasPrefix(password, common) && len(password) < len(common)+10 {
			return true
		}
	}

	return false
}

// stripNumbers removes all digits from string
func stripNumbers(s string) string {
	reg := regexp.MustCompile("[0-9]")
	return reg.ReplaceAllString(s, "")
}

// EstimatePasswordStrength returns a strength rating (0-4)
// 0 = very weak, 4 = very strong
func EstimatePasswordStrength(password string) int {
	score := 0

	if len(password) >= 8 {
		score++
	}
	if len(password) >= 12 {
		score++
	}
	if len(password) >= 16 {
		score++
	}

	if containsUppercase(password) && containsLowercase(password) {
		score++
	}
	if containsDigit(password) {
		score++
	}
	if containsSpecialChar(password) {
		score++
	}

	if isCommonPassword(password) {
		return 0
	}

	// Cap at 4
	if score > 4 {
		score = 4
	}

	return score
}
