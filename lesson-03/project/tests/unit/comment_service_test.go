package unit_test

import (
	"testing"

	"manage-system/models"
	"manage-system/services"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func TestGetMaxCommentPost(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	if err := db.AutoMigrate(&models.Post{}, &models.Comment{}); err != nil {
		t.Fatalf("migrate tables: %v", err)
	}

	posts := []models.Post{
		{Title: "post-1", Content: "first post", UserID: 1},
		{Title: "post-2", Content: "second post", UserID: 2},
	}
	if err := db.Create(&posts).Error; err != nil {
		t.Fatalf("seed posts: %v", err)
	}

	comments := []models.Comment{
		{Content: "a", UserID: 1, PostID: posts[0].ID},
		{Content: "b", UserID: 1, PostID: posts[0].ID},
		{Content: "c", UserID: 2, PostID: posts[1].ID},
		{Content: "d", UserID: 2, PostID: posts[1].ID},
		{Content: "e", UserID: 3, PostID: posts[1].ID},
	}
	if err := db.Create(&comments).Error; err != nil {
		t.Fatalf("seed comments: %v", err)
	}

	service := services.NewCommentService(db)
	post, err := service.GetMaxCommentPost()
	if err != nil {
		t.Fatalf("GetMaxCommentPost returned error: %v", err)
	}
	if post == nil {
		t.Fatal("GetMaxCommentPost returned nil post")
	}
	if post.ID != posts[1].ID {
		t.Fatalf("post.ID = %d, want %d", post.ID, posts[1].ID)
	}
	if post.Title != "post-2" {
		t.Fatalf("post.Title = %q, want %q", post.Title, "post-2")
	}
}
