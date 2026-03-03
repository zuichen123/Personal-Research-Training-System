package profile

import "context"

type Repository interface {
	GetByUserID(ctx context.Context, userID string) (UserProfile, error)
	Upsert(ctx context.Context, item UserProfile) (UserProfile, error)
}
