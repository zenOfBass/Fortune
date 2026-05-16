class_name ArcanaPanel
extends PanelContainer

@onready var arcana_image: TextureRect = $VBox/ArcanaImage
@onready var name_label: Label = $VBox/NameLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var ok_button: Button = $VBox/OkButton

var _is_interactive: bool = false

func _ready() -> void:
	ok_button.pressed.connect(_on_ok)
	visible = false

func show_arcana(arcana_id: int) -> void:
	_load_arcana(arcana_id)
	_is_interactive = true
	ok_button.text = "Continue"
	visible = true

func show_interactive(arcana_id: int) -> void:
	_load_arcana(arcana_id)
	_is_interactive = true
	ok_button.text = "Done"
	visible = true

func is_interactive() -> bool:
	return _is_interactive

func _load_arcana(arcana_id: int) -> void:
	var tex_path := MajorArcana.texture_path(arcana_id)
	if ResourceLoader.exists(tex_path):
		arcana_image.texture = load(tex_path)
	else:
		arcana_image.texture = null
	name_label.text = MajorArcana.arcana_name(arcana_id)
	desc_label.text = MajorArcana.get_desc(arcana_id)

func _on_ok() -> void:
	_is_interactive = false
	visible = false
	GameManager.complete_arcana_effect()
