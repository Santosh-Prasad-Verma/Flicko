package models

import "fmt"

// MoonclerkWebhookPayload represents the JSON body sent by Moonclerk webhooks.
type MoonclerkWebhookPayload struct {
	Event  string        `json:"event"`
	Object string        `json:"object"`
	Data   MoonclerkData `json:"data"`
}

// MoonclerkData contains the core information about the event.
type MoonclerkData struct {
	ID            string                 `json:"id"`
	Amount        int                    `json:"amount"` // in cents
	Currency      string                 `json:"currency"`
	Status        string                 `json:"status"`
	CustomerEmail string                 `json:"customer_email"`
	CustomFields  map[string]interface{} `json:"custom_fields"`
	CustomID      string                 `json:"custom_id"`
}

// GetUsername attempts to extract a username from custom fields.
func (p *MoonclerkWebhookPayload) GetUsername() string {
	if p.Data.CustomFields != nil {
		if username, ok := p.Data.CustomFields["username"].(string); ok && username != "" {
			return username
		}
	}
	return ""
}

// GetAmountFormatted returns the amount as a human-readable string (e.g. "4.99 USD").
func (p *MoonclerkWebhookPayload) GetAmountFormatted() string {
	return fmt.Sprintf("%.2f %s", float64(p.Data.Amount)/100.0, p.Data.Currency)
}
