extends Control

# ---- Audio -------------------------------------------------------------------

var _flip_sfx: AudioStreamPlayer
var _shuffle_sfx: AudioStreamPlayer

# ---- Top bar -----------------------------------------------------------------

@onready var pot_label: Label = $BetPanel/VBox/PotLabel
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
@onready var current_arcana_thumb: TextureRect = $CurrentArcana/ArcanaCardContainer/ArcanaThumb
@onready var current_arcana_name: Label = $CurrentArcana/ArcanaNameLabel
@onready var current_arcana_desc: Label = $CurrentArcana/ArcanaDescLabel

# ---- Arcana deck / discard pile ----------------------------------------------

@onready var arcana_deck_card: TextureRect = $ArcanaDeck/CardStack/DeckCard
@onready var arcana_deck_stack1: TextureRect = $ArcanaDeck/CardStack/StackCard1
@onready var arcana_deck_stack2: TextureRect = $ArcanaDeck/CardStack/StackCard2
@onready var arcana_deck_label: Label = $ArcanaDeck/DeckCountLabel
@onready var arcana_discard_card: TextureRect = $ArcanaDiscard/CardStack/DiscardCard
@onready var arcana_discard_stack1: TextureRect = $ArcanaDiscard/CardStack/StackCard1
@onready var arcana_discard_stack2: TextureRect = $ArcanaDiscard/CardStack/StackCard2
@onready var arcana_discard_label: Label = $ArcanaDiscard/DiscardCountLabel
@onready var flying_arcana_card: TextureRect = $FlyingArcanaCard
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

# ---- Dialogue display -------------------------------------------------------

@onready var dialogue_display: PanelContainer = $DialogueDisplay
@onready var dialogue_speaker: Label = $DialogueDisplay/VBox/SpeakerLabel
@onready var dialogue_text: Label = $DialogueDisplay/VBox/LineLabel

# ---- Pause panel -------------------------------------------------------------

@onready var pause_panel: PanelContainer = $PausePanel
@onready var resume_button: Button = $PausePanel/VBox/ResumeButton
@onready var main_menu_button: Button = $PausePanel/VBox/MainMenuButton

# ---- Setup -------------------------------------------------------------------

const _STRONG_HANDS := ["Royal Flush", "Straight Flush", "Four of a Kind"]
const _SPEAKER_COLORS: Dictionary = {
	1: Color(0.93, 0.46, 0.13),  # Tarvosk — burnt orange
	2: Color(0.42, 0.65, 0.85),  # Haldemar — steel blue
	3: Color(0.70, 0.42, 0.90),  # Mercival — violet
}

var _log_tween: Tween = null
var _dialogue_tween: Tween = null
var _dialogue_queue: Array = []  # lines queue so rapid-fire triggers don't cut each other off
var _skip_flip := false
var _bet_contributed: Dictionary = {}
var _starting_chips: int = 0
var _colored_label_settings: Dictionary = {}
var _current_phase: String = ""
var _pending_discard_indices: Array = []
var _skip_player_hand_redraw: bool = false
var _arcana_remaining: int = 22
var _arcana_discard_count: int = 0
var _current_arcana_id: int = -1

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
	dialogue_display.visible = false
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
	GameManager.player_raised.connect(_on_player_raised)
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
	DialogueManager.dialogue_line.connect(_on_dialogue_line)
	DialogueManager.tell_read.connect(_on_tell_read)
	GameManager.display_sort_changed.connect(_on_display_sort_changed)

	bet_panel.anchor_top = 1.0
	bet_panel.anchor_bottom = 1.0
	bet_panel.offset_top = -150.0
	bet_panel.offset_bottom = -5.0
	draw_panel.anchor_top = 1.0
	draw_panel.anchor_bottom = 1.0
	draw_panel.offset_top = -95.0
	draw_panel.offset_bottom = -5.0

	# Switch dialogue_display from anchor-based to offset-based positioning
	# so _reposition_dialogue can move it freely without anchor interference.
	dialogue_display.anchor_left = 0.0
	dialogue_display.anchor_right = 0.0

	# LabelSettings.font_color wins over add_theme_color_override, so we
	# duplicate the resource once per speaker color instead of using overrides.
	if dialogue_speaker.label_settings != null:
		var base_ls := dialogue_speaker.label_settings
		for pidx: int in _SPEAKER_COLORS:
			var ls: LabelSettings = base_ls.duplicate()
			ls.font_color = _SPEAKER_COLORS[pidx]
			_colored_label_settings[pidx] = ls

	var back_tex := load(SettingsManager.card_back_path()) as Texture2D
	arcana_deck_card.texture = back_tex
	arcana_deck_stack1.texture = back_tex
	arcana_deck_stack2.texture = back_tex
	arcana_discard_stack1.texture = back_tex
	arcana_discard_stack2.texture = back_tex
	flying_arcana_card.pivot_offset = Vector2(40.0, 60.0)

	GameManager.start_game()
	if GameManager.players.size() > 0:
		_starting_chips = GameManager.players[0].chips

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
	if GameManager.players[player_idx].chips == 0:
		if player_idx == GameManager.HUMAN_IDX:
			DialogueManager.try_fire_any("player_went_all_in", 0.90)
		else:
			DialogueManager.try_fire("ai_went_all_in", player_idx, 0.85)
		if randf() < 0.25:
			var allin_key := "player_went_all_in" if player_idx == GameManager.HUMAN_IDX else "ai_went_all_in"
			DialogueManager.try_fire_exchange(allin_key)

func _on_player_raised(player_idx: int, raise_to: int, prev_bet: int) -> void:
	if player_idx != GameManager.HUMAN_IDX:
		return
	if prev_bet > 0 and raise_to >= prev_bet * 3:
		DialogueManager.try_fire_any("player_raised_aggressively", 0.50)

func _dealer_screen_pos() -> Vector2:
	var vp := get_viewport_rect().size
	var num := GameManager.players.size()
	match GameManager.dealer_idx:
		0:
			return Vector2(vp.x * 0.50, vp.y * 0.90)
		1:
			return Vector2(vp.x * 0.07, vp.y * 0.50) if num == 3 \
				else Vector2(vp.x * 0.50, vp.y * 0.21)
		2:
			return Vector2(vp.x * 0.93, vp.y * 0.50) if num == 3 \
				else Vector2(vp.x * 0.07, vp.y * 0.50)
		3:
			return Vector2(vp.x * 0.93, vp.y * 0.50)
	return vp / 2.0

func _on_phase_changed(phase_name: String) -> void:
	_current_phase = phase_name
	_bet_contributed.clear()
	_refresh_player_labels()
	if phase_name == "DEAL":
		_shuffle_sfx.play()
	bet_panel.hide_betting()
	draw_panel.visible = false
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	hand_rank_label.modulate.a = 1.0 if phase_name == "BET" else 0.0
	if not arcana_panel.is_interactive():
		arcana_panel.visible = false
	if phase_name == "ANTE":
		player_hand.modulate = Color.WHITE
		ai1_area.modulate = Color.WHITE
		ai2_area.modulate = Color.WHITE
		ai3_area.modulate = Color.WHITE
		# Hierophant stays on the table between rounds until it cancels something;
		# leave the card displayed so the player can see it's still pending.
		# Once round_state.hierophant_active flips false (consumed), the next
		# ANTE clears it normally.
		if _current_arcana_id == 5 and GameManager.round_state.hierophant_active:
			pass
		else:
			if _current_arcana_id >= 0:
				_fly_arcana_to_discard()
			else:
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
	var deal_pos := _dealer_screen_pos() \
		if (_current_phase == "DEAL" and (_current_arcana_id < 0 or _current_arcana_id == 10)) \
		else Vector2.ZERO
	match player_idx:
		0:
			var sort_order := HandEvaluator.sort_order_for_display(
				hand,
				GameManager.round_state.king_beats_ace,
				GameManager.round_state.inverted_values
			)
			if _skip_player_hand_redraw:
				_skip_player_hand_redraw = false
			elif not _pending_discard_indices.is_empty():
				player_hand.replace_cards(hand, _pending_discard_indices, _dealer_screen_pos(), sort_order)
				_pending_discard_indices.clear()
			elif _current_phase != "DRAW":
				player_hand.set_hand(hand, true, sort_order, deal_pos)
			if not hand.is_empty():
				var opts := GameManager.round_state.eval_options()
				var score := HandEvaluator.score(hand, opts["king_beats_ace"], opts["inverted_values"], opts["fool_active"])
				hand_rank_label.text = HandEvaluator.hand_type_name(score)
		1: _set_ai_hand(ai1_hand, player_idx, hand, deal_pos)
		2: _set_ai_hand(ai2_hand, player_idx, hand, deal_pos)
		3: _set_ai_hand(ai3_hand, player_idx, hand, deal_pos)

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

func _set_ai_hand(display: HandDisplay, pidx: int, hand: Array, deal_pos: Vector2 = Vector2.ZERO) -> void:
	var revealed: Card = GameManager.round_state.priestess_revealed.get(pidx)
	if revealed == null:
		display.set_back_count(hand.size(), deal_pos)
	elif deal_pos == Vector2.ZERO and display.get_child_count() == hand.size():
		var idx: int = hand.find(revealed)
		if idx >= 0:
			display.flip_card_at_index(idx, revealed)
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
	if _starting_chips > 0 and chips > 0:
		var threshold: int = maxi(10, int(_starting_chips * 0.2))
		if chips <= threshold:
			if player_idx == GameManager.HUMAN_IDX:
				if randf() < 0.25:
					DialogueManager.try_fire_exchange("player_low_chips")
				DialogueManager.try_fire_any("player_low_chips", 0.75, {"chips": chips})
			else:
				if randf() < 0.25:
					DialogueManager.try_fire_exchange("ai_low_chips")
				DialogueManager.try_fire("ai_low_chips", player_idx, 0.70, {"chips": chips})

func _on_player_folded(player_idx: int) -> void:
	const DIM = Color(0.45, 0.45, 0.45)
	match player_idx:
		0: player_hand.modulate = DIM
		1: ai1_area.modulate = DIM
		2: ai2_area.modulate = DIM
		3: ai3_area.modulate = DIM
	if player_idx == GameManager.HUMAN_IDX:
		if randf() < 0.25:
			DialogueManager.try_fire_exchange("player_folded")
		DialogueManager.try_fire_any("player_folded", 0.70)

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
	_current_arcana_id = arcana_id
	_arcana_remaining = maxi(0, _arcana_remaining - 1)
	_update_arcana_deck_display()
	var tex_path := MajorArcana.texture_path(arcana_id)
	var face_tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	current_arcana_thumb.texture = face_tex
	current_arcana_name.text = MajorArcana.arcana_name(arcana_id)
	current_arcana_desc.text = MajorArcana.get_desc(arcana_id)
	current_arcana_desc.visible = true
	await _fly_arcana_from_deck(face_tex)
	current_arcana.visible = true
	if randf() < 0.25:
		DialogueManager.try_fire_exchange("arcana_revealed")
	DialogueManager.try_fire_any("arcana_revealed_%d" % arcana_id, 0.85, {"arcana_name": MajorArcana.arcana_name(arcana_id)})
	await get_tree().create_timer(1.5).timeout
	if arcana_id == 18:
		_show_moon_secrets()
	GameManager.complete_arcana_effect()
	if arcana_id in [8, 11, 13, 16, 19]:
		await get_tree().create_timer(2.0).timeout
		DialogueManager.try_fire_any("arcana_aftermath_%d" % arcana_id, 0.70)

func _on_arcana_cancelled(cancelled_id: int) -> void:
	_arcana_remaining = maxi(0, _arcana_remaining - 1)
	_update_arcana_deck_display()
	var tex_path := MajorArcana.texture_path(cancelled_id)
	var face_tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	_fly_arcana_deck_to_discard(face_tex)
	# Hierophant just consumed itself — fly it from the center to the discard
	# so the player sees the cancel happen visually, not just in the log.
	if _current_arcana_id == 5:
		_fly_arcana_to_discard()
		current_arcana_thumb.texture = null
		current_arcana_name.text = ""
		current_arcana_desc.text = ""
		current_arcana_desc.visible = false

func _on_last_round_announced() -> void:
	last_round_label.visible = true
	DialogueManager.try_fire_exchange("last_round_announced")
	DialogueManager.try_fire_any("last_round_announced", 1.0)

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
	_skip_player_hand_redraw = true
	player_hand.mark_priestess_card(selected[0])
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
	_pending_discard_indices = [hand_selected[0]]
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
	_hide_moon_secrets()
	GameManager.submit_arcana_choice(selected[0])

func _on_moon_keep() -> void:
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	moon_panel.visible = false
	_hide_moon_secrets()
	GameManager.submit_arcana_choice(-1)

func _show_moon_secrets() -> void:
	for i in GameManager.active_players:
		match i:
			0: player_hand.show_moon_secret()
			1: ai1_hand.show_moon_secret()
			2: ai2_hand.show_moon_secret()
			3: ai3_hand.show_moon_secret()

func _hide_moon_secrets() -> void:
	player_hand.hide_moon_secret()
	ai1_hand.hide_moon_secret()
	ai2_hand.hide_moon_secret()
	ai3_hand.hide_moon_secret()

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
	_pending_discard_indices = indices.duplicate()
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
	# Rare hand reactions — always use a reactor (not the winner themselves).
	for i in hand_names.size():
		var w: int = winner_indices[i]
		var ctx := {"hand_name": hand_names[i], "player_name": GameManager._pname(w)}
		if hand_names[i] == "Five of a Kind":
			DialogueManager.try_fire_exchange("five_of_a_kind_shown")
			DialogueManager.try_fire_any_except("five_of_a_kind_shown", w, 1.0)
			break
		elif hand_names[i] in _STRONG_HANDS:
			if randf() < 0.25:
				DialogueManager.try_fire_exchange("strong_hand_shown")
			DialogueManager.try_fire_any_except("strong_hand_shown", w, 0.95, ctx)
			break
	# Split pot commentary.
	if split:
		if randf() < 0.25:
			DialogueManager.try_fire_exchange("split_pot")
		DialogueManager.try_fire_any("split_pot", 0.80)
	# Normal round-end commentary (skipped for split pots).
	if not split:
		var exchange_trigger := "player_won_round" if winner_indices.has(GameManager.HUMAN_IDX) else "ai_won_round"
		if randf() < 0.20:
			DialogueManager.try_fire_exchange(exchange_trigger)
		elif winner_indices.has(GameManager.HUMAN_IDX):
			var hi := winner_indices.find(GameManager.HUMAN_IDX)
			var ctx := {"hand_name": hand_names[hi] if hi < hand_names.size() else ""}
			DialogueManager.try_fire_any("player_won_round", 0.85, ctx)
		else:
			var ctx := {"hand_name": hand_names[0] if not hand_names.is_empty() else ""}
			DialogueManager.try_fire("ai_won_round", winner_indices[0], 0.90, ctx)
	await get_tree().create_timer(4.0).timeout
	GameManager.confirm_next_round()

func _on_page_bonus(_winner_idx: int, _bonus_per_player: int) -> void:
	pass

func _on_game_ended(final_chips: Array) -> void:
	_hide_all_overlays()
	var max_chips: int = final_chips.max()
	var winners: Array = []
	for i in final_chips.size():
		if final_chips[i] == max_chips:
			winners.append(GameManager._pname(i))
	var standings: Array = range(final_chips.size())
	standings.sort_custom(func(a, b): return final_chips[a] > final_chips[b])
	for i in standings:
		var pname := GameManager._pname(i)
		log_label.append_text("%s: %d chips\n" % [pname, final_chips[i]])
	log_label.scroll_to_paragraph(log_label.get_paragraph_count() - 1)
	var return_to_career := RunManager.session_belongs_to_run()
	if return_to_career:
		RunManager.record_match_result(final_chips)
	# 16s fits ~3 game-end dialogue lines (~5s each) plus margin so the closing
	# Tarvosk/Haldemar/Mercival line isn't cut off by the scene transition.
	await get_tree().create_timer(16.0).timeout
	var next_scene := "res://scenes/career_screen.tscn" if return_to_career else "res://scenes/main_menu.tscn"
	get_tree().change_scene_to_file(next_scene)

func _update_arcana_deck_display() -> void:
	arcana_deck_label.text = str(_arcana_remaining)
	arcana_deck_card.visible = _arcana_remaining > 0
	arcana_deck_stack1.visible = _arcana_remaining > 1
	arcana_deck_stack2.visible = _arcana_remaining > 2

func _update_arcana_discard_display() -> void:
	arcana_discard_label.text = str(_arcana_discard_count)
	arcana_discard_card.visible = _arcana_discard_count > 0
	arcana_discard_stack1.visible = _arcana_discard_count > 1
	arcana_discard_stack2.visible = _arcana_discard_count > 2

func _fly_arcana_from_deck(face_tex: Texture2D) -> void:
	flying_arcana_card.texture = load(SettingsManager.card_back_path())
	flying_arcana_card.scale = Vector2.ONE
	flying_arcana_card.position = arcana_deck_card.get_global_rect().position
	flying_arcana_card.visible = true
	# Show current_arcana invisibly for one frame so its layout is computed.
	current_arcana.modulate.a = 0.0
	current_arcana.visible = true
	await get_tree().process_frame
	var to_pos := current_arcana_thumb.get_global_rect().position
	current_arcana.visible = false
	current_arcana.modulate.a = 1.0
	var t: Tween = create_tween()
	t.tween_property(flying_arcana_card, "position", to_pos, 0.45) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await t.finished
	if face_tex != null:
		t = create_tween()
		t.tween_property(flying_arcana_card, "scale:x", 0.0, 0.09)
		t.tween_callback(func(): flying_arcana_card.texture = face_tex)
		t.tween_property(flying_arcana_card, "scale:x", 1.0, 0.09)
		await t.finished
	flying_arcana_card.visible = false

func _fly_arcana_to_discard() -> void:
	var id := _current_arcana_id
	_current_arcana_id = -1
	var tex_path := MajorArcana.texture_path(id)
	var face_tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	var from_pos := current_arcana_thumb.get_global_rect().position
	flying_arcana_card.texture = face_tex
	flying_arcana_card.scale = Vector2.ONE
	flying_arcana_card.position = from_pos
	flying_arcana_card.visible = true
	current_arcana.visible = false
	var to_pos := arcana_discard_card.get_global_rect().position
	var t: Tween = create_tween()
	t.tween_property(flying_arcana_card, "position", to_pos, 0.40) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await t.finished
	flying_arcana_card.visible = false
	_arcana_discard_count += 1
	arcana_discard_card.texture = face_tex
	_update_arcana_discard_display()

func _fly_arcana_deck_to_discard(face_tex: Texture2D) -> void:
	flying_arcana_card.texture = load(SettingsManager.card_back_path())
	flying_arcana_card.scale = Vector2.ONE
	flying_arcana_card.position = arcana_deck_card.get_global_rect().position
	flying_arcana_card.visible = true
	var to_pos := arcana_discard_card.get_global_rect().position
	var t: Tween = create_tween()
	t.tween_property(flying_arcana_card, "position", to_pos, 0.40) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await t.finished
	flying_arcana_card.visible = false
	_arcana_discard_count += 1
	arcana_discard_card.texture = face_tex
	_update_arcana_discard_display()

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

func _ai_area_for_speaker(speaker_idx: int) -> Control:
	match speaker_idx:
		1: return ai1_area
		2: return ai2_area
		3: return ai3_area
	return null

# Where the given AI speaker is visually seated — mirrors the placement done
# by _layout_ai_areas. Used by dialogue positioning so each bubble appears
# near the AI who's speaking.
func _seat_for_speaker(speaker_idx: int) -> String:
	var n := GameManager.players.size()
	match n:
		2:
			return "top"
		3:
			if speaker_idx == 1: return "left"
			if speaker_idx == 2: return "right"
		4:
			if speaker_idx == 1: return "top"
			if speaker_idx == 2: return "left"
			if speaker_idx == 3: return "right"
	return "top"

func _reposition_dialogue(speaker_idx: int) -> void:
	# Position by the speaker's seat (top/left/right), not by speaker_idx —
	# in 3-player layouts Tarvosk (idx 1) sits on the LEFT, not the top, and
	# Haldemar (idx 2) sits on the RIGHT, not the left.
	var vp := get_viewport_rect().size
	var box_h := 70.0
	var box_w: float
	var left: float
	var top: float
	match _seat_for_speaker(speaker_idx):
		"top":
			box_w = vp.x * 0.45
			left = (vp.x - box_w) * 0.5
			top = vp.y * 0.20
		"left":
			box_w = vp.x * 0.35
			left = vp.x * 0.09
			top = vp.y * 0.52
		"right":
			box_w = vp.x * 0.35
			left = vp.x * 0.62
			top = vp.y * 0.45
		_:
			box_w = vp.x * 0.40
			left = (vp.x - box_w) * 0.5
			top = vp.y * 0.60
	left = clampf(left, 0.0, vp.x - box_w)
	top = clampf(top, 0.0, vp.y - box_h)
	dialogue_display.offset_left = left
	dialogue_display.offset_top = top
	dialogue_display.offset_right = left + box_w
	dialogue_display.offset_bottom = top + box_h

func _on_dialogue_line(speaker_idx: int, speaker_name: String, line: String) -> void:
	if _dialogue_queue.any(func(m): return m.speaker_idx == speaker_idx):
		return
	_dialogue_queue.append({speaker_idx = speaker_idx, speaker_name = speaker_name, line = line})
	if not (is_instance_valid(_dialogue_tween) and _dialogue_tween.is_running()):
		_show_next_dialogue()

func _show_next_dialogue() -> void:
	if _dialogue_queue.is_empty():
		return
	var msg: Dictionary = _dialogue_queue.pop_front()
	var speaker_idx: int = msg.speaker_idx
	var ls: LabelSettings = _colored_label_settings.get(speaker_idx)
	if ls != null:
		dialogue_speaker.label_settings = ls
	dialogue_speaker.text = msg.speaker_name
	dialogue_text.text = msg.line
	_reposition_dialogue(speaker_idx)
	dialogue_display.modulate.a = 0.0
	dialogue_display.visible = true
	_dialogue_tween = create_tween()
	_dialogue_tween.tween_property(dialogue_display, "modulate:a", 1.0, 0.3)
	_dialogue_tween.tween_interval(4.0)
	_dialogue_tween.tween_property(dialogue_display, "modulate:a", 0.0, 0.5)
	_dialogue_tween.tween_callback(func():
		dialogue_display.visible = false
		_show_next_dialogue()
	)

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
	# Pausing out of a career match leaves the run intact — the player can
	# resume it by clicking Career from the main menu. Detach so the eventual
	# game_ended from this orphaned session doesn't get misread as a result.
	RunManager.detach_session()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_tell_read() -> void:
	GameManager.game_log.emit("You read Tarvosk's tell.")

# Strength/Emperor activated mid-round; slide existing cards into the new
# display order without recreating them, so the player doesn't see a second
# deal animation play on top of the first.
func _on_display_sort_changed() -> void:
	if not GameManager.active_players.has(GameManager.HUMAN_IDX):
		return
	var hand: Array = GameManager.players[GameManager.HUMAN_IDX].hand
	if hand.is_empty():
		return
	var sort_order := HandEvaluator.sort_order_for_display(
		hand,
		GameManager.round_state.king_beats_ace,
		GameManager.round_state.inverted_values
	)
	player_hand.resort(hand, sort_order)
	var opts := GameManager.round_state.eval_options()
	var score := HandEvaluator.score(hand, opts["king_beats_ace"], opts["inverted_values"], opts["fool_active"])
	hand_rank_label.text = HandEvaluator.hand_type_name(score)

# Autoload signals stay alive across scene changes. Method-bound connections
# get auto-cleaned when this node is freed, but it's still safer to disconnect
# explicitly — protects against future inline-lambda mistakes that would leak
# (see the tell_read stacking bug fixed at the same time as this function).
func _exit_tree() -> void:
	var connections: Array = [
		[GameManager.player_bet_changed,      _on_player_bet_changed],
		[GameManager.player_raised,           _on_player_raised],
		[GameManager.phase_changed,           _on_phase_changed],
		[GameManager.player_hand_updated,     _on_player_hand_updated],
		[GameManager.player_chips_changed,    _on_player_chips_changed],
		[GameManager.player_folded,           _on_player_folded],
		[GameManager.pot_changed,             _on_pot_changed],
		[GameManager.arcana_revealed,         _on_arcana_revealed],
		[GameManager.arcana_cancelled,        _on_arcana_cancelled],
		[GameManager.last_round_announced,    _on_last_round_announced],
		[GameManager.bet_input_needed,        _on_bet_input_needed],
		[GameManager.discard_input_needed,    _on_discard_input_needed],
		[GameManager.arcana_choice_needed,    _on_arcana_choice_needed],
		[GameManager.cards_drawn,             _on_cards_drawn],
		[GameManager.player_hand_revealed,    _on_player_hand_revealed],
		[GameManager.round_ended,             _on_round_ended],
		[GameManager.page_bonus,              _on_page_bonus],
		[GameManager.game_ended,              _on_game_ended],
		[GameManager.game_log,                _on_game_log],
		[GameManager.display_sort_changed,    _on_display_sort_changed],
		[DialogueManager.dialogue_line,       _on_dialogue_line],
		[DialogueManager.tell_read,           _on_tell_read],
	]
	for c in connections:
		if c[0].is_connected(c[1]):
			c[0].disconnect(c[1])
