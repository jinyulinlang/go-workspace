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

func TestGetCommentsByPostIDPreloadsAssociations(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	if err := db.AutoMigrate(&models.User{}, &models.Post{}, &models.Comment{}); err != nil {
		t.Fatalf("migrate tables: %v", err)
	}

	user := models.User{Username: "commenter", Email: "commenter@example.com", Password: "password"}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("seed user: %v", err)
	}
	post := models.Post{Title: "post-1", Content: "first post", UserID: user.ID}
	if err := db.Create(&post).Error; err != nil {
		t.Fatalf("seed post: %v", err)
	}
	comment := models.Comment{Content: "hello", UserID: user.ID, PostID: post.ID}
	if err := db.Create(&comment).Error; err != nil {
		t.Fatalf("seed comment: %v", err)
	}

	service := services.NewCommentService(db)
	comments, total, err := service.GetCommentsByPostID(1, 10, post.ID)
	if err != nil {
		t.Fatalf("GetCommentsByPostID returned error: %v", err)
	}
	if total != 1 || len(comments) != 1 {
		t.Fatalf("got total=%d and %d comments, want 1", total, len(comments))
	}
	if comments[0].User.ID != user.ID || comments[0].User.Username != user.Username {
		t.Errorf("comment user = %+v, want user ID %d", comments[0].User, user.ID)
	}
	if comments[0].Post.ID != post.ID || comments[0].Post.Title != post.Title {
		t.Errorf("comment post = %+v, want post ID %d", comments[0].Post, post.ID)
	}
}
