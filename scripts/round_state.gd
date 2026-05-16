class_name RoundState
extends RefCounted

# ---- Modifier flags (active for the whole round) ----

var king_beats_ace     := false  # Emperor  (#4):  Kings outrank Aces
var inverted_values    := false  # Strength (#8):  2 is highest, Ace near-lowest, Page stays 0
var skip_draw          := false  # Hermit   (#9):  no draw phase; players keep their cards
var split_pot_two_best := false  # Lovers   (#6):  top two hands share the pot
var raise_must_double  := false  # Devil    (#15): any raise must be at least 2x current bet
var no_forced_min_bet  := false  # Justice  (#11): players may bet any amount; excess returned
var hanged_man_active  := false  # Hanged Man (#12): going all-in grants an extra drawn card
var fool_active        := false  # Fool     (#0):  a wild-card flop is available to all players
var six_card_hand      := false  # Empress  (#3):  each player has a sixth card this round

# ---- Turn-ender flags (set by Death or Sun; checked in game_manager) ----

var death_end := false  # Death (#13): compare hands immediately
var sun_end   := false  # Sun   (#19): split pot equally, discard remainder

# ---- Arcana meta-state ----

var arcana_id    := -1     # which arcana is active this round (-1 = none)
var arcana_drawn := false  # only one arcana may be drawn per round

# Hierophant persists across rounds until it cancels the next arcana drawn.
# Stored here so the game_manager can read it between rounds.
var hierophant_active := false

# ---- Convenience ----

func eval_options() -> Dictionary:
	return {"king_beats_ace": king_beats_ace, "inverted_values": inverted_values, "fool_active": fool_active}
