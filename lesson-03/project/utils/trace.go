package utils

import (
	"context"
	"log/slog"
)

type traceContextKey struct{}

type traceContext struct {
	traceID string
	spanID  string
}

func WithTraceIDs(ctx context.Context, traceID, spanID string) context.Context {
	return context.WithValue(ctx, traceContextKey{}, traceContext{
		traceID: traceID,
		spanID:  spanID,
	})
}

func TraceIDs(ctx context.Context) (string, string) {
	trace, ok := ctx.Value(traceContextKey{}).(traceContext)
	if !ok {
		return "-", "-"
	}
	return trace.traceID, trace.spanID
}

func LogWithTrace(ctx context.Context, message string, args ...any) {
	traceID, spanID := TraceIDs(ctx)
	logArgs := make([]any, 0, len(args)+4)
	logArgs = append(logArgs, "trace_id", traceID, "span_id", spanID)
	logArgs = append(logArgs, args...)
	slog.InfoContext(ctx, message, logArgs...)
}

func LogErrorWithTrace(ctx context.Context, message string, args ...any) {
	traceID, spanID := TraceIDs(ctx)
	logArgs := make([]any, 0, len(args)+4)
	logArgs = append(logArgs, "trace_id", traceID, "span_id", spanID)
	logArgs = append(logArgs, args...)
	slog.ErrorContext(ctx, message, logArgs...)
}
