package main

import (
	"log"
	"manage-system/config"
	"manage-system/handlers"
	"manage-system/middleware"
	"manage-system/models"
	"manage-system/services"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func main() {
	// load config
	config := config.Load()
	// init the database
	db, err := gorm.Open(sqlite.Open("users.db"), &gorm.Config{})
	if err != nil {
		log.Fatalf("failed to connect database:%v", err)
	}
	// auto migrate
	if err := db.AutoMigrate(&models.User{}); err != nil {
		log.Fatalf("failed to migrate database: %v", err)
	}

	// init services
	userService := services.NewUserService(db)

	// init handlers
	userHandler := handlers.NewUserHandler(userService, []byte(config.JWT.Secret))

	// create gin engine
	r := gin.Default()
	// global middleware
	r.Use(middleware.Logger()).Use(middleware.CORS())
	// create health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status": "ok",
		})
	})
	// create user routes
	// create public routes
	public := r.Group("/api/v1")
	{
		public.POST("/users/register", userHandler.Register)
		public.POST("/users/login", userHandler.Login)
	}
	// create  routes that require authentication
	private := r.Group("/api/v1")
	private.Use(middleware.Auth([]byte(config.JWT.Secret)))
	{
		private.GET("/users/me", userHandler.GetProfile)
		private.PUT("/users/me", userHandler.UpdateProfile)
	}

	addr := config.Server.Host + ":" + config.Server.Port
	log.Printf("server is running on %s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}

}
