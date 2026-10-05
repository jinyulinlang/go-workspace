package httpserver

import (
	"fmt"
	"manage-system/config"
	"manage-system/handlers"
	"manage-system/services"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/segmentio/kafka-go"
	"gorm.io/gorm"
)

type userRouteRegistrar func(*gin.RouterGroup, gin.HandlerFunc)

func registerUserRoute(api *gin.RouterGroup, handler gin.HandlerFunc) {
	api.POST("/users/register", handler)
}

func registerLoginRoute(api *gin.RouterGroup, handler gin.HandlerFunc) {
	api.POST("/users/login", handler)
}

func newUserHandler(public_api *gin.RouterGroup, private_api *gin.RouterGroup, db *gorm.DB, cfg *config.Config, redisClient *redis.Client, kafkaWriter *kafka.Writer, registerUser, registerLogin userRouteRegistrar) error {
	userService := services.NewUserService(db)
	if redisClient != nil {
		cacheTTL, err := time.ParseDuration(cfg.Redis.CacheTTL)
		if err != nil {
			return fmt.Errorf("parse redis.cache_ttl: %w", err)
		}
		userService.SetCache(redisClient, cacheTTL)
	}
	if kafkaWriter != nil {
		userService.SetKafkaWriter(kafkaWriter)
	}
	userHandler, err := handlers.NewUserHandler(userService, []byte(cfg.JWT.Secret), cfg.JWT.Expire)
	if err != nil {
		return err
	}

	registerUser(public_api, userHandler.Register)
	registerLogin(public_api, userHandler.Login)

	private_api.GET("/users/me", userHandler.GetProfile)
	private_api.PUT("/users/me", userHandler.UpdateProfile)

	return nil
}
