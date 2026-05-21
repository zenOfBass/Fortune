extends Control

@onready var title_label:    Label  = $VBox/TitleLabel
@onready var progress_label: Label  = $VBox/ProgressLabel
@onready var match_label:    Label  = $VBox/MatchLabel
@onready var opponents_label: Label = $VBox/OpponentsLabel
@onready var status_label:   Label  = $VBox/StatusLabel
@onready var primary_button: Button = $VBox/PrimaryButton
@onready var abandon_button: Button = $VBox/AbandonButton
@onready var back_button:    Button = $VBox/BackButton

# The roster faced at each ladder index. Mirrors RunManager._LADDER but kept
# here as display strings so the career screen has no coupling to the AI
# profile classes.
const _ROSTERS: Array[Array] = [
	["Tarvosk the Brazen"],
	["Tarvosk the Brazen", "Haldemar the Still"],
	["Tarvosk the Brazen", "Haldemar the Still", "Mercival the Oblique"],
	["Tarvosk the Brazen", "Haldemar the Still", "Mercival the Oblique"],
	["Tarvosk the Brazen", "Haldemar the Still", "Mercival the Oblique"],
]

func _ready() -> void:
	primary_button.pressed.connect(_on_primary)
	abandon_button.pressed.connect(_on_abandon)
	back_button.pressed.connect(_on_back)
	RunManager.run_state_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	title_label.text = "Career"
	var total := RunManager.total_matches()

	if RunManager.run_completed:
		progress_label.text = "Run complete — %d/%d" % [total, total]
		match_label.text = ""
		opponents_label.text = ""
		status_label.text = "You took every table. The Page bows to you."
		primary_button.text = "Start a New Run"
		abandon_button.visible = false
		return

	if RunManager.run_failed:
		progress_label.text = "Run failed at match %d/%d — %s" % [
			RunManager.current_match_number(), total, RunManager.current_match_label()]
		match_label.text = ""
		opponents_label.text = ""
		status_label.text = "The cards turned against you. The deck remembers."
		primary_button.text = "Start a New Run"
		abandon_button.visible = false
		return

	if not RunManager.run_active:
		progress_label.text = "5 matches. Escalating stakes. The opponents remember you between them."
	else:
		progress_label.text = "Run in progress."

	match_label.text = "Match %d/%d — %s" % [
		RunManager.current_match_number(), total, RunManager.current_match_label()]
	opponents_label.text = "Opponents: " + _roster_for(RunManager.match_index)
	status_label.text = ""
	primary_button.text = "Continue" if RunManager.run_active else "Begin Run"
	abandon_button.visible = RunManager.run_active

func _roster_for(idx: int) -> String:
	if idx < 0 or idx >= _ROSTERS.size():
		return ""
	return ", ".join(_ROSTERS[idx])

func _on_primary() -> void:
	if RunManager.run_completed or RunManager.run_failed or not RunManager.run_active:
		RunManager.start_run()
	RunManager.launch_current_match()
	get_tree().change_scene_to_file("res://scenes/game_table.tscn")

func _on_abandon() -> void:
	RunManager.abandon_run()
	_refresh()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
