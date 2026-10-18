package middleware

import (
	"log/slog"
	"runtime/debug"

	"manage-system/utils"

	"github.com/gin-gonic/gin"
)

func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if recovered := recover(); recovered != nil {
				traceID, spanID := utils.TraceIDs(c.Request.Context())
				slog.ErrorContext(c.Request.Context(), "http request panic recovered",
					"trace_id", traceID,
					"span_id", spanID,
					"method", c.Request.Method,
					"path", c.Request.URL.Path,
					"panic", recovered,
					"stack", string(debug.Stack()),
				)

				if !c.Writer.Written() {
					utils.Error(c, 500, "Internal Server Error")
				}
				c.Abort()
			}
		}()
		c.Next()
	}
}
