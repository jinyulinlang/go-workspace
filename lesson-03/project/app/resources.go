package app

import (
	"database/sql"
	"log/slog"

	"github.com/redis/go-redis/v9"
	"github.com/segmentio/kafka-go"
)

func closeDatabase(db *sql.DB) {
	if err := db.Close(); err != nil {
		slog.Error("close database connection", "error", err)
	}
}

func closeRedis(client *redis.Client) {
	if err := client.Close(); err != nil {
		slog.Error("close Redis client", "error", err)
	}
}

func closeKafka(writer *kafka.Writer) {
	if err := writer.Close(); err != nil {
		slog.Error("close Kafka writer", "error", err)
	}
}
