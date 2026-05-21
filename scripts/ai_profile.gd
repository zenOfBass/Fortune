class_name AIProfile
extends RefCounted

var persona_name:      String
var raise_threshold:   float
var fold_threshold:    float
var bluff_chance:      float
var noise_multiplier:  float
var raise_cap:         int

# How strongly opponent reads shift this AI's thresholds. 0.0 = ignores reads,
# 1.0 = full effect. Combined with the AI's accumulated OpponentMemory in ai_player.gd.
var memory_weight:     float = 1.0

static func aggressor() -> AIProfile:
	var p := AIProfile.new()
	p.persona_name     = "Tarvosk the Brazen"
	p.raise_threshold  = 2.8
	p.fold_threshold   = 0.8
	p.bluff_chance     = 0.18
	p.noise_multiplier = 0.8
	p.raise_cap        = 3
	p.memory_weight    = 1.1  # stubborn: once he reads you, he commits
	return p

static func rock() -> AIProfile:
	var p := AIProfile.new()
	p.persona_name     = "Haldemar the Still"
	p.raise_threshold  = 4.5
	p.fold_threshold   = 2.5
	p.bluff_chance     = 0.0
	p.noise_multiplier = 0.6
	p.raise_cap        = 1
	p.memory_weight    = 0.4  # sticks to his ranges regardless of you
	return p

static func ghost() -> AIProfile:
	var p := AIProfile.new()
	p.persona_name     = "Mercival the Oblique"
	p.raise_threshold  = 3.5
	p.fold_threshold   = 1.5
	p.bluff_chance     = 0.12
	p.noise_multiplier = 1.6
	p.raise_cap        = 2
	p.memory_weight    = 0.9  # reads you fast but the noise washes it out half the time
	return p
