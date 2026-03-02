package practice

import (
	"context"
	"sync"
)

type MemoryRepository struct {
	mu    sync.RWMutex
	items []Attempt
}

func NewMemoryRepository() *MemoryRepository {
	return &MemoryRepository{}
}

func (r *MemoryRepository) Create(_ context.Context, item Attempt) (Attempt, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.items = append(r.items, item)
	return item, nil
}

func (r *MemoryRepository) List(_ context.Context) ([]Attempt, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	result := make([]Attempt, len(r.items))
	copy(result, r.items)
	return result, nil
}
