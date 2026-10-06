package services

import (
	"context"
	"manage-system/models"
	"manage-system/utils"

	"gorm.io/gorm"
)

type PostService struct {
	db *gorm.DB
}

func NewPostService(db *gorm.DB) *PostService {
	return &PostService{db: db}
}

func (p *PostService) CreatePost(userId uint, ctx context.Context, req *models.CreatePostRequest) error {
	var post models.Post
	if err := p.db.Where("title = ?", req.Title).First(&post).Error; err == nil {
		return utils.NewAppError(500, "title hase existed")
	}
	post.UserID = userId
	post.Title = req.Title
	post.Content = req.Content
	if err := p.db.Create(post).Error; err != nil {
		return utils.NewAppError(500, "Failed to create post")
	}
	return nil
}
func (p *PostService) UpdatePost(post *models.Post) error {
	if err := p.db.Save(post).Error; err != nil {
		return utils.NewAppError(500, "Failed to update post")
	}
	return nil
}
func (p *PostService) DeletePost(ids []uint) error {
	if len(ids) == 0 {
		return utils.NewAppError(400, "No post IDs provided")
	}
	if err := p.db.Where("id IN ?", ids).Delete(&models.Post{}).Error; err != nil {
		return utils.NewAppError(500, "Failed to delete post")
	}
	return nil
}

func (p *PostService) GetAllPosts(pageNo int, pageSize int, post *models.Post) ([]models.Post, error) {
	var posts []models.Post
	var offset = (pageNo - 1) * pageSize
	if err := p.db.Offset(offset).Limit(pageSize).Find(&posts).Error; err != nil {
		return nil, utils.NewAppError(500, "Failed to get posts")
	}

	return posts, nil
}
func (p *PostService) GetPostByID(id uint) (*models.Post, error) {
	var post models.Post
	if err := p.db.First(&post, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, utils.NewAppError(404, "Post not found")
		}
		return nil, utils.NewAppError(500, "Failed to get post")
	}
	return &post, nil
}
