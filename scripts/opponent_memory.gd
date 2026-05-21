class_name OpponentMemory
extends Resource

# Per-AI read of an opponent (almost always the human, in single-player).
# Counters accumulate across rounds; derived stats (fold_rate, bluff_propensity)
# return 0.5 / 0.0 until a minimum sample size is reached so a single early
# round can't swing thresholds wildly.

const MIN_SAMPLES := 4   # below this, derived stats fall back to neutral defaults

@export var hands_observed:        int = 0
@export var hands_folded:          int = 0  # any fold during the round
@export var hands_to_showdown:     int = 0

@export var times_raised:          int = 0
@export var times_called_a_raise:  int = 0
@export var times_folded_to_raise: int = 0
@export var times_all_in:          int = 0

# Player went to showdown with a weak hand after raising at least once.
@export var bluffs_caught:         int = 0
@export var showdown_wins:         int = 0
@export var showdown_losses:       int = 0

@export var current_fold_streak:   int = 0

# Transient: set true for one round after a bluff is caught, cleared next call.
# Not persisted — read by dialogue_manager to fire immediate reactions.
var caught_bluff_this_round: bool = false


func note_round_outcome(j: Dictionary, human_hand_type: float, human_won_showdown: bool, human_reached_showdown: bool) -> void:
	caught_bluff_this_round = false
	if not j.get("human_active", false):
		return  # human wasn't in the round at all (eliminated, etc.)

	hands_observed += 1
	times_raised += int(j.get("human_raises", 0))
	if j.get("human_all_in", false):
		times_all_in += 1
	if j.get("human_called_raise", false):
		times_called_a_raise += 1
	if j.get("human_folded_to_raise", false):
		times_folded_to_raise += 1

	if j.get("human_folded", false):
		hands_folded += 1
		current_fold_streak += 1
	else:
		current_fold_streak = 0

	if human_reached_showdown:
		hands_to_showdown += 1
		if human_won_showdown:
			showdown_wins += 1
		else:
			showdown_losses += 1
		# Bluff-caught heuristic: aggressive bet line + showed weak hand + didn't win.
		if int(j.get("human_raises", 0)) >= 1 and human_hand_type < 3.0 and not human_won_showdown:
			bluffs_caught += 1
			caught_bluff_this_round = true


# ---- Derived stats (return neutral defaults until MIN_SAMPLES reached) ----

func fold_rate() -> float:
	if hands_observed < MIN_SAMPLES:
		return 0.5
	return float(hands_folded) / float(hands_observed)

# Of the times the player faced a raise (called + folded), how often did they fold?
func fold_to_raise_rate() -> float:
	var faced := times_called_a_raise + times_folded_to_raise
	if faced < MIN_SAMPLES:
		return 0.5
	return float(times_folded_to_raise) / float(faced)

# Of the times the player got to showdown, how often had they raised on a weak hand?
func bluff_propensity() -> float:
	if hands_to_showdown < MIN_SAMPLES:
		return 0.0
	return float(bluffs_caught) / float(hands_to_showdown)

# 0.0 = passive, 1.0 = constantly raising. Capped sensibly.
func aggression() -> float:
	if hands_observed < MIN_SAMPLES:
		return 0.5
	return clampf(float(times_raised) / float(hands_observed * 2), 0.0, 1.0)

# Single-phrase descriptor for UI. Ordered so the most distinctive read wins.
func read_descriptor() -> String:
	if hands_observed < MIN_SAMPLES:
		return "still learning your tells"
	if bluff_propensity() > 0.2:
		return "an unrepentant bluffer"
	if fold_to_raise_rate() > 0.7:
		return "folds to pressure"
	if aggression() > 0.55:
		return "aggressive"
	if current_fold_streak >= 4:
		return "currently passive"
	return "balanced"


# ---- Persistence (used by Stage 2 RunManager) ----

func to_dict() -> Dictionary:
	return {
		"hands_observed":        hands_observed,
		"hands_folded":          hands_folded,
		"hands_to_showdown":     hands_to_showdown,
		"times_raised":          times_raised,
		"times_called_a_raise":  times_called_a_raise,
		"times_folded_to_raise": times_folded_to_raise,
		"times_all_in":          times_all_in,
		"bluffs_caught":         bluffs_caught,
		"showdown_wins":         showdown_wins,
		"showdown_losses":       showdown_losses,
		"current_fold_streak":   current_fold_streak,
	}

static func from_dict(d: Dictionary) -> OpponentMemory:
	var m := OpponentMemory.new()
	m.hands_observed        = int(d.get("hands_observed", 0))
	m.hands_folded          = int(d.get("hands_folded", 0))
	m.hands_to_showdown     = int(d.get("hands_to_showdown", 0))
	m.times_raised          = int(d.get("times_raised", 0))
	m.times_called_a_raise  = int(d.get("times_called_a_raise", 0))
	m.times_folded_to_raise = int(d.get("times_folded_to_raise", 0))
	m.times_all_in          = int(d.get("times_all_in", 0))
	m.bluffs_caught         = int(d.get("bluffs_caught", 0))
	m.showdown_wins         = int(d.get("showdown_wins", 0))
	m.showdown_losses       = int(d.get("showdown_losses", 0))
	m.current_fold_streak   = int(d.get("current_fold_streak", 0))
	return m
