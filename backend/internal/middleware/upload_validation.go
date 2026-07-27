package middleware

import (
	"bytes"
	"io"
	"net/http"

	"go.uber.org/zap"
)

// Allowlists for the upload routes. Only formats that http.DetectContentType
// identifies reliably belong in the image list.
var (
	// AllowedImageUploadTypes covers the channel-background route.
	AllowedImageUploadTypes = []string{"image/jpeg", "image/png", "image/webp"}
)

// SniffAudioType reports the audio container format of buf, or "" if buf is not
// a recognised audio file.
//
// This exists because http.DetectContentType cannot classify audio usefully: a
// bare MP3 frame returns "application/octet-stream", WAV returns "audio/wave"
// rather than "audio/wav", and OGG returns "application/ogg". Relying on it for
// an audio allowlist would reject most legitimate uploads while still accepting
// anything it failed to sniff, so the container signatures are checked directly.
func SniffAudioType(buf []byte) string {
	// MP3 with an ID3v2 tag.
	if len(buf) >= 3 && bytes.Equal(buf[:3], []byte("ID3")) {
		return "audio/mpeg"
	}
	// Bare MPEG audio frame: 11 sync bits.
	if len(buf) >= 2 && buf[0] == 0xFF && buf[1]&0xE0 == 0xE0 {
		return "audio/mpeg"
	}
	// RIFF/WAVE.
	if len(buf) >= 12 && bytes.Equal(buf[:4], []byte("RIFF")) && bytes.Equal(buf[8:12], []byte("WAVE")) {
		return "audio/wav"
	}
	// Ogg (Vorbis or Opus).
	if len(buf) >= 4 && bytes.Equal(buf[:4], []byte("OggS")) {
		return "audio/ogg"
	}
	return ""
}

// AudioUploadValidationMiddleware rejects multipart uploads whose file contents
// are not a recognised audio container.
//
// A filename extension is attacker-controlled, so it cannot be the authority on
// file type: an HTML payload renamed to .mp3 would otherwise reach a public
// storage bucket and be served back as markup. This inspects the leading bytes
// of every uploaded part instead.
func AudioUploadValidationMiddleware(maxSize int64, logger *zap.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if !isMultipartUpload(r) {
				next.ServeHTTP(w, r)
				return
			}

			// Parsing here is safe: ParseMultipartForm is a no-op once the form
			// has already been parsed, so the downstream handler's own call
			// still succeeds and FormFile continues to work.
			if err := r.ParseMultipartForm(maxSize); err != nil {
				logger.Warn("audio upload: failed to parse multipart form",
					zap.String("remote_addr", r.RemoteAddr), zap.Error(err))
				writeJSONError(w, http.StatusRequestEntityTooLarge, "UPLOAD_TOO_LARGE", "File too large or malformed")
				return
			}

			for _, files := range r.MultipartForm.File {
				for _, fh := range files {
					if fh.Size > maxSize {
						writeJSONError(w, http.StatusRequestEntityTooLarge, "FILE_TOO_LARGE", "File exceeds size limit")
						return
					}

					f, err := fh.Open()
					if err != nil {
						writeJSONError(w, http.StatusBadRequest, "FILE_READ_ERROR", "Could not read file")
						return
					}

					buf := make([]byte, 512)
					n, err := f.Read(buf)
					f.Close() //nolint:errcheck // read-only handle on a parsed part
					if err != nil && err != io.EOF {
						writeJSONError(w, http.StatusBadRequest, "FILE_READ_ERROR", "Could not read file")
						return
					}

					detected := SniffAudioType(buf[:n])
					if detected == "" {
						logger.Warn("audio upload rejected: unrecognised container",
							zap.String("remote_addr", r.RemoteAddr),
							zap.String("filename", fh.Filename),
							zap.String("sniffed_as", http.DetectContentType(buf[:n])),
						)
						writeJSONError(w, http.StatusBadRequest, "FILE_TYPE_NOT_ALLOWED",
							"File contents are not a supported audio format (mp3, wav, ogg)")
						return
					}
				}
			}

			next.ServeHTTP(w, r)
		})
	}
}

func isMultipartUpload(r *http.Request) bool {
	if r.Method != http.MethodPost && r.Method != http.MethodPut && r.Method != http.MethodPatch {
		return false
	}
	ct := r.Header.Get("Content-Type")
	return len(ct) >= 19 && ct[:19] == "multipart/form-data"
}
