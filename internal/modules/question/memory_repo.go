package question

import (
	"context"
	"sync"

	"prts/internal/shared/errs"
)

type MemoryRepository struct {
	mu    sync.RWMutex
	items map[string]Question
}

func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{
		items: make(map[string]Question),
	}
}

func (r *MemoryRepository) Create(_ context.Context, item Question) (Question, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.items[item.ID]; exists {
		return Question{}, errs.Conflict("question already exists")
	}
	r.items[item.ID] = item
	return item, nil
}

func (r *MemoryRepository) GetByID(_ context.Context, id string) (Question, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	item, exists := r.items[id]
	if !exists {
		return Question{}, errs.NotFound("question not found")
	}
	return item, nil
}

func (r *MemoryRepository) List(_ context.Context) ([]Question, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	result := make([]Question, 0, len(r.items))
	for _, item := range r.items {
		result = append(result, item)
	}
	return result, nil
}

func (r *MemoryRepository) Update(_ context.Context, item Question) (Question, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.items[item.ID]; !exists {
		return Question{}, errs.NotFound("question not found")
	}
	r.items[item.ID] = item
	return item, nil
}

func (r *MemoryRepository) Delete(_ context.Context, id string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.items[id]; !exists {
		return errs.NotFound("question not found")
	}
	delete(r.items, id)
	return nil
}
