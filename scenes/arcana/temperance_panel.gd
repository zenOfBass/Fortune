extends PanelContainer

signal confirmed(flop_idx: int)

const CardDisplayScene = preload("res://scenes/card_display.tscn")
const CardDisplayGD := preload("res://scenes/card_display.gd")

var _selected_flop: int = -1

@onready var info_label: Label = $VBox/InfoLabel
@onready var flop_row: HBoxContainer = $VBox/FlopRow
@onready var confirm_button: Button = $VBox/ConfirmButton

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm)

func show_for_player(player_name: String, flop: Array) -> void:
	info_label.text = "%s: select a hand card to discard and a flop card to take." % player_name
	_selected_flop = -1
	for child in flop_row.get_children():
		child.queue_free()
	for i in flop.size():
		var display: CardDisplayGD = CardDisplayScene.instantiate()
		flop_row.add_child(display)
		display.card_index = i
		display.set_card(flop[i] as Card, true)
		display.set_selectable(true)
		var idx := i
		display.card_toggled.connect(func(_ci, sel): _on_flop_toggled(idx, sel))
	visible = true

func _on_flop_toggled(idx: int, selected: bool) -> void:
	if selected:
		_selected_flop = idx
		for child in flop_row.get_children():
			if child is CardDisplayGD and child.card_index != idx:
				child.deselect()
	elif _selected_flop == idx:
		_selected_flop = -1

func _on_confirm() -> void:
	if _selected_flop < 0:
		return
	confirmed.emit(_selected_flop)
