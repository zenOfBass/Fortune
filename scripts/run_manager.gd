extends Node

# A "run" is a sequence of matches played against escalating opponent line-ups.
# Opponent memory persists across matches in a run, so reads carry forward —
# Tarvosk in match 3 still remembers your fold pattern from matches 1 and 2.
#
# Stage 2 owns the data and persistence. UI (career screen / main-menu hook)
# arrives in Stage 3.

signal run_state_changed

const SAVE_PATH := "user://run.cfg"

# ---- Match ladder definition -------------------------------------------------
# Each entry: {num_players, starting_chips, ante, label, ai_overrides}.
# ai_overrides is an Array of Dictionaries (one per AI seat) with optional
# threshold deltas applied on top of the default AIProfile.
const _LADDER: Array = [
	{
		"num_players": 2, "starting_chips": 140, "ante": 1,
		"label": "The Tavern Game",
		# Tarvosk dials back here — Match 1 is the intro, not the gauntlet.
		# The brutal version of him shows up in matches 4 and 5.
		"ai_overrides": [{"raise_threshold": 0.4, "fold_threshold": 0.3}],
	},
	{
		"num_players": 3, "starting_chips": 100, "ante": 2,
		"label": "The Smoke Room",
		"ai_overrides": [{}, {}],
	},
	{
		"num_players": 4, "starting_chips": 100, "ante": 3,
		"label": "The High Table",
		"ai_overrides": [{}, {}, {}],
	},
	{
		"num_players": 4, "starting_chips": 80, "ante": 5,
		"label": "The Vault",
		"ai_overrides": [
			{"raise_threshold": -0.4, "fold_threshold": -0.3},   # Tarvosk sharper
			{"raise_threshold": -0.3},                           # Haldemar tighter to value
			{"noise_multiplier": -0.3, "raise_threshold": -0.2}, # Mercival less random
		],
	},
	{
		"num_players": 4, "starting_chips": 60, "ante": 8,
		"label": "The Final Reading",
		"ai_overrides": [
			{"raise_threshold": -0.6, "fold_threshold": -0.5, "bluff_chance": 0.10},
			{"raise_threshold": -0.5, "fold_threshold": -0.4},
			{"raise_threshold": -0.4, "noise_multiplier": -0.4},
		],
	},
]

# ---- State -------------------------------------------------------------------

var run_active: bool = false
var match_index: int = 0       # 0-based; index into _LADDER
var run_failed: bool = false   # set when a match ends without the human as chip leader
var run_completed: bool = false

# True iff the current GameManager session was launched by RunManager. Quick
# Play sets this false via detach_session() so its game_ended events don't get
# misread as a career match result.
var _session_belongs_to_run: bool = false

# Opponent memory keyed by AIProfile.persona_name so memory survives line-up
# changes (e.g. Haldemar joins in match 2 with a fresh slate; Tarvosk's read
# carries from match 1).
var opponent_memories: Dictionary = {}

func _ready() -> void:
	_load()

# ---- Public API --------------------------------------------------------------

func has_active_run() -> bool:
	return run_active and not run_failed and not run_completed

func total_matches() -> int:
	return _LADDER.size()

func current_match_label() -> String:
	if match_index >= _LADDER.size():
		return ""
	return _LADDER[match_index]["label"]

func current_match_number() -> int:
	return match_index + 1  # 1-based for UI

func current_match_config() -> Dictionary:
	if match_index >= _LADDER.size():
		return {}
	return _LADDER[match_index].duplicate(true)

func start_run() -> void:
	run_active = true
	run_failed = false
	run_completed = false
	match_index = 0
	opponent_memories.clear()
	_save()
	run_state_changed.emit()

func abandon_run() -> void:
	run_active = false
	run_failed = false
	run_completed = false
	match_index = 0
	opponent_memories.clear()
	_session_belongs_to_run = false
	_clear_save()
	run_state_changed.emit()

# Mark the current GameManager session as unrelated to any run — used by
# Quick Play so its game_ended doesn't get recorded as a career result.
func detach_session() -> void:
	_session_belongs_to_run = false

func session_belongs_to_run() -> bool:
	return _session_belongs_to_run

# Called after a match ends — final_chips comes straight from GameManager.game_ended.
# Snapshots opponent memory then decides whether the run advances or fails.
func record_match_result(final_chips: Array) -> void:
	if not run_active or not _session_belongs_to_run:
		return
	_session_belongs_to_run = false
	snapshot_memories()
	if final_chips.is_empty():
		return
	var human_chips: int = int(final_chips[GameManager.HUMAN_IDX])
	var max_chips: int = int(final_chips.max())
	var human_won := human_chips >= max_chips and human_chips > 0
	if human_won:
		match_index += 1
		if match_index >= _LADDER.size():
			run_completed = true
		_save()
	else:
		run_failed = true
		_save()
	run_state_changed.emit()

# Called by main menu / career screen when starting the configured match.
# Sets up GameManager, then restores any memory the AIs already have on you.
func launch_current_match() -> void:
	if match_index >= _LADDER.size():
		return
	var cfg: Dictionary = _LADDER[match_index]
	GameManager.setup_game(cfg["num_players"], cfg["starting_chips"], cfg["ante"])
	_apply_ai_overrides(cfg["ai_overrides"])
	restore_memories()
	_session_belongs_to_run = true

# ---- Memory snapshot / restore -----------------------------------------------

func snapshot_memories() -> void:
	for p in GameManager.players:
		if p.profile != null and p.memory != null:
			opponent_memories[p.profile.persona_name] = p.memory

func restore_memories() -> void:
	for p in GameManager.players:
		if p.profile != null and opponent_memories.has(p.profile.persona_name):
			p.memory = opponent_memories[p.profile.persona_name]

# ---- AI overrides ------------------------------------------------------------

func _apply_ai_overrides(overrides: Array) -> void:
	# overrides[i] applies to GameManager.players[i+1] (the i-th AI seat).
	for i in overrides.size():
		var seat_idx := i + 1
		if seat_idx >= GameManager.players.size():
			break
		var profile: AIProfile = GameManager.players[seat_idx].profile
		if profile == null:
			continue
		var ov: Dictionary = overrides[i]
		if ov.has("raise_threshold"):
			profile.raise_threshold += float(ov["raise_threshold"])
		if ov.has("fold_threshold"):
			profile.fold_threshold += float(ov["fold_threshold"])
		if ov.has("bluff_chance"):
			profile.bluff_chance = clampf(profile.bluff_chance + float(ov["bluff_chance"]), 0.0, 1.0)
		if ov.has("noise_multiplier"):
			profile.noise_multiplier = maxf(0.1, profile.noise_multiplier + float(ov["noise_multiplier"]))

# ---- Persistence -------------------------------------------------------------

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "active", run_active)
	cfg.set_value("run", "match_index", match_index)
	cfg.set_value("run", "failed", run_failed)
	cfg.set_value("run", "completed", run_completed)
	var mem_dict: Dictionary = {}
	for persona in opponent_memories:
		mem_dict[persona] = opponent_memories[persona].to_dict()
	cfg.set_value("run", "memories", mem_dict)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	run_active    = bool(cfg.get_value("run", "active", false))
	match_index   = int(cfg.get_value("run", "match_index", 0))
	run_failed    = bool(cfg.get_value("run", "failed", false))
	run_completed = bool(cfg.get_value("run", "completed", false))
	var mem_dict: Dictionary = cfg.get_value("run", "memories", {})
	opponent_memories.clear()
	for persona in mem_dict:
		opponent_memories[persona] = OpponentMemory.from_dict(mem_dict[persona])

func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove(SAVE_PATH.get_file())
