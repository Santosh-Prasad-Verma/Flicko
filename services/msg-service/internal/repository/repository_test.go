package repository_test

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
	"github.com/flicko-org/flicko/services/shared/errors"
)

// ============================================================
//  Mock implementations — used by unit tests (no DB required).
// ============================================================

// mockMessageRepo is an in-memory MessageRepository for testing.
type mockMessageRepo struct {
	messages map[string]*repository.Message // keyed by ID
}

func newMockMessageRepo() *mockMessageRepo {
	return &mockMessageRepo{messages: make(map[string]*repository.Message)}
}

func (m *mockMessageRepo) Create(_ context.Context, msg *repository.Message) error {
	if _, ok := m.messages[msg.ID]; ok {
		return errors.ErrConflict("message already exists")
	}
	msg.CreatedAt = time.Now()
	m.messages[msg.ID] = msg
	return nil
}

func (m *mockMessageRepo) BulkInsert(_ context.Context, msgs []*repository.Message) error {
	for _, msg := range msgs {
		if _, ok := m.messages[msg.ID]; ok {
			return errors.ErrConflict("message already exists")
		}
		msg.CreatedAt = time.Now()
		m.messages[msg.ID] = msg
	}
	return nil
}

func (m *mockMessageRepo) GetByChannel(_ context.Context, channelID, before string, limit int) ([]*repository.Message, error) {
	var result []*repository.Message
	for _, msg := range m.messages {
		if msg.ChannelID != channelID {
			continue
		}
		if before != "" && msg.ID >= before {
			continue
		}
		result = append(result, msg)
		if len(result) >= limit {
			break
		}
	}
	return result, nil
}

func (m *mockMessageRepo) GetByID(_ context.Context, channelID, msgID string) (*repository.Message, error) {
	msg, ok := m.messages[msgID]
	if !ok || msg.ChannelID != channelID {
		return nil, errors.ErrNotFound("message")
	}
	return msg, nil
}

func (m *mockMessageRepo) GetByMessageID(_ context.Context, msgID string) (*repository.Message, error) {
	msg, ok := m.messages[msgID]
	if !ok {
		return nil, errors.ErrNotFound("message")
	}
	return msg, nil
}

func (m *mockMessageRepo) Update(_ context.Context, msgID, content string) error {
	msg, ok := m.messages[msgID]
	if !ok {
		return errors.ErrNotFound("message")
	}
	msg.Content = content
	msg.Edited = true
	now := time.Now()
	msg.EditedAt = &now
	return nil
}

func (m *mockMessageRepo) SoftDelete(_ context.Context, msgID string) error {
	msg, ok := m.messages[msgID]
	if !ok {
		return errors.ErrNotFound("message")
	}
	msg.Content = ""
	msg.Pinned = false
	return nil
}

func (m *mockMessageRepo) GetByNonce(_ context.Context, _, _ string) (*repository.Message, error) {
	return nil, nil
}

func (m *mockMessageRepo) Search(_ context.Context, _, _, _ string, _ int) ([]*repository.Message, error) {
	return nil, nil
}

// mockChannelRepo is an in-memory ChannelRepository for testing.
type mockChannelRepo struct {
	channels map[string]*repository.Channel
	members  map[string]map[string]bool // channelID → set of userIDs
}

func newMockChannelRepo() *mockChannelRepo {
	return &mockChannelRepo{
		channels: make(map[string]*repository.Channel),
		members:  make(map[string]map[string]bool),
	}
}

func (m *mockChannelRepo) Create(_ context.Context, ch *repository.Channel) error {
	if _, ok := m.channels[ch.ID]; ok {
		return errors.ErrConflict("channel already exists")
	}
	ch.CreatedAt = time.Now()
	m.channels[ch.ID] = ch
	return nil
}

func (m *mockChannelRepo) GetByID(_ context.Context, channelID string) (*repository.Channel, error) {
	ch, ok := m.channels[channelID]
	if !ok {
		return nil, errors.ErrNotFound("channel")
	}
	return ch, nil
}

func (m *mockChannelRepo) GetByGuild(_ context.Context, guildID string) ([]*repository.Channel, error) {
	var result []*repository.Channel
	for _, ch := range m.channels {
		if ch.ServerID == guildID {
			result = append(result, ch)
		}
	}
	return result, nil
}

func (m *mockChannelRepo) Update(_ context.Context, channelID string, u repository.ChannelUpdate) error {
	ch, ok := m.channels[channelID]
	if !ok {
		return errors.ErrNotFound("channel")
	}
	if u.Name != nil {
		ch.Name = *u.Name
	}
	if u.Topic != nil {
		ch.Topic = u.Topic
	}
	if u.Position != nil {
		ch.Position = *u.Position
	}
	return nil
}

func (m *mockChannelRepo) Delete(_ context.Context, channelID string) error {
	if _, ok := m.channels[channelID]; !ok {
		return errors.ErrNotFound("channel")
	}
	delete(m.channels, channelID)
	return nil
}

func (m *mockChannelRepo) IsMember(_ context.Context, channelID, userID string) (bool, error) {
	users, ok := m.members[channelID]
	if !ok {
		return false, nil
	}
	return users[userID], nil
}

// mockGuildRepo is an in-memory GuildRepository for testing.
type mockGuildRepo struct {
	guilds  map[string]*repository.Guild
	members map[string]map[string]*repository.Member // guildID → userID → Member
}

func newMockGuildRepo() *mockGuildRepo {
	return &mockGuildRepo{
		guilds:  make(map[string]*repository.Guild),
		members: make(map[string]map[string]*repository.Member),
	}
}

func (m *mockGuildRepo) Create(_ context.Context, g *repository.Guild) error {
	if _, ok := m.guilds[g.ID]; ok {
		return errors.ErrConflict("guild already exists")
	}
	g.CreatedAt = time.Now()
	m.guilds[g.ID] = g
	return nil
}

func (m *mockGuildRepo) GetByID(_ context.Context, guildID string) (*repository.Guild, error) {
	g, ok := m.guilds[guildID]
	if !ok {
		return nil, errors.ErrNotFound("guild")
	}
	return g, nil
}

func (m *mockGuildRepo) GetUserGuilds(_ context.Context, userID string) ([]*repository.Guild, error) {
	var result []*repository.Guild
	for gID, members := range m.members {
		if _, ok := members[userID]; ok {
			if g, gOK := m.guilds[gID]; gOK {
				result = append(result, g)
			}
		}
	}
	return result, nil
}

func (m *mockGuildRepo) AddMember(_ context.Context, guildID, userID string) error {
	if _, ok := m.guilds[guildID]; !ok {
		return errors.ErrNotFound("guild")
	}
	if m.members[guildID] == nil {
		m.members[guildID] = make(map[string]*repository.Member)
	}
	if _, ok := m.members[guildID][userID]; ok {
		return errors.ErrConflict("already a member")
	}
	m.members[guildID][userID] = &repository.Member{
		ServerID: guildID,
		UserID:   userID,
		JoinedAt: time.Now(),
	}
	return nil
}

func (m *mockGuildRepo) RemoveMember(_ context.Context, guildID, userID string) error {
	members, ok := m.members[guildID]
	if !ok {
		return errors.ErrNotFound("member")
	}
	if _, ok := members[userID]; !ok {
		return errors.ErrNotFound("member")
	}
	delete(members, userID)
	return nil
}

func (m *mockGuildRepo) GetMembers(_ context.Context, guildID string, limit, offset int) ([]*repository.Member, error) {
	members := m.members[guildID]
	all := make([]*repository.Member, 0, len(members))
	for _, mem := range members {
		all = append(all, mem)
	}
	if offset >= len(all) {
		return nil, nil
	}
	end := offset + limit
	if end > len(all) {
		end = len(all)
	}
	return all[offset:end], nil
}

func (m *mockGuildRepo) IsMember(_ context.Context, guildID, userID string) (bool, error) {
	members, ok := m.members[guildID]
	if !ok {
		return false, nil
	}
	_, exists := members[userID]
	return exists, nil
}

// ============================================================
//  Tests — Message Repository
// ============================================================

func TestMessageCreate(t *testing.T) {
	repo := newMockMessageRepo()
	ctx := context.Background()

	msg := &repository.Message{
		ID:        "msg-001",
		ChannelID: "ch-001",
		AuthorID:  "user-001",
		Content:   "Hello, Flicko!",
		Type:      "default",
	}

	if err := repo.Create(ctx, msg); err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if msg.CreatedAt.IsZero() {
		t.Error("CreatedAt should be set after Create()")
	}
}

func TestMessageCreateDuplicate(t *testing.T) {
	repo := newMockMessageRepo()
	ctx := context.Background()

	msg := &repository.Message{ID: "msg-001", ChannelID: "ch-001", AuthorID: "user-001", Content: "hi"}
	_ = repo.Create(ctx, msg)

	dup := &repository.Message{ID: "msg-001", ChannelID: "ch-001", AuthorID: "user-001", Content: "again"}
	err := repo.Create(ctx, dup)
	if err == nil {
		t.Fatal("expected conflict error on duplicate Create")
	}
	if errors.GetCode(err) != errors.CodeConflict {
		t.Errorf("expected CodeConflict, got %v", errors.GetCode(err))
	}
}

func TestMessageBulkInsert(t *testing.T) {
	repo := newMockMessageRepo()
	ctx := context.Background()

	msgs := []*repository.Message{
		{ID: "msg-001", ChannelID: "ch-001", AuthorID: "user-001", Content: "one"},
		{ID: "msg-002", ChannelID: "ch-001", AuthorID: "user-001", Content: "two"},
		{ID: "msg-003", ChannelID: "ch-001", AuthorID: "user-002", Content: "three"},
	}

	if err := repo.BulkInsert(ctx, msgs); err != nil {
		t.Fatalf("BulkInsert() error = %v", err)
	}
	if len(repo.messages) != 3 {
		t.Errorf("expected 3 messages, got %d", len(repo.messages))
	}
}

func TestMessageGetByID(t *testing.T) {
	repo := newMockMessageRepo()
	ctx := context.Background()

	_ = repo.Create(ctx, &repository.Message{
		ID: "msg-001", ChannelID: "ch-001", AuthorID: "user-001", Content: "test",
	})

	got, err := repo.GetByID(ctx, "ch-001", "msg-001")
	if err != nil {
		t.Fatalf("GetByID() error = %v", err)
	}
	if got.Content != "test" {
		t.Errorf("Content = %q, want %q", got.Content, "test")
	}
}

func TestMessageGetByIDNotFound(t *testing.T) {
	repo := newMockMessageRepo()
	_, err := repo.GetByID(context.Background(), "ch-001", "nonexistent")
	if err == nil {
		t.Fatal("expected not found error")
	}
	if errors.GetCode(err) != errors.CodeNotFound {
		t.Errorf("expected CodeNotFound, got %v", errors.GetCode(err))
	}
}

func TestMessageUpdate(t *testing.T) {
	repo := newMockMessageRepo()
	ctx := context.Background()
	_ = repo.Create(ctx, &repository.Message{
		ID: "msg-001", ChannelID: "ch-001", AuthorID: "user-001", Content: "original",
	})

	if err := repo.Update(ctx, "msg-001", "edited content"); err != nil {
		t.Fatalf("Update() error = %v", err)
	}

	msg := repo.messages["msg-001"]
	if msg.Content != "edited content" {
		t.Errorf("Content = %q, want %q", msg.Content, "edited content")
	}
	if !msg.Edited {
		t.Error("Edited should be true after Update()")
	}
	if msg.EditedAt == nil {
		t.Error("EditedAt should be set after Update()")
	}
}

func TestMessageUpdateNotFound(t *testing.T) {
	repo := newMockMessageRepo()
	err := repo.Update(context.Background(), "nonexistent", "nope")
	if errors.GetCode(err) != errors.CodeNotFound {
		t.Errorf("expected CodeNotFound, got %v", errors.GetCode(err))
	}
}

func TestMessageSoftDelete(t *testing.T) {
	repo := newMockMessageRepo()
	ctx := context.Background()
	_ = repo.Create(ctx, &repository.Message{
		ID: "msg-001", ChannelID: "ch-001", AuthorID: "user-001",
		Content: "to be deleted", Pinned: true,
	})

	if err := repo.SoftDelete(ctx, "msg-001"); err != nil {
		t.Fatalf("SoftDelete() error = %v", err)
	}

	msg := repo.messages["msg-001"]
	if msg.Content != "" {
		t.Errorf("Content should be empty after SoftDelete, got %q", msg.Content)
	}
	if msg.Pinned {
		t.Error("Pinned should be false after SoftDelete")
	}
}

func TestMessageGetByChannel(t *testing.T) {
	repo := newMockMessageRepo()
	ctx := context.Background()

	for i := 0; i < 5; i++ {
		_ = repo.Create(ctx, &repository.Message{
			ID: "msg-" + string(rune('A'+i)), ChannelID: "ch-001",
			AuthorID: "user-001", Content: "msg",
		})
	}
	// Different channel — should not appear.
	_ = repo.Create(ctx, &repository.Message{
		ID: "msg-other", ChannelID: "ch-002", AuthorID: "user-001", Content: "other",
	})

	got, err := repo.GetByChannel(ctx, "ch-001", "", 10)
	if err != nil {
		t.Fatalf("GetByChannel() error = %v", err)
	}
	if len(got) != 5 {
		t.Errorf("expected 5 messages, got %d", len(got))
	}
}

func TestMessageGetByNonceReturnsNil(t *testing.T) {
	repo := newMockMessageRepo()
	msg, err := repo.GetByNonce(context.Background(), "ch-001", "some-nonce")
	if err != nil {
		t.Fatalf("GetByNonce() error = %v", err)
	}
	if msg != nil {
		t.Error("expected nil message from GetByNonce stub")
	}
}

// ============================================================
//  Tests — Channel Repository
// ============================================================

func TestChannelCreateAndGet(t *testing.T) {
	repo := newMockChannelRepo()
	ctx := context.Background()

	ch := &repository.Channel{
		ID: "ch-001", ServerID: "guild-001", Name: "general", Type: "text",
	}
	if err := repo.Create(ctx, ch); err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	got, err := repo.GetByID(ctx, "ch-001")
	if err != nil {
		t.Fatalf("GetByID() error = %v", err)
	}
	if got.Name != "general" {
		t.Errorf("Name = %q, want %q", got.Name, "general")
	}
}

func TestChannelGetByGuild(t *testing.T) {
	repo := newMockChannelRepo()
	ctx := context.Background()

	_ = repo.Create(ctx, &repository.Channel{ID: "ch-001", ServerID: "guild-001", Name: "general", Type: "text"})
	_ = repo.Create(ctx, &repository.Channel{ID: "ch-002", ServerID: "guild-001", Name: "random", Type: "text"})
	_ = repo.Create(ctx, &repository.Channel{ID: "ch-003", ServerID: "guild-002", Name: "other", Type: "text"})

	got, err := repo.GetByGuild(ctx, "guild-001")
	if err != nil {
		t.Fatalf("GetByGuild() error = %v", err)
	}
	if len(got) != 2 {
		t.Errorf("expected 2 channels, got %d", len(got))
	}
}

func TestChannelUpdate(t *testing.T) {
	repo := newMockChannelRepo()
	ctx := context.Background()
	_ = repo.Create(ctx, &repository.Channel{ID: "ch-001", ServerID: "guild-001", Name: "old", Type: "text"})

	newName := "renamed"
	if err := repo.Update(ctx, "ch-001", repository.ChannelUpdate{Name: &newName}); err != nil {
		t.Fatalf("Update() error = %v", err)
	}
	ch := repo.channels["ch-001"]
	if ch.Name != "renamed" {
		t.Errorf("Name = %q, want %q", ch.Name, "renamed")
	}
}

func TestChannelDelete(t *testing.T) {
	repo := newMockChannelRepo()
	ctx := context.Background()
	_ = repo.Create(ctx, &repository.Channel{ID: "ch-001", ServerID: "guild-001", Name: "general", Type: "text"})

	if err := repo.Delete(ctx, "ch-001"); err != nil {
		t.Fatalf("Delete() error = %v", err)
	}
	if _, ok := repo.channels["ch-001"]; ok {
		t.Error("channel should be deleted")
	}
}

func TestChannelDeleteNotFound(t *testing.T) {
	repo := newMockChannelRepo()
	err := repo.Delete(context.Background(), "nonexistent")
	if errors.GetCode(err) != errors.CodeNotFound {
		t.Errorf("expected CodeNotFound, got %v", errors.GetCode(err))
	}
}

func TestChannelIsMember(t *testing.T) {
	repo := newMockChannelRepo()
	repo.members["ch-001"] = map[string]bool{"user-001": true}

	ok, err := repo.IsMember(context.Background(), "ch-001", "user-001")
	if err != nil {
		t.Fatalf("IsMember() error = %v", err)
	}
	if !ok {
		t.Error("expected IsMember to return true")
	}

	ok, err = repo.IsMember(context.Background(), "ch-001", "user-999")
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Error("expected IsMember to return false for non-member")
	}
}

// ============================================================
//  Tests — Guild Repository
// ============================================================

func TestGuildCreateAndGet(t *testing.T) {
	repo := newMockGuildRepo()
	ctx := context.Background()

	g := &repository.Guild{ID: "guild-001", Name: "Test Server", OwnerID: "user-001", Region: "us-east"}
	if err := repo.Create(ctx, g); err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	got, err := repo.GetByID(ctx, "guild-001")
	if err != nil {
		t.Fatalf("GetByID() error = %v", err)
	}
	if got.Name != "Test Server" {
		t.Errorf("Name = %q, want %q", got.Name, "Test Server")
	}
}

func TestGuildAddAndRemoveMember(t *testing.T) {
	repo := newMockGuildRepo()
	ctx := context.Background()

	_ = repo.Create(ctx, &repository.Guild{ID: "guild-001", Name: "Test", OwnerID: "user-001"})

	if err := repo.AddMember(ctx, "guild-001", "user-002"); err != nil {
		t.Fatalf("AddMember() error = %v", err)
	}

	// Adding again should conflict.
	err := repo.AddMember(ctx, "guild-001", "user-002")
	if errors.GetCode(err) != errors.CodeConflict {
		t.Errorf("expected CodeConflict on double add, got %v", errors.GetCode(err))
	}

	if err := repo.RemoveMember(ctx, "guild-001", "user-002"); err != nil {
		t.Fatalf("RemoveMember() error = %v", err)
	}

	// Removing again should be not found.
	err = repo.RemoveMember(ctx, "guild-001", "user-002")
	if errors.GetCode(err) != errors.CodeNotFound {
		t.Errorf("expected CodeNotFound on remove non-member, got %v", errors.GetCode(err))
	}
}

func TestGuildGetUserGuilds(t *testing.T) {
	repo := newMockGuildRepo()
	ctx := context.Background()

	_ = repo.Create(ctx, &repository.Guild{ID: "guild-001", Name: "Server A", OwnerID: "user-001"})
	_ = repo.Create(ctx, &repository.Guild{ID: "guild-002", Name: "Server B", OwnerID: "user-001"})
	_ = repo.Create(ctx, &repository.Guild{ID: "guild-003", Name: "Server C", OwnerID: "user-002"})
	_ = repo.AddMember(ctx, "guild-001", "user-010")
	_ = repo.AddMember(ctx, "guild-002", "user-010")

	got, err := repo.GetUserGuilds(ctx, "user-010")
	if err != nil {
		t.Fatalf("GetUserGuilds() error = %v", err)
	}
	if len(got) != 2 {
		t.Errorf("expected 2 guilds, got %d", len(got))
	}
}

func TestGuildGetMembers(t *testing.T) {
	repo := newMockGuildRepo()
	ctx := context.Background()
	_ = repo.Create(ctx, &repository.Guild{ID: "guild-001", Name: "Test", OwnerID: "user-001"})
	_ = repo.AddMember(ctx, "guild-001", "user-001")
	_ = repo.AddMember(ctx, "guild-001", "user-002")
	_ = repo.AddMember(ctx, "guild-001", "user-003")

	got, err := repo.GetMembers(ctx, "guild-001", 2, 0)
	if err != nil {
		t.Fatalf("GetMembers() error = %v", err)
	}
	if len(got) != 2 {
		t.Errorf("expected 2 members (limit), got %d", len(got))
	}

	got2, _ := repo.GetMembers(ctx, "guild-001", 10, 2)
	if len(got2) != 1 {
		t.Errorf("expected 1 member (offset 2), got %d", len(got2))
	}
}

// ============================================================
//  Model tests
// ============================================================

func TestDefaultJSONB(t *testing.T) {
	att := repository.DefaultAttachments()
	emb := repository.DefaultEmbeds()
	if string(att) != "[]" {
		t.Errorf("DefaultAttachments = %s, want []", att)
	}
	if string(emb) != "[]" {
		t.Errorf("DefaultEmbeds = %s, want []", emb)
	}
}

func TestMessageJSON(t *testing.T) {
	msg := &repository.Message{
		ID:          "msg-001",
		ChannelID:   "ch-001",
		AuthorID:    "user-001",
		Content:     "hello",
		Attachments: repository.DefaultAttachments(),
		Embeds:      repository.DefaultEmbeds(),
		Type:        "default",
		CreatedAt:   time.Now(),
	}
	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("json.Marshal error = %v", err)
	}
	var decoded repository.Message
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("json.Unmarshal error = %v", err)
	}
	if decoded.ID != "msg-001" {
		t.Errorf("ID = %q, want %q", decoded.ID, "msg-001")
	}
	if decoded.Content != "hello" {
		t.Errorf("Content = %q, want %q", decoded.Content, "hello")
	}
}

// Verify mocks satisfy interfaces at compile time.
var _ repository.MessageRepository = (*mockMessageRepo)(nil)
var _ repository.ChannelRepository = (*mockChannelRepo)(nil)
var _ repository.GuildRepository = (*mockGuildRepo)(nil)
