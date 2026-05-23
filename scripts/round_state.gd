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
var tower_pending      := false  # Tower    (#16): half the pot is destroyed at showdown, after betting has filled it

# ---- Turn-ender flags (set by Death or Sun; checked in game_manager) ----

var death_end := false  # Death (#13): compare hands immediately
var sun_end   := false  # Sun   (#19): split pot equally, discard remainder

# ---- Arcana meta-state ----

var arcana_id    := -1     # which arcana is active this round (-1 = none)
var arcana_drawn := false  # only one arcana may be drawn per round

# Hierophant persists across rounds until it cancels the next arcana drawn.
# Stored here so the game_manager can read it between rounds.
var hierophant_active := false

# ---- Per-player arcana state ----

var priestess_revealed: Dictionary = {}  # player_idx -> Card (face-up for the round)
var moon_secret: Dictionary = {}         # player_idx -> Card (secret drawn card)
var moon_reveal_done: bool = false       # true after human acknowledges phase-1 draw
var temperance_flop: Array = []          # current face-up flop cards for Temperance (#14)
var judgement_active: bool = false       # Judgement (#20): folded players may re-enter before showdown

# ---- Betting-loop state (promoted from _phase_bet locals so mid-bet saves
# can restore the loop's exact position on resume) ----

var bet_current: int = 0                 # _current_bet — highest committed this betting round
var bet_contributed: Dictionary = {}     # player_idx -> chips contributed this betting round
var bet_acted: Dictionary = {}           # player_idx -> true once they've taken any action
var bet_player_raises: Dictionary = {}   # player_idx -> raises this phase (vs profile.raise_cap)
var bet_raise_count: int = 0             # total raises this phase (vs the hard cap of 6)
var bet_queue: Array[int] = []           # remaining players to act, in seat order
var bet_in_progress: bool = false        # true between entering _phase_bet and finishing it

# ---- Per-player progress trackers for resume ----
# Each phase that loops across players records who's already done their thing,
# so resuming mid-phase can skip them rather than re-prompting.

var draw_completed:        Array[int] = []  # _phase_draw — players who've discarded+redrawn
var moon_swap_completed:   Array[int] = []  # _phase_moon_swap — players who've resolved their secret
var judgement_decided:     Array[int] = []  # _phase_judgement_reentry — folded players who've chosen
var temperance_completed:  Array[int] = []  # arcana Temperance — players done with discard+pick
var magician_completed:    Array[int] = []  # arcana Magician — players done with the suit guess
var star_completed:        Array[int] = []  # arcana Star — players done with swap-or-pass
var chariot_chosen:        Dictionary = {}  # arcana Chariot pass 1 — pidx -> hand index to pass
var chariot_passed:        bool = false     # arcana Chariot pass 2 done — cards actually moved

# ---- Convenience ----

func eval_options() -> Dictionary:
	return {"king_beats_ace": king_beats_ace, "inverted_values": inverted_values, "fool_active": fool_active}
