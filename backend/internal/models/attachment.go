package models

import "time"

// Attachment represents a file attached to a message
type Attachment struct {
	ID        string    `json:"id" db:"id"`
	MessageID string    `json:"message_id" db:"message_id"`
	Filename  string    `json:"filename" db:"filename"`
	Size      int64     `json:"size" db:"size"`
	MimeType  string    `json:"mime_type" db:"mime_type"`
	URL       string    `json:"url" db:"url"`
	Width     *int      `json:"width,omitempty" db:"width"`
	Height    *int      `json:"height,omitempty" db:"height"`
	IsMalware bool      `json:"is_malware" db:"is_malware"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

// AttachmentMetadata represents the data returned to the client immediately after upload,
// before the attachment is officially linked to a message.
type AttachmentMetadata struct {
	Hash     string `json:"hash"`
	URL      string `json:"url"`
	Filename string `json:"filename"`
	Size     int64  `json:"size"`
	MimeType string `json:"mime_type"`
	Width    *int   `json:"width,omitempty"`
	Height   *int   `json:"height,omitempty"`
}

// AllowedMimeTypes defines which files can be uploaded
var AllowedMimeTypes = []string{
	"image/jpeg",
	"image/png",
	"image/gif",
	"image/webp",
	"video/mp4",
	"video/webm",
	"application/pdf",
	"text/plain",
}

func IsMimeTypeAllowed(mimeType string) bool {
	for _, allowed := range AllowedMimeTypes {
		if mimeType == allowed {
			return true
		}
	}
	return false
}
