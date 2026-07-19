extends Node

# Current progress indices
var current_chapter_index: int = 0
var current_sultan_index: int = 0

# Time and score
var total_study_time: float = 0.0
var score: int = 0
var completed_quizzes: Dictionary = {}

# i18n
var locale: String = "en"
const SUPPORTED_LOCALES := ["en", "tr", "zh", "ru", "es"]

# Quiz bonus constants
const CORRECT_ANSWER_BONUS: int = 50
const TIME_POINTS_INTERVAL: float = 10.0

# Signals
signal study_time_updated(new_time: float)
signal score_updated(new_score: int)
signal progress_changed(chapter_index: int, sultan_index: int)
signal quiz_completed(chapter_id: int, result: Dictionary)
signal locale_changed(new_locale: String)

func _ready() -> void:
	_load_translation_resources()
	SaveManager.load_progress()
	_apply_locale()
	_configure_desktop_display()

func _load_translation_resources() -> void:
	# Godot's project-setting translations are not always loaded in headless or
	# exported runs. Load the compiled .translation resources explicitly so tr()
	# works everywhere (editor, CI, exported builds).
	var paths := [
		"res://assets/i18n/ui_translations.en.translation",
		"res://assets/i18n/ui_translations.tr.translation",
		"res://assets/i18n/ui_translations.zh.translation",
		"res://assets/i18n/ui_translations.ru.translation",
		"res://assets/i18n/ui_translations.es.translation",
	]
	for path in paths:
		var res := ResourceLoader.load(path, "Translation")
		if res is Translation:
			TranslationServer.add_translation(res)
		else:
			push_warning("Failed to load translation resource: %s" % path)

func _configure_desktop_display() -> void:
	# Only apply on desktop platforms (Windows, macOS, Linux/BSD).
	var desktop_os := ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]
	if not (OS.get_name() in desktop_os):
		return

	# Full-screen on desktop so the mobile-portrait UI fills the monitor.
	# canvas_items + expand stretch mode scales menus and text automatically.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _process(delta: float) -> void:
	# Continuously track learning time in seconds
	total_study_time += delta
	study_time_updated.emit(total_study_time)

func set_locale(code: String) -> void:
	var lang := code.split("_")[0]
	if lang in SUPPORTED_LOCALES:
		locale = lang
		TranslationServer.set_locale(lang)
		locale_changed.emit(lang)
		SaveManager.save_progress()

func _apply_locale() -> void:
	if not (locale in SUPPORTED_LOCALES):
		var os_lang := OS.get_locale_language()
		locale = os_lang if os_lang in SUPPORTED_LOCALES else "en"
	TranslationServer.set_locale(locale)

func set_progress(chapter_index: int, sultan_index: int) -> void:
	current_chapter_index = chapter_index
	current_sultan_index = sultan_index
	progress_changed.emit(chapter_index, sultan_index)
	SaveManager.save_progress()

func advance_sultan() -> bool:
	var db := HistoricalData.get_data()
	var chapter = db["chapters"][current_chapter_index]
	if current_sultan_index + 1 < chapter["sultans"].size():
		current_sultan_index += 1
	else:
		return false
	progress_changed.emit(current_chapter_index, current_sultan_index)
	SaveManager.save_progress()
	return true

func retreat_sultan() -> bool:
	if current_sultan_index > 0:
		current_sultan_index -= 1
		progress_changed.emit(current_chapter_index, current_sultan_index)
		SaveManager.save_progress()
		return true
	return false

func get_current_sultan() -> Dictionary:
	var db := HistoricalData.get_data()
	var chapter = db["chapters"][current_chapter_index]
	return chapter["sultans"][current_sultan_index]

func get_current_chapter() -> Dictionary:
	var db := HistoricalData.get_data()
	return db["chapters"][current_chapter_index]

func mark_quiz_completed(chapter_id: int, correct_answers: int, total_questions: int) -> void:
	completed_quizzes[chapter_id] = {
		"correct": correct_answers,
		"total": total_questions,
		"timestamp": Time.get_unix_time_from_system()
	}
	var bonus := correct_answers * CORRECT_ANSWER_BONUS
	calculate_score(bonus)
	quiz_completed.emit(chapter_id, completed_quizzes[chapter_id])
	SaveManager.save_progress()

func calculate_score(quiz_points: int) -> void:
	# 1 point per 10 seconds learned + quiz rewards
	var time_points := int(total_study_time / TIME_POINTS_INTERVAL)
	score = time_points + quiz_points
	score_updated.emit(score)
	update_game_center()

func update_game_center() -> void:
	# Interface with Godot iOS GameCenter / Android Play Games plugin
	if Engine.has_singleton("GameCenter"):
		var gc = Engine.get_singleton("GameCenter")
		gc.submit_score({
			"score": score,
			"leaderboard_id": "com.ottoman.timeline.highscore"
		})
	elif Engine.has_singleton("GodotPlayGamesServices"):
		var pgs = Engine.get_singleton("GodotPlayGamesServices")
		if pgs.has_method("leaderboards_submit_score"):
			pgs.leaderboards_submit_score("com.ottoman.timeline.highscore", score)
