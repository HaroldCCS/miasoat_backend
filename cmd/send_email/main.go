package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/smtp"
	"os"

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

func sendSimpleEmail(to, subject, text string) error {
	from := os.Getenv("SMTP_USERNAME")
	password := os.Getenv("SMTP_PASSWORD")

	if from == "" || password == "" {
		return fmt.Errorf("SMTP_USERNAME and SMTP_PASSWORD env variables are required")
	}

	smtpHost := "smtp.gmail.com"
	smtpPort := "587"

	message := []byte("From: " + from + "\r\n" +
		"To: " + to + "\r\n" +
		"Subject: " + subject + "\r\n\r\n" +
		text + "\r\n")

	auth := smtp.PlainAuth("", from, password, smtpHost)

	log.Printf("Enviando correo simple a %s", to)
	err := smtp.SendMail(smtpHost+":"+smtpPort, auth, from, []string{to}, message)
	if err != nil {
		log.Printf("Error enviando correo simple a %s: %v", to, err)
		return err
	}
	log.Printf("Correo simple enviado exitosamente a %s", to)
	return nil
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
			subject := fmt.Sprintf("Notificación de Multas SIMIT - Vehículo %s", result.Placa)
			text := fmt.Sprintf("Hola,\n\nSe ha detectado que el vehículo con placa %s tiene multas pendientes por un valor de $%d.\n\nPor favor, verifica esta información.", result.Placa, result.Amount)
			
			if err := sendSimpleEmail(result.Email, subject, text); err != nil {
				log.Printf("Failed to send email to %s: %v", result.Email, err)
			}
		} else {
			fmt.Printf("User %s has no fines. Skipping email.\n", result.Placa)
		}
	}

	return nil
}

func main() {
	lambda.Start(handler)
}
