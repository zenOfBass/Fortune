extends PanelContainer

signal suit_chosen(suit_idx: int)

@onready var info_label: Label = $VBox/InfoLabel
@onready var suits_row: HBoxContainer = $VBox/SuitsRow

func _ready() -> void:
	for i in Card.SUIT_DISPLAY.size():
		var btn := Button.new()
		btn.text = Card.SUIT_DISPLAY[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		btn.pressed.connect(func(): suit_chosen.emit(idx))
		suits_row.add_child(btn)

func show_for_player(player_name: String) -> void:
	info_label.text = "%s: guess the suit of your drawn card." % player_name
	visible = true
