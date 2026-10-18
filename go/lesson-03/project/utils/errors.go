package utils

import (
	"errors"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type AppError struct {
	Code    int
	Message string
	Err     error
}

func HashPassword(rawPassword string) (*[]byte, error) {
	// Implement password hashing logic here
	hashedPassword, error := bcrypt.GenerateFromPassword([]byte(rawPassword), bcrypt.DefaultCost)
	if error != nil {
		return nil, error
	}
	return &hashedPassword, nil
}
func (e *AppError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s:%v", e.Message, e.Err)
	}
	return e.Message
}
func NewAppError(code int, message string) *AppError {
	return &AppError{
		Code:    code,
		Message: message,
	}
}


func HandleError(c *gin.Context, err error) {
	if appErr, ok := errors.AsType[*AppError](err); ok {
		Error(c, appErr.Code, appErr.Message)
		return
	}
	// For unknown errors, write the error msg to log and return a generic internal server error response.

	Error(c, http.StatusInternalServerError, "Internal Server Error")
}
