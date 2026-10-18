package middleware

import (
	"log/slog"
	"manage-system/utils"
	"time"

	"github.com/gin-gonic/gin"
)

// Logger is a middleware that logs the request method, path, status code, and latency.
func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		method := c.Request.Method
		c.Next()
		latency := time.Since(start)
		status := c.Writer.Status()
		traceID, spanID := utils.TraceIDs(c.Request.Context())
		slog.InfoContext(c.Request.Context(), "http request completed",
			"trace_id", traceID,
			"span_id", spanID,
			"method", method,
			"path", path,
			"status", status,
			"latency_ms", float64(latency)/float64(time.Millisecond),
		)
	}
}
