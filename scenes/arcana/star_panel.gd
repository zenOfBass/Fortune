extends PanelContainer

signal swap_chosen()
signal pass_chosen()

@onready var info_label: Label = $VBox/InfoLabel
@onready var swap_button: Button = $VBox/ButtonRow/SwapButton
@onready var pass_button: Button = $VBox/ButtonRow/PassButton

func _ready() -> void:
	swap_button.pressed.connect(func(): swap_chosen.emit())
	pass_button.pressed.connect(func(): pass_chosen.emit())

func show_for_player(player_name: String) -> void:
	info_label.text = "%s: select a card to swap with the top of the deck, or pass." % player_name
	visible = true
