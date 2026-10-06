package handlers

import (
	"manage-system/models"
	"manage-system/services"
	"manage-system/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type CommentHandler struct {
	commentService *services.CommentService
}

func NewCommentHandler(commentService *services.CommentService) (*CommentHandler, error) {
	return &CommentHandler{commentService: commentService}, nil
}

func (h *CommentHandler) CreateComment(c *gin.Context) {
	userId, exists := c.Get("userID")
	if !exists {
		utils.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	var req models.CreateCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ValidationError(c, parseValidationErrors(err))
		return
	}
	if err := h.commentService.CreateComment(userId.(uint), &req); err != nil {
		utils.HandleError(c, err)
		return
	}

}
func (h *CommentHandler) GetMaxCommentPost(c *gin.Context) {
	post, err := h.commentService.GetMaxCommentPost()
	if err != nil {
		utils.HandleError(c, err)
		return
	}
	comments, total, err := h.commentService.GetCommentsByPostID(1, 10, post.ID)
	if err != nil {
		utils.HandleError(c, err)
		return
	}
	pr := models.PostResponse{
		ID:        post.ID,
		Title:     post.Title,
		Content:   post.Content,
		CreatedAt: post.CreatedAt,
		Comments:  comments,
	}
	ppr := models.PostPageResponse{
		Posts: pr,
		Total: total,
	}

	utils.Success(c, ppr)

}
func (h *CommentHandler) DeleteComment(c *gin.Context) {
	var ids []uint
	if err := c.ShouldBindJSON(&ids); err != nil {
		utils.ValidationError(c, parseValidationErrors(err))
		return
	}
	if err := h.commentService.DeleteComment(ids); err != nil {
		utils.HandleError(c, err)
		return
	}

}

func (h *CommentHandler) GetCommentsByPostID(c *gin.Context) {
	var req models.CommentQueryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ValidationError(c, parseValidationErrors(err))
		return
	}
	comments, total, err := h.commentService.GetCommentsByPostID(req.PageNo, req.PageSize, req.PostID)
	if err != nil {
		utils.HandleError(c, err)
		return
	}
	comentResponses := make([]models.CommentResponse, len(comments))

	for i, comment := range comments {
		comentResponses[i] = models.CommentResponse{
			ID:        comment.ID,
			Content:   comment.Content,
			User:      comment.User,
			Post:      comment.Post,
			CreatedAt: comment.CreatedAt,
		}
	}

	utils.Success(c, gin.H{
		"comments": comentResponses,
		"total":    total,
	})

}
