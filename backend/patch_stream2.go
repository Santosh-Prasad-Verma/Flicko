package main

import (
        "os"
        "strings"
)

func main() {
        path := "backend/internal/services/stream_service.go"
        b, _ := os.ReadFile(path)
        s := string(b)
        
        s = strings.Replace(s, "\tuserUUID, err := uuid.Parse(userID)\n", "", 1)
        s = strings.Replace(s, "\tif err != nil {\n\t\treturn fmt.Errorf(\"invalid user_id: %w\", err)\n\t}\n", "", 1)

        // Add proper parsing
        s = strings.Replace(s, "hasPerm, err := s.permService.HasPermission(ctx, userID, channelID, \"MANAGE_CHANNELS\")", "currUserUUID, _ := uuid.Parse(userID)\n\t\teachChanUUID, _ := uuid.Parse(channelID)\n\t\thasPerm, err := s.permService.HasPermission(ctx, currUserUUID, eachChanUUID, \"MANAGE_CHANNELS\")", 1)

        os.WriteFile(path, []byte(s), 0644)
}
