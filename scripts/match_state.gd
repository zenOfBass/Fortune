class_name MatchState
extends Resource

# Full mid-match snapshot for Balatro-style resume. Captured after every human
# action and persisted by RunManager to user://match_state.cfg. On Continue Run,
# GameManager.resume_match() reads this and reconstructs the entire game state
# so the player picks up exactly where they left off.
#
# Cards are serialized as [suit:int, rank:int] pairs (ConfigFile-safe). Order
# matters everywhere — Deck.pop_back deals from the tail, so the saved tail is
# the next card out.

# ---- Top-level game state ----

@export var phase: String = ""                # "ARCANA" | "BET1" | "DRAW" | "BET2" | "MOON_SWAP" | "JUDGEMENT" | "SHOWDOWN"
@export var deck: Array = []                  # Array[[suit, rank]]
@export var dealer_idx: int = 0
@export var pot: int = 0
@export var ante_amount: int = 1
@export var round_num: int = 0
@export var last_round: bool = false
@export var active_players: Array = []        # Array[int]
@export var arcana_deck: Array = []           # Array[int]
@export var arcana_pos: int = 0
@export var debug_arcana_id: int = -1
@export var human_journal: Dictionary = {}

# ---- Per-player ----
# Parallel arrays indexed by player seat. profile_name "" means human.

@export var players_chips: Array = []         # Array[int]
@export var players_folded: Array = []        # Array[bool]
@export var players_hands: Array = []         # Array[Array[[suit, rank]]]
@export var players_profile_names: Array = [] # Array[String]

# ---- Opponent memories ----
# Keyed by persona_name → OpponentMemory.to_dict().

@export var opponent_memories: Dictionary = {}

# ---- RoundState (flat) ----

@export var rs_king_beats_ace: bool = false
@export var rs_inverted_values: bool = false
@export var rs_skip_draw: bool = false
@export var rs_split_pot_two_best: bool = false
@export var rs_raise_must_double: bool = false
@export var rs_no_forced_min_bet: bool = false
@export var rs_hanged_man_active: bool = false
@export var rs_fool_active: bool = false
@export var rs_six_card_hand: bool = false
@export var rs_tower_pending: bool = false
@export var rs_death_end: bool = false
@export var rs_sun_end: bool = false
@export var rs_arcana_id: int = -1
@export var rs_arcana_drawn: bool = false
@export var rs_hierophant_active: bool = false
@export var rs_priestess_revealed: Dictionary = {}  # pidx -> [suit, rank]
@export var rs_moon_secret: Dictionary = {}         # pidx -> [suit, rank]
@export var rs_moon_reveal_done: bool = false
@export var rs_temperance_flop: Array = []          # Array[[suit, rank]]
@export var rs_judgement_active: bool = false

# Betting-loop fields (promoted from _phase_bet locals).
@export var rs_bet_current: int = 0
@export var rs_bet_contributed: Dictionary = {}
@export var rs_bet_acted: Dictionary = {}
@export var rs_bet_player_raises: Dictionary = {}
@export var rs_bet_raise_count: int = 0
@export var rs_bet_queue: Array = []
@export var rs_bet_in_progress: bool = false

# Per-phase progress trackers.
@export var rs_draw_completed: Array = []
@export var rs_moon_swap_completed: Array = []
@export var rs_judgement_decided: Array = []
@export var rs_temperance_completed: Array = []
@export var rs_magician_completed: Array = []
@export var rs_star_completed: Array = []
@export var rs_chariot_chosen: Dictionary = {}
@export var rs_chariot_passed: bool = false


# ---- Serialization to/from ConfigFile-safe Dictionary ----

func to_dict() -> Dictionary:
	return {
		"phase": phase,
		"deck": deck,
		"dealer_idx": dealer_idx,
		"pot": pot,
		"ante_amount": ante_amount,
		"round_num": round_num,
		"last_round": last_round,
		"active_players": active_players,
		"arcana_deck": arcana_deck,
		"arcana_pos": arcana_pos,
		"debug_arcana_id": debug_arcana_id,
		"human_journal": human_journal,
		"players_chips": players_chips,
		"players_folded": players_folded,
		"players_hands": players_hands,
		"players_profile_names": players_profile_names,
		"opponent_memories": opponent_memories,
		"rs_king_beats_ace": rs_king_beats_ace,
		"rs_inverted_values": rs_inverted_values,
		"rs_skip_draw": rs_skip_draw,
		"rs_split_pot_two_best": rs_split_pot_two_best,
		"rs_raise_must_double": rs_raise_must_double,
		"rs_no_forced_min_bet": rs_no_forced_min_bet,
		"rs_hanged_man_active": rs_hanged_man_active,
		"rs_fool_active": rs_fool_active,
		"rs_six_card_hand": rs_six_card_hand,
		"rs_tower_pending": rs_tower_pending,
		"rs_death_end": rs_death_end,
		"rs_sun_end": rs_sun_end,
		"rs_arcana_id": rs_arcana_id,
		"rs_arcana_drawn": rs_arcana_drawn,
		"rs_hierophant_active": rs_hierophant_active,
		"rs_priestess_revealed": rs_priestess_revealed,
		"rs_moon_secret": rs_moon_secret,
		"rs_moon_reveal_done": rs_moon_reveal_done,
		"rs_temperance_flop": rs_temperance_flop,
		"rs_judgement_active": rs_judgement_active,
		"rs_bet_current": rs_bet_current,
		"rs_bet_contributed": rs_bet_contributed,
		"rs_bet_acted": rs_bet_acted,
		"rs_bet_player_raises": rs_bet_player_raises,
		"rs_bet_raise_count": rs_bet_raise_count,
		"rs_bet_queue": rs_bet_queue,
		"rs_bet_in_progress": rs_bet_in_progress,
		"rs_draw_completed": rs_draw_completed,
		"rs_moon_swap_completed": rs_moon_swap_completed,
		"rs_judgement_decided": rs_judgement_decided,
		"rs_temperance_completed": rs_temperance_completed,
		"rs_magician_completed": rs_magician_completed,
		"rs_star_completed": rs_star_completed,
		"rs_chariot_chosen": rs_chariot_chosen,
		"rs_chariot_passed": rs_chariot_passed,
	}

static func from_dict(d: Dictionary) -> MatchState:
	var m := MatchState.new()
	m.phase = String(d.get("phase", ""))
	m.deck = d.get("deck", [])
	m.dealer_idx = int(d.get("dealer_idx", 0))
	m.pot = int(d.get("pot", 0))
	m.ante_amount = int(d.get("ante_amount", 1))
	m.round_num = int(d.get("round_num", 0))
	m.last_round = bool(d.get("last_round", false))
	m.active_players = d.get("active_players", [])
	m.arcana_deck = d.get("arcana_deck", [])
	m.arcana_pos = int(d.get("arcana_pos", 0))
	m.debug_arcana_id = int(d.get("debug_arcana_id", -1))
	m.human_journal = d.get("human_journal", {})
	m.players_chips = d.get("players_chips", [])
	m.players_folded = d.get("players_folded", [])
	m.players_hands = d.get("players_hands", [])
	m.players_profile_names = d.get("players_profile_names", [])
	m.opponent_memories = d.get("opponent_memories", {})
	m.rs_king_beats_ace = bool(d.get("rs_king_beats_ace", false))
	m.rs_inverted_values = bool(d.get("rs_inverted_values", false))
	m.rs_skip_draw = bool(d.get("rs_skip_draw", false))
	m.rs_split_pot_two_best = bool(d.get("rs_split_pot_two_best", false))
	m.rs_raise_must_double = bool(d.get("rs_raise_must_double", false))
	m.rs_no_forced_min_bet = bool(d.get("rs_no_forced_min_bet", false))
	m.rs_hanged_man_active = bool(d.get("rs_hanged_man_active", false))
	m.rs_fool_active = bool(d.get("rs_fool_active", false))
	m.rs_six_card_hand = bool(d.get("rs_six_card_hand", false))
	m.rs_tower_pending = bool(d.get("rs_tower_pending", false))
	m.rs_death_end = bool(d.get("rs_death_end", false))
	m.rs_sun_end = bool(d.get("rs_sun_end", false))
	m.rs_arcana_id = int(d.get("rs_arcana_id", -1))
	m.rs_arcana_drawn = bool(d.get("rs_arcana_drawn", false))
	m.rs_hierophant_active = bool(d.get("rs_hierophant_active", false))
	m.rs_priestess_revealed = d.get("rs_priestess_revealed", {})
	m.rs_moon_secret = d.get("rs_moon_secret", {})
	m.rs_moon_reveal_done = bool(d.get("rs_moon_reveal_done", false))
	m.rs_temperance_flop = d.get("rs_temperance_flop", [])
	m.rs_judgement_active = bool(d.get("rs_judgement_active", false))
	m.rs_bet_current = int(d.get("rs_bet_current", 0))
	m.rs_bet_contributed = d.get("rs_bet_contributed", {})
	m.rs_bet_acted = d.get("rs_bet_acted", {})
	m.rs_bet_player_raises = d.get("rs_bet_player_raises", {})
	m.rs_bet_raise_count = int(d.get("rs_bet_raise_count", 0))
	m.rs_bet_queue = d.get("rs_bet_queue", [])
	m.rs_bet_in_progress = bool(d.get("rs_bet_in_progress", false))
	m.rs_draw_completed = d.get("rs_draw_completed", [])
	m.rs_moon_swap_completed = d.get("rs_moon_swap_completed", [])
	m.rs_judgement_decided = d.get("rs_judgement_decided", [])
	m.rs_temperance_completed = d.get("rs_temperance_completed", [])
	m.rs_magician_completed = d.get("rs_magician_completed", [])
	m.rs_star_completed = d.get("rs_star_completed", [])
	m.rs_chariot_chosen = d.get("rs_chariot_chosen", {})
	m.rs_chariot_passed = bool(d.get("rs_chariot_passed", false))
	return m
