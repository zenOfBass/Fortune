extends Node

signal dialogue_line(speaker_idx: int, speaker_name: String, line: String)
signal tell_read

const _DIALOGUE_PATH := "res://assets/dialogue/"
const _COOLDOWN_ROUNDS := 3
const _RECENT_MEMORY := 3
const _BASE_CHANCE := 0.80

# Player index -> trigger_id -> Array[String]
var _lines: Array = [{}, {}, {}, {}]

# trigger_id -> Array of exchange step-arrays (loaded from exchanges.json)
var _exchanges: Dictionary = {}

# Player index -> trigger_id -> rounds remaining
var _cooldowns: Array = [{}, {}, {}, {}]

# Player index -> Array[String] (last N lines shown)
var _recent: Array = [[], [], [], []]

var _exchange_cooldown: int = 0

var _player_raises: int = 0
var _player_folds: int = 0
var _rounds_played: int = 0
var _player_win_streak: int = 0
var _ai_win_streak: int = 0
var _streak_ai_idx: int = -1

const _MOOD_THRESHOLD := 3
var _tarvosk_humiliation: int = 0  # increments on player showdown wins
var _haldemar_impressed: int = 0   # increments on player showdown wins
var _mercival_curiosity: int = 0   # increments on unusual arcana + split pots

var _tarvosk_bluff_announced: bool = false  # set when a bluff tell line fires; cleared each round


func _ready() -> void:
	_load_character(1, "tarvosk")
	_load_character(2, "haldemar")
	_load_character(3, "mercival")
	_load_exchanges()
	GameManager.round_ended.connect(_on_round_ended_internal)
	GameManager.player_raised.connect(func(pidx, _r, _p): if pidx == GameManager.HUMAN_IDX: _player_raises += 1)
	GameManager.player_folded.connect(func(pidx): if pidx == GameManager.HUMAN_IDX: _player_folds += 1)
	GameManager.phase_changed.connect(func(phase): if phase == "DEAL" and _rounds_played == 0: try_fire_any("game_start", 1.0))
	GameManager.ai_bluffing.connect(func(pidx): try_fire("tarvosk_bluffing", pidx, 0.75))
	GameManager.game_ended.connect(_on_game_ended)
	GameManager.arcana_revealed.connect(func(arcana_id, _n):
		if arcana_id in [16, 18, 20, 21]: _mercival_curiosity += 1)

func _load_exchanges() -> void:
	var path := _DIALOGUE_PATH + "exchanges.json"
	if not FileAccess.file_exists(path):
		push_warning("DialogueManager: missing file %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_exchanges = parsed

func _load_character(pidx: int, filename: String) -> void:
	var path := _DIALOGUE_PATH + filename + ".json"
	if not FileAccess.file_exists(path):
		push_warning("DialogueManager: missing file %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_lines[pidx] = parsed

func _mood_suffix(speaker_idx: int) -> String:
	match speaker_idx:
		1: return "_humiliated" if _tarvosk_humiliation >= _MOOD_THRESHOLD else ""
		2: return "_impressed"  if _haldemar_impressed  >= _MOOD_THRESHOLD else ""
		3: return "_curious"    if _mercival_curiosity  >= _MOOD_THRESHOLD else ""
	return ""

# Fire a line for a specific AI speaker. chance ∈ [0,1].
# context keys (e.g. {"hand_name": "Flush"}) are substituted into the line via String.format().
func try_fire(trigger_id: String, speaker_idx: int, chance: float = _BASE_CHANCE, context: Dictionary = {}) -> void:
	if speaker_idx == 0 or speaker_idx >= GameManager.players.size():
		return
	if GameManager.players[speaker_idx].chips == 0:
		return
	if randf() > chance:
		return
	if _cooldowns[speaker_idx].get(trigger_id, 0) > 0:
		return
	# Try mood-shifted variant first; fall back to base trigger if no lines exist for it.
	var pool_key := trigger_id
	var suffix := _mood_suffix(speaker_idx)
	if not suffix.is_empty() and not _lines[speaker_idx].get(trigger_id + suffix, []).is_empty():
		pool_key = trigger_id + suffix
	var pool: Array = _lines[speaker_idx].get(pool_key, [])
	if pool.is_empty():
		return
	var recent: Array = _recent[speaker_idx]
	# Exclude lines whose placeholders would substitute to empty string.
	var _would_blank := func(l: String) -> bool:
		for key in context:
			if context[key] is String and context[key] == "" and l.contains("{%s}" % key):
				return true
		return false
	var candidates: Array = pool.filter(func(l): return not recent.has(l) and not _would_blank.call(l))
	if candidates.is_empty():
		candidates = pool.filter(func(l): return not _would_blank.call(l))
	if candidates.is_empty():
		return
	var line: String = candidates[randi() % candidates.size()]
	recent.append(line)
	if recent.size() > _RECENT_MEMORY:
		recent.pop_front()
	_cooldowns[speaker_idx][trigger_id] = _COOLDOWN_ROUNDS
	var ctx := context.duplicate()
	if ctx.has("hand_name") and ctx["hand_name"] is String:
		var hn: String = ctx["hand_name"].to_lower()
		if hn == "one pair":
			hn = "pair"
		ctx["hand_name"] = hn
	var formatted := line.format(ctx) if not ctx.is_empty() else line
	dialogue_line.emit(speaker_idx, GameManager._pname(speaker_idx), formatted)
	if trigger_id == "tarvosk_bluffing":
		_tarvosk_bluff_announced = true

# Pick one eligible AI at random and fire a trigger for them.
func try_fire_any(trigger_id: String, chance: float = _BASE_CHANCE, context: Dictionary = {}) -> void:
	var eligible: Array = []
	for i in range(1, GameManager.players.size()):
		if not _lines[i].get(trigger_id, []).is_empty() \
				and _cooldowns[i].get(trigger_id, 0) == 0:
			eligible.append(i)
	if eligible.is_empty():
		return
	try_fire(trigger_id, eligible[randi() % eligible.size()], chance, context)

# Like try_fire_any but excludes one speaker index (e.g. a winner reacting to their own hand).
func try_fire_any_except(trigger_id: String, exclude_idx: int, chance: float = _BASE_CHANCE, context: Dictionary = {}) -> void:
	var eligible: Array = []
	for i in range(1, GameManager.players.size()):
		if i != exclude_idx and not _lines[i].get(trigger_id, []).is_empty() \
				and _cooldowns[i].get(trigger_id, 0) == 0:
			eligible.append(i)
	if eligible.is_empty():
		return
	try_fire(trigger_id, eligible[randi() % eligible.size()], chance, context)

# Fire a scripted exchange between AI characters (sequential, async).
# trigger_id selects from that key in exchanges.json; falls back to "random" if empty.
# Requires at least 3 players (player + Tarvosk + Haldemar).
func try_fire_exchange(trigger_id: String = "random") -> void:
	if _exchange_cooldown > 0 or GameManager.players.size() < 3:
		return
	var pool: Array = _exchanges.get(trigger_id, [])
	if pool.is_empty() and trigger_id != "random":
		pool = _exchanges.get("random", [])
	if pool.is_empty():
		return
	_exchange_cooldown = 6
	var steps: Array = pool[randi() % pool.size()]
	for step in steps:
		var idx: int = step["idx"]
		var line: String = step.get("line", "")
		if idx < GameManager.players.size() and not line.is_empty():
			dialogue_line.emit(idx, GameManager._pname(idx), line)
		await get_tree().create_timer(2.5).timeout

func _on_round_ended_internal(winner_indices: Array, hand_names: Array, split: bool) -> void:
	if _tarvosk_bluff_announced and winner_indices.has(GameManager.HUMAN_IDX):
		tell_read.emit()
	_advance_round()
	_update_round_stats(winner_indices, hand_names, split)
	_fire_pattern_triggers_deferred()

func _update_round_stats(winner_indices: Array, hand_names: Array, split: bool) -> void:
	_rounds_played += 1
	if winner_indices.has(GameManager.HUMAN_IDX):
		_player_win_streak += 1
		_ai_win_streak = 0
		_streak_ai_idx = -1
		if not hand_names.is_empty():  # showdown win (not uncontested)
			_tarvosk_humiliation += 1
			_haldemar_impressed += 1
	elif not winner_indices.is_empty():
		var w: int = winner_indices[0]
		if w == _streak_ai_idx:
			_ai_win_streak += 1
		else:
			_ai_win_streak = 1
			_streak_ai_idx = w
		_player_win_streak = 0
	else:
		_player_win_streak = 0
		_ai_win_streak = 0
	if split:
		_mercival_curiosity += 1

func _fire_pattern_triggers_deferred() -> void:
	await get_tree().create_timer(5.2).timeout
	if _rounds_played < 3:
		return
	if _player_win_streak >= 2:
		try_fire_any("player_on_streak", 0.60)
	if _ai_win_streak >= 2 and _streak_ai_idx > 0:
		try_fire("ai_on_streak", _streak_ai_idx, 0.65)
	var aggression := float(_player_raises) / _rounds_played
	if aggression >= 0.4:
		try_fire_any("player_aggressive_pattern", 0.45)
	elif float(_player_folds) / _rounds_played >= 0.45:
		try_fire_any("player_passive_pattern", 0.40)

func _on_game_ended(final_chips: Array) -> void:
	if final_chips.is_empty():
		_reset_stats()
		return
	var max_chips: int = int(final_chips.max())
	if final_chips[GameManager.HUMAN_IDX] >= max_chips:
		try_fire_any("game_over_lose", 1.0)
	else:
		var winner_idx := final_chips.find(max_chips)
		if winner_idx > 0:
			try_fire("game_over_win", winner_idx, 1.0)
		else:
			try_fire_any("game_over_win", 1.0)
	_reset_stats()

func _reset_stats() -> void:
	_player_raises = 0
	_player_folds = 0
	_rounds_played = 0
	_player_win_streak = 0
	_ai_win_streak = 0
	_streak_ai_idx = -1
	_tarvosk_humiliation = 0
	_haldemar_impressed = 0
	_mercival_curiosity = 0

func _advance_round() -> void:
	for i in 4:
		for key in _cooldowns[i].keys():
			_cooldowns[i][key] = max(0, _cooldowns[i][key] - 1)
	_exchange_cooldown = max(0, _exchange_cooldown - 1)
	_tarvosk_bluff_announced = false
