package services

import (
	"errors"
	"log"
	"manage-system/models"
	"manage-system/utils"

	"gorm.io/gorm"
)

type UserService struct {
	db *gorm.DB
}

func NewUserService(db *gorm.DB) *UserService {
	return &UserService{db: db}
}

// create a new user
func (s *UserService) CreateUser(req models.CreateUserRequest) (*models.User, error) {
	// check if the username or email already exists
	var existingUser models.User
	if err := s.db.Where("username = ? OR email = ?", req.Username, req.Email).First(&existingUser).Error; err == nil {
		return nil, utils.NewAppError(409, "Username or email already exists")
	}
	// encrypt the password
	hashedPassword, err := utils.HashPassword(req.Password)
	if err != nil {
		return nil, utils.NewAppError(500, "Failed to hash password")
	}

	user := &models.User{
		Username: req.Username,
		Email:    req.Email,
		Password: string(*hashedPassword),
	}
	if err := s.db.Create(user).Error; err != nil {
		return nil, utils.NewAppError(500, "Failed to create user")
	}

	return user, nil
}

// get user by id
func (s *UserService) GetUserByID(id uint) (*models.User, error) {
	var user models.User
	if err := s.db.First(&user, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, utils.NewAppError(404, "User not found")
		}
		return nil, utils.NewAppError(500, "Failed to get user")
	}
	return &user, nil
}

// authenticate user by username and password
func (s *UserService) Authenticate(username, password string) (*models.User, error) {
	var user models.User
	if err := s.db.Where("username = ?", username).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, utils.NewAppError(401, "Invalid username or password")
		}
		return nil, err
	}
	log.Println("user has been finded in database")
	if err := utils.CheckPasswordHash(user.Password, password); err != nil {
		return nil, utils.NewAppError(401, "Invalid username or password")
	}
	log.Println("user password has been checked")
	return &user, nil
}

// update user
func (s *UserService) UpdateUser(id uint, req models.UpdateUserRequest) (*models.User, error) {
	user, err := s.GetUserByID(id)
	if err != nil {
		return nil, err
	}

	if req.Email != "" && req.Email != user.Email {
		var existingUser models.User
		if err := s.db.Where("email = ?", req.Email).First(&existingUser).Error; err == nil {
			return nil, utils.NewAppError(409, "Email already exists")
		}
		user.Email = req.Email
	}

	if err := s.db.Save(user).Error; err != nil {
		return nil, err
	}

	return user, nil
}
