package handlers

import (
	"log"
	"manage-system/models"
	"manage-system/services"
	"manage-system/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type UserHandler struct {
	userService *services.UserService
	jwtSecret   []byte
}

func NewUserHandler(userService *services.UserService, jwtSecret []byte) *UserHandler {
	return &UserHandler{
		userService: userService,
		jwtSecret:   jwtSecret,
	}
}

// Register a new user
func (h *UserHandler) Register(c *gin.Context) {
	var req models.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Error(c, http.StatusBadRequest, "Invalid request1")
		return
	}
	user, err := h.userService.CreateUser(req)
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
	user, err := h.userService.Authenticate(req.Username, req.Password)
	if err != nil {
		utils.HandleError(c, err)
		return
	}
	log.Println("generate the token")
	token, err := utils.GenerateToken(h.jwtSecret, user.ID, user.Username)
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

	user, err := h.userService.GetUserByID(userID.(uint))
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
	user, err := h.userService.UpdateUser(userID.(uint), req)
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
