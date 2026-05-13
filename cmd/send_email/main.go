package main

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type ScrapeResult struct {
	Placa             string `json:"placa"`
	Email             string `json:"email"`
	NotificationSIMIT bool   `json:"notification_SIMIT"`
	HasFines          bool   `json:"hasFines"`
	Amount            int    `json:"amount"`
}

func handler(ctx context.Context, sqsEvent events.SQSEvent) error {
	for _, message := range sqsEvent.Records {
		fmt.Printf("Message ID: %s\n", message.MessageId)

		var result ScrapeResult
		if err := json.Unmarshal([]byte(message.Body), &result); err != nil {
			fmt.Printf("Error parsing message body: %v\n", err)
			continue
		}

		if result.HasFines {
			// Simular envío de email
			fmt.Printf("[MOCK EMAIL] Sending email to %s for Placa %s. Total fines: $%d\n", result.Email, result.Placa, result.Amount)
		} else {
			fmt.Printf("User %s has no fines. Skipping email.\n", result.Placa)
		}
	}

	return nil
}

func main() {
	lambda.Start(handler)
}
