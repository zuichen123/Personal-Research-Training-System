package mistake

import "context"

type Repository interface {
	Create(ctx context.Context, item Record) (Record, error)
	List(ctx context.Context) ([]Record, error)
	ListByQuestionID(ctx context.Context, questionID string) ([]Record, error)
}
