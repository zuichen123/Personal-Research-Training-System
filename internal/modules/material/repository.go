package material

import "context"

type Repository interface {
	Create(ctx context.Context, item Material) (Material, error)
	GetByID(ctx context.Context, id string) (Material, error)
	List(ctx context.Context, filter ListFilter) ([]Material, error)
	Update(ctx context.Context, id string, item Material) (Material, error)
	Delete(ctx context.Context, id string) error
}
