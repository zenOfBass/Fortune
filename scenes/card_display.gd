class_name CardDisplay
extends TextureRect

signal card_toggled(index: int, selected: bool)

var card_index: int = -1
var _selected: bool = false
var _selectable: bool = false

func _ready() -> void:
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	expand_mode = TextureRect.EXPAND_KEEP_SIZE
	custom_minimum_size = Vector2(80, 120)
	mouse_filter = MOUSE_FILTER_PASS

func set_card(card: Card, face_up: bool) -> void:
	if face_up:
		texture = load(card.texture_path())
	else:
		texture = load("res://assets/cards/backs/back_of_card.png")
	_selected = false
	modulate = Color.WHITE

func set_back() -> void:
	texture = load("res://assets/cards/backs/back_of_card.png")
	_selected = false
	modulate = Color.WHITE

func animate_in(delay: float, flip: bool = false) -> void:
	if flip and texture != null:
		var face_tex := texture
		texture = load("res://assets/cards/backs/back_of_card.png")
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(self, "scale:x", 0.0, 0.07)
		tween.tween_callback(func(): texture = face_tex)
		tween.tween_property(self, "scale:x", 1.0, 0.07)
	else:
		scale = Vector2(0.8, 0.8)
		modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(self, "modulate:a", 1.0, 0.10)

func set_selectable(selectable: bool) -> void:
	_selectable = selectable
	mouse_filter = MOUSE_FILTER_STOP if selectable else MOUSE_FILTER_PASS

func is_selected() -> bool:
	return _selected

func deselect() -> void:
	_selected = false
	modulate = Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if not _selectable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_selected = not _selected
		modulate = Color(0.5, 0.5, 1.0) if _selected else Color.WHITE
		card_toggled.emit(card_index, _selected)
		accept_event()
