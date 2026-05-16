extends Control

@onready var player_count_spin: SpinBox = $VBox/PlayerCountRow/PlayerCountSpin
@onready var chips_spin: SpinBox = $VBox/ChipsRow/ChipsSpin
@onready var ante_spin: SpinBox = $VBox/AnteRow/AnteSpin
@onready var start_button: Button = $VBox/StartButton

func _ready() -> void:
	start_button.pressed.connect(_on_start)

func _on_start() -> void:
	var num_players := int(player_count_spin.value)
	var starting_chips := int(chips_spin.value)
	var ante := int(ante_spin.value)
	GameManager.setup_game(num_players, starting_chips, ante)
	get_tree().change_scene_to_file("res://scenes/game_table.tscn")
