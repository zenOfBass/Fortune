class_name HandDisplay
extends HBoxContainer

const CardDisplayScene = preload("res://scenes/card_display.tscn")
const CardDisplayGD := preload("res://scenes/card_display.gd")

var _max_select: int = 0  # 0 = unlimited

func set_hand(hand: Array, face_up: bool) -> void:
	_clear()
	for i in hand.size():
		var display: CardDisplayGD = CardDisplayScene.instantiate()
		add_child(display)
		display.card_index = i
		display.set_card(hand[i] as Card, face_up)
		display.card_toggled.connect(_on_child_toggled)

func set_back_count(count: int) -> void:
	_clear()
	for _i in count:
		var display: CardDisplayGD = CardDisplayScene.instantiate()
		add_child(display)
		display.set_back()

func set_selectable(selectable: bool, max_select: int = 0) -> void:
	_max_select = max_select
	for child in get_children():
		if child is CardDisplayGD:
			child.set_selectable(selectable)

func _on_child_toggled(index: int, selected: bool) -> void:
	if _max_select <= 0 or not selected:
		return
	for child in get_children():
		if child is CardDisplayGD and child.card_index != index:
			child.deselect()

func get_selected_indices() -> Array[int]:
	var indices: Array[int] = []
	var i := 0
	for child in get_children():
		if child is CardDisplayGD:
			if child.is_selected():
				indices.append(i)
			i += 1
	return indices

func clear_selection() -> void:
	for child in get_children():
		if child is CardDisplayGD:
			child.deselect()

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
