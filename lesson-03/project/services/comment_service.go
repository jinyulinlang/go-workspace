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
	if err := c.db.Create(comment).Error; err != nil {
		return utils.NewAppError(500, "Failed to create comment")
	}
	return nil

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
        Offset((pageNo - 1) * pageSize).
        Limit(pageSize).
        Find(&comments).Error; err != nil {
        return nil, 0, utils.NewAppError(500, "Failed to get comments")
    }

    return comments, total, nil
}

