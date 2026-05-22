package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

type CreatorHandler struct {
	creatorSvc services.CreatorService
	logger     *zap.Logger
}

func NewCreatorHandler(creatorSvc services.CreatorService, logger *zap.Logger) *CreatorHandler {
	return &CreatorHandler{
		creatorSvc: creatorSvc,
		logger:     logger,
	}
}

// ── Create Post ─────────────────────────────────────────────────────────────

type createPostRequest struct {
	Content      string   `json:"content"`
	MediaURLs    []string `json:"media_urls"`
	ParentPostID *string  `json:"parent_post_id"`
	RootPostID   *string  `json:"root_post_id"`
	Category     string   `json:"category"`
	Title        *string  `json:"title"`
	PostType     string   `json:"post_type"`
	Visibility   string   `json:"visibility"`
}

func (h *CreatorHandler) CreatePost(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req createPostRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Basic validation
	if req.Content == "" && len(req.MediaURLs) == 0 {
		writeError(w, http.StatusBadRequest, "Content or media_urls is required")
		return
	}

	if req.Visibility == "" {
		req.Visibility = "public"
	}
	if req.PostType == "" {
		req.PostType = "tweet"
	}
	if req.Category == "" {
		req.Category = "general"
	}

	// Valid types check
	if req.PostType != "tweet" && req.PostType != "discussion" && req.PostType != "qna" {
		writeError(w, http.StatusBadRequest, "Invalid post_type; must be 'tweet', 'discussion', or 'qna'")
		return
	}
	if req.Visibility != "public" && req.Visibility != "followers" {
		writeError(w, http.StatusBadRequest, "Invalid visibility; must be 'public' or 'followers'")
		return
	}

	post := &models.CreatorPost{
		UserID:       userID,
		Content:      req.Content,
		MediaURLs:    req.MediaURLs,
		ParentPostID: req.ParentPostID,
		RootPostID:   req.RootPostID,
		Category:     req.Category,
		Title:        req.Title,
		PostType:     req.PostType,
		Visibility:   req.Visibility,
	}

	err := h.creatorSvc.CreatePost(r.Context(), post)
	if err != nil {
		h.logger.Error("failed to create post", zap.Error(err), zap.String("user_id", userID))
		writeError(w, http.StatusInternalServerError, "Failed to create post: "+err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, post)
}

// ── Get User Profile ────────────────────────────────────────────────────────

func (h *CreatorHandler) GetUserProfile(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	targetUserID := vars["id"]
	if targetUserID == "" {
		writeError(w, http.StatusBadRequest, "User ID is required")
		return
	}

	requestingUserID := getUserID(r)

	profile, err := h.creatorSvc.GetUserProfile(r.Context(), targetUserID, requestingUserID)
	if err != nil {
		h.logger.Error("failed to get user profile", zap.Error(err), zap.String("target_user_id", targetUserID))
		writeError(w, http.StatusNotFound, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, profile)
}

// ── Get User Posts ──────────────────────────────────────────────────────────

func (h *CreatorHandler) GetUserPosts(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	targetUserID := vars["id"]
	if targetUserID == "" {
		writeError(w, http.StatusBadRequest, "User ID is required")
		return
	}

	requestingUserID := getUserID(r)

	q := r.URL.Query()
	cursor := q.Get("cursor")
	limit := 20
	if limitVal := q.Get("limit"); limitVal != "" {
		if val, err := strconv.Atoi(limitVal); err == nil && val > 0 {
			limit = val
		}
	}

	posts, err := h.creatorSvc.GetUserPosts(r.Context(), targetUserID, requestingUserID, cursor, limit)
	if err != nil {
		h.logger.Error("failed to get user posts", zap.Error(err), zap.String("target_user_id", targetUserID))
		writeError(w, http.StatusInternalServerError, "Failed to fetch posts")
		return
	}

	writeJSON(w, http.StatusOK, posts)
}

// ── Get Post ────────────────────────────────────────────────────────────────

func (h *CreatorHandler) GetPost(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	postID := vars["id"]
	if postID == "" {
		writeError(w, http.StatusBadRequest, "Post ID is required")
		return
	}

	requestingUserID := getUserID(r)

	post, err := h.creatorSvc.GetPost(r.Context(), postID, requestingUserID)
	if err != nil {
		h.logger.Error("failed to get post", zap.Error(err), zap.String("post_id", postID))
		writeError(w, http.StatusNotFound, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, post)
}

// ── Get Replies ─────────────────────────────────────────────────────────────

func (h *CreatorHandler) GetReplies(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	postID := vars["id"]
	if postID == "" {
		writeError(w, http.StatusBadRequest, "Post ID is required")
		return
	}

	requestingUserID := getUserID(r)

	replies, err := h.creatorSvc.GetReplies(r.Context(), postID, requestingUserID)
	if err != nil {
		h.logger.Error("failed to get replies", zap.Error(err), zap.String("post_id", postID))
		writeError(w, http.StatusInternalServerError, "Failed to fetch replies")
		return
	}

	writeJSON(w, http.StatusOK, replies)
}

// ── Toggle Like ─────────────────────────────────────────────────────────────

func (h *CreatorHandler) ToggleLike(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	vars := mux.Vars(r)
	postID := vars["id"]
	if postID == "" {
		writeError(w, http.StatusBadRequest, "Post ID is required")
		return
	}

	liked, err := h.creatorSvc.ToggleLike(r.Context(), postID, userID)
	if err != nil {
		h.logger.Error("failed to toggle like", zap.Error(err), zap.String("post_id", postID), zap.String("user_id", userID))
		writeError(w, http.StatusInternalServerError, "Failed to update like status")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"liked": liked,
	})
}

// ── Toggle Repost ───────────────────────────────────────────────────────────

func (h *CreatorHandler) ToggleRepost(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	vars := mux.Vars(r)
	postID := vars["id"]
	if postID == "" {
		writeError(w, http.StatusBadRequest, "Post ID is required")
		return
	}

	reposted, err := h.creatorSvc.ToggleRepost(r.Context(), postID, userID)
	if err != nil {
		h.logger.Error("failed to toggle repost", zap.Error(err), zap.String("post_id", postID), zap.String("user_id", userID))
		writeError(w, http.StatusInternalServerError, "Failed to update repost status")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"reposted": reposted,
	})
}

// ── Mark Accepted Answer ────────────────────────────────────────────────────

type markAcceptedAnswerRequest struct {
	AnswerID string `json:"answer_id"`
}

func (h *CreatorHandler) MarkAcceptedAnswer(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	vars := mux.Vars(r)
	postID := vars["id"]
	if postID == "" {
		writeError(w, http.StatusBadRequest, "Post ID is required")
		return
	}

	var req markAcceptedAnswerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.AnswerID == "" {
		writeError(w, http.StatusBadRequest, "Invalid request body or answer_id is missing")
		return
	}

	err := h.creatorSvc.MarkAcceptedAnswer(r.Context(), postID, req.AnswerID, userID)
	if err != nil {
		h.logger.Error("failed to mark accepted answer", zap.Error(err), zap.String("post_id", postID), zap.String("answer_id", req.AnswerID))
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "accepted"})
}

// ── Get Feed ────────────────────────────────────────────────────────────────

func (h *CreatorHandler) GetFeed(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	q := r.URL.Query()
	cursor := q.Get("cursor")
	limit := 20
	if limitVal := q.Get("limit"); limitVal != "" {
		if val, err := strconv.Atoi(limitVal); err == nil && val > 0 {
			limit = val
		}
	}

	feed, err := h.creatorSvc.GetFeed(r.Context(), userID, cursor, limit)
	if err != nil {
		h.logger.Error("failed to get feed", zap.Error(err), zap.String("user_id", userID))
		writeError(w, http.StatusInternalServerError, "Failed to fetch feed")
		return
	}

	writeJSON(w, http.StatusOK, feed)
}

// ── Toggle Follow ───────────────────────────────────────────────────────────

func (h *CreatorHandler) ToggleFollow(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	vars := mux.Vars(r)
	targetUserID := vars["id"]
	if targetUserID == "" {
		writeError(w, http.StatusBadRequest, "User ID is required")
		return
	}

	following, err := h.creatorSvc.ToggleFollow(r.Context(), userID, targetUserID)
	if err != nil {
		h.logger.Error("failed to toggle follow", zap.Error(err), zap.String("follower_id", userID), zap.String("following_id", targetUserID))
		writeError(w, http.StatusInternalServerError, "Failed to update follow status: "+err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"following": following,
	})
}

// ── Get Followers ───────────────────────────────────────────────────────────

func (h *CreatorHandler) GetFollowers(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	targetUserID := vars["id"]
	if targetUserID == "" {
		writeError(w, http.StatusBadRequest, "User ID is required")
		return
	}

	q := r.URL.Query()
	cursor := q.Get("cursor")
	limit := 20
	if limitVal := q.Get("limit"); limitVal != "" {
		if val, err := strconv.Atoi(limitVal); err == nil && val > 0 {
			limit = val
		}
	}

	followers, err := h.creatorSvc.GetFollowers(r.Context(), targetUserID, cursor, limit)
	if err != nil {
		h.logger.Error("failed to get followers", zap.Error(err), zap.String("user_id", targetUserID))
		writeError(w, http.StatusInternalServerError, "Failed to fetch followers")
		return
	}

	writeJSON(w, http.StatusOK, followers)
}

// ── Get Following ───────────────────────────────────────────────────────────

func (h *CreatorHandler) GetFollowing(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	targetUserID := vars["id"]
	if targetUserID == "" {
		writeError(w, http.StatusBadRequest, "User ID is required")
		return
	}

	q := r.URL.Query()
	cursor := q.Get("cursor")
	limit := 20
	if limitVal := q.Get("limit"); limitVal != "" {
		if val, err := strconv.Atoi(limitVal); err == nil && val > 0 {
			limit = val
		}
	}

	following, err := h.creatorSvc.GetFollowing(r.Context(), targetUserID, cursor, limit)
	if err != nil {
		h.logger.Error("failed to get following", zap.Error(err), zap.String("user_id", targetUserID))
		writeError(w, http.StatusInternalServerError, "Failed to fetch following")
		return
	}

	writeJSON(w, http.StatusOK, following)
}

// ── Delete Post ─────────────────────────────────────────────────────────────

func (h *CreatorHandler) DeletePost(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	vars := mux.Vars(r)
	postID := vars["id"]
	if postID == "" {
		writeError(w, http.StatusBadRequest, "Post ID is required")
		return
	}

	err := h.creatorSvc.DeletePost(r.Context(), postID, userID)
	if err != nil {
		h.logger.Error("failed to delete post", zap.Error(err), zap.String("post_id", postID), zap.String("user_id", userID))
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

// ── Search Posts ────────────────────────────────────────────────────────────

func (h *CreatorHandler) SearchPosts(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	query := q.Get("q")
	if query == "" {
		writeError(w, http.StatusBadRequest, "Search query 'q' is required")
		return
	}

	category := q.Get("category")
	cursor := q.Get("cursor")
	limit := 20
	if limitVal := q.Get("limit"); limitVal != "" {
		if val, err := strconv.Atoi(limitVal); err == nil && val > 0 {
			limit = val
		}
	}

	posts, err := h.creatorSvc.SearchPosts(r.Context(), query, category, cursor, limit)
	if err != nil {
		h.logger.Error("failed to search posts", zap.Error(err), zap.String("query", query), zap.String("category", category))
		writeError(w, http.StatusInternalServerError, "Failed to search posts")
		return
	}

	writeJSON(w, http.StatusOK, posts)
}

// ── Generate Upload URL ─────────────────────────────────────────────────────

type generateUploadURLRequest struct {
	Filename    string `json:"filename"`
	ContentType string `json:"content_type"`
}

func (h *CreatorHandler) GenerateUploadPresignedURL(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var req generateUploadURLRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.Filename == "" || req.ContentType == "" {
		writeError(w, http.StatusBadRequest, "filename and content_type are required")
		return
	}

	signedURL, publicURL, err := h.creatorSvc.GenerateUploadPresignedURL(r.Context(), req.Filename, req.ContentType, userID)
	if err != nil {
		h.logger.Error("failed to generate signed upload url", zap.Error(err), zap.String("user_id", userID))
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"upload_url": signedURL,
		"public_url": publicURL,
	})
}
