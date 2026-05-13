package models

import (
	"github.com/aws/aws-lambda-go/events"
)

// User representa la entidad de usuario en DynamoDB
type User struct {
	Placa             string `json:"placa" dynamodbav:"placa"`
	Email             string `json:"email" dynamodbav:"email"`
	NotificationSIMIT bool   `json:"notification_SIMIT" dynamodbav:"notification_SIMIT"`
}

// Helper para respuestas estandarizadas de API Gateway
func APIResponse(status int, body string) (events.APIGatewayProxyResponse, error) {
	return events.APIGatewayProxyResponse{
		StatusCode: status,
		Body:       body,
		Headers: map[string]string{
			"Content-Type":                 "application/json",
			"Access-Control-Allow-Origin":  "https://haroldsoftware.com",
			"Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
		},
	}, nil
}