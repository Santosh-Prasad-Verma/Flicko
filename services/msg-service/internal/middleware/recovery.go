package middleware

import (
	"encoding/json"
	"net/http"
	"runtime/debug"

	"go.uber.org/zap"

	fkerr "github.com/flicko-org/flicko/services/shared/errors"
)

// Recovery catches panics and returns a 500 JSON error.
func Recovery(log *zap.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rv := recover(); rv != nil {
					log.Error("panic recovered",
						zap.Any("panic", rv),
						zap.String("stack", string(debug.Stack())),
						zap.String("method", r.Method),
						zap.String("path", r.URL.Path),
						zap.String("rid", GetRequestID(r.Context())),
					)

					// Write 500 using the shared error format.
					err := fkerr.ErrInternal(nil)
					code := fkerr.GetCode(err)
					msg := fkerr.GetMessage(err)
					status := fkerr.HTTPStatus(err)

					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(status)
					_ = json.NewEncoder(w).Encode(map[string]interface{}{
						"error": map[string]interface{}{
							"code":    string(code),
							"message": msg,
						},
					})
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}
