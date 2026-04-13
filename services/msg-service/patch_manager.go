package main

import (
        "fmt"
        "os"
        "strings"
)

func main() {
        content, err := os.ReadFile("services/ws-gateway/internal/conn/manager.go")
        if err != nil {
                panic(err)
        }

        s := string(content)

        // 1. Modify Register logic
        repl1 := `                      case client := <-m.register:
                                m.clients.Store(client.ID, client)
                                m.activeConns.Add(1)
                                m.totalConns.Add(1)
                                m.log.Info("client registered",
                                        zap.String("client_id", client.ID),
                                        zap.String("user_id", client.UserID),
                                )
                                if client.SessionID != "" {
                                        if saved, ok := m.sessions.Load(client.SessionID); ok {
                                                for _, ch := range saved.([]string) {
                                                        m.SubscribeToChannel(client, ch)
                                                }
                                        }
                                }`
        
        s = strings.Replace(s, `                        case client := <-m.register:
                                m.clients.Store(client.ID, client)
                                m.activeConns.Add(1)
                                m.totalConns.Add(1)
                                m.log.Info("client registered",
                                        zap.String("client_id", client.ID),
                                        zap.String("user_id", client.UserID),
                                )`, repl1, 1)

        // 2. Modify SubscribeToChannel logic
        repl2 := `func (m *Manager) SubscribeToChannel(client *Client, channelID string) {
        if _, loaded := m.clients.Load(client.ID); !loaded {
                return // client already unregistered
        }

        client.Channels[channelID] = true

        if client.SessionID != "" {
                var newChannels []string
                if saved, ok := m.sessions.Load(client.SessionID); ok {
                        newChannels = saved.([]string)
                        found := false
                        for _, c := range newChannels {
                                if c == channelID {
                                        found = true
                                        break
                                }
                        }
                        if !found {
                                newChannels = append(newChannels, channelID)
                        }
                } else {
                        newChannels = []string{channelID}
                }
                m.sessions.Store(client.SessionID, newChannels)
        }`

        s = strings.Replace(s, `func (m *Manager) SubscribeToChannel(client *Client, channelID string) {
        if _, loaded := m.clients.Load(client.ID); !loaded {
                return // client already unregistered
        }

        client.Channels[channelID] = true`, repl2, 1)

        // 3. Modify UnsubscribeFromChannel logic
        repl3 := `func (m *Manager) UnsubscribeFromChannel(client *Client, channelID string) {
        delete(client.Channels, channelID)

        if client.SessionID != "" {
                if saved, ok := m.sessions.Load(client.SessionID); ok {
                        channels := saved.([]string)
                        newChannels := []string{}
                        for _, c := range channels {
                                if c != channelID {
                                        newChannels = append(newChannels, c)
                                }
                        }
                        if len(newChannels) > 0 {
                                m.sessions.Store(client.SessionID, newChannels)
                        } else {
                                m.sessions.Delete(client.SessionID)
                        }
                }
        }`

        s = strings.Replace(s, `func (m *Manager) UnsubscribeFromChannel(client *Client, channelID string) {
        delete(client.Channels, channelID)`, repl3, 1)

        os.WriteFile("services/ws-gateway/internal/conn/manager.go", []byte(s), 0644)
        fmt.Println("Patched manager.go")
}
