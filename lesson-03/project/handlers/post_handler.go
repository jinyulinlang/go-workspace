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
	status := "暂无评论"
	if len(comments) != 0 {
		status = string("有" + strconv.Itoa(len(comments)) + "条评论")
	}
	pr := models.PostResponse{
		ID:        post.ID,
		Title:     post.Title,
		Content:   post.Content,
		CreatedAt: post.CreatedAt,
		Comments:  comments,
		User: models.UserResponse{
			ID:        post.UserID,
			Username:  post.User.Username,
			Email:     post.User.Email,
			PostNo:    post.User.PostNo,
			CreatedAt: post.User.CreatedAt,
		},
		Status: status,
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
	postId, ok := c.Params.Get("id")
	if !ok {
		utils.Error(c, http.StatusUnauthorized, "postId can not empty")
		return
	}
	var req models.UpdatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request")
		return
	}
	// postId cast to int
	pid, err := strconv.Atoi(postId)
	if err != nil {
		utils.HandleError(c, err)
		return
	}

	post, err := h.postService.GetPostByID(uint(pid))
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
	var req models.DeletePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
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
	for _, postId := range req.IDS {
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

	if err := h.postService.DeletePost(id, req.IDS); err != nil {
		utils.HandleError(c, err)
		return
	}

}
