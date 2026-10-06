package httpserver

import (
	"manage-system/handlers"
	"manage-system/services"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func newPostHandler(router *gin.RouterGroup, db *gorm.DB) error {
	postService := services.NewPostService(db)
	commentService := services.NewCommentService(db)

	handler, err := handlers.NewPostHandler(postService, commentService)
	if err != nil {
		return err
	}
	RegisterPostRoutes(router, handler)
	return nil
}

func RegisterPostRoutes(router *gin.RouterGroup, postHandler *handlers.PostHandler) {
	router.POST("/posts", postHandler.CreatePost)
	router.GET("/posts/:id", postHandler.GetPostByID)
	router.PUT("/posts/:id", postHandler.UpdatePost)
	router.DELETE("/posts", postHandler.DeleteByIds)
}
