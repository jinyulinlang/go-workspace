package unit_test

import (
	"testing"

	"manage-system/models"
	"manage-system/services"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func TestPostAfterCreateIncrementsUserPostNo(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}

	if err := db.AutoMigrate(&models.User{}, &models.Post{}); err != nil {
		t.Fatalf("migrate tables: %v", err)
	}

	user := models.User{
		Username: "alice",
		Email:    "alice@example.com",
		Password: "password123",
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	post := models.Post{
		Title:   "first post",
		Content: "hello world",
		UserID:  user.ID,
	}
	if err := db.Create(&post).Error; err != nil {
		t.Fatalf("create post: %v", err)
	}

	var updated models.User
	if err := db.First(&updated, user.ID).Error; err != nil {
		t.Fatalf("load updated user: %v", err)
	}
	if updated.PostNo != 1 {
		t.Fatalf("user.PostNo = %d, want 1", updated.PostNo)
	}
}

func TestPostAfterDeleteDecrementsUserPostNo(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}

	if err := db.AutoMigrate(&models.User{}, &models.Post{}); err != nil {
		t.Fatalf("migrate tables: %v", err)
	}

	user := models.User{Username: "bob", Email: "bob@example.com", Password: "password123"}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	post := models.Post{Title: "delete me", Content: "content", UserID: user.ID}
	if err := db.Create(&post).Error; err != nil {
		t.Fatalf("create post: %v", err)
	}
	if err := db.Delete(&post).Error; err != nil {
		t.Fatalf("delete post: %v", err)
	}

	var updated models.User
	if err := db.First(&updated, user.ID).Error; err != nil {
		t.Fatalf("load updated user: %v", err)
	}
	if updated.PostNo != 0 {
		t.Fatalf("user.PostNo = %d, want 0", updated.PostNo)
	}
}

func TestGetUserPostRank(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}

	if err := db.AutoMigrate(&models.User{}, &models.Post{}); err != nil {
		t.Fatalf("migrate tables: %v", err)
	}

	users := []models.User{
		{Username: "alice", Email: "alice@example.com", Password: "123456", PostNo: 2},
		{Username: "bob", Email: "bob@example.com", Password: "123456", PostNo: 4},
		{Username: "carl", Email: "carl@example.com", Password: "123456", PostNo: 1},
	}
	if err := db.Create(&users).Error; err != nil {
		t.Fatalf("seed users: %v", err)
	}

	service := services.NewUserService(db)
	ranked, err := service.GetUserPostRank(2)
	if err != nil {
		t.Fatalf("GetUserPostRank returned error: %v", err)
	}
	if len(ranked) != 2 {
		t.Fatalf("len(ranked) = %d, want 2", len(ranked))
	}
	if ranked[0].Username != "bob" || ranked[0].PostNo != 4 {
		t.Fatalf("top user = %+v, want bob with 4 posts", ranked[0])
	}
	if ranked[1].Username != "alice" || ranked[1].PostNo != 2 {
		t.Fatalf("second user = %+v, want alice with 2 posts", ranked[1])
	}
}
