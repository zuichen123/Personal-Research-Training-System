package practice

import "context"

type Repository interface {
	Create(ctx context.Context, item Attempt) (Attempt, error)
	List(ctx context.Context) ([]Attempt, error)
}
