extends PanelContainer

signal reenter_chosen()
signal pass_chosen()

@onready var info_label: Label = $VBox/InfoLabel
@onready var reenter_button: Button = $VBox/ButtonRow/ReenterButton
@onready var pass_button: Button = $VBox/ButtonRow/PassButton

func _ready() -> void:
	reenter_button.pressed.connect(func(): reenter_chosen.emit())
	pass_button.pressed.connect(func(): pass_chosen.emit())

func show_for_player(player_name: String, ante: int) -> void:
	info_label.text = "%s: pay %d chips to re-enter with a fresh hand?" % [player_name, ante]
	visible = true
