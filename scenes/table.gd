extends Control

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

# ---- Game log ----------------------------------------------------------------

@onready var log_label: RichTextLabel = $GameLog/LogLabel

# ---- Center arcana display ---------------------------------------------------

@onready var current_arcana: Control = $CurrentArcana
@onready var current_arcana_thumb: TextureRect = $CurrentArcana/ArcanaThumb
@onready var current_arcana_name: Label = $CurrentArcana/ArcanaNameLabel

# ---- Action panels -----------------------------------------------------------

@onready var bet_panel: BetPanel = $BetPanel
@onready var draw_panel: Control = $DrawPanel
@onready var draw_label: Label = $DrawPanel/DrawVBox/DrawLabel
@onready var confirm_button: Button = $DrawPanel/DrawVBox/ConfirmButton
@onready var arcana_panel: ArcanaPanel = $ArcanaPanel
@onready var chariot_panel = $ChariotPanel
@onready var star_panel = $StarPanel

# ---- Result panel ------------------------------------------------------------

@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_label: Label = $ResultPanel/VBox/ResultLabel
@onready var next_button: Button = $ResultPanel/VBox/NextButton

# ---- Setup -------------------------------------------------------------------

var _game_over: bool = false

func _ready() -> void:
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

	confirm_button.pressed.connect(_on_confirm_discard)
	next_button.pressed.connect(_on_next_pressed)
	chariot_panel.confirmed.connect(_on_chariot_confirmed)
	star_panel.swap_chosen.connect(_on_star_swap)
	star_panel.pass_chosen.connect(_on_star_pass)

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
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.page_bonus.connect(_on_page_bonus)
	GameManager.game_ended.connect(_on_game_ended)
	GameManager.game_log.connect(_on_game_log)

	GameManager.start_game()

# ---- Layout ------------------------------------------------------------------

func _layout_ai_areas(num_players: int) -> void:
	var vp := get_viewport_rect().size
	match num_players:
		2:
			ai1_area.visible = true
			_anchor_area(ai1_area, 0.2, 0.06, 0.8, 0.36)
		3:
			ai1_area.visible = true
			ai2_area.visible = true
			_anchor_area(ai1_area, 0.02, 0.06, 0.5, 0.36)
			_anchor_area(ai2_area, 0.5, 0.06, 0.98, 0.36)
		4:
			ai1_area.visible = true
			ai2_area.visible = true
			ai3_area.visible = true
			_place_side(ai1_area, vp, true)
			_anchor_area(ai2_area, 0.22, 0.06, 0.78, 0.36)
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

func _on_phase_changed(phase_name: String) -> void:
	phase_label.text = "Phase: " + phase_name
	bet_panel.hide_betting()
	draw_panel.visible = false
	player_hand.set_selectable(false)
	player_hand.clear_selection()
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

func _on_player_hand_updated(player_idx: int, hand: Array) -> void:
	match player_idx:
		0: player_hand.set_hand(hand, true)
		1: ai1_hand.set_back_count(hand.size())
		2: ai2_hand.set_back_count(hand.size())
		3: ai3_hand.set_back_count(hand.size())

func _on_player_chips_changed(player_idx: int, chips: int) -> void:
	match player_idx:
		0: player_chips_label.text = "You: %d chips" % chips
		1: ai1_chips.text = "AI 1: %d chips" % chips
		2: ai2_chips.text = "AI 2: %d chips" % chips
		3: ai3_chips.text = "AI 3: %d chips" % chips

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
	result_panel.visible = false
	chariot_panel.visible = false
	star_panel.visible = false

func _on_arcana_revealed(arcana_id: int, _arcana_name: String) -> void:
	_hide_all_overlays()
	arcana_panel.show_arcana(arcana_id)
	var tex_path := MajorArcana.texture_path(arcana_id)
	current_arcana_thumb.texture = load(tex_path) if ResourceLoader.exists(tex_path) else null
	current_arcana_name.text = MajorArcana.arcana_name(arcana_id)
	current_arcana.visible = true

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
		var pname := "You" if player_idx == GameManager.HUMAN_IDX else "AI %d" % player_idx
		chariot_panel.show_for_player(pname)
		player_hand.set_selectable(true)
	elif arcana_id == 17:
		var pname := "You" if player_idx == GameManager.HUMAN_IDX else "AI %d" % player_idx
		star_panel.show_for_player(pname)
		player_hand.set_selectable(true)
	else:
		arcana_panel.show_interactive(arcana_id)

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
	var msg := ""
	if split and hand_names.is_empty():
		msg = "Split pot! (equal share)"
	else:
		if split:
			msg = "Split pot!\n"
		for i in winner_indices.size():
			var w: int = winner_indices[i]
			var player_name := "You" if w == 0 else "AI %d" % w
			var hand_name: String = hand_names[i] if i < hand_names.size() else ""
			var verb := "win" if w == 0 else "wins"
			msg += "%s %s with %s\n" % [player_name, verb, hand_name]
	result_label.text = msg.strip_edges()
	next_button.text = "Next Round"
	_game_over = false
	result_panel.visible = true

func _on_page_bonus(winner_idx: int, bonus_per_player: int) -> void:
	var player_name := "You" if winner_idx == 0 else "AI %d" % winner_idx
	phase_label.text = "%s gets Page bonus: +%d per player!" % [player_name, bonus_per_player]

func _on_game_ended(final_chips: Array) -> void:
	_hide_all_overlays()
	var msg := "Game Over!\n"
	for i in final_chips.size():
		var player_name := "You" if i == 0 else "AI %d" % i
		msg += "%s: %d chips\n" % [player_name, final_chips[i]]
	result_label.text = msg.strip_edges()
	next_button.text = "Main Menu"
	_game_over = true
	result_panel.visible = true

func _on_game_log(message: String) -> void:
	print(message)
	log_label.append_text(message + "\n")
	log_label.scroll_to_paragraph(log_label.get_paragraph_count() - 1)

func _on_next_pressed() -> void:
	result_panel.visible = false
	if _game_over:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
