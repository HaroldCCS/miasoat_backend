package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"lambda-go-project/internal/models"
)

var dynamoClient *dynamodb.Client
var tableName = "UsersTable"

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}
	dynamoClient = dynamodb.NewFromConfig(cfg)
}

func handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	fmt.Println("Received request:", req.Body)

	var user models.User
	if err := json.Unmarshal([]byte(req.Body), &user); err != nil {
		return models.APIResponse(400, `{"message":"Invalid request body"}`, req)
	}

	if user.Placa == "" || user.Email == "" {
		return models.APIResponse(400, `{"message":"placa and email are required"}`, req)
	}

	item, err := attributevalue.MarshalMap(user)
	if err != nil {
		return models.APIResponse(500, `{"message":"Failed to marshal user data"}`, req)
	}

	_, err = dynamoClient.PutItem(ctx, &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
	})
	if err != nil {
		fmt.Println("Error putting item in dynamodb:", err)
		return models.APIResponse(500, `{"message":"Failed to save user"}`, req)
	}

	return models.APIResponse(201, `{"message":"User created successfully"}`, req)
}

func main() {
	lambda.Start(handler)
}
