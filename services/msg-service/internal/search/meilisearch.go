package search

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/meilisearch/meilisearch-go"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
)

// MeiliSearchClient coordinates document synchronization and searches in Meilisearch.
type MeiliSearchClient struct {
	client meilisearch.ServiceManager
	log    *zap.Logger
}

// NewMeiliSearchClient creates a new Meilisearch coordinator.
func NewMeiliSearchClient(log *zap.Logger) *MeiliSearchClient {
	host := os.Getenv("MEILISEARCH_HOST")
	if host == "" {
		host = "http://localhost:7700"
	}
	apiKey := os.Getenv("MEILISEARCH_API_KEY")

	client := meilisearch.New(host, meilisearch.WithAPIKey(apiKey))

	m := &MeiliSearchClient{
		client: client,
		log:    log.Named("search.meili"),
	}

	// Initialize the index asynchronously so it doesn't block startup
	go m.ensureIndex()

	return m
}

func (m *MeiliSearchClient) ensureIndex() {
	indexUID := "messages"
	
	// Retries to handle slow startup of Meilisearch in dev environments
	var index meilisearch.IndexManager
	var err error
	for i := 0; i < 5; i++ {
		_, err = m.client.GetIndex(indexUID)
		if err == nil {
			index = m.client.Index(indexUID)
			break
		}
		
		// Attempt to create index
		_, err = m.client.CreateIndex(&meilisearch.IndexConfig{
			Uid:        indexUID,
			PrimaryKey: "id",
		})
		if err == nil {
			index = m.client.Index(indexUID)
			break
		}
		
		time.Sleep(1 * time.Second)
	}

	if err != nil {
		m.log.Warn("could not connect or initialize Meilisearch index, will retry on demand", zap.Error(err))
		return
	}

	// Configure filterable and sortable attributes
	filterableAttrs := []interface{}{"channel_id", "author_id", "created_at"}
	_, err = index.UpdateFilterableAttributes(&filterableAttrs)
	if err != nil {
		m.log.Error("failed to configure meilisearch filterable attributes", zap.Error(err))
	}

	sortableAttrs := []string{"created_at"}
	_, err = index.UpdateSortableAttributes(&sortableAttrs)
	if err != nil {
		m.log.Error("failed to configure meilisearch sortable attributes", zap.Error(err))
	}
	
	m.log.Info("successfully configured Meilisearch index 'messages'")
}

// BatchSyncMessages sends messages to Meilisearch in a single batch.
func (m *MeiliSearchClient) BatchSyncMessages(ctx context.Context, msgs []*repository.Message) error {
	if len(msgs) == 0 {
		return nil
	}

	_, err := m.client.Index("messages").AddDocumentsWithContext(ctx, msgs, nil)
	if err != nil {
		m.log.Error("failed to sync batch to meilisearch", zap.Error(err), zap.Int("count", len(msgs)))
		return err
	}

	return nil
}

// Search performs full-text queries matching channelID and optional beforeTimestamp parameters.
func (m *MeiliSearchClient) Search(ctx context.Context, channelID, query string, beforeTime *time.Time, limit int) ([]*repository.Message, error) {
	// Construct filters
	filters := []string{fmt.Sprintf("channel_id = %s", channelID)}
	if beforeTime != nil {
		// RFC3339 formatted string comparison
		filters = append(filters, fmt.Sprintf("created_at < %s", beforeTime.Format(time.RFC3339Nano)))
	}

	var filterString string
	if len(filters) > 1 {
		filterString = fmt.Sprintf("%s AND %s", filters[0], filters[1])
	} else {
		filterString = filters[0]
	}

	searchReq := &meilisearch.SearchRequest{
		Filter: filterString,
		Limit:  int64(limit),
		Sort:   []string{"created_at:desc"},
	}

	res, err := m.client.Index("messages").SearchWithContext(ctx, query, searchReq)
	if err != nil {
		return nil, err
	}

	msgs := make([]*repository.Message, 0, len(res.Hits))
	for _, hit := range res.Hits {
		hitBytes, err := json.Marshal(hit)
		if err != nil {
			continue
		}
		var msg repository.Message
		if err := json.Unmarshal(hitBytes, &msg); err == nil {
			msgs = append(msgs, &msg)
		}
	}

	return msgs, nil
}
