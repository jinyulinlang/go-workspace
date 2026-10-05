package main

import (
	"log/slog"
	"manage-system/clients"
	"manage-system/config"
	"manage-system/database"
	"manage-system/handlers"
	"manage-system/middleware"
	"manage-system/models"
	"manage-system/services"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	cfg, err := config.Load()
	if err != nil {
		fatal("failed to load config", err)
	}
	gin.SetMode(cfg.Server.Mode)

	db, err := database.Open(cfg.Database)
	if err != nil {
		fatal("failed to connect database", err)
	}
	if err := db.AutoMigrate(&models.User{}); err != nil {
		fatal("failed to migrate database", err)
	}

	userService := services.NewUserService(db)
	if cfg.Redis.Enabled {
		redisClient, err := clients.NewRedisClient(cfg.Redis)
		if err != nil {
			fatal("failed to initialize Redis", err)
		}
		cacheTTL, err := time.ParseDuration(cfg.Redis.CacheTTL)
		if err != nil {
			fatal("invalid redis.cache_ttl", err)
		}
		userService.SetCache(redisClient, cacheTTL)
		defer redisClient.Close()
	}

	if cfg.Kafka.Enabled {
		writer := clients.NewKafkaWriter(cfg.Kafka)
		userService.SetKafkaWriter(writer)
		defer writer.Close()
	}

	jwtTTL, err := time.ParseDuration(cfg.JWT.Expire)
	if err != nil {
		fatal("invalid jwt.expire", err)
	}
	userHandler := handlers.NewUserHandler(userService, []byte(cfg.JWT.Secret), jwtTTL)

	r := gin.New()
	r.Use(middleware.Trace(), middleware.Logger(), gin.Recovery(), middleware.CORS())
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status": "ok",
		})
	})
	public := r.Group("/api/v1")
	{
		public.POST("/users/register", userHandler.Register)
		public.POST("/users/login", userHandler.Login)
	}
	private := r.Group("/api/v1")
	private.Use(middleware.Auth([]byte(cfg.JWT.Secret)))
	{
		private.GET("/users/me", userHandler.GetProfile)
		private.PUT("/users/me", userHandler.UpdateProfile)
	}

	addr := cfg.Server.Host + ":" + cfg.Server.Port
	slog.Info("server started", "address", addr)
	if err := r.Run(addr); err != nil {
		fatal("failed to start server", err)
	}
}

func fatal(message string, err error) {
	slog.Error(message, "error", err)
	os.Exit(1)
}
