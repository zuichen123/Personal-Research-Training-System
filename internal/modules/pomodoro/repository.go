package pomodoro

import "context"

type Repository interface {
	Create(ctx context.Context, item Session) (Session, error)
	GetByID(ctx context.Context, id string) (Session, error)
	List(ctx context.Context, status string) ([]Session, error)
	Update(ctx context.Context, item Session) (Session, error)
}
