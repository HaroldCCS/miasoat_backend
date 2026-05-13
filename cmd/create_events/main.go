package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"lambda-go-project/internal/models"
)

var dynamoClient *dynamodb.Client
var sqsClient *sqs.Client
var tableName = "UsersTable"
// Queue name for scrappers
var queueName = "queue-scrapping-misoat"

func init() {
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}
	dynamoClient = dynamodb.NewFromConfig(cfg)
	sqsClient = sqs.NewFromConfig(cfg)
}

func getQueueUrl(ctx context.Context, qName string) string {
	res, err := sqsClient.GetQueueUrl(ctx, &sqs.GetQueueUrlInput{
		QueueName: aws.String(qName),
	})
	if err != nil {
		fmt.Println("Error getting queue url:", err)
		return ""
	}
	return *res.QueueUrl
}

func handler(ctx context.Context, event events.CloudWatchEvent) error {
	fmt.Println("Scheduler triggered create_events, finding users...")

	// Normally we would use a Query with a Global Secondary Index on NotificationSIMIT,
	// but to keep it simple, we can do a Scan as it is a demo, or use the NotificationSIMIT attr.
	// We'll perform a Scan for prototype (since we only have PK = placa).
	scanInput := &dynamodb.ScanInput{
		TableName: aws.String(tableName),
	}

	res, err := dynamoClient.Scan(ctx, scanInput)
	if err != nil {
		return fmt.Errorf("failed to scan dynamodb: %v", err)
	}

	var users []models.User
	err = attributevalue.UnmarshalListOfMaps(res.Items, &users)
	if err != nil {
		return fmt.Errorf("failed to unmarshal users: %v", err)
	}

	queueUrl := os.Getenv("QUEUE_SCRAPPING_URL")
	if queueUrl == "" {
		queueUrl = getQueueUrl(ctx, queueName)
	}

	for _, u := range users {
		if u.NotificationSIMIT {
			body, _ := json.Marshal(u)
			fmt.Printf("Sending user %s to scrapper\n", u.Placa)
			
			// Optional DelaySeconds logic can be added if needed, but we keep it immediate
			_, err := sqsClient.SendMessage(ctx, &sqs.SendMessageInput{
				QueueUrl:    aws.String(queueUrl),
				MessageBody: aws.String(string(body)),
			})
			if err != nil {
				fmt.Printf("Error sending message for user %s: %v\n", u.Placa, err)
			}
		}
	}

	return nil
}

func main() {
	lambda.Start(handler)
}
