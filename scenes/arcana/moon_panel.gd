extends PanelContainer

signal phase1_confirmed()
signal swap_chosen()
signal keep_chosen()

@onready var info_label: Label = $VBox/InfoLabel
@onready var card_thumb: TextureRect = $VBox/CardThumb
@onready var ok_button: Button = $VBox/OKButton
@onready var button_row: HBoxContainer = $VBox/ButtonRow
@onready var swap_button: Button = $VBox/ButtonRow/SwapButton
@onready var keep_button: Button = $VBox/ButtonRow/KeepButton

func _ready() -> void:
	ok_button.pressed.connect(func(): phase1_confirmed.emit())
	swap_button.pressed.connect(func(): swap_chosen.emit())
	keep_button.pressed.connect(func(): keep_chosen.emit())

func show_reveal(card: Card, player_name: String) -> void:
	info_label.text = "%s draws a secret card — only you can see it." % player_name
	_load_card(card)
	ok_button.visible = true
	button_row.visible = false
	visible = true

func show_swap(card: Card, player_name: String) -> void:
	info_label.text = "%s: select a hand card to swap with your Moon secret, or keep your hand." % player_name
	_load_card(card)
	ok_button.visible = false
	button_row.visible = true
	visible = true

func _load_card(card: Card) -> void:
	var tex_path := card.texture_path()
	card_thumb.texture = load(tex_path) if ResourceLoader.exists(tex_path) else null
