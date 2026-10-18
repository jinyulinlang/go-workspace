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
	api := router.Group("/api/v1")
	public := api.Group("")
	private := api.Group("")
	private.Use(middleware.Auth([]byte(cfg.JWT.Secret)))
	if err := newUserHandler(public, private, db, cfg, redisClient, kafkaWriter, registerUserRoute, registerLoginRoute); err != nil {
		return nil, err
	}
	if err := newPostHandler(private, db); err != nil {
		return nil, err
	}
	if err := newCommentHandler(private, db); err != nil {
		return nil, err
	}

	return router, nil
}
