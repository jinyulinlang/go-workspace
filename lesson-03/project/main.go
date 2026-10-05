package main

import (
	"log/slog"
	"manage-system/app"
	"os"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	if err := app.Run(); err != nil {
		slog.Error("application stopped", "error", err)
		os.Exit(1)
	}
}
