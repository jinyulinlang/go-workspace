package handlers

import (
	"manage-system/models"
	"manage-system/services"
	"manage-system/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type PostHandler struct {
	postService    *services.PostService
	commentService *services.CommentService
}

func NewPostHandler(postService *services.PostService, commentService *services.CommentService) (*PostHandler, error) {
	return &PostHandler{postService: postService, commentService: commentService}, nil
}

func (h *PostHandler) CreatePost(c *gin.Context) {
	var req models.CreatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request")
		return
	}
	userID, exists := c.Get("userID")
	if !exists {
		utils.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	id, ok := userID.(uint)
	if !ok {
		utils.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	if err := h.postService.CreatePost(id, c.Request.Context(), &req); err != nil {
		utils.HandleError(c, err)
		return
	}
	utils.Success(c, nil)
}
func (h *PostHandler) GetPostByID(c *gin.Context) {
	id, ok := c.Params.Get("id")
	if !ok {
		utils.Error(c, http.StatusBadRequest, "Invalid post ID")
		return
	}
	postId, err := strconv.Atoi(id)
	if err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid post ID")
		return
	}
	if postId <= 0 {
		utils.Error(c, http.StatusBadRequest, "Invalid post ID")
		return
	}
	post, err := h.postService.GetPostByID(uint(postId))
	if err != nil {
		utils.HandleError(c, err)
		return
	}

	comments, _, err := h.commentService.GetCommentsByPostID(1, 10, uint(postId))
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
		User:      post.User,
	}

	utils.Success(c, pr)
}
func (h *PostHandler) UpdatePost(c *gin.Context) {
	userId, exists := c.Get("userID")
	if !exists {
		utils.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	id, ok := userId.(uint)
	if !ok {
		utils.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	var req models.UpdatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request")
		return
	}
	post, err := h.postService.GetPostByID(req.ID)
	if err != nil {
		utils.HandleError(c, err)
		return
	}
	if post.UserID != id {
		utils.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	post.Title = req.Title
	post.Content = req.Content

	if err := h.postService.UpdatePost(post); err != nil {
		utils.HandleError(c, err)
		return
	}
	utils.Success(c, nil)

}

func (h *PostHandler) DeleteByIds(c *gin.Context) {
	var ids []uint
	if err := c.ShouldBindJSON(&ids); err != nil {
		utils.ValidationError(c, parseValidationErrors(err))
		return
	}
	userId, exists := c.Get("userID")
	if !exists {
		utils.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	id, ok := userId.(uint)
	if !ok {
		utils.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	for _, postId := range ids {
		post, err := h.postService.GetPostByID(postId)
		if err != nil {
			utils.HandleError(c, err)
			return
		}
		if post.UserID != id {
			utils.Error(c, http.StatusUnauthorized, "Unauthorized")
			return
		}
	}

	if err := h.postService.DeletePost(ids); err != nil {
		utils.HandleError(c, err)
		return
	}

}
