extends Node

signal dialogue_line(speaker_idx: int, speaker_name: String, line: String)

const _DIALOGUE_PATH := "res://assets/dialogue/"
const _COOLDOWN_ROUNDS := 3
const _RECENT_MEMORY := 3
const _BASE_CHANCE := 0.80

# Player index -> trigger_id -> Array[String]
var _lines: Array = [{}, {}, {}, {}]

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

# Hardcoded Tarvosk (idx 1) vs Haldemar (idx 2) exchanges.
# Each entry is an Array of {idx, line} steps shown in sequence.
const _EXCHANGES: Array = [
	[
		{"idx": 1, "line": "Still breathing, Haldemar? I thought you had fossilized."},
		{"idx": 2, "line": "Still here, Tarvosk."}
	],
	[
		{"idx": 1, "line": "Your silence speaks volumes. About very little."},
		{"idx": 2, "line": "And yet I remain."}
	],
	[
		{"idx": 1, "line": "I have met doorposts with more personality."},
		{"idx": 2, "line": "Expected."}
	],
	[
		{"idx": 1, "line": "Do you enjoy this game, Haldemar, or merely endure it?"},
		{"idx": 2, "line": "I endure your commentary. The game is fine."}
	],
	[
		{"idx": 1, "line": "One day you will lose your composure. I intend to be there."},
		{"idx": 2, "line": "You have been present every round. It has not happened yet."}
	],
]

func _ready() -> void:
	_load_character(1, "tarvosk")
	_load_character(2, "haldemar")
	_load_character(3, "mercival")
	GameManager.round_ended.connect(_on_round_ended_internal)
	GameManager.player_raised.connect(func(pidx, _r, _p): if pidx == GameManager.HUMAN_IDX: _player_raises += 1)
	GameManager.player_folded.connect(func(pidx): if pidx == GameManager.HUMAN_IDX: _player_folds += 1)
	GameManager.phase_changed.connect(func(phase): if phase == "DEAL" and _rounds_played == 0: try_fire_any("game_start", 1.0))
	GameManager.ai_bluffing.connect(func(pidx): try_fire("tarvosk_bluffing", pidx, 0.75))
	GameManager.game_ended.connect(_on_game_ended)

func _load_character(pidx: int, filename: String) -> void:
	var path := _DIALOGUE_PATH + filename + ".json"
	if not FileAccess.file_exists(path):
		push_warning("DialogueManager: missing file %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_lines[pidx] = parsed

# Fire a line for a specific AI speaker. chance ∈ [0,1].
# context keys (e.g. {"hand_name": "Flush"}) are substituted into the line via String.format().
func try_fire(trigger_id: String, speaker_idx: int, chance: float = _BASE_CHANCE, context: Dictionary = {}) -> void:
	if speaker_idx == 0 or speaker_idx >= GameManager.players.size():
		return
	if randf() > chance:
		return
	if _cooldowns[speaker_idx].get(trigger_id, 0) > 0:
		return
	var pool: Array = _lines[speaker_idx].get(trigger_id, [])
	if pool.is_empty():
		return
	var recent: Array = _recent[speaker_idx]
	# Exclude lines whose placeholders would substitute to empty string.
	var _would_blank := func(l: String) -> bool:
		for key in context:
			if context[key] == "" and l.contains("{%s}" % key):
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
	var formatted := line.format(context) if not context.is_empty() else line
	dialogue_line.emit(speaker_idx, GameManager._pname(speaker_idx), formatted)

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

# Fire a scripted Tarvosk/Haldemar exchange (sequential, async).
# Requires at least 3 players (player + Tarvosk + Haldemar).
func try_fire_exchange() -> void:
	if _exchange_cooldown > 0 or GameManager.players.size() < 3:
		return
	_exchange_cooldown = 6
	var steps: Array = _EXCHANGES[randi() % _EXCHANGES.size()]
	for step in steps:
		var idx: int = step["idx"]
		if idx < GameManager.players.size():
			dialogue_line.emit(idx, GameManager._pname(idx), step["line"])
		await get_tree().create_timer(2.5).timeout

func _on_round_ended_internal(winner_indices: Array, _hand_names: Array, _split: bool) -> void:
	_advance_round()
	_update_round_stats(winner_indices)
	_fire_pattern_triggers_deferred()

func _update_round_stats(winner_indices: Array) -> void:
	_rounds_played += 1
	if winner_indices.has(GameManager.HUMAN_IDX):
		_player_win_streak += 1
		_ai_win_streak = 0
		_streak_ai_idx = -1
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

func _advance_round() -> void:
	for i in 4:
		for key in _cooldowns[i].keys():
			_cooldowns[i][key] = max(0, _cooldowns[i][key] - 1)
	_exchange_cooldown = max(0, _exchange_cooldown - 1)
