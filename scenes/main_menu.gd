extends Control

@onready var player_count_spin: SpinBox = $VBox/PlayerCountRow/PlayerCountSpin
@onready var chips_spin: SpinBox = $VBox/ChipsRow/ChipsSpin
@onready var ante_spin: SpinBox = $VBox/AnteRow/AnteSpin
@onready var arcana_option: OptionButton = $VBox/ArcanaRow/ArcanaOption
@onready var start_button: Button = $VBox/StartButton

func _ready() -> void:
	arcana_option.add_item("Random (normal)")
	for i in range(22):
		arcana_option.add_item("%d — %s" % [i, MajorArcana.arcana_name(i)])
	start_button.pressed.connect(_on_start)

func _on_start() -> void:
	var num_players := int(player_count_spin.value)
	var starting_chips := int(chips_spin.value)
	var ante := int(ante_spin.value)
	var arcana_id := arcana_option.selected - 1  # 0 = Random, 1–22 = arcana IDs 0–21
	GameManager.setup_game(num_players, starting_chips, ante, arcana_id)
	get_tree().change_scene_to_file("res://scenes/game_table.tscn")
