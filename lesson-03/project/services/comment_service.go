package services

import (
	"manage-system/models"
	"manage-system/utils"

	"gorm.io/gorm"
)

type CommentService struct {
	db *gorm.DB
}

func NewCommentService(db *gorm.DB) *CommentService {
	return &CommentService{db: db}
}

func (c *CommentService) CreateComment(userId uint, req *models.CreateCommentRequest) error {
	var comment models.Comment
	comment.UserID = userId
	comment.Content = req.Content
	comment.PostID = req.PostID
	if err := c.db.Create(&comment).Error; err != nil {
		return utils.NewAppError(500, "Failed to create comment")
	}
	return nil

}

func (c *CommentService) GetMaxCommentPost() (*models.Post, error) {
	var result struct {
		PostID uint  `gorm:"column:post_id"`
		Count  int64 `gorm:"column:count"`
	}

	if err := c.db.Model(&models.Comment{}).
		Select("post_id, COUNT(*) AS count").
		Group("post_id").
		Order("count DESC").
		Limit(1).
		Scan(&result).Error; err != nil {
		return nil, utils.NewAppError(500, "Failed to get max comment post")
	}

	if result.PostID == 0 {
		return nil, utils.NewAppError(404, "No post found")
	}
	var post models.Post
	if err := c.db.Model(&models.Post{}).Where("id = ?", result.PostID).First(&post).Error; err != nil {
		return nil, utils.NewAppError(500, "Failed to get post")
	}

	return &post, nil
}
func (c *CommentService) DeleteComment(ids []uint) error {
	if len(ids) == 0 {
		return utils.NewAppError(400, "No comment IDs provided")
	}
	if err := c.db.Where("id IN ?", ids).Delete(&models.Comment{}).Error; err != nil {
		return utils.NewAppError(500, "Failed to delete comment")
	}
	return nil
}

func (c *CommentService) GetAllComments(postId uint) ([]models.Comment, error) {
	var comments []models.Comment
	if err := c.db.Where("post_id = ?", postId).Find(&comments).Error; err != nil {
		return nil, utils.NewAppError(500, "Failed to get comments")
	}
	return comments, nil
}

func (s *CommentService) GetCommentsByPostID(
	pageNo int,
	pageSize int,
	postId uint,
) ([]models.Comment, int64, error) {
	var comments []models.Comment
	var total int64

	if err := s.db.Model(&models.Comment{}).
		Where("post_id = ?", postId).
		Count(&total).Error; err != nil {
		return nil, 0, utils.NewAppError(500, "Failed to count comments")
	}

	if err := s.db.Where("post_id = ?", postId).
		Preload("User").
		Preload("Post").
		Offset((pageNo - 1) * pageSize).
		Limit(pageSize).
		Find(&comments).Error; err != nil {
		return nil, 0, utils.NewAppError(500, "Failed to get comments")
	}

	return comments, total, nil
}
