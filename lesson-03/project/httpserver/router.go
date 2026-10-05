package httpserver

import (
	"manage-system/handlers"
	"manage-system/middleware"

	"github.com/gin-gonic/gin"
)

func NewRouter(jwtSecret []byte, userHandler *handlers.UserHandler) *gin.Engine {
	router := gin.New()
	router.Use(middleware.Trace(), middleware.Logger(), middleware.Recovery(), middleware.CORS())
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	public := router.Group("/api/v1")
	public.POST("/users/register", userHandler.Register)
	public.POST("/users/login", userHandler.Login)

	private := router.Group("/api/v1")
	private.Use(middleware.Auth(jwtSecret))
	private.GET("/users/me", userHandler.GetProfile)
	private.PUT("/users/me", userHandler.UpdateProfile)

	return router
}
