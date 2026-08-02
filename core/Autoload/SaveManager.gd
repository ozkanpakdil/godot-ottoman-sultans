extends Node

const SAVE_PATH := "user://ottoman_save.dat"
const ENCRYPTION_KEY := "SultanSecretKey1299!"

func save_progress() -> void:
	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, ENCRYPTION_KEY)
	if file:
		var data := {
			"current_chapter_index": GameManager.current_chapter_index,
			"current_sultan_index": GameManager.current_sultan_index,
			"total_study_time": GameManager.total_study_time,
			"score": GameManager.score,
			"completed_quizzes": GameManager.completed_quizzes,
			"locale": GameManager.locale,
			"locale_user_set": GameManager.locale_user_set,
			"music_muted": GameManager.music_muted,
			"sfx_muted": GameManager.sfx_muted,
			"category_stats": GameManager.category_stats,
			"earned_badges": GameManager.earned_badges,
			"level_game_scores": GameManager.level_game_scores
		}
		file.store_var(data)
		file.close()

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, ENCRYPTION_KEY)
	if file:
		var data: Variant = file.get_var()
		file.close()
		if data is Dictionary:
			GameManager.current_chapter_index = data.get("current_chapter_index", 0)
			GameManager.current_sultan_index = data.get("current_sultan_index", 0)
			GameManager.total_study_time = data.get("total_study_time", 0.0)
			GameManager.score = data.get("score", 0)
			GameManager.completed_quizzes = data.get("completed_quizzes", {})
			var loaded_locale: String = data.get("locale", "en")
			GameManager.locale = loaded_locale if loaded_locale in GameManager.SUPPORTED_LOCALES else "en"
			GameManager.locale_user_set = data.get("locale_user_set", false)
			GameManager.music_muted = data.get("music_muted", false)
			GameManager.sfx_muted = data.get("sfx_muted", false)
			GameManager.category_stats = data.get("category_stats", {})
			GameManager.earned_badges = data.get("earned_badges", [])
			GameManager.level_game_scores = data.get("level_game_scores", {})
