const { SQSClient, SendMessageCommand } = require("@aws-sdk/client-sqs");

const sqsClient = new SQSClient({});
const QUEUE_URL = process.env.QUEUE_SEND_EMAIL_URL || "queue-send-email-misoat"; 
// Best practice: queue url should be passed as env var, but for testing or simple setup we assume full url needs to be fetched if we only have the name, or we can use the name if AWS SDK automatically resolves it in the same region (wait, QueueUrl requires full URL, let's just make sure we instruct the user, or use the name indirectly, but SDK v3 requires absolute QueueUrl).
// Actually, terraform could export it as an env var. Let's just assume we get an sqs event, extract the account ID/region from ARN, and construct it if QUEUE_URL is not provided.
// Or we just use `process.env.QUEUE_SEND_EMAIL_URL`. Let's tell Terraform to inject `QUEUE_SEND_EMAIL_URL` in `main.tf` later if needed. For now I'll just put a placeholder env var logic.

exports.handler = async (event) => {
    console.log("Received event from scraping SQS:", JSON.stringify(event));

    for (const record of event.Records) {
        console.log("Processing record:", record.messageId);
        let user;
        try {
            user = JSON.parse(record.body);
        } catch(e) {
            console.error("Invalid message body", record.body);
            continue;
        }

        // Mocking scraping logic
        const scrapedData = {
            placa: user.placa,
            email: user.email,
            notification_SIMIT: user.notification_SIMIT,
            hasFines: Math.random() > 0.5,
            amount: Math.floor(Math.random() * 1000000)
        };
        console.log("Scraped data result for user:", scrapedData);

        // Send to send-email SQS
        if (scrapedData.hasFines && scrapedData.notification_SIMIT) {
            try {
                // If QueuUrl is not provided, we extract AWS account id and region from the record.eventSourceARN
                // Example ARN: arn:aws:sqs:us-east-1:123456789012:queue-scrapping-misoat
                let destQueueUrl = process.env.QUEUE_SEND_EMAIL_URL;
                if (!destQueueUrl) {
                    const parts = record.eventSourceARN.split(":");
                    const region = parts[3];
                    const accountId = parts[4];
                    destQueueUrl = `https://sqs.${region}.amazonaws.com/${accountId}/queue-send-email-misoat`;
                }

                console.log("Sending message to:", destQueueUrl);
                const sendCommand = new SendMessageCommand({
                    QueueUrl: destQueueUrl,
                    MessageBody: JSON.stringify(scrapedData)
                });
                
                await sqsClient.send(sendCommand);
                console.log("Message successfully sent to email queue");
            } catch (sqsErr) {
                console.error("Failed to send to SQS:", sqsErr);
            }
        }
    }
    
    return { statusCode: 200, body: "Success" };
};
