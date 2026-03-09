package ai

import (
	"context"
	"strings"
)

type learningSchedulePromptPatchCarrier interface {
	learningScheduleBinding() *ScheduleBinding
	learningPromptPatch() PromptRuntimePatch
	learningSchedulePromptInput() string
	setLearningPromptPatch(PromptRuntimePatch)
}

func (s *Service) applyLearningSchedulePromptPatch(
	ctx context.Context,
	carrier learningSchedulePromptPatchCarrier,
) {
	if carrier == nil {
		return
	}
	binding := carrier.learningScheduleBinding()
	if binding == nil {
		return
	}
	schedulePatch := s.buildLearningSchedulePromptPatch(ctx, binding, carrier.learningSchedulePromptInput())
	carrier.setLearningPromptPatch(mergePromptRuntimePatch(carrier.learningPromptPatch(), schedulePatch))
}

func (r *LearnRequest) learningScheduleBinding() *ScheduleBinding {
	if r == nil {
		return nil
	}
	return r.ScheduleBinding
}

func (r *LearnRequest) learningPromptPatch() PromptRuntimePatch {
	if r == nil {
		return PromptRuntimePatch{}
	}
	return r.PromptPatch
}

func (r *LearnRequest) learningSchedulePromptInput() string {
	if r == nil {
		return ""
	}
	return joinPromptInput(r.Subject, r.Unit, strings.Join(r.Themes, " "), r.Supplement)
}

func (r *LearnRequest) setLearningPromptPatch(patch PromptRuntimePatch) {
	if r == nil {
		return
	}
	r.PromptPatch = patch
}

func (r *OptimizeLearnRequest) learningScheduleBinding() *ScheduleBinding {
	if r == nil {
		return nil
	}
	return r.ScheduleBinding
}

func (r *OptimizeLearnRequest) learningPromptPatch() PromptRuntimePatch {
	if r == nil {
		return PromptRuntimePatch{}
	}
	return r.PromptPatch
}

func (r *OptimizeLearnRequest) learningSchedulePromptInput() string {
	if r == nil {
		return ""
	}
	return joinPromptInput(r.Action, r.Reason, r.Supplement, r.Plan.Subject, r.Plan.Unit)
}

func (r *OptimizeLearnRequest) setLearningPromptPatch(patch PromptRuntimePatch) {
	if r == nil {
		return
	}
	r.PromptPatch = patch
}
