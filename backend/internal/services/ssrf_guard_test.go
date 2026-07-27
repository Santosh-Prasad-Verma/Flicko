package services

import (
	"errors"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestIsBlockedIP(t *testing.T) {
	blocked := []struct {
		name string
		ip   string
	}{
		{"AWS/GCP metadata", "169.254.169.254"},
		{"Azure metadata alias", "169.254.169.254"},
		{"IPv4 loopback", "127.0.0.1"},
		{"IPv4 loopback range", "127.1.2.3"},
		{"RFC1918 10/8", "10.0.0.1"},
		{"RFC1918 172.16/12", "172.16.5.4"},
		{"RFC1918 192.168/16", "192.168.1.1"},
		{"unspecified v4", "0.0.0.0"},
		{"link-local", "169.254.1.1"},
		{"CGNAT", "100.64.0.1"},
		{"benchmarking", "198.18.0.1"},
		{"TEST-NET-1", "192.0.2.1"},
		{"reserved 240/4", "240.0.0.1"},
		{"multicast v4", "224.0.0.1"},
		{"IPv6 loopback", "::1"},
		{"IPv6 unspecified", "::"},
		{"IPv6 unique-local", "fd00::1"},
		{"IPv6 unique-local low bit", "fc00::1"},
		{"IPv6 link-local", "fe80::1"},
		{"IPv6 documentation", "2001:db8::1"},
		// IPv4-mapped IPv6 must not slip past the v4 predicates.
		{"v4-mapped loopback", "::ffff:127.0.0.1"},
		{"v4-mapped metadata", "::ffff:169.254.169.254"},
		{"v4-mapped RFC1918", "::ffff:10.0.0.1"},
	}

	for _, tc := range blocked {
		t.Run("blocked/"+tc.name, func(t *testing.T) {
			ip := net.ParseIP(tc.ip)
			require.NotNil(t, ip, "test fixture %q is not a valid IP", tc.ip)
			assert.True(t, isBlockedIP(ip), "%s (%s) should be blocked", tc.name, tc.ip)
		})
	}

	allowed := []struct {
		name string
		ip   string
	}{
		{"public v4", "93.184.216.34"},
		{"Cloudflare DNS", "1.1.1.1"},
		{"Google DNS", "8.8.8.8"},
		{"public v6", "2606:4700:4700::1111"},
		// Adjacent to a blocked range but outside it.
		{"just past CGNAT", "100.128.0.1"},
		{"just past 172.16/12", "172.32.0.1"},
	}

	for _, tc := range allowed {
		t.Run("allowed/"+tc.name, func(t *testing.T) {
			ip := net.ParseIP(tc.ip)
			require.NotNil(t, ip, "test fixture %q is not a valid IP", tc.ip)
			assert.False(t, isBlockedIP(ip), "%s (%s) should be allowed", tc.name, tc.ip)
		})
	}

	t.Run("nil is blocked", func(t *testing.T) {
		assert.True(t, isBlockedIP(nil))
	})
}

func TestValidateOutboundURL(t *testing.T) {
	valid := []string{
		"http://example.com",
		"https://example.com/path?q=1",
		"https://example.com:8443/x",
	}
	for _, raw := range valid {
		t.Run("valid/"+raw, func(t *testing.T) {
			assert.NoError(t, ValidateOutboundURL(raw))
		})
	}

	invalid := []struct {
		name string
		raw  string
	}{
		{"file scheme", "file:///etc/passwd"},
		{"gopher scheme", "gopher://example.com/"},
		{"ftp scheme", "ftp://example.com/"},
		{"no scheme", "example.com"},
		{"no host", "http://"},
		{"metadata IP literal", "http://169.254.169.254/latest/meta-data/"},
		{"loopback IP literal", "http://127.0.0.1:8080/admin"},
		{"RFC1918 IP literal", "http://10.0.0.5/internal"},
		{"IPv6 loopback literal", "http://[::1]:9000/"},
		{"v4-mapped loopback literal", "http://[::ffff:127.0.0.1]/"},
	}
	for _, tc := range invalid {
		t.Run("invalid/"+tc.name, func(t *testing.T) {
			assert.Error(t, ValidateOutboundURL(tc.raw))
		})
	}

	t.Run("blocked literal reports ErrBlockedDestination", func(t *testing.T) {
		err := ValidateOutboundURL("http://169.254.169.254/")
		require.Error(t, err)
		assert.True(t, errors.Is(err, ErrBlockedDestination),
			"want ErrBlockedDestination, got %v", err)
	})
}

// End-to-end proof that the guarded client refuses a real loopback listener.
// httptest servers bind to 127.0.0.1, so a client that can reach one would also
// be able to reach an internal service.
func TestNewSSRFSafeClient_BlocksLoopbackServer(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("internal secret")) //nolint:errcheck
	}))
	defer srv.Close()

	client := NewSSRFSafeClient(5*time.Second, 3)

	resp, err := client.Get(srv.URL)
	if resp != nil {
		resp.Body.Close() //nolint:errcheck
	}
	require.Error(t, err, "guarded client must not connect to a loopback address")
	assert.ErrorIs(t, err, ErrBlockedDestination)
}

// A redirect chain must not be able to walk into the internal network after an
// initially public-looking request.
func TestNewSSRFSafeClient_BlocksRedirectToLoopback(t *testing.T) {
	internal := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("internal secret")) //nolint:errcheck
	}))
	defer internal.Close()

	redirector := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, internal.URL, http.StatusFound)
	}))
	defer redirector.Close()

	client := NewSSRFSafeClient(5*time.Second, 3)

	// The first hop is itself loopback here, so this asserts the dialer refuses
	// the chain rather than asserting anything about redirect bookkeeping.
	resp, err := client.Get(redirector.URL)
	if resp != nil {
		resp.Body.Close() //nolint:errcheck
	}
	require.Error(t, err)
	assert.ErrorIs(t, err, ErrBlockedDestination)
}

func TestNewSSRFSafeClient_RejectsNonHTTPRedirectScheme(t *testing.T) {
	client := NewSSRFSafeClient(5*time.Second, 3)
	require.NotNil(t, client.CheckRedirect)

	req := httptest.NewRequest(http.MethodGet, "https://example.com/next", nil)
	req.URL.Scheme = "file"

	err := client.CheckRedirect(req, nil)
	assert.Error(t, err, "redirect to a non-HTTP scheme must be refused")
}

func TestNewSSRFSafeClient_CapsRedirects(t *testing.T) {
	const maxRedirects = 3
	client := NewSSRFSafeClient(5*time.Second, maxRedirects)
	require.NotNil(t, client.CheckRedirect)

	req := httptest.NewRequest(http.MethodGet, "https://example.com/next", nil)

	// Under the cap: allowed.
	assert.NoError(t, client.CheckRedirect(req, make([]*http.Request, maxRedirects-1)))
	// At the cap: refused.
	assert.Error(t, client.CheckRedirect(req, make([]*http.Request, maxRedirects)))
}

// Proxy configuration would route the connection to the proxy rather than the
// vetted address, bypassing the dialer's checks entirely.
func TestNewSSRFSafeClient_HasNoProxy(t *testing.T) {
	client := NewSSRFSafeClient(5*time.Second, 3)

	transport, ok := client.Transport.(*http.Transport)
	require.True(t, ok, "expected *http.Transport")
	assert.Nil(t, transport.Proxy, "proxy would bypass the guarded dialer")
}
