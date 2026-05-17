class_name AIProfile
extends RefCounted

var persona_name:      String
var raise_threshold:   float
var fold_threshold:    float
var bluff_chance:      float
var noise_multiplier:  float
var raise_cap:         int

static func aggressor() -> AIProfile:
	var p := AIProfile.new()
	p.persona_name     = "Tarvosk the Brazen"
	p.raise_threshold  = 2.8
	p.fold_threshold   = 0.8
	p.bluff_chance     = 0.18
	p.noise_multiplier = 0.8
	p.raise_cap        = 3
	return p

static func rock() -> AIProfile:
	var p := AIProfile.new()
	p.persona_name     = "Haldemar the Still"
	p.raise_threshold  = 4.5
	p.fold_threshold   = 2.5
	p.bluff_chance     = 0.0
	p.noise_multiplier = 0.6
	p.raise_cap        = 1
	return p

static func ghost() -> AIProfile:
	var p := AIProfile.new()
	p.persona_name     = "Mercival the Oblique"
	p.raise_threshold  = 3.5
	p.fold_threshold   = 1.5
	p.bluff_chance     = 0.12
	p.noise_multiplier = 1.6
	p.raise_cap        = 2
	return p
