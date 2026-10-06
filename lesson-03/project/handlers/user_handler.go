package handlers

import (
	"fmt"
	"manage-system/models"
	"manage-system/services"
	"manage-system/utils"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type UserHandler struct {
	userService *services.UserService
	jwtSecret   []byte
	jwtTTL      time.Duration
}

func NewUserHandler(userService *services.UserService, jwtSecret []byte, jwtExpire string) (*UserHandler, error) {
	jwtTTL, err := time.ParseDuration(jwtExpire)
	if err != nil {
		return nil, fmt.Errorf("parse jwt.expire: %w", err)
	}

	return &UserHandler{
		userService: userService,
		jwtSecret:   jwtSecret,
		jwtTTL:      jwtTTL,
	}, nil
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
		PostNo:   user.PostNo,
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
			PostNo:    user.PostNo,
			CreatedAt: user.CreatedAt,
		},
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
		PostNo:    user.PostNo,
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
		PostNo:    user.PostNo,
		CreatedAt: user.CreatedAt,
	})
}

func (h *UserHandler) GetUserPostRank(c *gin.Context) {
	limit := 10
	if raw := c.Query("limit"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	users, err := h.userService.GetUserPostRank(limit)
	if err != nil {
		utils.HandleError(c, err)
		return
	}

	responses := make([]models.UserResponse, 0, len(users))
	for _, user := range users {
		responses = append(responses, models.UserResponse{
			ID:        user.ID,
			Username:  user.Username,
			Email:     user.Email,
			PostNo:    user.PostNo,
			CreatedAt: user.CreatedAt,
		})
	}

	utils.Success(c, responses)
}

func parseValidationErrors(err error) map[string]string {
	errors := make(map[string]string)
	// simpify the error message
	errors["general"] = err.Error()
	return errors
}
