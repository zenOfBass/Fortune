class_name HandDisplay
extends Control

const CardDisplayScene = preload("res://scenes/card_display.tscn")
const CardDisplayGD := preload("res://scenes/card_display.gd")

const _CARD_W := 80
const _CARD_H := 120
const _CARD_GAP := 8

var _max_select: int = 0
var _show_moon_secret: bool = false
var _moon_card: TextureRect = null

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
	if _show_moon_secret:
		_add_moon_card()

func set_back_count(count: int, deal_pos: Vector2 = Vector2.ZERO) -> void:
	_clear()
	var positions := _slot_positions(count)
	for i in count:
		var display: CardDisplayGD = CardDisplayScene.instantiate()
		add_child(display)
		display.position = positions[i]
		display.card_index = i
		display.set_back()
		if deal_pos != Vector2.ZERO:
			display.deal_from(deal_pos, i * 0.10, false)
		else:
			display.animate_in(i * 0.10)
	if _show_moon_secret:
		_add_moon_card()

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
	if _show_moon_secret:
		_add_moon_card()

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

func replace_cards(new_hand: Array, discarded_indices: Array, deal_pos: Vector2, sort_order: Array[int] = []) -> void:
	var kept: Dictionary = {}   # Card → CardDisplayGD
	var to_remove: Array = []
	for child in get_children():
		if child is CardDisplayGD:
			if discarded_indices.has(child.card_index):
				to_remove.append(child)
			elif child.card_ref != null:
				kept[child.card_ref] = child
	for card in to_remove:
		remove_child(card)
		card.queue_free()
	var positions := _slot_positions(new_hand.size())
	var new_slot := 0
	for display_pos in new_hand.size():
		var orig_idx: int = sort_order[display_pos] if not sort_order.is_empty() else display_pos
		var c: Card = new_hand[orig_idx] as Card
		var target_pos := positions[display_pos]
		if kept.has(c):
			kept[c].card_index = orig_idx
			var t: Tween = kept[c].create_tween()
			t.tween_property(kept[c], "position", target_pos, 0.25) \
				.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		else:
			var display: CardDisplayGD = CardDisplayScene.instantiate()
			add_child(display)
			display.position = target_pos
			display.card_index = orig_idx
			display.set_card(c, true)
			display.card_toggled.connect(_on_child_toggled)
			display.deal_from(deal_pos, new_slot * 0.10, true)
			new_slot += 1

# Re-orders existing cards to match a new sort_order, without recreating
# them. Used when arcana like Emperor or Strength change the display sort
# mid-round — cards don't change, only their positions do, so reusing
# set_hand would trigger a second deal animation that looks like a bug.
func resort(hand: Array, sort_order: Array[int]) -> void:
	if get_child_count() == 0 or sort_order.is_empty():
		return
	var positions := _slot_positions(hand.size())
	var by_index: Dictionary = {}
	for child in get_children():
		if child is CardDisplayGD:
			by_index[child.card_index] = child
	for display_pos in hand.size():
		var orig_idx: int = sort_order[display_pos]
		if not by_index.has(orig_idx):
			continue
		var card_disp: CardDisplayGD = by_index[orig_idx]
		var t: Tween = card_disp.create_tween()
		t.tween_property(card_disp, "position", positions[display_pos], 0.25) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

func flip_card_at_index(idx: int, card: Card) -> void:
	for child in get_children():
		if child is CardDisplayGD and child.card_index == idx:
			child.set_card(card, true)
			child.animate_in(0.0, true)
			return

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

func show_moon_secret() -> void:
	_show_moon_secret = true
	_add_moon_card()

func hide_moon_secret() -> void:
	_show_moon_secret = false
	if is_instance_valid(_moon_card):
		_moon_card.queue_free()
	_moon_card = null

func _add_moon_card() -> void:
	if is_instance_valid(_moon_card) or custom_minimum_size == Vector2.ZERO:
		return
	_moon_card = TextureRect.new()
	_moon_card.texture = load(SettingsManager.card_back_path())
	_moon_card.custom_minimum_size = Vector2(_CARD_W, _CARD_H)
	_moon_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_moon_card.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	# 3× gap (not 1×) so the 8° rotation around the top-left pivot doesn't
	# swing the bottom-left corner back over the last hand card.
	_moon_card.position = Vector2(custom_minimum_size.x + _CARD_GAP * 3, 0)
	_moon_card.rotation_degrees = 8.0
	_moon_card.modulate = Color(0.7, 0.7, 1.0, 0.8)
	add_child(_moon_card)

func mark_priestess_card(idx: int) -> void:
	for child in get_children():
		if child is CardDisplayGD and child.card_index == idx:
			child.modulate = Color(1.0, 0.85, 0.3)
			child.position.y -= 8

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_moon_card = null
