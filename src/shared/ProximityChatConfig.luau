-- Client-side presentation values for immersive proximity text.

return {
	MaximumDistance = 55,
	FullClarityDistance = 12,

	-- Walls reduce opacity and readability separately. This keeps obstructed
	-- speech faintly present while making the actual words hard to understand.
	OccludedVisibility = 0.3,
	OccludedClarity = 0.1,
	UpdateInterval = 0.05,
	VisibilityResponsiveness = 10,

	FadeInTime = 0.2,
	MinimumHoldTime = 3.5,
	MaximumHoldTime = 7.5,
	FadeOutTime = 2.5,
	SecondsPerCharacter = 0.055,

	ClaritySteps = 12,
	FullTextClarity = 0.85,
	PartialWordThreshold = 0.3,
	ReadableWordExponent = 1.35,

	BillboardWidth = 300,
	BillboardHeight = 82,
	VerticalOffset = 3.4,
	TextSize = 18,
}