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

func (p *Post) AfterCreate(tx *gorm.DB) error {
	if p.UserID == 0 {
		return nil
	}

	return tx.Model(&User{}).
		Where("id = ?", p.UserID).
		UpdateColumn("post_no", gorm.Expr("post_no + ?", 1)).
		Error
}

func (p *Post) AfterDelete(tx *gorm.DB) error {
	if p.UserID == 0 {
		return nil
	}

	return tx.Model(&User{}).
		Where("id = ?", p.UserID).
		UpdateColumn("post_no", gorm.Expr("post_no - ?", 1)).
		Error
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
	Status    string    `json:"status"`
}

type PostPageResponse struct {
	Posts PostResponse `json:"posts"`
	Total int64        `json:"total"`
}
