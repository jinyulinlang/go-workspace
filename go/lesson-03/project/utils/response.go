package utils

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type Response struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
	Error   any    `json:"error,omitempty"`
}

// Success returns a successful response with the provided data.
func Success(c *gin.Context, data any) {
	c.JSON(http.StatusOK, Response{
		Code:    200,
		Message: "success",
		Data:    data,
	})
}

// Error returns an error response with the provided code and message.
func Error(c *gin.Context, code int, message string) {
	c.JSON(code, Response{
		Code:    code,
		Message: message,
		Error:   message,
	})
}

// ValidationError returns a validation error response with the provided errors.
func ValidationError(c *gin.Context, erros map[string]string) {
	c.JSON(http.StatusUnprocessableEntity, Response{
		Code:    422,
		Message: "validation failed",
		Error:   erros,
	})
}
