package protocol

import "testing"

func TestCloseText(t *testing.T) {
tests := []struct {
code int
want string
}{
{CloseUnknownError, "unknown error"},
{CloseInvalidPayload, "invalid message payload"},
{CloseNotAuthenticated, "not authenticated"},
{CloseAuthFailed, "authentication failed"},
{CloseAlreadyAuthenticated, "already authenticated"},
{CloseRateLimited, "rate limited"},
{CloseSessionTimeout, "session timed out"},
{CloseInvalidChannel, "invalid channel"},
{CloseServerFull, "server full"},
{9999, "unknown error"},
}
for _, tc := range tests {
got := CloseText(tc.code)
if got != tc.want {
t.Errorf("CloseText(%d) = %q, want %q", tc.code, got, tc.want)
}
}
}

func TestCloseCode_Values(t *testing.T) {
// Verify exact values from the architecture doc.
tests := []struct {
name string
code int
want int
}{
{"Unknown", CloseUnknownError, 4000},
{"InvalidPayload", CloseInvalidPayload, 4001},
{"NotAuthenticated", CloseNotAuthenticated, 4003},
{"AuthFailed", CloseAuthFailed, 4004},
{"AlreadyAuthenticated", CloseAlreadyAuthenticated, 4005},
{"RateLimited", CloseRateLimited, 4008},
{"SessionTimeout", CloseSessionTimeout, 4009},
{"InvalidChannel", CloseInvalidChannel, 4010},
{"ServerFull", CloseServerFull, 4011},
}
for _, tc := range tests {
t.Run(tc.name, func(t *testing.T) {
if tc.code != tc.want {
t.Errorf("%s = %d, architecture requires %d", tc.name, tc.code, tc.want)
}
})
}
}

func TestIsRetryableClose(t *testing.T) {
retryable := []int{CloseRateLimited, CloseSessionTimeout, CloseServerFull}
for _, code := range retryable {
if !IsRetryableClose(code) {
t.Errorf("CloseCode %d (%s) should be retryable", code, CloseText(code))
}
}

nonRetryable := []int{
CloseUnknownError, CloseInvalidPayload, CloseNotAuthenticated,
CloseAuthFailed, CloseAlreadyAuthenticated, CloseInvalidChannel,
}
for _, code := range nonRetryable {
if IsRetryableClose(code) {
t.Errorf("CloseCode %d (%s) should NOT be retryable", code, CloseText(code))
}
}
}
