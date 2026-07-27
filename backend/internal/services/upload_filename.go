package services

import (
	"path/filepath"
	"regexp"
	"strings"
)

// unsafeFilenameChars matches every character not permitted in a stored object
// name. Backslashes are excluded from the allowlist deliberately: filepath.Base
// does not treat "\" as a separator on Linux, so a Windows-style payload such as
// `..\..\etc\passwd` survives Base() and must be neutralised here.
var unsafeFilenameChars = regexp.MustCompile(`[^A-Za-z0-9._-]`)

// maxUploadFilenameLen bounds the stored name. Supabase object keys also carry a
// user/channel prefix and a 64-char hash, so this leaves ample headroom.
const maxUploadFilenameLen = 128

// SanitizeUploadFilename reduces a client-supplied filename to a single safe
// path segment for use in an object storage key.
//
// Client filenames are attacker-controlled and must never be interpolated into
// a storage path directly — `../../other-user/avatar.png` would otherwise let an
// uploader write outside their own prefix. This strips directory components,
// replaces unsafe characters, and refuses names that carry no usable content.
//
// Returns an empty string when the input cannot be made safe; callers must
// treat that as a validation failure and reject the upload.
func SanitizeUploadFilename(name string) string {
	// Strip directory components. Base() also collapses trailing separators.
	name = filepath.Base(strings.TrimSpace(name))

	// Base() maps empty and separator-only input to "." or "/".
	if name == "." || name == ".." || name == "" || name == string(filepath.Separator) {
		return ""
	}

	name = unsafeFilenameChars.ReplaceAllString(name, "_")

	// A leading dot creates a hidden file and, for names like "..foo", keeps
	// traversal-adjacent text in the key. Strip leading dots entirely.
	name = strings.TrimLeft(name, ".")

	// Reject names that held nothing but separators, dots, or unsafe bytes.
	if strings.Trim(name, "._-") == "" {
		return ""
	}

	if len(name) > maxUploadFilenameLen {
		ext := filepath.Ext(name)
		if len(ext) >= maxUploadFilenameLen {
			// Pathological extension; drop it rather than slice into it.
			return name[:maxUploadFilenameLen]
		}
		name = name[:maxUploadFilenameLen-len(ext)] + ext
	}

	return name
}
