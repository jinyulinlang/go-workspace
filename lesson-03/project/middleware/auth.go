package middleware

import (
	"manage-system/utils"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func Auth(jwtSecret []byte) gin.HandlerFunc {
	return func(ctx *gin.Context) {
		// get token from header
		token := ctx.GetHeader("Authorization")
		if token == "" {
			utils.Error(ctx, http.StatusUnauthorized, "Authorization header required")
			ctx.Abort()
			return
		}

		// split token and check if it has "Bearer" prefix
		parts := strings.Split(token, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			utils.Error(ctx, http.StatusUnauthorized, "Authorization header format must be Bearer {token}")
			ctx.Abort()
			return
		}
		// parse token and check if it's valid
		claims, err := utils.ParseToken(parts[1], jwtSecret)
		if err != nil {
			utils.Error(ctx, http.StatusUnauthorized, "Invalid token")
			ctx.Abort()
			return
		}
		ctx.Set("userID", claims.UserID)
		ctx.Set("username", claims.Username)
		ctx.Next()

	}
}
