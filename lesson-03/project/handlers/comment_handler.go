package handlers

import (
	"manage-system/models"
	"manage-system/services"
	"manage-system/utils"
	"net/http"
	"strconv"

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
	maxComments := make([]models.CommentMaxResponse, len(comments))
	for i, comment := range comments {
		maxComments[i] = models.CommentMaxResponse{
			ID:        comment.ID,
			Content:   comment.Content,
			CreatedAt: comment.CreatedAt,
		}
	}
	status := "暂无评论"
	if len(comments) > 0 {
		status = "评论数:" + strconv.Itoa(len(comments))
	}
	pr := models.PostMaxResponse{
		ID:        post.ID,
		Title:     post.Title,
		Content:   post.Content,
		CreatedAt: post.CreatedAt,
		Comments:  maxComments,
		Status:    status,
	}
	ppr := models.PostPageResponse{
		Posts: pr,
		Total: total,
	}

	utils.Success(c, ppr)

}
func (h *CommentHandler) DeleteComment(c *gin.Context) {
	var req models.DeleteCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ValidationError(c, parseValidationErrors(err))
		return
	}
	if err := h.commentService.DeleteComment(req.IDS); err != nil {
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
	postIDText, ok := c.Params.Get("postId")
	if !ok {
		utils.Error(c, http.StatusBadRequest, "Invalid post ID")
		return
	}
	postID, err := strconv.Atoi(postIDText)
	if err != nil || postID <= 0 {
		utils.Error(c, http.StatusBadRequest, "Invalid post ID")
		return
	}

	comments, total, err := h.commentService.GetCommentsByPostID(req.PageNo, req.PageSize, uint(postID))
	if err != nil {
		utils.HandleError(c, err)
		return
	}
	comentResponses := make([]models.CommentResponse, len(comments))

	for i, comment := range comments {
		comentResponses[i] = models.CommentResponse{
			ID:      comment.ID,
			Content: comment.Content,
			Post: models.PostResponse{
				ID:      comment.Post.ID,
				Content: comment.Post.Content,
				Title:   comment.Post.Title,
				User: models.UserResponse{
					ID:        comment.User.ID,
					Username:  comment.User.Username,
					Email:     comment.User.Email,
					PostNo:    comment.User.PostNo,
					CreatedAt: comment.User.CreatedAt,
				},
			},
			CreatedAt: comment.CreatedAt,
		}
	}

	utils.Success(c, gin.H{
		"comments": comentResponses,
		"total":    total,
	})

}
