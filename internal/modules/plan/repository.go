package plan

import "context"

type Repository interface {
	Create(ctx context.Context, item Item) (Item, error)
	GetByID(ctx context.Context, id string) (Item, error)
	List(ctx context.Context, planType string) ([]Item, error)
	Update(ctx context.Context, item Item) (Item, error)
	Delete(ctx context.Context, id string) error
}
