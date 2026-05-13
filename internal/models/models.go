package models

import (
	"os"
	"strings"
	"sync"

	"github.com/aws/aws-lambda-go/events"
)

var (
	allowedOrigins map[string]bool
	once           sync.Once
	defaultOrigin = "http://localhost:8080"
)

// initCORS inicializa el mapa de orígenes permitidos desde variables de entorno.
func initCORS() {
	once.Do(func() {
		allowedOrigins = make(map[string]bool)
		envOrigins := os.Getenv("CORS_ALLOWED_ORIGINS")
		if envOrigins != "" {
			origins := strings.Split(envOrigins, ",")
			for _, o := range origins {
				trimmed := strings.TrimSpace(o)
				if trimmed != "" {
					allowedOrigins[trimmed] = true
				}
			}
		}
		// Asegurar que siempre haya un origen por defecto si la env está vacía
		if len(allowedOrigins) == 0 {
			allowedOrigins[defaultOrigin] = true
		}
	})
}

// corsOrigin devuelve el origen de la request si está permitido, o el por defecto.
func corsOrigin(req events.APIGatewayProxyRequest) string {
	initCORS()
	origin := req.Headers["origin"]
	if origin == "" {
		origin = req.Headers["Origin"]
	}
	if allowedOrigins[origin] {
		return origin
	}
	return defaultOrigin
}

// User representa la entidad de usuario en DynamoDB
type User struct {
	Placa             string `json:"placa" dynamodbav:"placa"`
	Email             string `json:"email" dynamodbav:"email"`
	NotificationSIMIT bool   `json:"notification_SIMIT" dynamodbav:"notification_SIMIT"`
}

// APIResponse construye una respuesta estándar de API Gateway con cabeceras CORS.
func APIResponse(status int, body string, req ...events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	origin := defaultOrigin
	if len(req) > 0 {
		origin = corsOrigin(req[0])
	}
	return events.APIGatewayProxyResponse{
		StatusCode: status,
		Body:       body,
		Headers: map[string]string{
			"Content-Type":                  "application/json",
			"Access-Control-Allow-Origin":   origin,
			"Access-Control-Allow-Methods":  "GET,POST,PUT,DELETE,OPTIONS",
			"Access-Control-Allow-Headers":  "Content-Type,Authorization",
		},
	}, nil
}