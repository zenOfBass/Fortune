class_name BetPanel
extends PanelContainer

@onready var info_label: Label = $VBox/InfoLabel
@onready var check_button: Button = $VBox/ButtonRow/CheckButton
@onready var call_button: Button = $VBox/ButtonRow/CallButton
@onready var fold_button: Button = $VBox/ButtonRow/FoldButton
@onready var raise_spin: SpinBox = $VBox/RaiseRow/RaiseSpin
@onready var raise_button: Button = $VBox/RaiseRow/RaiseButton
@onready var all_in_button: Button = $VBox/RaiseRow/AllInButton

func _ready() -> void:
	check_button.pressed.connect(_on_check)
	call_button.pressed.connect(_on_call)
	raise_button.pressed.connect(_on_raise)
	all_in_button.pressed.connect(_on_all_in)
	fold_button.pressed.connect(_on_fold)
	visible = false

func show_betting(current_bet: int, can_check: bool, min_raise: int) -> void:
	var player_chips := GameManager.players[GameManager.HUMAN_IDX].chips
	if current_bet == 0:
		info_label.text = "Your action (no bet yet):"
	else:
		info_label.text = "Current bet: %d" % current_bet
	check_button.visible = can_check
	call_button.visible = not can_check
	call_button.text = "Call (%d)" % current_bet
	raise_spin.min_value = min_raise
	raise_spin.max_value = player_chips
	raise_spin.value = min_raise
	all_in_button.text = "All In (%d)" % player_chips
	all_in_button.visible = player_chips > 0
	visible = true

func hide_betting() -> void:
	visible = false

func _on_check() -> void:
	visible = false
	GameManager.submit_bet("check")

func _on_call() -> void:
	visible = false
	GameManager.submit_bet("call")

func _on_raise() -> void:
	visible = false
	GameManager.submit_bet("raise", int(raise_spin.value))

func _on_all_in() -> void:
	visible = false
	GameManager.submit_bet("raise", 999999)

func _on_fold() -> void:
	visible = false
	GameManager.submit_bet("fold")
