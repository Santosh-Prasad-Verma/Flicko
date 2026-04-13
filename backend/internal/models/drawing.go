package models

import "time"

type DrawingTool string

const (
	ToolPen         DrawingTool = "pen"
	ToolHighlighter DrawingTool = "highlighter"
	ToolEraser      DrawingTool = "eraser"
	ToolShape       DrawingTool = "shape"
)

type DrawingStroke struct {
	ID            string                 `json:"id" db:"id"`
	ScreenShareID string                 `json:"screen_share_id" db:"screen_share_id"`
	UserID        string                 `json:"user_id" db:"user_id"`
	Tool          DrawingTool            `json:"tool" db:"tool"`
	Color         string                 `json:"color" db:"color"`
	Width         int                    `json:"width" db:"width"`
	Opacity       float64                `json:"opacity" db:"opacity"`
	Coordinates   map[string]interface{} `json:"coordinates" db:"coordinates"`
	CreatedAt     time.Time              `json:"created_at" db:"created_at"`
}
