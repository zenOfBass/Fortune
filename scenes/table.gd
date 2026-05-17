extends Control

# ---- Audio -------------------------------------------------------------------

var _flip_sfx: AudioStreamPlayer
var _shuffle_sfx: AudioStreamPlayer

# ---- Top bar -----------------------------------------------------------------

@onready var phase_label: Label = $TopBar/PhaseLabel
@onready var pot_label: Label = $TopBar/PotLabel
@onready var last_round_label: Label = $LastRoundLabel

# ---- AI areas ----------------------------------------------------------------

@onready var ai1_area: Control = $AIContainer/AI1Area
@onready var ai1_chips: Label = $AIContainer/AI1Area/ChipsLabel
@onready var ai1_hand: HandDisplay = $AIContainer/AI1Area/HandDisplay
@onready var ai2_area: Control = $AIContainer/AI2Area
@onready var ai2_chips: Label = $AIContainer/AI2Area/ChipsLabel
@onready var ai2_hand: HandDisplay = $AIContainer/AI2Area/HandDisplay
@onready var ai3_area: Control = $AIContainer/AI3Area
@onready var ai3_chips: Label = $AIContainer/AI3Area/ChipsLabel
@onready var ai3_hand: HandDisplay = $AIContainer/AI3Area/HandDisplay

# ---- Player area -------------------------------------------------------------

@onready var player_chips_label: Label = $PlayerArea/ChipsLabel
@onready var player_hand: HandDisplay = $PlayerArea/HandDisplay
@onready var hand_rank_label: Label = $PlayerArea/HandRankLabel

# ---- Game log ----------------------------------------------------------------

@onready var log_label: RichTextLabel = $GameLog/LogLabel

# ---- Center arcana display ---------------------------------------------------

@onready var current_arcana: Control = $CurrentArcana
@onready var current_arcana_thumb: TextureRect = $CurrentArcana/ArcanaThumb
@onready var current_arcana_name: Label = $CurrentArcana/ArcanaNameLabel
@onready var current_arcana_desc: Label = $CurrentArcana/ArcanaDescLabel
@onready var latest_log_label: Label = $LatestLogLabel

# ---- Action panels -----------------------------------------------------------

@onready var bet_panel: BetPanel = $BetPanel
@onready var draw_panel: Control = $DrawPanel
@onready var draw_label: Label = $DrawPanel/DrawVBox/DrawLabel
@onready var confirm_button: Button = $DrawPanel/DrawVBox/ConfirmButton
@onready var arcana_panel: ArcanaPanel = $ArcanaPanel
@onready var chariot_panel = $ChariotPanel
@onready var star_panel = $StarPanel
@onready var magician_panel = $MagicianPanel
@onready var priestess_panel = $PriestessPanel
@onready var moon_panel = $MoonPanel
@onready var temperance_panel = $TemperancePanel
@onready var judgement_panel = $JudgementPanel

# ---- Pause panel -------------------------------------------------------------

@onready var pause_panel: PanelContainer = $PausePanel
@onready var resume_button: Button = $PausePanel/VBox/ResumeButton
@onready var main_menu_button: Button = $PausePanel/VBox/MainMenuButton

# ---- Setup -------------------------------------------------------------------

var _log_tween: Tween = null
var _skip_flip := false
var _bet_contributed: Dictionary = {}

func _ready() -> void:
	_flip_sfx = AudioStreamPlayer.new()
	_flip_sfx.stream = load("res://assets/audio/card_flip.mp3")
	add_child(_flip_sfx)
	_shuffle_sfx = AudioStreamPlayer.new()
	_shuffle_sfx.stream = load("res://assets/audio/card_shuffle.mp3")
	add_child(_shuffle_sfx)

	var num_players := GameManager.players.size()
	ai1_area.visible = false
	ai2_area.visible = false
	ai3_area.visible = false
	_layout_ai_areas(num_players)

	draw_panel.visible = false
	result_panel.visible = false
	last_round_label.visible = false
	arcana_panel.visible = false
	chariot_panel.visible = false
	star_panel.visible = false
	magician_panel.visible = false
	priestess_panel.visible = false
	moon_panel.visible = false
	temperance_panel.visible = false
	judgement_panel.visible = false

	confirm_button.pressed.connect(_on_confirm_discard)
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	chariot_panel.confirmed.connect(_on_chariot_confirmed)
	star_panel.swap_chosen.connect(_on_star_swap)
	star_panel.pass_chosen.connect(_on_star_pass)
	magician_panel.suit_chosen.connect(_on_magician_suit_chosen)
	priestess_panel.confirmed.connect(_on_priestess_confirmed)
	moon_panel.phase1_confirmed.connect(_on_moon_phase1_confirmed)
	moon_panel.swap_chosen.connect(_on_moon_swap)
	moon_panel.keep_chosen.connect(_on_moon_keep)
	temperance_panel.confirmed.connect(_on_temperance_confirmed)
	judgement_panel.reenter_chosen.connect(_on_judgement_reenter)
	judgement_panel.pass_chosen.connect(_on_judgement_pass)

	GameManager.player_bet_changed.connect(_on_player_bet_changed)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.player_hand_updated.connect(_on_player_hand_updated)
	GameManager.player_chips_changed.connect(_on_player_chips_changed)
	GameManager.player_folded.connect(_on_player_folded)
	GameManager.pot_changed.connect(_on_pot_changed)
	GameManager.arcana_revealed.connect(_on_arcana_revealed)
	GameManager.arcana_cancelled.connect(_on_arcana_cancelled)
	GameManager.last_round_announced.connect(_on_last_round_announced)
	GameManager.bet_input_needed.connect(_on_bet_input_needed)
	GameManager.discard_input_needed.connect(_on_discard_input_needed)
	GameManager.arcana_choice_needed.connect(_on_arcana_choice_needed)
	GameManager.cards_drawn.connect(_on_cards_drawn)
	GameManager.player_hand_revealed.connect(_on_player_hand_revealed)
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.page_bonus.connect(_on_page_bonus)
	GameManager.game_ended.connect(_on_game_ended)
	GameManager.game_log.connect(_on_game_log)

	current_arcana_thumb.custom_minimum_size = Vector2(80, 120)
	current_arcana_thumb.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	current_arcana_thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	current_arcana_thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	bet_panel.anchor_top = 1.0
	bet_panel.anchor_bottom = 1.0
	bet_panel.offset_top = -150.0
	bet_panel.offset_bottom = -5.0
	draw_panel.anchor_top = 1.0
	draw_panel.anchor_bottom = 1.0
	draw_panel.offset_top = -95.0
	draw_panel.offset_bottom = -5.0
	GameManager.start_game()

# ---- Layout ------------------------------------------------------------------

func _layout_ai_areas(num_players: int) -> void:
	var vp := get_viewport_rect().size
	$GameLog.visible = false
	match num_players:
		2:
			ai1_area.visible = true
			_anchor_area(ai1_area, 0.22, 0.06, 0.78, 0.36)
		3:
			ai1_area.visible = true
			ai2_area.visible = true
			_place_side(ai1_area, vp, true)
			_place_side(ai2_area, vp, false)
		4:
			ai1_area.visible = true
			ai2_area.visible = true
			ai3_area.visible = true
			_place_side(ai2_area, vp, true)
			_anchor_area(ai1_area, 0.22, 0.06, 0.78, 0.36)
			_place_side(ai3_area, vp, false)

func _anchor_area(area: Control, al: float, at: float, ar: float, ab: float) -> void:
	area.rotation = 0.0
	area.anchor_left = al
	area.anchor_top = at
	area.anchor_right = ar
	area.anchor_bottom = ab
	area.offset_left = 0.0
	area.offset_top = 0.0
	area.offset_right = 0.0
	area.offset_bottom = 0.0

func _place_side(area: Control, vp: Vector2, is_left: bool) -> void:
	var vis_w: float = vp.x * 0.14
	var vis_h: float = vp.y * 0.70
	var w: float = vis_h
	var h: float = vis_w
	var cx: float = vp.x * 0.07 if is_left else vp.x * 0.93
	var cy: float = vp.y * 0.50
	area.anchor_left = 0.0
	area.anchor_top = 0.0
	area.anchor_right = 0.0
	area.anchor_bottom = 0.0
	area.offset_left = cx - w / 2.0
	area.offset_top = cy - h / 2.0
	area.offset_right = cx + w / 2.0
	area.offset_bottom = cy + h / 2.0
	area.pivot_offset = Vector2(w / 2.0, h / 2.0)
	area.rotation_degrees = 90.0 if is_left else -90.0

# ---- Signal handlers ---------------------------------------------------------

func _on_player_bet_changed(player_idx: int, contributed: int) -> void:
	_bet_contributed[player_idx] = contributed
	_set_player_label(player_idx, GameManager.players[player_idx].chips)

func _on_phase_changed(phase_name: String) -> void:
	_bet_contributed.clear()
	_refresh_player_labels()
	if phase_name == "DEAL":
		_shuffle_sfx.play()
	phase_label.text = "Phase: " + phase_name
	bet_panel.hide_betting()
	draw_panel.visible = false
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	hand_rank_label.visible = (phase_name == "BET")
	if not arcana_panel.is_interactive():
		arcana_panel.visible = false
	if phase_name == "ANTE":
		player_hand.modulate = Color.WHITE
		ai1_area.modulate = Color.WHITE
		ai2_area.modulate = Color.WHITE
		ai3_area.modulate = Color.WHITE
		current_arcana.visible = false
		current_arcana_thumb.texture = null
		current_arcana_name.text = ""
		current_arcana_desc.text = ""
		current_arcana_desc.visible = false

func _on_cards_drawn(_player_idx: int, count: int) -> void:
	_skip_flip = true
	_flip_sfx.play()
	for i in range(1, count):
		await get_tree().create_timer(0.15).timeout
		_flip_sfx.play()

func _on_player_hand_updated(player_idx: int, hand: Array) -> void:
	if _skip_flip:
		_skip_flip = false
	elif not hand.is_empty():
		_flip_sfx.play()
	if GameManager.active_players.has(player_idx):
		match player_idx:
			0: player_hand.modulate = Color.WHITE
			1: ai1_area.modulate = Color.WHITE
			2: ai2_area.modulate = Color.WHITE
			3: ai3_area.modulate = Color.WHITE
	match player_idx:
		0:
			var sort_order := HandEvaluator.sort_order_for_display(
				hand,
				GameManager.round_state.king_beats_ace,
				GameManager.round_state.inverted_values
			)
			player_hand.set_hand(hand, true, sort_order)
			if not hand.is_empty():
				var opts := GameManager.round_state.eval_options()
				var score := HandEvaluator.score(hand, opts["king_beats_ace"], opts["inverted_values"], opts["fool_active"])
				hand_rank_label.text = HandEvaluator.hand_type_name(score)
		1: _set_ai_hand(ai1_hand, player_idx, hand)
		2: _set_ai_hand(ai2_hand, player_idx, hand)
		3: _set_ai_hand(ai3_hand, player_idx, hand)

func _on_player_hand_revealed(player_idx: int, hand: Array) -> void:
	if player_idx == GameManager.HUMAN_IDX or hand.is_empty():
		return
	_flip_sfx.play()
	var sort_order := HandEvaluator.sort_order_for_display(
		hand,
		GameManager.round_state.king_beats_ace,
		GameManager.round_state.inverted_values
	)
	match player_idx:
		1: ai1_hand.set_hand(hand, true, sort_order)
		2: ai2_hand.set_hand(hand, true, sort_order)
		3: ai3_hand.set_hand(hand, true, sort_order)

func _set_ai_hand(display: HandDisplay, pidx: int, hand: Array) -> void:
	var revealed: Card = GameManager.round_state.priestess_revealed.get(pidx)
	if revealed == null:
		display.set_back_count(hand.size())
	else:
		var idx: int = hand.find(revealed)
		display.set_hand_mixed(hand, [idx] if idx >= 0 else [])

func _label_for(pidx: int, chips: int) -> String:
	var dealer := " (D)" if pidx == GameManager.dealer_idx else ""
	var in_str := " (%d in)" % _bet_contributed[pidx] if _bet_contributed.has(pidx) else ""
	return "%s%s: %d chips%s" % [GameManager._pname(pidx), dealer, chips, in_str]

func _set_player_label(pidx: int, chips: int) -> void:
	var text := _label_for(pidx, chips)
	match pidx:
		0: player_chips_label.text = text
		1: ai1_chips.text = text
		2: ai2_chips.text = text
		3: ai3_chips.text = text

func _refresh_player_labels() -> void:
	for i in GameManager.players.size():
		_set_player_label(i, GameManager.players[i].chips)

func _on_player_chips_changed(player_idx: int, chips: int) -> void:
	_set_player_label(player_idx, chips)

func _on_player_folded(player_idx: int) -> void:
	const DIM = Color(0.45, 0.45, 0.45)
	match player_idx:
		0: player_hand.modulate = DIM
		1: ai1_area.modulate = DIM
		2: ai2_area.modulate = DIM
		3: ai3_area.modulate = DIM

func _on_pot_changed(new_amount: int) -> void:
	pot_label.text = "Pot: %d" % new_amount

func _hide_all_overlays() -> void:
	arcana_panel.visible = false
	chariot_panel.visible = false
	star_panel.visible = false
	magician_panel.visible = false
	priestess_panel.visible = false
	moon_panel.visible = false
	temperance_panel.visible = false
	judgement_panel.visible = false

func _on_arcana_revealed(arcana_id: int, _arcana_name: String) -> void:
	_hide_all_overlays()
	var tex_path := MajorArcana.texture_path(arcana_id)
	current_arcana_thumb.texture = load(tex_path) if ResourceLoader.exists(tex_path) else null
	current_arcana_name.text = MajorArcana.arcana_name(arcana_id)
	current_arcana_desc.text = MajorArcana.get_desc(arcana_id)
	current_arcana_desc.visible = true
	current_arcana.visible = true
	await get_tree().create_timer(1.5).timeout
	GameManager.complete_arcana_effect()

func _on_arcana_cancelled(cancelled_id: int) -> void:
	phase_label.text = "Hierophant cancelled: " + MajorArcana.arcana_name(cancelled_id)

func _on_last_round_announced() -> void:
	last_round_label.visible = true

func _on_bet_input_needed(player_idx: int, current_bet: int, can_check: bool, min_raise: int) -> void:
	if player_idx == GameManager.HUMAN_IDX:
		bet_panel.show_betting(current_bet, can_check, min_raise)

func _on_discard_input_needed(_player_idx: int) -> void:
	draw_label.text = "Click cards to discard, then confirm (keep all = click none):"
	draw_panel.visible = true
	player_hand.set_selectable(true)

func _on_arcana_choice_needed(player_idx: int, arcana_id: int) -> void:
	_hide_all_overlays()
	if arcana_id == 7:
		var pname := GameManager._pname(player_idx)
		chariot_panel.show_for_player(pname)
		player_hand.set_selectable(true, 1)
	elif arcana_id == 17:
		var pname := GameManager._pname(player_idx)
		star_panel.show_for_player(pname)
		player_hand.set_selectable(true, 1)
	elif arcana_id == 1:
		var pname := GameManager._pname(player_idx)
		magician_panel.show_for_player(pname)
	elif arcana_id == 2:
		var pname := GameManager._pname(player_idx)
		priestess_panel.show_for_player(pname)
		player_hand.set_selectable(true, 1)
	elif arcana_id == 20:
		judgement_panel.show_for_player("You", GameManager.ante_amount)
	elif arcana_id == 14:
		var pname := GameManager._pname(player_idx)
		temperance_panel.show_for_player(pname, GameManager.round_state.temperance_flop)
		player_hand.set_selectable(true, 1)
	elif arcana_id == 18:
		var secret: Card = GameManager.round_state.moon_secret.get(player_idx)
		var pname := GameManager._pname(player_idx)
		if not GameManager.round_state.moon_reveal_done:
			moon_panel.show_reveal(secret, pname)
		else:
			moon_panel.show_swap(secret, pname)
			player_hand.set_selectable(true, 1)
	else:
		await get_tree().create_timer(1.0).timeout
		GameManager.complete_arcana_effect()

func _on_priestess_confirmed() -> void:
	var selected := player_hand.get_selected_indices()
	if selected.is_empty():
		return
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	priestess_panel.visible = false
	GameManager.submit_arcana_choice(selected[0])

func _on_judgement_reenter() -> void:
	judgement_panel.visible = false
	GameManager.submit_arcana_choice(1)

func _on_judgement_pass() -> void:
	judgement_panel.visible = false
	GameManager.submit_arcana_choice(0)

func _on_temperance_confirmed(flop_idx: int) -> void:
	var hand_selected := player_hand.get_selected_indices()
	if hand_selected.is_empty():
		return
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	temperance_panel.visible = false
	GameManager.submit_arcana_choice_pair(hand_selected[0], flop_idx)

func _on_moon_phase1_confirmed() -> void:
	moon_panel.visible = false
	GameManager.complete_arcana_effect()

func _on_moon_swap() -> void:
	var selected := player_hand.get_selected_indices()
	if selected.is_empty():
		return
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	moon_panel.visible = false
	GameManager.submit_arcana_choice(selected[0])

func _on_moon_keep() -> void:
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	moon_panel.visible = false
	GameManager.submit_arcana_choice(-1)

func _on_magician_suit_chosen(suit_idx: int) -> void:
	magician_panel.visible = false
	GameManager.submit_arcana_choice(suit_idx)

func _on_star_swap() -> void:
	var selected := player_hand.get_selected_indices()
	if selected.is_empty():
		return
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	star_panel.visible = false
	GameManager.submit_arcana_choice(selected[0])

func _on_star_pass() -> void:
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	star_panel.visible = false
	GameManager.submit_arcana_choice(-1)

func _on_chariot_confirmed() -> void:
	var selected := player_hand.get_selected_indices()
	if selected.is_empty():
		return
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	chariot_panel.visible = false
	GameManager.submit_arcana_choice(selected[0])

func _on_confirm_discard() -> void:
	var indices := player_hand.get_selected_indices()
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	draw_panel.visible = false
	GameManager.submit_discard(indices)

func _on_round_ended(winner_indices: Array, hand_names: Array, split: bool) -> void:
	_hide_all_overlays()
	bet_panel.hide_betting()
	draw_panel.visible = false
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	var parts: Array = []
	if split and hand_names.is_empty():
		parts.append("Split pot!")
	else:
		for i in winner_indices.size():
			var w: int = winner_indices[i]
			var player_name := GameManager._pname(w)
			var hand_name: String = hand_names[i] if i < hand_names.size() else ""
			var verb := "win" if w == 0 else "wins"
			parts.append("%s %s with %s" % [player_name, verb, hand_name])
		if split:
			parts.insert(0, "Split pot!")
	phase_label.text = " | ".join(parts)
	await get_tree().create_timer(4.0).timeout
	GameManager.confirm_next_round()

func _on_page_bonus(winner_idx: int, bonus_per_player: int) -> void:
	var player_name := GameManager._pname(winner_idx)
	phase_label.text = "%s gets Page bonus: +%d per player!" % [player_name, bonus_per_player]

func _on_game_ended(final_chips: Array) -> void:
	_hide_all_overlays()
	var max_chips: int = final_chips.max()
	var winners: Array = []
	for i in final_chips.size():
		if final_chips[i] == max_chips:
			winners.append(GameManager._pname(i))
	var header := "%s wins!" % " & ".join(winners) if winners.size() < final_chips.size() \
		else "It's a tie!"
	phase_label.text = "Game Over — " + header
	var standings: Array = range(final_chips.size())
	standings.sort_custom(func(a, b): return final_chips[a] > final_chips[b])
	for i in standings:
		var pname := GameManager._pname(i)
		log_label.append_text("%s: %d chips\n" % [pname, final_chips[i]])
	log_label.scroll_to_paragraph(log_label.get_paragraph_count() - 1)
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_game_log(message: String) -> void:
	print(message)
	log_label.append_text(message + "\n")
	log_label.scroll_to_paragraph(log_label.get_paragraph_count() - 1)
	_flash_latest_log(message)

func _flash_latest_log(message: String) -> void:
	if is_instance_valid(_log_tween):
		_log_tween.kill()
	_log_tween = create_tween()
	_log_tween.tween_property(latest_log_label, "modulate:a", 0.0, 0.10)
	_log_tween.tween_callback(func(): latest_log_label.text = message)
	_log_tween.tween_property(latest_log_label, "modulate:a", 1.0, 0.20).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _toggle_pause() -> void:
	var pausing := not pause_panel.visible
	pause_panel.visible = pausing
	get_tree().paused = pausing

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
