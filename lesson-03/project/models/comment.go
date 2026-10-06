package models

import (
	"time"

	"gorm.io/gorm"
)

type Comment struct {
	gorm.Model
	Content string `json:"content" gorm:"not null"`
	UserID  uint   `json:"user_id" gorm:"not null"`
	User    User   `json:"user" gorm:"foreignKey:UserID"`
	PostID  uint   `json:"post_id" gorm:"not null"`
	Post    Post   `json:"post" gorm:"foreignKey:PostID"`
}

type CreateCommentRequest struct {
	Content string `json:"content" binding:"required"`
	PostID  uint   `json:"post_id" binding:"required"`
}

type CommentQueryRequest struct {
	PostID   uint `json:"post_id" binding:"required"`
	PageNo   int  `json:"page_no" binding:"required"`
	PageSize int  `json:"page_size" binding:"required"`
}
type CommentResponse struct {
	ID        uint      `json:"id"`
	Content   string    `json:"content"`
	User      User      `json:"user"`
	Post      Post      `json:"post"`
	CreatedAt time.Time `json:"created_at"`
}
