extends Node

# Current progress indices
var current_chapter_index: int = 0
var current_sultan_index: int = 0

# Time and score
var total_study_time: float = 0.0
var score: int = 0
var completed_quizzes: Dictionary = {}
var level_game_scores: Dictionary = {}

# Mini-game routing context set before pushing ArcheryGame/CannonGame.
var mini_game_context: Dictionary = {}

const MINI_GAME_ARCHERY := "archery"
const MINI_GAME_CANNON := "cannon"

# i18n
var locale: String = "en"
var locale_user_set: bool = false
const SUPPORTED_LOCALES := ["en", "tr", "zh", "ru", "es"]

# Audio
var music_muted: bool = false
var sfx_muted: bool = false

# Category mastery badges
var category_stats: Dictionary = {}
var earned_badges: Array = []
const CATEGORIES := ["war", "diplomacy", "family", "chronology"]
const BADGE_THRESHOLDS := [3, 8, 15, 25]
const BADGE_TITLES := {
	"war": ["UI_BADGE_WAR_1", "UI_BADGE_WAR_2", "UI_BADGE_WAR_3", "UI_BADGE_WAR_4"],
	"diplomacy": ["UI_BADGE_DIPLOMACY_1", "UI_BADGE_DIPLOMACY_2", "UI_BADGE_DIPLOMACY_3", "UI_BADGE_DIPLOMACY_4"],
	"family": ["UI_BADGE_FAMILY_1", "UI_BADGE_FAMILY_2", "UI_BADGE_FAMILY_3", "UI_BADGE_FAMILY_4"],
	"chronology": ["UI_BADGE_CHRONOLOGY_1", "UI_BADGE_CHRONOLOGY_2", "UI_BADGE_CHRONOLOGY_3", "UI_BADGE_CHRONOLOGY_4"]
}
const CATEGORY_ICONS := {
	"war": "⚔️",
	"diplomacy": "🕊️",
	"family": "👑",
	"chronology": "⏳"
}

# Quiz bonus constants
const CORRECT_ANSWER_BONUS: int = 50
const TIME_POINTS_INTERVAL: float = 10.0

# Signals
signal study_time_updated(new_time: float)
signal score_updated(new_score: int)
signal progress_changed(chapter_index: int, sultan_index: int)
signal quiz_completed(chapter_id: int, result: Dictionary)
signal locale_changed(new_locale: String)
signal badge_earned(badge_id: String)

func _ready() -> void:
	_load_translation_resources()
	SaveManager.load_progress()
	# Never inherit a non-English locale from an old/corrupt save unless the user
	# explicitly chose it. This prevents the game from auto-switching to Chinese
	# or any other language on startup.
	if not locale_user_set:
		locale = "en"
	_apply_locale()
	print("Locale resolved: %s (user_set=%s)" % [locale, locale_user_set])
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
		locale_user_set = true
		TranslationServer.set_locale(lang)
		locale_changed.emit(lang)
		SaveManager.save_progress()

func _apply_locale() -> void:
	# Always fall back to English for invalid/missing saved locales so the game
	# never switches to an unintended language on its own.
	if not (locale in SUPPORTED_LOCALES):
		locale = "en"
	TranslationServer.set_locale(locale)
	SaveManager.save_progress()

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
	# 1 point per 10 seconds learned + quiz rewards + mini-games
	var time_points := int(total_study_time / TIME_POINTS_INTERVAL)
	var game_points := get_total_mini_game_score()
	score = time_points + quiz_points + game_points
	score_updated.emit(score)
	update_game_center()

func get_total_mini_game_score() -> int:
	var total := 0
	for chapter_scores in level_game_scores.values():
		if chapter_scores is Dictionary:
			for value in chapter_scores.values():
				if value is int:
					total += value
	return total

func record_mini_game_score(game_mode: String, chapter_index: int, game_score: int) -> void:
	if not level_game_scores.has(chapter_index):
		level_game_scores[chapter_index] = {}
	var chapter_scores: Dictionary = level_game_scores[chapter_index]
	# Keep the best score for each mode per chapter.
	var current: int = chapter_scores.get(game_mode, 0)
	chapter_scores[game_mode] = max(current, game_score)
	calculate_score(0)
	SaveManager.save_progress()

func set_mini_game_context(mode: String, chapter_index: int, sultan_index: int, return_scene: String) -> void:
	mini_game_context = {
		"mode": mode,
		"chapter_index": chapter_index,
		"sultan_index": sultan_index,
		"return_scene": return_scene,
	}

func clear_mini_game_context() -> void:
	mini_game_context = {}

func toggle_sfx_mute() -> bool:
	sfx_muted = not sfx_muted
	SaveManager.save_progress()
	return sfx_muted

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

func record_category_answer(category: String, correct: bool) -> void:
	if not (category in CATEGORIES):
		return
	if not category_stats.has(category):
		category_stats[category] = {"correct": 0, "total": 0}
	category_stats[category]["total"] += 1
	if correct:
		category_stats[category]["correct"] += 1

func check_and_award_badges() -> Array:
	var newly_earned: Array = []
	for category in CATEGORIES:
		var stats: Dictionary = category_stats.get(category, {"correct": 0, "total": 0})
		var correct: int = stats.get("correct", 0)
		for i in BADGE_THRESHOLDS.size():
			var badge_id: String = BADGE_TITLES[category][i]
			if correct >= BADGE_THRESHOLDS[i] and not (badge_id in earned_badges):
				earned_badges.append(badge_id)
				newly_earned.append(badge_id)
				badge_earned.emit(badge_id)
	if not newly_earned.is_empty():
		SaveManager.save_progress()
	return newly_earned

func get_category_badge_level(category: String) -> int:
	if not (category in CATEGORIES):
		return -1
	var stats: Dictionary = category_stats.get(category, {"correct": 0, "total": 0})
	var correct: int = stats.get("correct", 0)
	var level := -1
	for i in BADGE_THRESHOLDS.size():
		if correct >= BADGE_THRESHOLDS[i]:
			level = i
	return level

func get_badge_display_name(badge_id: String) -> String:
	return tr(badge_id)

func get_category_display_name(category: String) -> String:
	return tr("UI_CATEGORY_" + category.to_upper())
