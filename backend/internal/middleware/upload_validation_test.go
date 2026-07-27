package middleware

import (
	"bytes"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.uber.org/zap"
)

func TestSniffAudioType(t *testing.T) {
	tests := []struct {
		name string
		buf  []byte
		want string
	}{
		{"mp3 with ID3v2 tag", []byte("ID3\x03\x00\x00\x00\x00\x00\x00rest"), "audio/mpeg"},
		// Bare MPEG frames carry no ID3 tag; http.DetectContentType reports
		// these as application/octet-stream, which is why we sniff ourselves.
		{"mp3 bare frame FFFB", []byte{0xFF, 0xFB, 0x90, 0x44, 0x00, 0x00}, "audio/mpeg"},
		{"mp3 bare frame FFF3", []byte{0xFF, 0xF3, 0x90, 0x44, 0x00, 0x00}, "audio/mpeg"},
		{"mp3 bare frame FFE0", []byte{0xFF, 0xE0, 0x00, 0x00}, "audio/mpeg"},
		{"wav", []byte("RIFF\x24\x08\x00\x00WAVEfmt "), "audio/wav"},
		{"ogg", []byte("OggS\x00\x02\x00\x00\x00\x00"), "audio/ogg"},

		// Non-audio must not be classified as audio.
		{"html payload", []byte("<html><script>alert(1)</script></html>"), ""},
		{"png", []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}, ""},
		{"jpeg", []byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10}, ""},
		{"elf binary", []byte{0x7F, 0x45, 0x4C, 0x46, 0x02, 0x01}, ""},
		{"php", []byte("<?php system($_GET['c']); ?>"), ""},
		{"empty", []byte{}, ""},
		{"single byte", []byte{0xFF}, ""},
		// RIFF container that is not WAVE (e.g. WebP) must be rejected.
		{"riff webp not wave", []byte("RIFF\x00\x00\x00\x00WEBPVP8 "), ""},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			assert.Equal(t, tc.want, SniffAudioType(tc.buf))
		})
	}
}

// JPEG starts with 0xFF 0xD8, which shares the first byte with an MPEG sync
// word. The frame check must not be loose enough to accept it.
func TestSniffAudioType_JPEGNotMistakenForMP3(t *testing.T) {
	jpeg := []byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46}
	assert.Empty(t, SniffAudioType(jpeg), "JPEG must not sniff as audio")
}

func multipartUploadRequest(t *testing.T, filename string, content []byte) *http.Request {
	t.Helper()

	var body bytes.Buffer
	w := multipart.NewWriter(&body)
	part, err := w.CreateFormFile("file", filename)
	require.NoError(t, err)
	_, err = part.Write(content)
	require.NoError(t, err)
	require.NoError(t, w.Close())

	req := httptest.NewRequest(http.MethodPost, "/servers/s1/soundboard", &body)
	req.Header.Set("Content-Type", w.FormDataContentType())
	return req
}

func TestAudioUploadValidationMiddleware(t *testing.T) {
	const maxSize = 5 * 1024 * 1024

	tests := []struct {
		name       string
		filename   string
		content    []byte
		wantStatus int
		wantNext   bool
	}{
		{
			name:       "valid mp3 passes",
			filename:   "sound.mp3",
			content:    []byte("ID3\x03\x00\x00\x00\x00\x00\x00audio data here"),
			wantStatus: http.StatusOK,
			wantNext:   true,
		},
		{
			name:       "valid wav passes",
			filename:   "sound.wav",
			content:    []byte("RIFF\x24\x08\x00\x00WAVEfmt more data"),
			wantStatus: http.StatusOK,
			wantNext:   true,
		},
		{
			// The core bypass: HTML renamed to .mp3. The extension check in the
			// handler would accept this; the content check must not.
			name:       "html disguised as mp3 is rejected",
			filename:   "payload.mp3",
			content:    []byte("<html><script>alert(document.cookie)</script></html>"),
			wantStatus: http.StatusBadRequest,
			wantNext:   false,
		},
		{
			name:       "png disguised as ogg is rejected",
			filename:   "image.ogg",
			content:    []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A},
			wantStatus: http.StatusBadRequest,
			wantNext:   false,
		},
		{
			name:       "svg disguised as wav is rejected",
			filename:   "vector.wav",
			content:    []byte(`<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>`),
			wantStatus: http.StatusBadRequest,
			wantNext:   false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			nextCalled := false
			next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				nextCalled = true
				w.WriteHeader(http.StatusOK)
			})

			mw := AudioUploadValidationMiddleware(maxSize, zap.NewNop())
			rec := httptest.NewRecorder()
			mw(next).ServeHTTP(rec, multipartUploadRequest(t, tc.filename, tc.content))

			assert.Equal(t, tc.wantStatus, rec.Code)
			assert.Equal(t, tc.wantNext, nextCalled, "downstream handler invocation")
		})
	}
}

// The middleware parses the form; the handler parses it again. Go returns early
// on the second call, but assert the handler can still read the file so the
// double-parse cannot silently break uploads.
func TestAudioUploadValidationMiddleware_HandlerCanStillReadFile(t *testing.T) {
	var gotName string
	var gotBytes []byte

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.NoError(t, r.ParseMultipartForm(5*1024*1024)) // second parse
		f, hdr, err := r.FormFile("file")
		require.NoError(t, err)
		defer f.Close()

		gotName = hdr.Filename
		buf := make([]byte, 32)
		n, _ := f.Read(buf)
		gotBytes = buf[:n]
		w.WriteHeader(http.StatusOK)
	})

	content := []byte("OggS\x00\x02\x00\x00\x00\x00payload")
	mw := AudioUploadValidationMiddleware(5*1024*1024, zap.NewNop())
	rec := httptest.NewRecorder()
	mw(next).ServeHTTP(rec, multipartUploadRequest(t, "clip.ogg", content))

	require.Equal(t, http.StatusOK, rec.Code)
	assert.Equal(t, "clip.ogg", gotName)
	assert.Equal(t, content, gotBytes, "handler must still see the full file body")
}

// Non-multipart requests (GET, JSON POST) must pass through untouched.
func TestAudioUploadValidationMiddleware_IgnoresNonUploads(t *testing.T) {
	for _, tc := range []struct {
		name        string
		method      string
		contentType string
	}{
		{"GET", http.MethodGet, ""},
		{"JSON POST", http.MethodPost, "application/json"},
		{"form POST", http.MethodPost, "application/x-www-form-urlencoded"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			nextCalled := false
			next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				nextCalled = true
				w.WriteHeader(http.StatusOK)
			})

			req := httptest.NewRequest(tc.method, "/servers/s1/soundboard", bytes.NewReader([]byte("{}")))
			if tc.contentType != "" {
				req.Header.Set("Content-Type", tc.contentType)
			}

			mw := AudioUploadValidationMiddleware(5*1024*1024, zap.NewNop())
			rec := httptest.NewRecorder()
			mw(next).ServeHTTP(rec, req)

			assert.True(t, nextCalled, "non-upload request must pass through")
			assert.Equal(t, http.StatusOK, rec.Code)
		})
	}
}
