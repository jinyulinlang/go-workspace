package unit_test

import (
	"net/http/httptest"
	"regexp"
	"testing"

	"manage-system/middleware"
	"manage-system/utils"

	"github.com/gin-gonic/gin"
)

func TestTraceMiddlewareSetsResponseHeadersAndContext(t *testing.T) {
	previousMode := gin.Mode()
	gin.SetMode(gin.TestMode)
	t.Cleanup(func() { gin.SetMode(previousMode) })

	const incomingTraceID = "0123456789abcdef0123456789abcdef"
	router := gin.New()
	router.Use(middleware.Trace())
	router.GET("/", func(c *gin.Context) {
		traceID, spanID := utils.TraceIDs(c.Request.Context())
		c.Header("X-Context-Trace-ID", traceID)
		c.Header("X-Context-Span-ID", spanID)
	})

	req := httptest.NewRequest("GET", "/", nil)
	req.Header.Set(middleware.TraceIDHeader, incomingTraceID)
	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, req)

	if got := recorder.Header().Get(middleware.TraceIDHeader); got != incomingTraceID {
		t.Fatalf("trace ID response header = %q, want %q", got, incomingTraceID)
	}
	spanID := recorder.Header().Get(middleware.SpanIDHeader)
	if !regexp.MustCompile(`^[0-9a-f]{16}$`).MatchString(spanID) {
		t.Fatalf("span ID response header = %q, want 16 lowercase hex characters", spanID)
	}
	if got := recorder.Header().Get("X-Context-Trace-ID"); got != incomingTraceID {
		t.Fatalf("trace ID in request context = %q, want %q", got, incomingTraceID)
	}
	if got := recorder.Header().Get("X-Context-Span-ID"); got != spanID {
		t.Fatalf("span ID in request context = %q, want response header %q", got, spanID)
	}
}
