package handlers

import (
	"manage-system/models"
	"manage-system/services"
	"manage-system/utils"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type UserHandler struct {
	userService *services.UserService
	jwtSecret   []byte
	jwtTTL      time.Duration
}

func NewUserHandler(userService *services.UserService, jwtSecret []byte, jwtTTL time.Duration) *UserHandler {
	return &UserHandler{
		userService: userService,
		jwtSecret:   jwtSecret,
		jwtTTL:      jwtTTL,
	}
}

// Register a new user
func (h *UserHandler) Register(c *gin.Context) {
	var req models.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request1")
		return
	}
	user, err := h.userService.CreateUser(c.Request.Context(), req)
	if err != nil {
		utils.HandleError(c, err)
		return
	}
	utils.Success(c, models.UserResponse{
		ID:       user.ID,
		Username: user.Username,
		Email:    user.Email,
	})

}

// Login

func (h *UserHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request")
		return
	}
	user, err := h.userService.Authenticate(c.Request.Context(), req.Username, req.Password)
	if err != nil {
		utils.HandleError(c, err)
		return
	}
	utils.LogWithTrace(c.Request.Context(), "generating authentication token")
	token, err := utils.GenerateToken(h.jwtSecret, user.ID, user.Username, h.jwtTTL)
	if err != nil {
		utils.HandleError(c, err)
		return
	}

	utils.Success(c, gin.H{
		"token": token,
		"user": models.UserResponse{
			ID:        user.ID,
			Username:  user.Username,
			Email:     user.Email,
			CreatedAt: user.CreatedAt},
	})
}

// get profile

func (h *UserHandler) GetProfile(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		utils.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}

	user, err := h.userService.GetUserByID(c.Request.Context(), userID.(uint))
	if err != nil {
		utils.HandleError(c, err)
		return
	}
	utils.Success(c, models.UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		Email:     user.Email,
		CreatedAt: user.CreatedAt,
	})
}

// update profile
func (h *UserHandler) UpdateProfile(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		utils.Error(c, http.StatusUnauthorized, "Unauthorized")
		return
	}
	var req models.UpdateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ValidationError(c, parseValidationErrors(err))
		return
	}
	user, err := h.userService.UpdateUser(c.Request.Context(), userID.(uint), req)
	if err != nil {
		utils.HandleError(c, err)
		return
	}
	utils.Success(c, models.UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		Email:     user.Email,
		CreatedAt: user.CreatedAt,
	})
}
func parseValidationErrors(err error) map[string]string {
	errors := make(map[string]string)
	// simpify the error message
	errors["general"] = err.Error()
	return errors
}
