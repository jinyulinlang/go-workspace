package unit_test

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http/httptest"
	"strings"
	"testing"

	"manage-system/middleware"
	"manage-system/utils"

	"github.com/gin-gonic/gin"
)

func TestRecoveryReturnsGenericJSONOnPanic(t *testing.T) {
	previousMode := gin.Mode()
	gin.SetMode(gin.TestMode)
	t.Cleanup(func() { gin.SetMode(previousMode) })

	previousLogger := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(io.Discard, nil)))
	t.Cleanup(func() { slog.SetDefault(previousLogger) })

	router := gin.New()
	router.Use(middleware.Trace(), middleware.Recovery())
	router.GET("/", func(*gin.Context) {
		panic("sensitive panic details")
	})

	recorder := httptest.NewRecorder()
	router.ServeHTTP(recorder, httptest.NewRequest("GET", "/", nil))

	if recorder.Code != 500 {
		t.Fatalf("status = %d, want %d", recorder.Code, 500)
	}
	var response utils.Response
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if response.Code != 500 || response.Message != "Internal Server Error" {
		t.Fatalf("response = %+v, want generic internal server error", response)
	}
	if got := recorder.Header().Get(middleware.TraceIDHeader); got == "" {
		t.Fatal("trace ID response header is empty")
	}
	if got := recorder.Header().Get(middleware.SpanIDHeader); got == "" {
		t.Fatal("span ID response header is empty")
	}
	if recorder.Body.String() == "" || strings.Contains(recorder.Body.String(), "sensitive panic details") {
		t.Fatal("response must not expose panic details")
	}
}
