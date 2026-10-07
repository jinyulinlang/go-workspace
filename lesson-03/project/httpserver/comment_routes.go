package httpserver

import (
	"manage-system/handlers"
	"manage-system/services"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func newCommentHandler(router *gin.RouterGroup, db *gorm.DB) error {
	commentService := services.NewCommentService(db)
	handler, err := handlers.NewCommentHandler(commentService)
	if err != nil {
		return err
	}
	RegisterCommentRoutes(router, handler)
	return nil
}

func RegisterCommentRoutes(router *gin.RouterGroup, commentHandler *handlers.CommentHandler) {
	router.POST("/comments", commentHandler.CreateComment)
	router.GET("/comments/:postId/posts", commentHandler.GetCommentsByPostID)
	router.DELETE("/comments", commentHandler.DeleteComment)
	router.GET("/comments/max/posts", commentHandler.GetMaxCommentPost)
}
