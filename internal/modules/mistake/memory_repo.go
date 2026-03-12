package mistake

import (
	"context"
	"sync"

	"prts/internal/shared/errs"
)

type MemoryRepository struct {
	mu    sync.RWMutex
	items []Record
}

func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{}
}

func (r *MemoryRepository) Create(_ context.Context, item Record) (Record, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.items = append(r.items, item)
	return item, nil
}

func (r *MemoryRepository) List(_ context.Context) ([]Record, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	result := make([]Record, len(r.items))
	copy(result, r.items)
	return result, nil
}

func (r *MemoryRepository) ListByQuestionID(_ context.Context, questionID string) ([]Record, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	result := make([]Record, 0)
	for _, item := range r.items {
		if item.QuestionID == questionID {
			result = append(result, item)
		}
	}
	return result, nil
}

func (r *MemoryRepository) GetByID(_ context.Context, id string) (Record, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	for _, item := range r.items {
		if item.ID == id {
			return item, nil
		}
	}
	return Record{}, errs.NotFound("mistake not found")
}

func (r *MemoryRepository) Delete(_ context.Context, id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	for i, item := range r.items {
		if item.ID == id {
			r.items = append(r.items[:i], r.items[i+1:]...)
			return nil
		}
	}
	return errs.NotFound("mistake not found")
}
