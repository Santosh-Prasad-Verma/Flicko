package services

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// ErrBlockedDestination is returned when a request targets an address that is
// not reachable from the public internet.
var ErrBlockedDestination = errors.New("blocked destination: address is not publicly routable")

// blockedNets lists ranges that net.IP's own predicates do not already cover.
// Loopback, link-local, private (RFC1918), multicast and unspecified addresses
// are handled by isBlockedIP via the stdlib helpers.
var blockedNets = func() []*net.IPNet {
	cidrs := []string{
		"100.64.0.0/10",   // RFC 6598 carrier-grade NAT
		"192.0.0.0/24",    // RFC 6890 IETF protocol assignments
		"192.0.2.0/24",    // TEST-NET-1
		"198.18.0.0/15",   // RFC 2544 benchmarking
		"198.51.100.0/24", // TEST-NET-2
		"203.0.113.0/24",  // TEST-NET-3
		"240.0.0.0/4",     // reserved
		"::/128",          // unspecified
		"64:ff9b::/96",    // NAT64
		"100::/64",        // discard-only
		"2001:db8::/32",   // documentation
	}
	nets := make([]*net.IPNet, 0, len(cidrs))
	for _, c := range cidrs {
		if _, n, err := net.ParseCIDR(c); err == nil {
			nets = append(nets, n)
		}
	}
	return nets
}()

// isBlockedIP reports whether ip is outside the publicly routable space and so
// must not be reached by a user-influenced request.
func isBlockedIP(ip net.IP) bool {
	if ip == nil {
		return true
	}

	// Normalise IPv4-in-IPv6 (e.g. ::ffff:127.0.0.1) so an attacker cannot
	// smuggle a loopback address past the v4 checks.
	if v4 := ip.To4(); v4 != nil {
		ip = v4
	}

	if ip.IsLoopback() || ip.IsPrivate() || ip.IsUnspecified() ||
		ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() ||
		ip.IsInterfaceLocalMulticast() || ip.IsMulticast() {
		return true
	}

	// IPv6 unique-local (fc00::/7). No stdlib predicate covers this.
	if len(ip) == net.IPv6len && ip.To4() == nil && ip[0]&0xfe == 0xfc {
		return true
	}

	for _, n := range blockedNets {
		if n.Contains(ip) {
			return true
		}
	}

	return false
}

// ValidateOutboundURL checks that raw is a syntactically valid absolute HTTP(S)
// URL. It deliberately does NOT resolve the host: DNS results can change between
// a pre-flight check and the actual dial, so address filtering belongs in the
// dialer (see NewSSRFSafeClient). Use this to reject obviously unsuitable input
// early and cheaply.
func ValidateOutboundURL(raw string) error {
	u, err := url.Parse(raw)
	if err != nil {
		return fmt.Errorf("invalid URL: %w", err)
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return fmt.Errorf("unsupported scheme %q", u.Scheme)
	}
	if u.Host == "" {
		return errors.New("URL has no host")
	}
	// A bare IP literal can be rejected without a lookup.
	host := u.Hostname()
	if ip := net.ParseIP(host); ip != nil && isBlockedIP(ip) {
		return fmt.Errorf("%w: %s", ErrBlockedDestination, host)
	}
	return nil
}

// ssrfSafeDialContext resolves the target host and refuses to connect if any
// resolved address is non-public.
//
// Validating every returned address and then dialing one of those same
// addresses (rather than re-resolving the hostname) closes the DNS-rebinding
// window that a check-then-connect approach leaves open: the connection is made
// to an address that has already been vetted.
func ssrfSafeDialContext(dialer *net.Dialer) func(context.Context, string, string) (net.Conn, error) {
	return func(ctx context.Context, network, addr string) (net.Conn, error) {
		host, port, err := net.SplitHostPort(addr)
		if err != nil {
			return nil, fmt.Errorf("invalid address %q: %w", addr, err)
		}

		ips, err := net.DefaultResolver.LookupIPAddr(ctx, host)
		if err != nil {
			return nil, fmt.Errorf("resolve %q: %w", host, err)
		}
		if len(ips) == 0 {
			return nil, fmt.Errorf("resolve %q: no addresses", host)
		}

		// Reject if ANY resolved address is non-public. Dialing only the "good"
		// subset of a mixed result would let a hostname that intentionally
		// resolves to both a public and a private address through.
		for _, ip := range ips {
			if isBlockedIP(ip.IP) {
				return nil, fmt.Errorf("%w: %s resolves to %s", ErrBlockedDestination, host, ip.IP)
			}
		}

		var lastErr error
		for _, ip := range ips {
			conn, err := dialer.DialContext(ctx, network, net.JoinHostPort(ip.IP.String(), port))
			if err == nil {
				return conn, nil
			}
			lastErr = err
		}
		return nil, lastErr
	}
}

// NewSSRFSafeClient returns an HTTP client for fetching user-supplied URLs.
//
// It blocks connections to non-public addresses (cloud metadata endpoints,
// loopback, RFC1918, link-local), caps redirects, and re-checks the scheme on
// every hop so a public URL cannot redirect into the internal network.
func NewSSRFSafeClient(timeout time.Duration, maxRedirects int) *http.Client {
	dialer := &net.Dialer{Timeout: 5 * time.Second, KeepAlive: 15 * time.Second}

	return &http.Client{
		Timeout: timeout,
		Transport: &http.Transport{
			DialContext:           ssrfSafeDialContext(dialer),
			TLSHandshakeTimeout:   5 * time.Second,
			ResponseHeaderTimeout: timeout,
			DisableKeepAlives:     true,
			MaxIdleConns:          10,
			// Proxying would bypass the guarded dialer entirely, since the
			// connection would be made to the proxy instead of the target.
			Proxy: nil,
		},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= maxRedirects {
				return fmt.Errorf("stopped after %d redirects", maxRedirects)
			}
			if s := strings.ToLower(req.URL.Scheme); s != "http" && s != "https" {
				return fmt.Errorf("redirect to unsupported scheme %q", req.URL.Scheme)
			}
			return nil
		},
	}
}
