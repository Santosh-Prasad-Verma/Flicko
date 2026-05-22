package models

import (
	"time"
)

type CreatorPost struct {
	ID               string    `json:"id" db:"id"`
	UserID           string    `json:"user_id" db:"user_id"`
	Username         string    `json:"username" db:"username"`
	DisplayName      *string   `json:"display_name" db:"display_name"`
	AvatarURL        *string   `json:"avatar" db:"avatar"`
	Verified         bool      `json:"verified" db:"verified"`
	Content          string    `json:"content" db:"content"`
	MediaURLs        []string  `json:"media_urls" db:"media_urls"`
	ParentPostID     *string   `json:"parent_post_id" db:"parent_post_id"`
	RootPostID       *string   `json:"root_post_id" db:"root_post_id"`
	Category         string    `json:"category" db:"category"`
	Title            *string   `json:"title" db:"title"`
	AcceptedAnswerID *string   `json:"accepted_answer_id" db:"accepted_answer_id"`
	IsDeleted        bool      `json:"is_deleted" db:"is_deleted"`
	Flagged          bool      `json:"flagged" db:"flagged"`
	ReplyCount       int       `json:"reply_count" db:"reply_count"`
	LikeCount        int       `json:"like_count" db:"like_count"`
	RepostCount      int       `json:"repost_count" db:"repost_count"`
	PostType         string    `json:"post_type" db:"post_type"`
	Visibility       string    `json:"visibility" db:"visibility"`
	LikedByMe        bool      `json:"liked_by_me"`
	RepostedByMe     bool      `json:"reposted_by_me"`
	CreatedAt        time.Time `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time `json:"updated_at" db:"updated_at"`
}

type CreatorProfile struct {
	ID             string  `json:"id"`
	Username       string  `json:"username"`
	DisplayName    *string `json:"display_name"`
	AvatarURL      *string `json:"avatar"`
	Bio            *string `json:"bio"`
	Verified       bool    `json:"verified"`
	FollowerCount  int     `json:"follower_count"`
	FollowingCount int     `json:"following_count"`
	PostCount      int     `json:"post_count"`
	IsFollowing    bool    `json:"is_following"`
	IsBlocked      bool    `json:"is_blocked"`
}
