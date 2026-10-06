package models

import (
	"time"

	"gorm.io/gorm"
)

type Post struct {
	gorm.Model
	Title   string `json:"title" gorm:"uniqueIndex;not null"`
	Content string `json:"content" gorm:"not null"`
	UserID  uint   `json:"user_id" gorm:"not null"`
	User    User   `json:"user" gorm:"foreignKey:UserID"`
}

type CreatePostRequest struct {
	Title   string `json:"title" binding:"required"`
	Content string `json:"content" binding:"required"`
}

type UpdatePostRequest struct {
	ID      uint   `json:"id" binding:"required"`
	Title   string `json:"title"`
	Content string `json:"content"`
}

type PostResponse struct {
	ID        uint      `json:"id"`
	Title     string    `json:"title"`
	Content   string    `json:"content"`
	User      User      `json:"user"`
	Comments  []Comment `json:"comments"`
	CreatedAt time.Time `json:"created_at"`
}

type PostPageResponse struct {
	Posts PostResponse `json:"posts"`
	Total int64        `json:"total"`
}
