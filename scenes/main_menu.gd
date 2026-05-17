extends Control

@onready var player_count_spin: SpinBox = $VBox/PlayerCountRow/PlayerCountSpin
@onready var chips_spin: SpinBox = $VBox/ChipsRow/ChipsSpin
@onready var ante_spin: SpinBox = $VBox/AnteRow/AnteSpin
@onready var arcana_option: OptionButton = $VBox/ArcanaRow/ArcanaOption
@onready var start_button: Button = $VBox/StartButton

var _back_btns: Array = []

func _ready() -> void:
	_back_btns = [
		$VBox/CardBackRow/Back0Btn,
		$VBox/CardBackRow/Back1Btn,
		$VBox/CardBackRow/Back2Btn,
	]
	for i in _back_btns.size():
		_back_btns[i].texture_normal = load(SettingsManager.CARD_BACK_PATHS[i])
		var idx := i
		_back_btns[i].pressed.connect(func(): _on_back_selected(idx))
	_refresh_back_highlight()

	arcana_option.add_item("Random (normal)")
	for i in range(22):
		arcana_option.add_item("%d — %s" % [i, MajorArcana.arcana_name(i)])
	start_button.pressed.connect(_on_start)

func _on_back_selected(index: int) -> void:
	SettingsManager.set_card_back(index)
	_refresh_back_highlight()

func _refresh_back_highlight() -> void:
	for i in _back_btns.size():
		_back_btns[i].modulate = Color.WHITE if i == SettingsManager.card_back_index else Color(0.55, 0.55, 0.55)

func _on_start() -> void:
	var num_players := clampi(player_count_spin.get_line_edit().text.to_int(), 2, 4)
	var starting_chips := clampi(chips_spin.get_line_edit().text.to_int(), 10, 10000)
	var ante := clampi(ante_spin.get_line_edit().text.to_int(), 1, 100)
	var arcana_id := arcana_option.selected - 1  # 0 = Random, 1–22 = arcana IDs 0–21
	GameManager.setup_game(num_players, starting_chips, ante, arcana_id)
	get_tree().change_scene_to_file("res://scenes/game_table.tscn")
