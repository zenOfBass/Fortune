class_name CardDisplay
extends TextureRect

signal card_toggled(index: int, selected: bool)

var card_index: int = -1
var card_ref: Card = null
var _selected: bool = false
var _selectable: bool = false
var _tween: Tween = null

func _ready() -> void:
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	expand_mode = TextureRect.EXPAND_KEEP_SIZE
	custom_minimum_size = Vector2(80, 120)
	mouse_filter = MOUSE_FILTER_PASS

func set_card(card: Card, face_up: bool) -> void:
	card_ref = card
	if face_up:
		texture = load(card.texture_path())
	else:
		texture = load(SettingsManager.card_back_path())
	_selected = false
	modulate = Color.WHITE

func set_back() -> void:
	texture = load(SettingsManager.card_back_path())
	_selected = false
	modulate = Color.WHITE

func _exit_tree() -> void:
	if is_instance_valid(_tween):
		_tween.kill()

func deal_from(from_global: Vector2, delay: float, flip: bool = false) -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	var target_pos := position
	position = get_parent().get_global_transform().affine_inverse() * from_global
	modulate.a = 0.0
	var face_tex: Texture2D = null
	if flip:
		face_tex = texture
		texture = load(SettingsManager.card_back_path())
	_tween = create_tween()
	_tween.tween_interval(delay)
	_tween.tween_property(self, "modulate:a", 1.0, 0.06)
	_tween.parallel().tween_property(self, "position", target_pos, 0.40) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if flip:
		_tween.tween_property(self, "scale:x", 0.0, 0.07)
		_tween.tween_callback(func(): texture = face_tex)
		_tween.tween_property(self, "scale:x", 1.0, 0.07)

func animate_in(delay: float, flip: bool = false) -> void:
	if is_instance_valid(_tween):
		_tween.kill()
	if flip and texture != null:
		var face_tex := texture
		texture = load(SettingsManager.card_back_path())
		_tween = create_tween()
		_tween.tween_interval(delay)
		_tween.tween_property(self, "scale:x", 0.0, 0.07)
		_tween.tween_callback(func(): texture = face_tex)
		_tween.tween_property(self, "scale:x", 1.0, 0.07)
	else:
		scale = Vector2(0.8, 0.8)
		modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_interval(delay)
		_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.10)

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
