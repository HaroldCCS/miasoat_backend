package models

import (
	"os"
	"sync"
	"testing"

	"github.com/aws/aws-lambda-go/events"
)

func TestCorsOrigin(t *testing.T) {
	// Limpiar el estado global antes del test
	once = sync.Once{}
	allowedOrigins = nil

	os.Setenv("CORS_ALLOWED_ORIGINS", "http://localhost:5173,https://misoat.co")
	defer os.Unsetenv("CORS_ALLOWED_ORIGINS")

	tests := []struct {
		name     string
		origin   string
		expected string
	}{
		{
			name:     "Allowed localhost",
			origin:   "http://localhost:5173",
			expected: "http://localhost:5173",
		},
		{
			name:     "Allowed production",
			origin:   "https://misoat.co",
			expected: "https://misoat.co",
		},
		{
			name:     "Not allowed origin",
			origin:   "https://evil.com",
			expected: "https://misoat.co",
		},
		{
			name:     "Empty origin",
			origin:   "",
			expected: "https://misoat.co",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := events.APIGatewayProxyRequest{
				Headers: map[string]string{
					"origin": tt.origin,
				},
			}
			got := corsOrigin(req)
			if got != tt.expected {
				t.Errorf("corsOrigin() = %v, want %v", got, tt.expected)
			}
		})
	}
}
