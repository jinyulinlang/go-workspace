package middleware

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"strings"

	"manage-system/utils"

	"github.com/gin-gonic/gin"
)

const (
	TraceIDHeader = "X-Trace-ID"
	SpanIDHeader  = "X-Span-ID"
)

func Trace() gin.HandlerFunc {
	return func(c *gin.Context) {
		traceID := strings.ToLower(c.GetHeader(TraceIDHeader))
		if !isHexID(traceID, 32) {
			var err error
			traceID, err = newHexID(16)
			if err != nil {
				c.AbortWithStatus(http.StatusInternalServerError)
				return
			}
		}

		spanID, err := newHexID(8)
		if err != nil {
			c.AbortWithStatus(http.StatusInternalServerError)
			return
		}

		requestContext := utils.WithTraceIDs(c.Request.Context(), traceID, spanID)
		c.Request = c.Request.WithContext(requestContext)
		c.Set("traceID", traceID)
		c.Set("spanID", spanID)
		c.Header(TraceIDHeader, traceID)
		c.Header(SpanIDHeader, spanID)
		c.Next()
	}
}

func newHexID(size int) (string, error) {
	value := make([]byte, size)
	if _, err := rand.Read(value); err != nil {
		return "", err
	}
	return hex.EncodeToString(value), nil
}

func isHexID(value string, length int) bool {
	if len(value) != length {
		return false
	}
	_, err := hex.DecodeString(value)
	return err == nil
}
