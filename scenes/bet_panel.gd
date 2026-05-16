class_name BetPanel
extends PanelContainer

@onready var info_label: Label = $VBox/InfoLabel
@onready var check_button: Button = $VBox/ButtonRow/CheckButton
@onready var call_button: Button = $VBox/ButtonRow/CallButton
@onready var fold_button: Button = $VBox/ButtonRow/FoldButton
@onready var raise_spin: SpinBox = $VBox/RaiseRow/RaiseSpin
@onready var raise_button: Button = $VBox/RaiseRow/RaiseButton

func _ready() -> void:
	check_button.pressed.connect(_on_check)
	call_button.pressed.connect(_on_call)
	raise_button.pressed.connect(_on_raise)
	fold_button.pressed.connect(_on_fold)
	visible = false

func show_betting(current_bet: int, can_check: bool, min_raise: int) -> void:
	if current_bet == 0:
		info_label.text = "Your action (no bet yet):"
	else:
		info_label.text = "Current bet: %d" % current_bet
	check_button.visible = can_check
	call_button.visible = not can_check
	call_button.text = "Call (%d)" % current_bet
	raise_spin.min_value = min_raise
	raise_spin.max_value = 9999
	raise_spin.value = min_raise
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

func _on_fold() -> void:
	visible = false
	GameManager.submit_bet("fold")
