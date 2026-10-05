package httpserver

import (
	"manage-system/config"
	"manage-system/middleware"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/segmentio/kafka-go"
	"gorm.io/gorm"
)

func NewRouter(cfg *config.Config, db *gorm.DB, redisClient *redis.Client, kafkaWriter *kafka.Writer) (*gin.Engine, error) {
	router := gin.New()
	router.Use(middleware.Trace(), middleware.Logger(), middleware.Recovery(), middleware.CORS())
	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
	api_prefix := router.Group("/api/v1")
	public_api := api_prefix.Group("public")
	private_api := api_prefix.Group("private")
	private_api.Use(middleware.Auth([]byte(cfg.JWT.Secret)))
	if err := newUserHandler(public_api, private_api, db, cfg, redisClient, kafkaWriter); err != nil {
		return nil, err
	}

	return router, nil
}
