extends Control

@onready var score_label: Label = %ScoreLabel
@onready var time_label: Label = %TimeLabel
@onready var completion_list: VBoxContainer = %CompletionList
@onready var complete_label: Label = %CompleteLabel
@onready var native_board_button: Button = %NativeBoardButton

func _ready() -> void:
	%TitleLabel.text = tr("UI_LEADERBOARD_TITLE")
	score_label.text = tr("UI_TOTAL_SCORE") % GameManager.score
	time_label.text = tr("UI_TOTAL_TIME") % TimeTracker.format_time(GameManager.total_study_time)
	_build_completion_list()
	%BackButton.text = tr("UI_BACK_TO_MENU")
	native_board_button.text = tr("UI_OPEN_NATIVE_LEADERBOARD")
	%BackButton.pressed.connect(_on_back_pressed)
	native_board_button.visible = Engine.has_singleton("GameCenter") or Engine.has_singleton("GodotPlayGamesServices")
	native_board_button.pressed.connect(_on_native_board_pressed)

func _build_completion_list() -> void:
	var all_done := true
	for chapter in HistoricalData.get_chapters():
		var entry := Label.new()
		var quiz: Dictionary = GameManager.completed_quizzes.get(chapter["id"], {})
		var chapter_line: String = tr("UI_CHAPTER_TITLE") % [chapter["id"], HistoricalData.localize(chapter["title"]), chapter["years"]]
		if quiz.is_empty():
			entry.text = "• " + chapter_line + " — " + tr("UI_TEST_NOT_COMPLETED")
			all_done = false
		else:
			entry.text = "• " + chapter_line + " — " + tr("UI_X_OF_Y_CORRECT") % [quiz["correct"], quiz["total"]]
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		completion_list.add_child(entry)
	complete_label.text = tr("UI_JOURNEY_COMPLETE")
	complete_label.visible = all_done and not HistoricalData.get_chapters().is_empty()

func _on_native_board_pressed() -> void:
	if Engine.has_singleton("GameCenter"):
		var gc = Engine.get_singleton("GameCenter")
		if gc.has_method("show_game_center"):
			gc.show_game_center()
	elif Engine.has_singleton("GodotPlayGamesServices"):
		var pgs = Engine.get_singleton("GodotPlayGamesServices")
		if pgs.has_method("leaderboards_show"):
			pgs.leaderboards_show("com.ottoman.timeline.highscore")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu/MainMenu.tscn")
