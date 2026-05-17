package music

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// SpotAPIClient calls the Python SpotAPI microservice.
// All Spotify interactions go through this service — the Go backend
// never talks to Spotify directly.
type SpotAPIClient struct {
	baseURL    string
	httpClient *http.Client
}

// NewSpotAPIClient creates a client for the SpotAPI service.
func NewSpotAPIClient(baseURL string) *SpotAPIClient {
	return &SpotAPIClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

// ── Request / Response types ──────────────────────────────────────────────────

type SearchResult struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Artist     string `json:"artist"`
	Album      string `json:"album"`
	DurationMs int    `json:"duration_ms"`
	ImageURL   string `json:"image_url"`
	URI        string `json:"uri"`
}

type SearchResponse struct {
	Tracks []SearchResult `json:"tracks"`
	Total  int            `json:"total"`
}

type PlaybackState struct {
	IsPlaying  bool   `json:"is_playing"`
	PositionMs int    `json:"position_ms"`
	TrackID    string `json:"track_id"`
	TrackName  string `json:"track_name"`
	Artist     string `json:"artist"`
	DurationMs int    `json:"duration_ms"`
}

type Device struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Type     string  `json:"type"`
	IsActive bool    `json:"is_active"`
	Volume   float64 `json:"volume"`
}

// ── Methods ───────────────────────────────────────────────────────────────────

// Search searches the Spotify catalog.
func (c *SpotAPIClient) Search(ctx context.Context, cookies SessionCookies, query string, limit int) (*SearchResponse, error) {
	req, err := c.newRequest(ctx, http.MethodGet, "/search/songs", nil, cookies)
	if err != nil {
		return nil, err
	}
	q := req.URL.Query()
	q.Set("q", query)
	q.Set("limit", fmt.Sprintf("%d", limit))
	req.URL.RawQuery = q.Encode()

	var result SearchResponse
	if err := c.do(req, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

// Play adds a track to the queue and skips to it.
func (c *SpotAPIClient) Play(ctx context.Context, cookies SessionCookies, trackID, deviceID string) error {
	body := map[string]string{"track_id": trackID, "device_id": deviceID}
	req, err := c.newRequest(ctx, http.MethodPost, "/player/play", body, cookies)
	if err != nil {
		return err
	}
	return c.do(req, nil)
}

// Pause pauses playback.
func (c *SpotAPIClient) Pause(ctx context.Context, cookies SessionCookies) error {
	req, err := c.newRequest(ctx, http.MethodPost, "/player/pause", nil, cookies)
	if err != nil {
		return err
	}
	return c.do(req, nil)
}

// Resume resumes playback.
func (c *SpotAPIClient) Resume(ctx context.Context, cookies SessionCookies) error {
	req, err := c.newRequest(ctx, http.MethodPost, "/player/resume", nil, cookies)
	if err != nil {
		return err
	}
	return c.do(req, nil)
}

// SkipNext skips to the next track.
func (c *SpotAPIClient) SkipNext(ctx context.Context, cookies SessionCookies) error {
	req, err := c.newRequest(ctx, http.MethodPost, "/player/skip-next", nil, cookies)
	if err != nil {
		return err
	}
	return c.do(req, nil)
}

// Seek seeks to a position in the current track.
func (c *SpotAPIClient) Seek(ctx context.Context, cookies SessionCookies, positionMs int) error {
	body := map[string]int{"position_ms": positionMs}
	req, err := c.newRequest(ctx, http.MethodPost, "/player/seek", body, cookies)
	if err != nil {
		return err
	}
	return c.do(req, nil)
}

// SetVolume sets playback volume (0.0–1.0).
func (c *SpotAPIClient) SetVolume(ctx context.Context, cookies SessionCookies, volume float64) error {
	body := map[string]float64{"volume": volume}
	req, err := c.newRequest(ctx, http.MethodPost, "/player/volume", body, cookies)
	if err != nil {
		return err
	}
	return c.do(req, nil)
}

// GetState returns the current playback state.
func (c *SpotAPIClient) GetState(ctx context.Context, cookies SessionCookies) (*PlaybackState, error) {
	req, err := c.newRequest(ctx, http.MethodGet, "/player/state", nil, cookies)
	if err != nil {
		return nil, err
	}
	var state PlaybackState
	if err := c.do(req, &state); err != nil {
		return nil, err
	}
	return &state, nil
}

// GetDevices returns available playback devices.
func (c *SpotAPIClient) GetDevices(ctx context.Context, cookies SessionCookies) ([]Device, error) {
	req, err := c.newRequest(ctx, http.MethodGet, "/player/devices", nil, cookies)
	if err != nil {
		return nil, err
	}
	var devices []Device
	if err := c.do(req, &devices); err != nil {
		return nil, err
	}
	return devices, nil
}

// ── Internal helpers ──────────────────────────────────────────────────────────

func (c *SpotAPIClient) newRequest(ctx context.Context, method, path string, body any, cookies SessionCookies) (*http.Request, error) {
	var bodyReader io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return nil, err
		}
		bodyReader = bytes.NewReader(data)
	}

	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, bodyReader)
	if err != nil {
		return nil, err
	}

	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	// Pass session cookies as a JSON header (SpotAPI service reads this)
	if len(cookies) > 0 {
		cookieJSON, _ := json.Marshal(cookies)
		req.Header.Set("X-Spotify-Session", string(cookieJSON))
	}

	return req, nil
}

func (c *SpotAPIClient) do(req *http.Request, dst any) error {
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("spotapi request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("spotapi error %d: %s", resp.StatusCode, string(body))
	}

	if dst != nil {
		return json.NewDecoder(resp.Body).Decode(dst)
	}
	return nil
}
