# AI Music Recommendations — TRD

## Architecture
```
listening events (Spotify SDK callbacks) → flicko.music.events
  → user_taste_vectors (rolling 30d)
during music-party:
  room_vector = blend(participant taste vectors, recently played)
  Groq picks N tracks via prompt grounded with audio features (tempo, key, energy)
  → enqueued tracks
```

## Components
- Backend: `backend/internal/services/ai/music_recs/{taste_vector.go, room_vector.go, picker.go}`
- Existing music-party queue.
- Spotify API for audio features (free public endpoint).
- Groq for natural language picking.

## API
```
POST /music-party/:id/auto-queue {n}
POST /music-party/:id/vibe {prompt}
GET  /me/music-recs
```

## NFRs
| NFR | Target |
|-----|--------|
| Pick latency | <2s for 5 tracks |
| Cost / pick | <$0.001 |
| Accept rate | >70% |

## Observability
- `flicko_ai_music_recs_total{kind, accepted}`
- `flicko_ai_music_taste_vec_size`

## Failure
- Spotify rate-limit: serve from cache.
- LLM hallucinates non-existent track: validate against catalog before queuing; retry with refined prompt.
