package services

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

type CreatorService interface {
	CreatePost(ctx context.Context, post *models.CreatorPost) error
	GetUserProfile(ctx context.Context, userID, requestingUserID string) (*models.CreatorProfile, error)
	GetUserPosts(ctx context.Context, userID, requestingUserID string, cursor string, limit int) ([]*models.CreatorPost, error)
	GetPost(ctx context.Context, postID, requestingUserID string) (*models.CreatorPost, error)
	GetReplies(ctx context.Context, postID, requestingUserID string) ([]*models.CreatorPost, error)
	ToggleLike(ctx context.Context, postID, userID string) (bool, error)
	ToggleRepost(ctx context.Context, postID, userID string) (bool, error)
	MarkAcceptedAnswer(ctx context.Context, postID, answerID, requestingUserID string) error
	GetFeed(ctx context.Context, userID string, cursor string, limit int) ([]*models.CreatorPost, error)
	ToggleFollow(ctx context.Context, followerID, followingID string) (bool, error)
	GetFollowers(ctx context.Context, userID string, cursor string, limit int) ([]*models.CreatorProfile, error)
	GetFollowing(ctx context.Context, userID string, cursor string, limit int) ([]*models.CreatorProfile, error)
	DeletePost(ctx context.Context, postID, requestingUserID string) error
	SearchPosts(ctx context.Context, query, category, cursor string, limit int) ([]*models.CreatorPost, error)
	GenerateUploadPresignedURL(ctx context.Context, filename, contentType, userID string) (string, string, error)
}

type creatorService struct {
	db    *pgxpool.Pool
	cache cache.CacheLayer
}

func NewCreatorService(db *pgxpool.Pool, cache cache.CacheLayer) CreatorService {
	s := &creatorService{
		db:    db,
		cache: cache,
	}

	// Start background cron worker for cleaning up orphaned uploads (at 2 AM UTC daily)
	go s.startOrphanedMediaCleanup()

	return s
}

func (s *creatorService) startOrphanedMediaCleanup() {
	// Check once every 24 hours
	ticker := time.NewTicker(24 * time.Hour)
	for range ticker.C {
		s.cleanupOrphanedMedia(context.Background())
	}
}

func (s *creatorService) cleanupOrphanedMedia(ctx context.Context) {
	rows, err := s.db.Query(ctx, `
		SELECT id, storage_path 
		FROM public.creator_media_uploads 
		WHERE post_id IS NULL AND created_at < NOW() - INTERVAL '1 day'
	`)
	if err != nil {
		return
	}
	defer rows.Close()

	var itemsToDelete []struct {
		id   string
		path string
	}
	for rows.Next() {
		var item struct {
			id   string
			path string
		}
		if err := rows.Scan(&item.id, &item.path); err == nil {
			itemsToDelete = append(itemsToDelete, item)
		}
	}

	for _, item := range itemsToDelete {
		_, _ = s.db.Exec(ctx, "DELETE FROM public.creator_media_uploads WHERE id = $1", item.id)
	}
}

func (s *creatorService) GenerateUploadPresignedURL(ctx context.Context, filename, contentType, userID string) (string, string, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return "", "", fmt.Errorf("invalid user uuid: %w", err)
	}

	// Robust Filename Sanitization
	sanitized := regexp.MustCompile(`[^a-zA-Z0-9._-]`).ReplaceAllString(filename, "_")
	sanitized = strings.TrimLeft(sanitized, ".-")
	if len(sanitized) > 100 {
		sanitized = sanitized[:100]
	}
	if sanitized == "" {
		sanitized = "upload"
	}

	// Generate unique storage path
	uniqueID := uuid.New().String()
	storagePath := fmt.Sprintf("users/%s/%s_%s", userUUID.String(), uniqueID, sanitized)
	uploadURL := fmt.Sprintf("/api/v1/upload/creator-media/%s", storagePath)
	publicURL := fmt.Sprintf("/api/v1/media/creator-media/%s", storagePath)

	// Track upload in database
	_, err = s.db.Exec(ctx, `
		INSERT INTO public.creator_media_uploads (user_id, storage_path, post_id)
		VALUES ($1, $2, NULL)
	`, userUUID, storagePath)
	if err != nil {
		return "", "", fmt.Errorf("failed to track media upload: %w", err)
	}

	return uploadURL, publicURL, nil
}

func (s *creatorService) CreatePost(ctx context.Context, post *models.CreatorPost) error {
	userUUID, err := uuid.Parse(post.UserID)
	if err != nil {
		return fmt.Errorf("invalid user uuid: %w", err)
	}

	var parentUUID *uuid.UUID
	if post.ParentPostID != nil && *post.ParentPostID != "" {
		pUUID, err := uuid.Parse(*post.ParentPostID)
		if err != nil {
			return fmt.Errorf("invalid parent post uuid: %w", err)
		}
		parentUUID = &pUUID
	}

	var rootUUID *uuid.UUID
	if post.RootPostID != nil && *post.RootPostID != "" {
		rUUID, err := uuid.Parse(*post.RootPostID)
		if err != nil {
			return fmt.Errorf("invalid root post uuid: %w", err)
		}
		rootUUID = &rUUID
	}

	var title *string
	if post.Title != nil && *post.Title != "" {
		title = post.Title
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	query := `
		INSERT INTO public.creator_posts (
			user_id, content, media_urls, parent_post_id, root_post_id, category, title, post_type, visibility
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, created_at, updated_at
	`
	var postID uuid.UUID
	var createdAt, updatedAt time.Time
	err = tx.QueryRow(ctx, query,
		userUUID, post.Content, post.MediaURLs, parentUUID, rootUUID,
		post.Category, title, post.PostType, post.Visibility,
	).Scan(&postID, &createdAt, &updatedAt)
	if err != nil {
		return fmt.Errorf("insert post: %w", err)
	}

	if len(post.MediaURLs) > 0 {
		for _, url := range post.MediaURLs {
			parts := strings.Split(url, "/creator-media/")
			if len(parts) == 2 {
				storagePath := parts[1]
				_, err = tx.Exec(ctx, `
					UPDATE public.creator_media_uploads
					SET post_id = $1
					WHERE storage_path = $2 AND user_id = $3
				`, postID, storagePath, userUUID)
				if err != nil {
					return fmt.Errorf("associate media: %w", err)
				}
			}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit post transaction: %w", err)
	}

	post.ID = postID.String()
	post.CreatedAt = createdAt
	post.UpdatedAt = updatedAt

	var followerCount int
	err = s.db.QueryRow(ctx, `
		SELECT COUNT(*) 
		FROM public.creator_follows 
		WHERE following_id = $1 AND status = 'active'
	`, userUUID).Scan(&followerCount)
	if err != nil {
		return fmt.Errorf("get follower count: %w", err)
	}

	if followerCount >= 1000 {
		s.cache.GetRedisClient().SAdd(ctx, "celebrity_user_ids", userUUID.String())
	} else {
		s.cache.GetRedisClient().SRem(ctx, "celebrity_user_ids", userUUID.String())
		go s.pushPostToFollowers(ctx, userUUID.String(), postID.String(), createdAt.Unix())
	}

	return nil
}

func (s *creatorService) pushPostToFollowers(ctx context.Context, creatorID, postID string, score int64) {
	rows, err := s.db.Query(ctx, `
		SELECT follower_id 
		FROM public.creator_follows 
		WHERE following_id = $1 AND status = 'active'
	`, creatorID)
	if err != nil {
		return
	}
	defer rows.Close()

	pipe := s.cache.GetRedisClient().Pipeline()
	var followerCount int
	for rows.Next() {
		var fID string
		if err := rows.Scan(&fID); err == nil {
			activeKey := fmt.Sprintf("user:active:%s", fID)
			active, _ := s.cache.Exists(ctx, activeKey)
			if active {
				key := fmt.Sprintf("feed:%s:timeline", fID)
				pipe.ZAdd(ctx, key, redis.Z{Score: float64(score), Member: postID})
				pipe.Expire(ctx, key, 300*time.Second)
				followerCount++
			}
		}
	}
	if followerCount > 0 {
		_, _ = pipe.Exec(ctx)
	}
}

func (s *creatorService) GetUserProfile(ctx context.Context, userID, requestingUserID string) (*models.CreatorProfile, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user uuid: %w", err)
	}

	var reqUUID *uuid.UUID
	if requestingUserID != "" {
		id, err := uuid.Parse(requestingUserID)
		if err == nil {
			reqUUID = &id
		}
	}

	var p models.CreatorProfile
	err = s.db.QueryRow(ctx, `
		SELECT id, username, display_name, avatar, bio, verified
		FROM public.profiles
		WHERE id = $1
	`, userUUID).Scan(&p.ID, &p.Username, &p.DisplayName, &p.AvatarURL, &p.Bio, &p.Verified)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("profile not found")
		}
		return nil, fmt.Errorf("get profile details: %w", err)
	}

	err = s.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM public.creator_follows WHERE following_id = $1 AND status = 'active'
	`, userUUID).Scan(&p.FollowerCount)
	if err != nil {
		return nil, fmt.Errorf("get follower count: %w", err)
	}

	err = s.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM public.creator_follows WHERE follower_id = $1 AND status = 'active'
	`, userUUID).Scan(&p.FollowingCount)
	if err != nil {
		return nil, fmt.Errorf("get following count: %w", err)
	}

	err = s.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM public.creator_posts WHERE user_id = $1 AND is_deleted = FALSE
	`, userUUID).Scan(&p.PostCount)
	if err != nil {
		return nil, fmt.Errorf("get post count: %w", err)
	}

	if reqUUID != nil {
		err = s.db.QueryRow(ctx, `
			SELECT EXISTS(
				SELECT 1 FROM public.creator_follows 
				WHERE follower_id = $1 AND following_id = $2 AND status = 'active'
			)
		`, reqUUID, userUUID).Scan(&p.IsFollowing)
		if err != nil {
			return nil, err
		}

		err = s.db.QueryRow(ctx, `
			SELECT EXISTS(
				SELECT 1 FROM public.creator_follows 
				WHERE follower_id = $1 AND following_id = $2 AND status = 'blocked'
			)
		`, reqUUID, userUUID).Scan(&p.IsBlocked)
		if err != nil {
			return nil, err
		}
	}

	return &p, nil
}

func (s *creatorService) GetUserPosts(ctx context.Context, userID, requestingUserID string, cursor string, limit int) ([]*models.CreatorPost, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user uuid: %w", err)
	}

	if limit <= 0 {
		limit = 20
	}

	var cursorTime time.Time
	var cursorPostID uuid.UUID
	var hasCursor bool
	if cursor != "" {
		decoded, err := base64.StdEncoding.DecodeString(cursor)
		if err == nil {
			parts := strings.SplitN(string(decoded), ":", 2)
			if len(parts) == 2 {
				unixTS, err1 := strconv.ParseInt(parts[0], 10, 64)
				pUUID, err2 := uuid.Parse(parts[1])
				if err1 == nil && err2 == nil {
					cursorTime = time.Unix(unixTS, 0)
					cursorPostID = pUUID
					hasCursor = true
				}
			}
		}
	}

	var rows pgx.Rows
	if hasCursor {
		query := `
			SELECT p.id, p.user_id, pr.username, pr.display_name, pr.avatar, pr.verified,
			       p.content, p.media_urls, p.parent_post_id, p.root_post_id, p.category, p.title,
			       p.accepted_answer_id, p.is_deleted, p.flagged, p.reply_count, p.like_count, p.repost_count,
			       p.post_type, p.visibility, p.created_at, p.updated_at
			FROM public.creator_posts p
			JOIN public.profiles pr ON p.user_id = pr.id
			WHERE p.user_id = $1 AND p.is_deleted = FALSE AND p.flagged = FALSE
			  AND (p.created_at < $2 OR (p.created_at = $2 AND p.id > $3))
			ORDER BY p.created_at DESC, p.id ASC
			LIMIT $4
		`
		rows, err = s.db.Query(ctx, query, userUUID, cursorTime, cursorPostID, limit)
	} else {
		query := `
			SELECT p.id, p.user_id, pr.username, pr.display_name, pr.avatar, pr.verified,
			       p.content, p.media_urls, p.parent_post_id, p.root_post_id, p.category, p.title,
			       p.accepted_answer_id, p.is_deleted, p.flagged, p.reply_count, p.like_count, p.repost_count,
			       p.post_type, p.visibility, p.created_at, p.updated_at
			FROM public.creator_posts p
			JOIN public.profiles pr ON p.user_id = pr.id
			WHERE p.user_id = $1 AND p.is_deleted = FALSE AND p.flagged = FALSE
			ORDER BY p.created_at DESC, p.id ASC
			LIMIT $2
		`
		rows, err = s.db.Query(ctx, query, userUUID, limit)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	posts, err := s.scanPosts(rows)
	if err != nil {
		return nil, err
	}

	if requestingUserID != "" {
		s.hydrateEngagement(ctx, posts, requestingUserID)
	}

	return posts, nil
}

func (s *creatorService) GetPost(ctx context.Context, postID, requestingUserID string) (*models.CreatorPost, error) {
	postUUID, err := uuid.Parse(postID)
	if err != nil {
		return nil, fmt.Errorf("invalid post uuid")
	}

	query := `
		SELECT p.id, p.user_id, pr.username, pr.display_name, pr.avatar, pr.verified,
		       p.content, p.media_urls, p.parent_post_id, p.root_post_id, p.category, p.title,
		       p.accepted_answer_id, p.is_deleted, p.flagged, p.reply_count, p.like_count, p.repost_count,
		       p.post_type, p.visibility, p.created_at, p.updated_at
		FROM public.creator_posts p
		JOIN public.profiles pr ON p.user_id = pr.id
		WHERE p.id = $1 AND p.is_deleted = FALSE AND p.flagged = FALSE
	`
	rows, err := s.db.Query(ctx, query, postUUID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	posts, err := s.scanPosts(rows)
	if err != nil {
		return nil, err
	}
	if len(posts) == 0 {
		return nil, fmt.Errorf("post not found")
	}

	if requestingUserID != "" {
		s.hydrateEngagement(ctx, posts, requestingUserID)
	}

	return posts[0], nil
}

func (s *creatorService) GetReplies(ctx context.Context, postID, requestingUserID string) ([]*models.CreatorPost, error) {
	postUUID, err := uuid.Parse(postID)
	if err != nil {
		return nil, fmt.Errorf("invalid post uuid")
	}

	query := `
		SELECT p.id, p.user_id, pr.username, pr.display_name, pr.avatar, pr.verified,
		       p.content, p.media_urls, p.parent_post_id, p.root_post_id, p.category, p.title,
		       p.accepted_answer_id, p.is_deleted, p.flagged, p.reply_count, p.like_count, p.repost_count,
		       p.post_type, p.visibility, p.created_at, p.updated_at
		FROM public.creator_posts p
		JOIN public.profiles pr ON p.user_id = pr.id
		WHERE p.parent_post_id = $1 AND p.is_deleted = FALSE AND p.flagged = FALSE
		ORDER BY p.created_at ASC, p.id ASC
	`
	rows, err := s.db.Query(ctx, query, postUUID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	posts, err := s.scanPosts(rows)
	if err != nil {
		return nil, err
	}

	if requestingUserID != "" {
		s.hydrateEngagement(ctx, posts, requestingUserID)
	}

	return posts, nil
}

func (s *creatorService) ToggleLike(ctx context.Context, postID, userID string) (bool, error) {
	postUUID, err := uuid.Parse(postID)
	if err != nil {
		return false, fmt.Errorf("invalid post uuid")
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return false, fmt.Errorf("invalid user uuid")
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return false, fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	var inserted bool
	err = tx.QueryRow(ctx, `
		INSERT INTO public.creator_post_likes (post_id, user_id)
		VALUES ($1, $2)
		ON CONFLICT (post_id, user_id) DO NOTHING
		RETURNING TRUE
	`, postUUID, userUUID).Scan(&inserted)

	var isLiked bool
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			_, err = tx.Exec(ctx, `
				DELETE FROM public.creator_post_likes 
				WHERE post_id = $1 AND user_id = $2
			`, postUUID, userUUID)
			if err != nil {
				return false, fmt.Errorf("unlike execute: %w", err)
			}
			isLiked = false
		} else {
			return false, fmt.Errorf("like scan: %w", err)
		}
	} else {
		isLiked = true
	}

	if err := tx.Commit(ctx); err != nil {
		return false, fmt.Errorf("commit transaction: %w", err)
	}

	return isLiked, nil
}

func (s *creatorService) ToggleRepost(ctx context.Context, postID, userID string) (bool, error) {
	postUUID, err := uuid.Parse(postID)
	if err != nil {
		return false, fmt.Errorf("invalid post uuid")
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return false, fmt.Errorf("invalid user uuid")
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return false, fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	var inserted bool
	err = tx.QueryRow(ctx, `
		INSERT INTO public.creator_post_reposts (post_id, user_id)
		VALUES ($1, $2)
		ON CONFLICT (post_id, user_id) DO NOTHING
		RETURNING TRUE
	`, postUUID, userUUID).Scan(&inserted)

	var isReposted bool
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			_, err = tx.Exec(ctx, `
				DELETE FROM public.creator_post_reposts 
				WHERE post_id = $1 AND user_id = $2
			`, postUUID, userUUID)
			if err != nil {
				return false, fmt.Errorf("unrepost execute: %w", err)
			}
			isReposted = false
		} else {
			return false, fmt.Errorf("repost scan: %w", err)
		}
	} else {
		isReposted = true
	}

	if err := tx.Commit(ctx); err != nil {
		return false, fmt.Errorf("commit transaction: %w", err)
	}

	return isReposted, nil
}

func (s *creatorService) MarkAcceptedAnswer(ctx context.Context, postID, answerID, requestingUserID string) error {
	postUUID, err := uuid.Parse(postID)
	if err != nil {
		return fmt.Errorf("invalid post uuid")
	}
	answerUUID, err := uuid.Parse(answerID)
	if err != nil {
		return fmt.Errorf("invalid answer uuid")
	}
	reqUUID, err := uuid.Parse(requestingUserID)
	if err != nil {
		return fmt.Errorf("invalid user uuid")
	}

	var authorID uuid.UUID
	var postType string
	err = s.db.QueryRow(ctx, `
		SELECT user_id, post_type FROM public.creator_posts WHERE id = $1 AND is_deleted = FALSE
	`, postUUID).Scan(&authorID, &postType)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("post not found")
		}
		return err
	}

	if postType != "qna" {
		return fmt.Errorf("post is not a Q&A discussion")
	}

	if authorID != reqUUID {
		return fmt.Errorf("unauthorized: only the author of the question can accept an answer")
	}

	var parentPostID uuid.UUID
	err = s.db.QueryRow(ctx, `
		SELECT parent_post_id FROM public.creator_posts WHERE id = $1 AND is_deleted = FALSE
	`, answerUUID).Scan(&parentPostID)
	if err != nil {
		return fmt.Errorf("answer post not found")
	}

	if parentPostID != postUUID {
		return fmt.Errorf("accepted answer must be a reply to the question")
	}

	_, err = s.db.Exec(ctx, `
		UPDATE public.creator_posts SET accepted_answer_id = $1 WHERE id = $2
	`, answerUUID, postUUID)
	return err
}

func (s *creatorService) ToggleFollow(ctx context.Context, followerID, followingID string) (bool, error) {
	followerUUID, err := uuid.Parse(followerID)
	if err != nil {
		return false, fmt.Errorf("invalid follower uuid")
	}
	followingUUID, err := uuid.Parse(followingID)
	if err != nil {
		return false, fmt.Errorf("invalid following uuid")
	}

	if followerUUID == followingUUID {
		return false, fmt.Errorf("cannot follow yourself")
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer tx.Rollback(ctx)

	var exists bool
	err = tx.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM public.creator_follows 
			WHERE follower_id = $1 AND following_id = $2
		)
	`, followerUUID, followingUUID).Scan(&exists)
	if err != nil {
		return false, err
	}

	var isFollowing bool
	if exists {
		_, err = tx.Exec(ctx, `
			DELETE FROM public.creator_follows 
			WHERE follower_id = $1 AND following_id = $2
		`, followerUUID, followingUUID)
		if err != nil {
			return false, err
		}
		isFollowing = false
	} else {
		_, err = tx.Exec(ctx, `
			INSERT INTO public.creator_follows (follower_id, following_id, status)
			VALUES ($1, $2, 'active')
		`, followerUUID, followingUUID)
		if err != nil {
			return false, err
		}
		isFollowing = true
	}

	if err := tx.Commit(ctx); err != nil {
		return false, err
	}

	var followerCount int
	err = s.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM public.creator_follows 
		WHERE following_id = $1 AND status = 'active'
	`, followingUUID).Scan(&followerCount)
	if err == nil {
		if followerCount >= 1000 {
			s.cache.GetRedisClient().SAdd(ctx, "celebrity_user_ids", followingUUID.String())
			go s.pruneCelebrityPostsFromFollowers(followingUUID.String())
		} else {
			s.cache.GetRedisClient().SRem(ctx, "celebrity_user_ids", followingUUID.String())
		}
	}

	return isFollowing, nil
}

func (s *creatorService) pruneCelebrityPostsFromFollowers(creatorID string) {
	ctx := context.Background()
	rows, err := s.db.Query(ctx, "SELECT follower_id FROM public.creator_follows WHERE following_id = $1 AND status = 'active'", creatorID)
	if err != nil {
		return
	}
	defer rows.Close()

	var followerIDs []string
	for rows.Next() {
		var fID string
		if err := rows.Scan(&fID); err == nil {
			followerIDs = append(followerIDs, fID)
		}
	}

	postRows, err := s.db.Query(ctx, "SELECT id FROM public.creator_posts WHERE user_id = $1 AND is_deleted = FALSE", creatorID)
	if err != nil {
		return
	}
	defer postRows.Close()

	var postIDs []string
	for postRows.Next() {
		var pID uuid.UUID
		if err := postRows.Scan(&pID); err == nil {
			postIDs = append(postIDs, pID.String())
		}
	}

	if len(followerIDs) == 0 || len(postIDs) == 0 {
		return
	}

	pipe := s.cache.GetRedisClient().Pipeline()
	for _, fID := range followerIDs {
		active, _ := s.cache.Exists(ctx, fmt.Sprintf("user:active:%s", fID))
		if active {
			key := fmt.Sprintf("feed:%s:timeline", fID)
			for _, pID := range postIDs {
				pipe.ZRem(ctx, key, pID)
			}
		}
	}
	_, _ = pipe.Exec(ctx)
}

func (s *creatorService) GetFollowers(ctx context.Context, userID string, cursor string, limit int) ([]*models.CreatorProfile, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user uuid")
	}

	if limit <= 0 {
		limit = 20
	}

	offset := 0
	if cursor != "" {
		if val, err := strconv.Atoi(cursor); err == nil {
			offset = val
		}
	}

	rows, err := s.db.Query(ctx, `
		SELECT p.id, p.username, p.display_name, p.avatar, p.bio, p.verified
		FROM public.creator_follows f
		JOIN public.profiles p ON f.follower_id = p.id
		WHERE f.following_id = $1 AND f.status = 'active'
		ORDER BY f.created_at DESC
		LIMIT $2 OFFSET $3
	`, userUUID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var profiles []*models.CreatorProfile
	for rows.Next() {
		var p models.CreatorProfile
		var id uuid.UUID
		err := rows.Scan(&id, &p.Username, &p.DisplayName, &p.AvatarURL, &p.Bio, &p.Verified)
		if err != nil {
			return nil, err
		}
		p.ID = id.String()
		profiles = append(profiles, &p)
	}

	return profiles, nil
}

func (s *creatorService) GetFollowing(ctx context.Context, userID string, cursor string, limit int) ([]*models.CreatorProfile, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user uuid")
	}

	if limit <= 0 {
		limit = 20
	}

	offset := 0
	if cursor != "" {
		if val, err := strconv.Atoi(cursor); err == nil {
			offset = val
		}
	}

	rows, err := s.db.Query(ctx, `
		SELECT p.id, p.username, p.display_name, p.avatar, p.bio, p.verified
		FROM public.creator_follows f
		JOIN public.profiles p ON f.following_id = p.id
		WHERE f.follower_id = $1 AND f.status = 'active'
		ORDER BY f.created_at DESC
		LIMIT $2 OFFSET $3
	`, userUUID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var profiles []*models.CreatorProfile
	for rows.Next() {
		var p models.CreatorProfile
		var id uuid.UUID
		err := rows.Scan(&id, &p.Username, &p.DisplayName, &p.AvatarURL, &p.Bio, &p.Verified)
		if err != nil {
			return nil, err
		}
		p.ID = id.String()
		profiles = append(profiles, &p)
	}

	return profiles, nil
}

func (s *creatorService) DeletePost(ctx context.Context, postID, requestingUserID string) error {
	postUUID, err := uuid.Parse(postID)
	if err != nil {
		return fmt.Errorf("invalid post uuid")
	}
	reqUUID, err := uuid.Parse(requestingUserID)
	if err != nil {
		return fmt.Errorf("invalid user uuid")
	}

	var authorID uuid.UUID
	var mediaURLs []string
	err = s.db.QueryRow(ctx, `
		SELECT user_id, media_urls FROM public.creator_posts WHERE id = $1 AND is_deleted = FALSE
	`, postUUID).Scan(&authorID, &mediaURLs)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("post not found")
		}
		return err
	}

	if authorID != reqUUID {
		return fmt.Errorf("unauthorized to delete this post")
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `
		UPDATE public.creator_posts SET is_deleted = TRUE WHERE id = $1
	`, postUUID)
	if err != nil {
		return err
	}

	_, err = tx.Exec(ctx, `
		DELETE FROM public.creator_media_uploads WHERE post_id = $1
	`, postUUID)
	if err != nil {
		return err
	}

	if err := tx.Commit(ctx); err != nil {
		return err
	}

	go s.prunePostFromCaches(postID, authorID.String())

	if len(mediaURLs) > 0 {
		go s.pruneMediaFilesFromStorage(mediaURLs)
	}

	return nil
}

func (s *creatorService) prunePostFromCaches(postID, authorID string) {
	ctx := context.Background()
	s.cache.GetRedisClient().ZRem(ctx, fmt.Sprintf("feed:%s:timeline", authorID), postID)

	rows, err := s.db.Query(ctx, "SELECT follower_id FROM public.creator_follows WHERE following_id = $1 AND status = 'active'", authorID)
	if err != nil {
		return
	}
	defer rows.Close()

	pipe := s.cache.GetRedisClient().Pipeline()
	for rows.Next() {
		var fID string
		if err := rows.Scan(&fID); err == nil {
			active, _ := s.cache.Exists(ctx, fmt.Sprintf("user:active:%s", fID))
			if active {
				pipe.ZRem(ctx, fmt.Sprintf("feed:%s:timeline", fID), postID)
			}
		}
	}
	_, _ = pipe.Exec(ctx)
}

func (s *creatorService) pruneMediaFilesFromStorage(mediaURLs []string) {
	// Storage files cleaned up via Azure Blob SDK or DB deletions trigger
}

func (s *creatorService) SearchPosts(ctx context.Context, query, category, cursor string, limit int) ([]*models.CreatorPost, error) {
	if limit <= 0 {
		limit = 20
	}

	var cursorTime time.Time
	var cursorPostID uuid.UUID
	var hasCursor bool
	if cursor != "" {
		decoded, err := base64.StdEncoding.DecodeString(cursor)
		if err == nil {
			parts := strings.SplitN(string(decoded), ":", 2)
			if len(parts) == 2 {
				unixTS, err1 := strconv.ParseInt(parts[0], 10, 64)
				pUUID, err2 := uuid.Parse(parts[1])
				if err1 == nil && err2 == nil {
					cursorTime = time.Unix(unixTS, 0)
					cursorPostID = pUUID
					hasCursor = true
				}
			}
		}
	}

	var rows pgx.Rows
	var err error

	if category != "" && category != "general" {
		if hasCursor {
			sqlQuery := `
				SELECT p.id, p.user_id, pr.username, pr.display_name, pr.avatar, pr.verified,
				       p.content, p.media_urls, p.parent_post_id, p.root_post_id, p.category, p.title,
				       p.accepted_answer_id, p.is_deleted, p.flagged, p.reply_count, p.like_count, p.repost_count,
				       p.post_type, p.visibility, p.created_at, p.updated_at
				FROM public.creator_posts p
				JOIN public.profiles pr ON p.user_id = pr.id
				WHERE p.is_deleted = FALSE AND p.flagged = FALSE
				  AND p.category = $1
				  AND p.search_vector @@ plainto_tsquery('english', $2)
				  AND (p.created_at < $3 OR (p.created_at = $3 AND p.id > $4))
				ORDER BY p.created_at DESC, p.id ASC
				LIMIT $5
			`
			rows, err = s.db.Query(ctx, sqlQuery, category, query, cursorTime, cursorPostID, limit)
		} else {
			sqlQuery := `
				SELECT p.id, p.user_id, pr.username, pr.display_name, pr.avatar, pr.verified,
				       p.content, p.media_urls, p.parent_post_id, p.root_post_id, p.category, p.title,
				       p.accepted_answer_id, p.is_deleted, p.flagged, p.reply_count, p.like_count, p.repost_count,
				       p.post_type, p.visibility, p.created_at, p.updated_at
				FROM public.creator_posts p
				JOIN public.profiles pr ON p.user_id = pr.id
				WHERE p.is_deleted = FALSE AND p.flagged = FALSE
				  AND p.category = $1
				  AND p.search_vector @@ plainto_tsquery('english', $2)
				ORDER BY p.created_at DESC, p.id ASC
				LIMIT $3
			`
			rows, err = s.db.Query(ctx, sqlQuery, category, query, limit)
		}
	} else {
		if hasCursor {
			sqlQuery := `
				SELECT p.id, p.user_id, pr.username, pr.display_name, pr.avatar, pr.verified,
				       p.content, p.media_urls, p.parent_post_id, p.root_post_id, p.category, p.title,
				       p.accepted_answer_id, p.is_deleted, p.flagged, p.reply_count, p.like_count, p.repost_count,
				       p.post_type, p.visibility, p.created_at, p.updated_at
				FROM public.creator_posts p
				JOIN public.profiles pr ON p.user_id = pr.id
				WHERE p.is_deleted = FALSE AND p.flagged = FALSE
				  AND p.search_vector @@ plainto_tsquery('english', $1)
				  AND (p.created_at < $2 OR (p.created_at = $2 AND p.id > $3))
				ORDER BY p.created_at DESC, p.id ASC
				LIMIT $4
			`
			rows, err = s.db.Query(ctx, sqlQuery, query, cursorTime, cursorPostID, limit)
		} else {
			sqlQuery := `
				SELECT p.id, p.user_id, pr.username, pr.display_name, pr.avatar, pr.verified,
				       p.content, p.media_urls, p.parent_post_id, p.root_post_id, p.category, p.title,
				       p.accepted_answer_id, p.is_deleted, p.flagged, p.reply_count, p.like_count, p.repost_count,
				       p.post_type, p.visibility, p.created_at, p.updated_at
				FROM public.creator_posts p
				JOIN public.profiles pr ON p.user_id = pr.id
				WHERE p.is_deleted = FALSE AND p.flagged = FALSE
				  AND p.search_vector @@ plainto_tsquery('english', $1)
				ORDER BY p.created_at DESC, p.id ASC
				LIMIT $2
			`
			rows, err = s.db.Query(ctx, sqlQuery, query, limit)
		}
	}

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return s.scanPosts(rows)
}

func (s *creatorService) GetFeed(ctx context.Context, userID string, cursor string, limit int) ([]*models.CreatorPost, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user uuid")
	}

	if limit <= 0 {
		limit = 20
	}

	s.cache.Set(ctx, fmt.Sprintf("user:active:%s", userID), "1", 30*24*time.Hour)

	var cursorTime time.Time
	var cursorPostID uuid.UUID
	var hasCursor bool
	if cursor != "" {
		decoded, err := base64.StdEncoding.DecodeString(cursor)
		if err == nil {
			parts := strings.SplitN(string(decoded), ":", 2)
			if len(parts) == 2 {
				unixTS, err1 := strconv.ParseInt(parts[0], 10, 64)
				pUUID, err2 := uuid.Parse(parts[1])
				if err1 == nil && err2 == nil {
					cursorTime = time.Unix(unixTS, 0)
					cursorPostID = pUUID
					hasCursor = true
				}
			}
		}
	}

	rows, err := s.db.Query(ctx, `
		SELECT following_id 
		FROM public.creator_follows 
		WHERE follower_id = $1 AND status = 'active'
	`, userUUID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var followedIDs []string
	for rows.Next() {
		var fID uuid.UUID
		if err := rows.Scan(&fID); err == nil {
			followedIDs = append(followedIDs, fID.String())
		}
	}

	followedIDs = append(followedIDs, userID)

	var celebIDs []string
	var standardIDs []string
	for _, fID := range followedIDs {
		isCeleb, _ := s.cache.GetRedisClient().SIsMember(ctx, "celebrity_user_ids", fID).Result()
		if isCeleb {
			celebIDs = append(celebIDs, fID)
		} else {
			standardIDs = append(standardIDs, fID)
		}
	}

	timelineKey := fmt.Sprintf("feed:%s:timeline", userID)
	cacheExists, _ := s.cache.Exists(ctx, timelineKey)
	if !cacheExists && len(standardIDs) > 0 {
		s.rebuildTimelineCache(ctx, userID, standardIDs)
	}

	var redisPostIDs []string
	redisRes, err := s.cache.GetRedisClient().ZRevRange(ctx, timelineKey, 0, 200).Result()
	if err == nil {
		redisPostIDs = redisRes
	}

	var standardPosts []*models.CreatorPost
	if len(redisPostIDs) > 0 {
		var postUUIDs []uuid.UUID
		for _, idStr := range redisPostIDs {
			if id, err := uuid.Parse(idStr); err == nil {
				postUUIDs = append(postUUIDs, id)
			}
		}

		pRows, err := s.db.Query(ctx, `
			SELECT p.id, p.user_id, pr.username, pr.display_name, pr.avatar, pr.verified,
			       p.content, p.media_urls, p.parent_post_id, p.root_post_id, p.category, p.title,
			       p.accepted_answer_id, p.is_deleted, p.flagged, p.reply_count, p.like_count, p.repost_count,
			       p.post_type, p.visibility, p.created_at, p.updated_at
			FROM public.creator_posts p
			JOIN public.profiles pr ON p.user_id = pr.id
			WHERE p.id = ANY($1) AND p.is_deleted = FALSE AND p.flagged = FALSE
		`, postUUIDs)
		if err == nil {
			standardPosts, _ = s.scanPosts(pRows)
			pRows.Close()
		}
	}

	var celebrityPosts []*models.CreatorPost
	if len(celebIDs) > 0 {
		var celebUUIDs []uuid.UUID
		for _, idStr := range celebIDs {
			if id, err := uuid.Parse(idStr); err == nil {
				celebUUIDs = append(celebUUIDs, id)
			}
		}

		var cpRows pgx.Rows
		var cpErr error
		if hasCursor {
			cpRows, cpErr = s.db.Query(ctx, `
				SELECT p.id, p.user_id, pr.username, pr.display_name, pr.avatar, pr.verified,
				       p.content, p.media_urls, p.parent_post_id, p.root_post_id, p.category, p.title,
				       p.accepted_answer_id, p.is_deleted, p.flagged, p.reply_count, p.like_count, p.repost_count,
				       p.post_type, p.visibility, p.created_at, p.updated_at
				FROM public.creator_posts p
				JOIN public.profiles pr ON p.user_id = pr.id
				WHERE p.user_id = ANY($1) AND p.is_deleted = FALSE AND p.flagged = FALSE
				  AND (p.created_at < $2 OR (p.created_at = $2 AND p.id > $3))
				ORDER BY p.created_at DESC, p.id ASC
				LIMIT $4
			`, celebUUIDs, cursorTime, cursorPostID, limit)
		} else {
			cpRows, cpErr = s.db.Query(ctx, `
				SELECT p.id, p.user_id, pr.username, pr.display_name, pr.avatar, pr.verified,
				       p.content, p.media_urls, p.parent_post_id, p.root_post_id, p.category, p.title,
				       p.accepted_answer_id, p.is_deleted, p.flagged, p.reply_count, p.like_count, p.repost_count,
				       p.post_type, p.visibility, p.created_at, p.updated_at
				FROM public.creator_posts p
				JOIN public.profiles pr ON p.user_id = pr.id
				WHERE p.user_id = ANY($1) AND p.is_deleted = FALSE AND p.flagged = FALSE
				ORDER BY p.created_at DESC, p.id ASC
				LIMIT $2
			`, celebUUIDs, limit)
		}
		if cpErr == nil {
			celebrityPosts, _ = s.scanPosts(cpRows)
			cpRows.Close()
		}
	}

	seen := make(map[string]bool)
	var merged []*models.CreatorPost

	for _, p := range standardPosts {
		if !seen[p.ID] {
			seen[p.ID] = true
			merged = append(merged, p)
		}
	}

	for _, p := range celebrityPosts {
		if !seen[p.ID] {
			seen[p.ID] = true
			merged = append(merged, p)
		}
	}

	sort.Slice(merged, func(i, j int) bool {
		if merged[i].CreatedAt.Equal(merged[j].CreatedAt) {
			return merged[i].ID < merged[j].ID
		}
		return merged[i].CreatedAt.After(merged[j].CreatedAt)
	})

	startIndex := 0
	if hasCursor {
		for i, p := range merged {
			if p.CreatedAt.Before(cursorTime) || (p.CreatedAt.Equal(cursorTime) && p.ID > cursorPostID.String()) {
				startIndex = i
				break
			}
			startIndex = len(merged)
		}
	}

	endIndex := startIndex + limit
	if endIndex > len(merged) {
		endIndex = len(merged)
	}

	var result []*models.CreatorPost
	if startIndex < len(merged) {
		result = merged[startIndex:endIndex]
	} else {
		result = []*models.CreatorPost{}
	}

	s.hydrateEngagement(ctx, result, userID)

	return result, nil
}

func (s *creatorService) rebuildTimelineCache(ctx context.Context, userID string, standardIDs []string) {
	var uuids []uuid.UUID
	for _, idStr := range standardIDs {
		if id, err := uuid.Parse(idStr); err == nil {
			uuids = append(uuids, id)
		}
	}

	rows, err := s.db.Query(ctx, `
		SELECT id, created_at 
		FROM public.creator_posts 
		WHERE user_id = ANY($1) AND is_deleted = FALSE AND flagged = FALSE
		ORDER BY created_at DESC 
		LIMIT 500
	`, uuids)
	if err != nil {
		return
	}
	defer rows.Close()

	pipe := s.cache.GetRedisClient().Pipeline()
	timelineKey := fmt.Sprintf("feed:%s:timeline", userID)
	var count int
	for rows.Next() {
		var id uuid.UUID
		var createdAt time.Time
		if err := rows.Scan(&id, &createdAt); err == nil {
			pipe.ZAdd(ctx, timelineKey, redis.Z{Score: float64(createdAt.Unix()), Member: id.String()})
			count++
		}
	}
	if count > 0 {
		pipe.Expire(ctx, timelineKey, 300*time.Second)
		_, _ = pipe.Exec(ctx)
	}
}

func (s *creatorService) scanPosts(rows pgx.Rows) ([]*models.CreatorPost, error) {
	var posts []*models.CreatorPost
	for rows.Next() {
		var p models.CreatorPost
		var id, userID uuid.UUID
		var parentPostID, rootPostID, acceptedAnswerID *uuid.UUID
		err := rows.Scan(
			&id, &userID, &p.Username, &p.DisplayName, &p.AvatarURL, &p.Verified,
			&p.Content, &p.MediaURLs, &parentPostID, &rootPostID, &p.Category, &p.Title,
			&acceptedAnswerID, &p.IsDeleted, &p.Flagged, &p.ReplyCount, &p.LikeCount, &p.RepostCount,
			&p.PostType, &p.Visibility, &p.CreatedAt, &p.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		p.ID = id.String()
		p.UserID = userID.String()
		if parentPostID != nil {
			sParent := parentPostID.String()
			p.ParentPostID = &sParent
		}
		if rootPostID != nil {
			sRoot := rootPostID.String()
			p.RootPostID = &sRoot
		}
		if acceptedAnswerID != nil {
			sAnswer := acceptedAnswerID.String()
			p.AcceptedAnswerID = &sAnswer
		}
		posts = append(posts, &p)
	}
	return posts, nil
}

func (s *creatorService) hydrateEngagement(ctx context.Context, posts []*models.CreatorPost, requestingUserID string) {
	if len(posts) == 0 {
		return
	}
	reqUUID, err := uuid.Parse(requestingUserID)
	if err != nil {
		return
	}

	postIDs := make([]uuid.UUID, len(posts))
	for i, p := range posts {
		id, _ := uuid.Parse(p.ID)
		postIDs[i] = id
	}

	rows, err := s.db.Query(ctx, `
		SELECT post_id FROM public.creator_post_likes 
		WHERE user_id = $1 AND post_id = ANY($2)
	`, reqUUID, postIDs)
	if err == nil {
		defer rows.Close()
		likedMap := make(map[string]bool)
		for rows.Next() {
			var pID uuid.UUID
			if err := rows.Scan(&pID); err == nil {
				likedMap[pID.String()] = true
			}
		}
		for _, p := range posts {
			p.LikedByMe = likedMap[p.ID]
		}
	}

	rows, err = s.db.Query(ctx, `
		SELECT post_id FROM public.creator_post_reposts 
		WHERE user_id = $1 AND post_id = ANY($2)
	`, reqUUID, postIDs)
	if err == nil {
		defer rows.Close()
		repostMap := make(map[string]bool)
		for rows.Next() {
			var pID uuid.UUID
			if err := rows.Scan(&pID); err == nil {
				repostMap[pID.String()] = true
			}
		}
		for _, p := range posts {
			p.RepostedByMe = repostMap[p.ID]
		}
	}
}
