package middleware

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

func TestIPJailingMiddleware(t *testing.T) {
	log := zap.NewNop()

	nextHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("allowed"))
	})

	t.Run("Normal traffic - allows requests", func(t *testing.T) {
		mr := miniredis.RunT(t)
		defer mr.Close()
		rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
		defer rdb.Close()

		mw := IPJailingMiddleware(rdb, log)
		handler := mw(nextHandler)

		// Make 5 requests under the 10 requests/sec limit
		for i := 0; i < 5; i++ {
			req := httptest.NewRequest("POST", "/v1/messages", nil)
			req.RemoteAddr = "1.2.3.4:12345"
			w := httptest.NewRecorder()
			handler.ServeHTTP(w, req)
			assert.Equal(t, http.StatusOK, w.Code)
		}
	})

	t.Run("Spam traffic - triggers jailing and blocks requests", func(t *testing.T) {
		mr := miniredis.RunT(t)
		defer mr.Close()
		rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
		defer rdb.Close()

		mw := IPJailingMiddleware(rdb, log)
		handler := mw(nextHandler)

		ip := "5.6.7.8"
		remoteAddr := ip + ":12345"

		// Send 10 requests (which are allowed under the limit of 10 requests/sec)
		for i := 0; i < 10; i++ {
			req := httptest.NewRequest("POST", "/v1/messages", nil)
			req.RemoteAddr = remoteAddr
			w := httptest.NewRecorder()
			handler.ServeHTTP(w, req)
			assert.Equal(t, http.StatusOK, w.Code)
		}

		// The 11th request in the same second should trigger jailing
		req11 := httptest.NewRequest("POST", "/v1/messages", nil)
		req11.RemoteAddr = remoteAddr
		w11 := httptest.NewRecorder()
		handler.ServeHTTP(w11, req11)
		assert.Equal(t, http.StatusForbidden, w11.Code)

		var resp struct {
			Error struct {
				Code    string `json:"code"`
				Message string `json:"message"`
			} `json:"error"`
		}
		err := json.Unmarshal(w11.Body.Bytes(), &resp)
		assert.NoError(t, err)
		assert.Equal(t, "FORBIDDEN", resp.Error.Code)
		assert.Contains(t, resp.Error.Message, "IP jailed due to spamming")

		// A 12th request from the same IP should immediately hit the jail check and be blocked
		req12 := httptest.NewRequest("POST", "/v1/messages", nil)
		req12.RemoteAddr = remoteAddr
		w12 := httptest.NewRecorder()
		handler.ServeHTTP(w12, req12)
		assert.Equal(t, http.StatusForbidden, w12.Code)

		// Request from a DIFFERENT IP should still be allowed
		reqOther := httptest.NewRequest("POST", "/v1/messages", nil)
		reqOther.RemoteAddr = "9.9.9.9:12345"
		wOther := httptest.NewRecorder()
		handler.ServeHTTP(wOther, reqOther)
		assert.Equal(t, http.StatusOK, wOther.Code)
	})

	t.Run("Jail expiration - automatically unjails after 10 minutes", func(t *testing.T) {
		mr := miniredis.RunT(t)
		defer mr.Close()
		rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
		defer rdb.Close()

		mw := IPJailingMiddleware(rdb, log)
		handler := mw(nextHandler)

		ip := "1.1.1.1"
		remoteAddr := ip + ":12345"

		// Exceed limit to jail the IP (11 requests, 11th is forbidden)
		for i := 0; i < 11; i++ {
			req := httptest.NewRequest("POST", "/v1/messages", nil)
			req.RemoteAddr = remoteAddr
			w := httptest.NewRecorder()
			handler.ServeHTTP(w, req)
			if i == 10 {
				assert.Equal(t, http.StatusForbidden, w.Code)
			} else {
				assert.Equal(t, http.StatusOK, w.Code)
			}
		}

		// Fast-forward miniredis by 11 minutes (TTL is 10 minutes)
		mr.FastForward(11 * time.Minute)

		// The IP should now be allowed to make requests again!
		reqAfter := httptest.NewRequest("POST", "/v1/messages", nil)
		reqAfter.RemoteAddr = remoteAddr
		wAfter := httptest.NewRecorder()
		handler.ServeHTTP(wAfter, reqAfter)
		assert.Equal(t, http.StatusOK, wAfter.Code)
	})

	t.Run("Redis offline - fails open/gracefully for availability", func(t *testing.T) {
		mr := miniredis.RunT(t)
		rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
		defer rdb.Close()

		mw := IPJailingMiddleware(rdb, log)
		handler := mw(nextHandler)

		// Close miniredis to simulate offline Redis
		mr.Close()

		req := httptest.NewRequest("POST", "/v1/messages", nil)
		req.RemoteAddr = "2.2.2.2:12345"
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, req)

		// Request should succeed despite Redis being down
		assert.Equal(t, http.StatusOK, w.Code)
		assert.Equal(t, "allowed", w.Body.String())
	})
}
