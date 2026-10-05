package app

import (
	"fmt"
	"log/slog"
	"manage-system/clients"
	"manage-system/config"
	"manage-system/database"
	"manage-system/httpserver"
	"manage-system/models"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/segmentio/kafka-go"
)

func Run() error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}
	gin.SetMode(cfg.Server.Mode)

	db, err := database.Open(cfg.Database)
	if err != nil {
		return fmt.Errorf("connect database: %w", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		return fmt.Errorf("get database connection: %w", err)
	}
	defer closeDatabase(sqlDB)
	if err := db.AutoMigrate(&models.User{}); err != nil {
		return fmt.Errorf("migrate database: %w", err)
	}

	var redisClient *redis.Client
	if cfg.Redis.Enabled {
		redisClient, err = clients.NewRedisClient(cfg.Redis)
		if err != nil {
			return fmt.Errorf("initialize Redis: %w", err)
		}
		defer closeRedis(redisClient)
	}

	var writer *kafka.Writer
	if cfg.Kafka.Enabled {
		writer = clients.NewKafkaWriter(cfg.Kafka)
		defer closeKafka(writer)
	}

	router, err := httpserver.NewRouter(cfg, db, redisClient, writer)
	if err != nil {
		return fmt.Errorf("create HTTP router: %w", err)
	}
	addr := cfg.Server.Host + ":" + cfg.Server.Port
	slog.Info("server started", "address", addr)
	if err := router.Run(addr); err != nil {
		return fmt.Errorf("run HTTP server: %w", err)
	}
	return nil
}
