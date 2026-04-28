// Example bot using Flicko SDK
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/flicko-org/flicko-backend/pkg/flickosdk"
)

func main() {
	apiKey := os.Getenv("FLICKO_BOT_API_KEY")
	webhookSecret := os.Getenv("FLICKO_WEBHOOK_SECRET")

	if apiKey == "" || webhookSecret == "" {
		log.Fatal("FLICKO_BOT_API_KEY and FLICKO_WEBHOOK_SECRET must be set")
	}

	client := flickosdk.NewClient(apiKey, "")

	server := flickosdk.NewWebhookServer(webhookSecret, func(event flickosdk.Event) error {
		return handleEvent(client, event)
	})

	go func() {
		log.Println("Starting webhook server on :8080")
		if err := server.Start(8080); err != nil {
			log.Printf("Webhook server error: %v", err)
		}
	}()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	server.Shutdown(ctx)
}

func handleEvent(client *flickosdk.Client, event flickosdk.Event) error {
	ctx := context.Background()

	switch event.EventType {
	case "MESSAGE_CREATE":
		return handleMessageCreate(ctx, client, event)
	case "MEMBER_JOIN":
		return handleMemberJoin(ctx, client, event)
	}

	return nil
}

func handleMessageCreate(ctx context.Context, client *flickosdk.Client, event flickosdk.Event) error {
	content, ok := event.Data["content"].(string)
	if !ok {
		return nil
	}

	channelID := event.ChannelID

	if strings.HasPrefix(content, "!ping") {
		_, err := client.SendMessage(ctx, channelID, "🏓 Pong!")
		return err
	}

	if strings.HasPrefix(content, "!hello") {
		userID := event.UserID
		_, err := client.SendMessage(ctx, channelID, fmt.Sprintf("👋 Hello <@%s>!", userID))
		return err
	}

	return nil
}

func handleMemberJoin(ctx context.Context, client *flickosdk.Client, event flickosdk.Event) error {
	welcomeChannelID := os.Getenv("WELCOME_CHANNEL_ID")
	if welcomeChannelID == "" {
		return nil
	}

	username := event.Data["username"].(string)
	_, err := client.SendMessage(ctx, welcomeChannelID, fmt.Sprintf("👋 Welcome **%s**!", username))
	return err
}
