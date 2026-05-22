class_name BetPanel
extends PanelContainer

@onready var info_label:   Label  = $VBox/InfoLabel
@onready var raise_label:  Label  = $VBox/RaiseLabel
@onready var incr_row:     HBoxContainer = $VBox/IncrRow
@onready var plus1_button: Button = $VBox/IncrRow/Plus1Button
@onready var plus5_button: Button = $VBox/IncrRow/Plus5Button
@onready var plus10_button: Button = $VBox/IncrRow/Plus10Button
@onready var plus25_button: Button = $VBox/IncrRow/Plus25Button
@onready var min_button:   Button = $VBox/IncrRow/MinButton
@onready var check_button: Button = $VBox/ActionRow/CheckButton
@onready var call_button:  Button = $VBox/ActionRow/CallButton
@onready var raise_button: Button = $VBox/ActionRow/RaiseButton
@onready var all_in_button: Button = $VBox/ActionRow/AllInButton
@onready var fold_button:  Button = $VBox/ActionRow/FoldButton

var _raise_amount: int = 1
var _min_raise:    int = 1
var _max_raise:    int = 1

func _ready() -> void:
	check_button.pressed.connect(_on_check)
	call_button.pressed.connect(_on_call)
	raise_button.pressed.connect(_on_raise)
	all_in_button.pressed.connect(_on_all_in)
	fold_button.pressed.connect(_on_fold)
	plus1_button.pressed.connect(func(): _increment(1))
	plus5_button.pressed.connect(func(): _increment(5))
	plus10_button.pressed.connect(func(): _increment(10))
	plus25_button.pressed.connect(func(): _increment(25))
	min_button.pressed.connect(_reset_raise)
	visible = false

func show_betting(current_bet: int, can_check: bool, min_raise: int, opponents_have_chips: bool = true) -> void:
	var player_chips := GameManager.players[GameManager.HUMAN_IDX].chips
	_min_raise = min_raise
	_max_raise = player_chips
	_raise_amount = min_raise

	if current_bet == 0:
		info_label.text = "Your action:"
	else:
		info_label.text = "Current bet: %d" % current_bet

	check_button.visible = can_check
	call_button.visible = not can_check
	call_button.text = "Call (%d)" % current_bet

	# Raising above the current bet only matters if at least one opponent has
	# chips to call with — otherwise the excess gets refunded as an unmatched
	# overbet. Hide the raise controls entirely in that case.
	var can_raise := player_chips >= min_raise and opponents_have_chips
	raise_label.visible = can_raise
	incr_row.visible = can_raise
	raise_button.visible = can_raise

	all_in_button.text = "All In (%d)" % player_chips
	all_in_button.visible = player_chips > 0 and opponents_have_chips

	_update_raise_label()
	visible = true

func hide_betting() -> void:
	visible = false

func _increment(amount: int) -> void:
	_raise_amount = mini(_raise_amount + amount, _max_raise)
	_update_raise_label()

func _reset_raise() -> void:
	_raise_amount = _min_raise
	_update_raise_label()

func _update_raise_label() -> void:
	raise_label.text = "Raise to: %d" % _raise_amount

func _on_check() -> void:
	visible = false
	GameManager.submit_bet("check")

func _on_call() -> void:
	visible = false
	GameManager.submit_bet("call")

func _on_raise() -> void:
	visible = false
	GameManager.submit_bet("raise", _raise_amount)

func _on_all_in() -> void:
	visible = false
	GameManager.submit_bet("raise", 999999)

func _on_fold() -> void:
	visible = false
	GameManager.submit_bet("fold")
