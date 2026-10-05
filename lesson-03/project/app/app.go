package app

import (
	"fmt"
	"log/slog"
	"manage-system/clients"
	"manage-system/config"
	"manage-system/database"
	"manage-system/handlers"
	"manage-system/httpserver"
	"manage-system/models"
	"manage-system/services"
	"time"

	"github.com/gin-gonic/gin"
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

	userService := services.NewUserService(db)
	if cfg.Redis.Enabled {
		redisClient, err := clients.NewRedisClient(cfg.Redis)
		if err != nil {
			return fmt.Errorf("initialize Redis: %w", err)
		}
		defer closeRedis(redisClient)

		cacheTTL, err := time.ParseDuration(cfg.Redis.CacheTTL)
		if err != nil {
			return fmt.Errorf("parse redis.cache_ttl: %w", err)
		}
		userService.SetCache(redisClient, cacheTTL)
	}

	if cfg.Kafka.Enabled {
		writer := clients.NewKafkaWriter(cfg.Kafka)
		defer closeKafka(writer)
		userService.SetKafkaWriter(writer)
	}

	jwtTTL, err := time.ParseDuration(cfg.JWT.Expire)
	if err != nil {
		return fmt.Errorf("parse jwt.expire: %w", err)
	}
	userHandler := handlers.NewUserHandler(userService, []byte(cfg.JWT.Secret), jwtTTL)
	router := httpserver.NewRouter([]byte(cfg.JWT.Secret), userHandler)
	addr := cfg.Server.Host + ":" + cfg.Server.Port
	slog.Info("server started", "address", addr)
	if err := router.Run(addr); err != nil {
		return fmt.Errorf("run HTTP server: %w", err)
	}
	return nil
}
