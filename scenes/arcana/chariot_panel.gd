extends PanelContainer

signal confirmed()

@onready var info_label: Label = $VBox/InfoLabel
@onready var confirm_button: Button = $VBox/ConfirmButton

func _ready() -> void:
	confirm_button.pressed.connect(_on_confirm)

func show_for_player(player_name: String) -> void:
	info_label.text = "%s: click one card in your hand, then press Pass Card." % player_name
	visible = true

func _on_confirm() -> void:
	confirmed.emit()
