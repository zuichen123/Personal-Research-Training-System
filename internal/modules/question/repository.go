package question

import "context"

type Repository interface {
	Create(ctx context.Context, item Question) (Question, error)
	GetByID(ctx context.Context, id string) (Question, error)
	List(ctx context.Context) ([]Question, error)
	Update(ctx context.Context, item Question) (Question, error)
	Delete(ctx context.Context, id string) error
}
