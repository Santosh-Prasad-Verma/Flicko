package services_test

import (
	"context"
	"reflect"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/mock"
)

// MockDatabaseClient for testing
type MockDatabaseClient struct {
	mock.Mock
}

func (m *MockDatabaseClient) Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error) {
	callArgs := append([]any{ctx, sql}, args...)
	r := m.Called(callArgs...)
	if r.Get(0) == nil {
		return nil, r.Error(1)
	}
	return r.Get(0).(pgx.Rows), r.Error(1)
}

func (m *MockDatabaseClient) QueryRow(ctx context.Context, sql string, args ...any) pgx.Row {
	callArgs := append([]any{ctx, sql}, args...)
	return m.Called(callArgs...).Get(0).(pgx.Row)
}

func (m *MockDatabaseClient) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
	callArgs := append([]any{ctx, sql}, args...)
	r := m.Called(callArgs...)
	if r.Get(0) == nil {
		return pgconn.CommandTag{}, r.Error(1)
	}
	return r.Get(0).(pgconn.CommandTag), r.Error(1)
}

func (m *MockDatabaseClient) Close() {
	m.Called()
}

func (m *MockDatabaseClient) Ping(ctx context.Context) error {
	args := m.Called(ctx)
	return args.Error(0)
}

func (m *MockDatabaseClient) Pool() *pgxpool.Pool {
	args := m.Called()
	if args.Get(0) == nil {
		return nil
	}
	return args.Get(0).(*pgxpool.Pool)
}

func (m *MockDatabaseClient) Begin(ctx context.Context) (pgx.Tx, error) {
	args := m.Called(ctx)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(pgx.Tx), args.Error(1)
}

// MockTx for testing
type MockTx struct {
	mock.Mock
}

func (m *MockTx) Begin(ctx context.Context) (pgx.Tx, error) {
	args := m.Called(ctx)
	return args.Get(0).(pgx.Tx), args.Error(1)
}

func (m *MockTx) Commit(ctx context.Context) error {
	return m.Called(ctx).Error(0)
}

func (m *MockTx) Rollback(ctx context.Context) error {
	return m.Called(ctx).Error(0)
}

func (m *MockTx) CopyFrom(ctx context.Context, tableName pgx.Identifier, columnNames []string, rowSrc pgx.CopyFromSource) (int64, error) {
	args := m.Called(ctx, tableName, columnNames, rowSrc)
	return args.Get(0).(int64), args.Error(1)
}

func (m *MockTx) SendBatch(ctx context.Context, b *pgx.Batch) pgx.BatchResults {
	return m.Called(ctx, b).Get(0).(pgx.BatchResults)
}

func (m *MockTx) LargeObjects() pgx.LargeObjects {
	return m.Called().Get(0).(pgx.LargeObjects)
}

func (m *MockTx) Prepare(ctx context.Context, name, sql string) (*pgconn.StatementDescription, error) {
	args := m.Called(ctx, name, sql)
	return args.Get(0).(*pgconn.StatementDescription), args.Error(1)
}

func (m *MockTx) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
	callArgs := append([]any{ctx, sql}, args...)
	r := m.Called(callArgs...)
	if r.Get(0) == nil {
		return pgconn.CommandTag{}, r.Error(1)
	}
	return r.Get(0).(pgconn.CommandTag), r.Error(1)
}

func (m *MockTx) Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error) {
	callArgs := append([]any{ctx, sql}, args...)
	r := m.Called(callArgs...)
	if r.Get(0) == nil {
		return nil, r.Error(1)
	}
	return r.Get(0).(pgx.Rows), r.Error(1)
}

func (m *MockTx) QueryRow(ctx context.Context, sql string, args ...any) pgx.Row {
	callArgs := append([]any{ctx, sql}, args...)
	return m.Called(callArgs...).Get(0).(pgx.Row)
}

func (m *MockTx) Conn() *pgx.Conn {
	return m.Called().Get(0).(*pgx.Conn)
}

// MockRows for testing
type MockRows struct {
	mock.Mock
	NextFunc func() bool
}

func (m *MockRows) Close()                      { m.Called() }
func (m *MockRows) Err() error                  { return m.Called().Error(0) }
func (m *MockRows) CommandTag() pgconn.CommandTag { return m.Called().Get(0).(pgconn.CommandTag) }
func (m *MockRows) FieldDescriptions() []pgconn.FieldDescription {
	return m.Called().Get(0).([]pgconn.FieldDescription)
}
func (m *MockRows) Next() bool {
	if m.NextFunc != nil {
		return m.NextFunc()
	}
	return m.Called().Bool(0)
}
func (m *MockRows) Scan(dest ...any) error {
	args := m.Called(dest...)
	return args.Error(0)
}
func (m *MockRows) Values() ([]any, error) {
	args := m.Called()
	return args.Get(0).([]any), args.Error(1)
}
func (m *MockRows) RawValues() [][]byte {
	return m.Called().Get(0).([][]byte)
}
func (m *MockRows) Conn() *pgx.Conn {
	return m.Called().Get(0).(*pgx.Conn)
}

// MockRow for testing QueryRow
type MockRow struct {
	mock.Mock
	values []any
}

func NewMockRow(values ...any) *MockRow {
	return &MockRow{values: values}
}

func (m *MockRow) Scan(dest ...any) error {
	if len(m.values) == 0 {
		args := m.Called(dest...)
		return args.Error(0)
	}

	for i, d := range dest {
		if i >= len(m.values) {
			break
		}

		if m.values[i] == nil {
			continue
		}

		destVal := reflect.ValueOf(d)
		if destVal.Kind() != reflect.Ptr {
			continue
		}

		elem := destVal.Elem()
		srcVal := reflect.ValueOf(m.values[i])

		if srcVal.Type().AssignableTo(elem.Type()) {
			elem.Set(srcVal)
		} else if srcVal.Kind() == reflect.String && elem.Kind() == reflect.Ptr && elem.Type().Elem().Kind() == reflect.String {
			// Handle string to *string
			s := srcVal.String()
			elem.Set(reflect.ValueOf(&s))
		} else if srcVal.Type().String() == "uuid.UUID" && elem.Kind() == reflect.String {
			// Handle uuid.UUID to string
			elem.Set(reflect.ValueOf(srcVal.Interface().(uuid.UUID).String()))
		} else if srcVal.Type().ConvertibleTo(elem.Type()) {
			elem.Set(srcVal.Convert(elem.Type()))
		}
	}
	return nil
}

// MockPermissionService for testing
type MockPermissionService struct {
	mock.Mock
}

func (m *MockPermissionService) HasPermission(ctx context.Context, userID, channelID uuid.UUID, permission string) (bool, error) {
	args := m.Called(ctx, userID, channelID, permission)
	return args.Bool(0), args.Error(1)
}

func (m *MockPermissionService) HasServerPermission(ctx context.Context, userID, serverID uuid.UUID, permission string) (bool, error) {
	args := m.Called(ctx, userID, serverID, permission)
	return args.Bool(0), args.Error(1)
}

func (m *MockPermissionService) InvalidatePermissionCache(ctx context.Context, userID, channelID uuid.UUID) error {
	args := m.Called(ctx, userID, channelID)
	return args.Error(0)
}

// MockAuditLogService for testing
type MockAuditLogService struct {
	mock.Mock
}

func (m *MockAuditLogService) CreateLog(ctx context.Context, serverID string, actorID *string, actionType models.AuditLogAction, targetType string, targetID, reason *string, changes map[string]interface{}) error {
	args := m.Called(ctx, serverID, actorID, actionType, targetType, targetID, reason, changes)
	return args.Error(0)
}

func (m *MockAuditLogService) GetLogs(ctx context.Context, serverID, executorID string, actionType, actorID, targetType *string, limit, offset int) ([]*models.AuditLog, error) {
	args := m.Called(ctx, serverID, executorID, actionType, actorID, targetType, limit, offset)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]*models.AuditLog), args.Error(1)
}

// MockCache for testing
type MockCache struct {
	mock.Mock
	store map[string]string
}

func NewMockCache() *MockCache {
	return &MockCache{
		store: make(map[string]string),
	}
}

func (m *MockCache) Get(ctx context.Context, key string) (string, error) {
	args := m.Called(ctx, key)
	if args.Get(0) == nil {
		return m.store[key], args.Error(1)
	}
	return args.String(0), args.Error(1)
}

func (m *MockCache) Set(ctx context.Context, key, value string, ttl time.Duration) error {
	m.store[key] = value
	args := m.Called(ctx, key, value, ttl)
	return args.Error(0)
}

func (m *MockCache) Delete(ctx context.Context, key string) error {
	delete(m.store, key)
	args := m.Called(ctx, key)
	return args.Error(0)
}

func (m *MockCache) DeletePattern(ctx context.Context, pattern string) error {
	args := m.Called(ctx, pattern)
	return args.Error(0)
}

func (m *MockCache) GetJSON(ctx context.Context, key string, value interface{}) error {
	args := m.Called(ctx, key, value)
	return args.Error(0)
}

func (m *MockCache) SetJSON(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	args := m.Called(ctx, key, value, ttl)
	return args.Error(0)
}

func (m *MockCache) Exists(ctx context.Context, key string) (bool, error) {
	args := m.Called(ctx, key)
	return args.Bool(0), args.Error(1)
}

func (m *MockCache) Publish(ctx context.Context, channel string, message interface{}) error {
	args := m.Called(ctx, channel, message)
	return args.Error(0)
}

func (m *MockCache) Subscribe(ctx context.Context, channel string) *redis.PubSub {
	args := m.Called(ctx, channel)
	if args.Get(0) == nil {
		return nil
	}
	return args.Get(0).(*redis.PubSub)
}

func (m *MockCache) Close() error {
	args := m.Called()
	return args.Error(0)
}

func (m *MockCache) ZAdd(ctx context.Context, key string, score float64, member string) error {
	args := m.Called(ctx, key, score, member)
	return args.Error(0)
}

func (m *MockCache) ZCard(ctx context.Context, key string) (int64, error) {
	args := m.Called(ctx, key)
	return int64(args.Int(0)), args.Error(1)
}

func (m *MockCache) ZRemRangeByScore(ctx context.Context, key, min, max string) error {
	args := m.Called(ctx, key, min, max)
	return args.Error(0)
}

func (m *MockCache) ZRangeFirst(ctx context.Context, key string) (int64, error) {
	args := m.Called(ctx, key)
	return int64(args.Int(0)), args.Error(1)
}

func (m *MockCache) Expire(ctx context.Context, key string, expiration time.Duration) error {
	args := m.Called(ctx, key, expiration)
	return args.Error(0)
}

func (m *MockCache) Ping(ctx context.Context) error {
	args := m.Called(ctx)
	return args.Error(0)
}

func (m *MockCache) GetRedisClient() redis.Cmdable {
	args := m.Called()
	if args.Get(0) == nil {
		return nil
	}
	return args.Get(0).(redis.Cmdable)
}
