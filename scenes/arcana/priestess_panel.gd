extends PanelContainer

signal confirmed()

@onready var info_label: Label = $VBox/InfoLabel
@onready var confirm_button: Button = $VBox/ConfirmButton

func _ready() -> void:
	confirm_button.pressed.connect(func(): confirmed.emit())

func show_for_player(player_name: String) -> void:
	info_label.text = "%s: select one card to reveal face-up for the round." % player_name
	visible = true
