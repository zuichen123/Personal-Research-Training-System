package mistake

import "context"

type Repository interface {
	Create(ctx context.Context, item Record) (Record, error)
	GetByID(ctx context.Context, id string) (Record, error)
	List(ctx context.Context) ([]Record, error)
	ListByQuestionID(ctx context.Context, questionID string) ([]Record, error)
	Delete(ctx context.Context, id string) error
}
