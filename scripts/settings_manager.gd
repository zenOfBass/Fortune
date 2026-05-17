extends Node

const SAVE_PATH := "user://settings.cfg"
const CARD_BACK_PATHS: Array[String] = [
	"res://assets/cards/backs/back_of_card.png",
	"res://assets/cards/backs/back_of_card_2.png",
	"res://assets/cards/backs/back_of_card_3.png",
]

var card_back_index: int = 0

func _ready() -> void:
	_load()

func card_back_path() -> String:
	return CARD_BACK_PATHS[card_back_index]

func set_card_back(index: int) -> void:
	card_back_index = clampi(index, 0, CARD_BACK_PATHS.size() - 1)
	_save()

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "card_back", card_back_index)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		card_back_index = clampi(cfg.get_value("display", "card_back", 0), 0, CARD_BACK_PATHS.size() - 1)
