package services

import (
	"context"
	"encoding/json"
	"errors"
	"manage-system/models"
	"manage-system/utils"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/segmentio/kafka-go"
	"gorm.io/gorm"
)

type UserService struct {
	db          *gorm.DB
	cache       *redis.Client
	cacheTTL    time.Duration
	kafkaWriter *kafka.Writer
}

func NewUserService(db *gorm.DB) *UserService {
	return &UserService{db: db}
}

func (s *UserService) SetCache(client *redis.Client, ttl time.Duration) {
	s.cache = client
	s.cacheTTL = ttl
}

func (s *UserService) SetKafkaWriter(writer *kafka.Writer) {
	s.kafkaWriter = writer
}

// create a new user
func (s *UserService) CreateUser(ctx context.Context, req models.CreateUserRequest) (*models.User, error) {
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
	if s.kafkaWriter != nil {
		payload, err := json.Marshal(models.UserResponse{
			ID: user.ID, Username: user.Username, Email: user.Email, CreatedAt: user.CreatedAt,
		})
		if err == nil {
			publishContext, cancel := context.WithTimeout(ctx, 3*time.Second)
			err = s.kafkaWriter.WriteMessages(publishContext, kafka.Message{
				Key:   []byte(strconv.FormatUint(uint64(user.ID), 10)),
				Value: payload,
			})
			cancel()
		}
		if err != nil {
			utils.LogErrorWithTrace(ctx, "failed to publish user registration event", "error", err)
		}
	}

	return user, nil
}

// get user by id
func (s *UserService) GetUserByID(ctx context.Context, id uint) (*models.User, error) {
	cacheKey := "user:" + strconv.FormatUint(uint64(id), 10)
	if s.cache != nil {
		cached, err := s.cache.Get(ctx, cacheKey).Bytes()
		if err == nil {
			var user models.User
			if json.Unmarshal(cached, &user) == nil {
				return &user, nil
			}
			_ = s.cache.Del(ctx, cacheKey).Err()
		}
	}

	var user models.User
	if err := s.db.First(&user, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, utils.NewAppError(404, "User not found")
		}
		return nil, utils.NewAppError(500, "Failed to get user")
	}
	if s.cache != nil {
		if cached, err := json.Marshal(&user); err == nil {
			_ = s.cache.Set(ctx, cacheKey, cached, s.cacheTTL).Err()
		}
	}
	return &user, nil
}

// authenticate user by username and password
func (s *UserService) Authenticate(ctx context.Context, username, password string) (*models.User, error) {
	var user models.User
	if err := s.db.Where("username = ?", username).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, utils.NewAppError(401, "Invalid username or password")
		}
		return nil, err
	}
	utils.LogWithTrace(ctx, "user found in database")
	if err := utils.CheckPasswordHash(user.Password, password); err != nil {
		return nil, utils.NewAppError(401, "Invalid username or password")
	}
	utils.LogWithTrace(ctx, "user password verified")
	return &user, nil
}

// update user
func (s *UserService) UpdateUser(ctx context.Context, id uint, req models.UpdateUserRequest) (*models.User, error) {
	user, err := s.GetUserByID(ctx, id)
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
	if s.cache != nil {
		cacheKey := "user:" + strconv.FormatUint(uint64(id), 10)
		_ = s.cache.Del(ctx, cacheKey).Err()
	}

	return user, nil
}
