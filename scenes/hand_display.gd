class_name HandDisplay
extends HBoxContainer

const CardDisplayScene = preload("res://scenes/card_display.tscn")
const CardDisplayGD := preload("res://scenes/card_display.gd")

var _max_select: int = 0  # 0 = unlimited

func set_hand(hand: Array, face_up: bool, sort_order: Array[int] = []) -> void:
	_clear()
	for display_pos in hand.size():
		var orig_idx: int = sort_order[display_pos] if not sort_order.is_empty() else display_pos
		var display: CardDisplayGD = CardDisplayScene.instantiate()
		add_child(display)
		display.card_index = orig_idx
		display.set_card(hand[orig_idx] as Card, face_up)
		display.card_toggled.connect(_on_child_toggled)
		display.animate_in(display_pos * 0.12, face_up)

func set_back_count(count: int) -> void:
	_clear()
	for i in count:
		var display: CardDisplayGD = CardDisplayScene.instantiate()
		add_child(display)
		display.set_back()
		display.animate_in(i * 0.10)

func set_selectable(selectable: bool, max_select: int = 0) -> void:
	_max_select = max_select
	for child in get_children():
		if child is CardDisplayGD:
			child.set_selectable(selectable)

func set_hand_mixed(hand: Array, face_up_indices: Array) -> void:
	_clear()
	for i in hand.size():
		var display: CardDisplayGD = CardDisplayScene.instantiate()
		add_child(display)
		display.card_index = i
		var is_face_up := i in face_up_indices
		if is_face_up:
			display.set_card(hand[i] as Card, true)
		else:
			display.set_back()
		display.card_toggled.connect(_on_child_toggled)
		display.animate_in(i * 0.12, is_face_up)

func _on_child_toggled(index: int, selected: bool) -> void:
	if _max_select <= 0 or not selected:
		return
	for child in get_children():
		if child is CardDisplayGD and child.card_index != index:
			child.deselect()

func get_selected_indices() -> Array[int]:
	var indices: Array[int] = []
	for child in get_children():
		if child is CardDisplayGD and child.is_selected():
			indices.append(child.card_index)
	return indices

func clear_selection() -> void:
	for child in get_children():
		if child is CardDisplayGD:
			child.deselect()

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
