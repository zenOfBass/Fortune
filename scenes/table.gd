extends Control

# ---- Top bar -----------------------------------------------------------------

@onready var phase_label: Label = $TopBar/PhaseLabel
@onready var pot_label: Label = $TopBar/PotLabel
@onready var last_round_label: Label = $LastRoundLabel

# ---- AI areas ----------------------------------------------------------------

@onready var ai1_area: Control = $AIRow/AI1Area
@onready var ai1_chips: Label = $AIRow/AI1Area/ChipsLabel
@onready var ai1_hand: HandDisplay = $AIRow/AI1Area/HandDisplay
@onready var ai2_area: Control = $AIRow/AI2Area
@onready var ai2_chips: Label = $AIRow/AI2Area/ChipsLabel
@onready var ai2_hand: HandDisplay = $AIRow/AI2Area/HandDisplay
@onready var ai3_area: Control = $AIRow/AI3Area
@onready var ai3_chips: Label = $AIRow/AI3Area/ChipsLabel
@onready var ai3_hand: HandDisplay = $AIRow/AI3Area/HandDisplay

# ---- Player area -------------------------------------------------------------

@onready var player_chips_label: Label = $PlayerArea/ChipsLabel
@onready var player_hand: HandDisplay = $PlayerArea/HandDisplay

# ---- Action panels -----------------------------------------------------------

@onready var bet_panel: BetPanel = $BetPanel
@onready var draw_panel: Control = $DrawPanel
@onready var draw_label: Label = $DrawPanel/DrawLabel
@onready var confirm_button: Button = $DrawPanel/ConfirmButton
@onready var arcana_panel: ArcanaPanel = $ArcanaPanel

# ---- Result panel ------------------------------------------------------------

@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_label: Label = $ResultPanel/VBox/ResultLabel
@onready var next_button: Button = $ResultPanel/VBox/NextButton

# ---- Setup -------------------------------------------------------------------

var _game_over: bool = false

func _ready() -> void:
	# Show AI areas based on actual player count set up in the menu.
	var num_players := GameManager.players.size()
	ai1_area.visible = (num_players >= 2)
	ai2_area.visible = (num_players >= 3)
	ai3_area.visible = (num_players >= 4)

	draw_panel.visible = false
	result_panel.visible = false
	last_round_label.visible = false
	arcana_panel.visible = false

	confirm_button.pressed.connect(_on_confirm_discard)
	next_button.pressed.connect(_on_next_pressed)

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

	GameManager.start_game()

# ---- Signal handlers ---------------------------------------------------------

func _on_phase_changed(phase_name: String) -> void:
	phase_label.text = "Phase: " + phase_name
	bet_panel.hide_betting()
	draw_panel.visible = false
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	# Non-interactive arcana panel auto-dismisses at next phase.
	if not arcana_panel.is_interactive():
		arcana_panel.visible = false
	if phase_name == "ANTE":
		# New round — reset fold dimming.
		player_hand.modulate = Color.WHITE
		ai1_area.modulate = Color.WHITE
		ai2_area.modulate = Color.WHITE
		ai3_area.modulate = Color.WHITE

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

func _on_arcana_revealed(arcana_id: int, _arcana_name: String) -> void:
	arcana_panel.show_arcana(arcana_id)

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

func _on_arcana_choice_needed(_player_idx: int, arcana_id: int) -> void:
	arcana_panel.show_interactive(arcana_id)

func _on_confirm_discard() -> void:
	var indices := player_hand.get_selected_indices()
	player_hand.set_selectable(false)
	player_hand.clear_selection()
	draw_panel.visible = false
	GameManager.submit_discard(indices)

func _on_round_ended(winner_indices: Array, hand_names: Array, split: bool) -> void:
	var msg := "Split pot!\n" if split else ""
	for i in winner_indices.size():
		var w: int = winner_indices[i]
		var player_name := "You" if w == 0 else "AI %d" % w
		var hand_name: String = hand_names[i] if i < hand_names.size() else ""
		msg += "%s wins with %s\n" % [player_name, hand_name]
	result_label.text = msg.strip_edges()
	next_button.text = "Next Round"
	_game_over = false
	result_panel.visible = true

func _on_page_bonus(winner_idx: int, bonus_per_player: int) -> void:
	var player_name := "You" if winner_idx == 0 else "AI %d" % winner_idx
	phase_label.text = "%s gets Page bonus: +%d per player!" % [player_name, bonus_per_player]

func _on_game_ended(final_chips: Array) -> void:
	var msg := "Game Over!\n"
	for i in final_chips.size():
		var player_name := "You" if i == 0 else "AI %d" % i
		msg += "%s: %d chips\n" % [player_name, final_chips[i]]
	result_label.text = msg.strip_edges()
	next_button.text = "Main Menu"
	_game_over = true
	result_panel.visible = true

func _on_next_pressed() -> void:
	result_panel.visible = false
	if _game_over:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
