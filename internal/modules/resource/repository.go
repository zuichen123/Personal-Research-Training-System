package resource

import "context"

type Repository interface {
	Create(ctx context.Context, item Material) (Material, error)
	GetByID(ctx context.Context, id string) (Material, error)
	List(ctx context.Context, questionID string) ([]Material, error)
}
