class_name HandDisplay
extends Control

const CardDisplayScene = preload("res://scenes/card_display.tscn")
const CardDisplayGD := preload("res://scenes/card_display.gd")

const _CARD_W := 80
const _CARD_H := 120
const _CARD_GAP := 8

var _max_select: int = 0

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func set_hand(hand: Array, face_up: bool, sort_order: Array[int] = [], deal_pos: Vector2 = Vector2.ZERO) -> void:
	_clear()
	var positions := _slot_positions(hand.size())
	for display_pos in hand.size():
		var orig_idx: int = sort_order[display_pos] if not sort_order.is_empty() else display_pos
		var display: CardDisplayGD = CardDisplayScene.instantiate()
		add_child(display)
		display.position = positions[display_pos]
		display.card_index = orig_idx
		display.set_card(hand[orig_idx] as Card, face_up)
		display.card_toggled.connect(_on_child_toggled)
		if deal_pos != Vector2.ZERO:
			display.deal_from(deal_pos, display_pos * 0.10, face_up)
		else:
			display.animate_in(display_pos * 0.12, face_up)

func set_back_count(count: int, deal_pos: Vector2 = Vector2.ZERO) -> void:
	_clear()
	var positions := _slot_positions(count)
	for i in count:
		var display: CardDisplayGD = CardDisplayScene.instantiate()
		add_child(display)
		display.position = positions[i]
		display.set_back()
		if deal_pos != Vector2.ZERO:
			display.deal_from(deal_pos, i * 0.10, false)
		else:
			display.animate_in(i * 0.10)

func set_hand_mixed(hand: Array, face_up_indices: Array) -> void:
	_clear()
	var positions := _slot_positions(hand.size())
	for i in hand.size():
		var display: CardDisplayGD = CardDisplayScene.instantiate()
		add_child(display)
		display.position = positions[i]
		display.card_index = i
		var is_face_up := i in face_up_indices
		if is_face_up:
			display.set_card(hand[i] as Card, true)
		else:
			display.set_back()
		display.card_toggled.connect(_on_child_toggled)
		display.animate_in(i * 0.12, is_face_up)

func _slot_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count == 0:
		custom_minimum_size = Vector2.ZERO
		return positions
	var content_w := count * _CARD_W + (count - 1) * _CARD_GAP
	custom_minimum_size = Vector2(content_w, _CARD_H)
	size = custom_minimum_size
	for i in count:
		positions.append(Vector2(i * (_CARD_W + _CARD_GAP), 0.0))
	return positions

func replace_cards(new_hand: Array, discarded_indices: Array, deal_pos: Vector2) -> void:
	# Separate kept displays (by card identity) from discarded ones.
	var kept: Dictionary = {}   # Card → CardDisplayGD
	var vacated_x: Array[float] = []
	var to_remove: Array = []
	for child in get_children():
		if child is CardDisplayGD:
			if discarded_indices.has(child.card_index):
				vacated_x.append(child.position.x)
				to_remove.append(child)
			elif child.card_ref != null:
				kept[child.card_ref] = child
	vacated_x.sort()
	for card in to_remove:
		remove_child(card)
		card.queue_free()
	# Update kept cards' indices and fly in new cards at the vacated slots.
	var new_slot := 0
	for i in new_hand.size():
		var c: Card = new_hand[i] as Card
		if kept.has(c):
			kept[c].card_index = i
		else:
			var display: CardDisplayGD = CardDisplayScene.instantiate()
			add_child(display)
			display.position = Vector2(vacated_x[new_slot] if new_slot < vacated_x.size() else 0.0, 0.0)
			display.card_index = i
			display.set_card(c, true)
			display.card_toggled.connect(_on_child_toggled)
			display.deal_from(deal_pos, new_slot * 0.10, true)
			new_slot += 1

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
