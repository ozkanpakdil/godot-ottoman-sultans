extends Control

# Headless functional test: validates the database, translations, portraits, audio, quizzes, scoring, and save/load.
# Run with: godot --headless --path . res://test_runner.tscn

func _check_locale_dict(parent: Dictionary, key: String, ctx: String) -> int:
	var value: Variant = parent.get(key)
	if value is Dictionary:
		var expected := PackedStringArray(["en", "tr", "zh", "ru", "es"])
		for k in expected:
			if not value.has(k):
				print("FAIL: %s.%s missing locale %s" % [ctx, key, k])
				return 1
	else:
		print("FAIL: %s.%s is not a locale dict" % [ctx, key])
		return 1
	return 0

func _ready() -> void:
	var failures := 0
	var chapters := HistoricalData.get_chapters()
	print("Chapters loaded: %d" % chapters.size())
	if chapters.size() != 5:
		print("FAIL: expected 5 chapters, got %d" % chapters.size())
		failures += 1

	# Structural checks: every localized field has all 5 languages and every portrait file exists.
	var portraits_dir := ProjectSettings.globalize_path("res://assets/sultans/")
	for chapter in chapters:
		failures += _check_locale_dict(chapter, "title", "chapter %d" % chapter["id"])
		failures += _check_locale_dict(chapter, "description", "chapter %d" % chapter["id"])
		for sultan in chapter["sultans"]:
			var slug: String = sultan.get("slug", "")
			failures += _check_locale_dict(sultan, "name", slug)
			failures += _check_locale_dict(sultan, "summary", slug)
			failures += _check_locale_dict(sultan, "video_title", slug)
			var portrait: String = sultan.get("portrait", "")
			if not portrait.begins_with("res://assets/sultans/") or not portrait.ends_with(".jpg"):
				print("FAIL: bad portrait path for ", slug)
				failures += 1
			if not FileAccess.file_exists(portrait):
				print("FAIL: missing portrait ", portrait)
				failures += 1
			for b in sultan["battles"]:
				failures += _check_locale_dict(b, "name", slug + " battle")
				failures += _check_locale_dict(b, "description", slug + " battle")

	# Audio track presence (works for editor builds with raw files and exported
	# builds where only the .import metadata is shipped).
	if not DirAccess.dir_exists_absolute("res://assets/audio"):
		print("FAIL: assets/audio directory missing")
		failures += 1
	else:
		var dir := DirAccess.open("res://assets/audio")
		var has_audio := false
		if dir:
			dir.list_dir_begin()
			var f := dir.get_next()
			while f != "":
				var ext := f.get_extension().to_lower()
				if ext in ["ogg", "mp3", "wav"]:
					has_audio = true
					break
				if ext == "import":
					var base_ext := f.get_basename().get_extension().to_lower()
					if base_ext in ["ogg", "mp3", "wav"]:
						has_audio = true
						break
				f = dir.get_next()
		if not has_audio:
			print("FAIL: no audio tracks in assets/audio")
			failures += 1

	# Quiz generation in every supported locale
	var locales := HistoricalData.get_supported_locales()
	for loc in locales:
		TranslationServer.set_locale(loc)
		for ci in chapters.size():
			var qs := QuizSystem.new()
			add_child(qs)
			var questions: Array = qs.generate_quiz(ci)
			if questions.size() != QuizSystem.QUESTIONS_PER_CHAPTER:
				print("FAIL [%s]: chapter %d produced %d questions" % [loc, ci, questions.size()])
				failures += 1
			for q in questions:
				var choices: Array = q["choices"]
				if choices.size() < 2:
					print("FAIL [%s]: chapter %d question has %d choices" % [loc, ci, choices.size()])
					failures += 1
				if q["correct_index"] < 0 or q["correct_index"] >= choices.size():
					print("FAIL [%s]: chapter %d bad correct_index" % [loc, ci])
					failures += 1
				if q["context"] == "":
					print("FAIL [%s]: chapter %d empty context" % [loc, ci])
					failures += 1
			qs.queue_free()

	# Score calculation: 100s of study time = 10 points, plus 2 correct answers = 100 bonus
	GameManager.total_study_time = 100.0
	GameManager.calculate_score(2 * GameManager.CORRECT_ANSWER_BONUS)
	if GameManager.score != 110:
		print("FAIL: score calc expected 110, got %d" % GameManager.score)
		failures += 1

	# Time formatting
	if TimeTracker.format_time(3661.0) != "1h 01m":
		print("FAIL: format_time(3661)")
		failures += 1
	if TimeTracker.format_time(125.0) != "02:05":
		print("FAIL: format_time(125)")
		failures += 1

	# Locale save/load round-trip
	GameManager.set_progress(2, 1)
	GameManager.set_locale("zh")
	SaveManager.save_progress()
	GameManager.current_chapter_index = 0
	GameManager.current_sultan_index = 0
	GameManager.locale = "en"
	SaveManager.load_progress()
	if GameManager.current_chapter_index != 2 or GameManager.current_sultan_index != 1:
		print("FAIL: save/load round-trip lost progress")
		failures += 1
	if GameManager.locale != "zh":
		print("FAIL: locale save/load expected zh, got " + GameManager.locale)
		failures += 1

	# UI translation check: make sure project translations are registered so exported
	# builds show human-readable labels instead of raw keys like UI_EXIT.
	TranslationServer.set_locale("en")
	var ui_keys := ["UI_EXIT", "UI_CONTINUE", "UI_BACK", "UI_FORWARD"]
	for key in ui_keys:
		var translated: String = tr(key)
		if translated == key or translated.is_empty():
			print("FAIL: UI key '%s' is not translated (exported builds will show the key)" % key)
			failures += 1
		else:
			print("OK: %s -> %s" % [key, translated])

	# Music track check: ensure MusicPlayer found audio files so the bottom bar is
	# visible and autoplay works in exported builds (which only ship .import files).
	if MusicPlayer.tracks.is_empty():
		print("FAIL: MusicPlayer found no audio tracks")
		failures += 1
	else:
		print("OK: MusicPlayer tracks: %d" % MusicPlayer.tracks.size())

	# Reset locale for clean exit state
	TranslationServer.set_locale("en")

	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("%d FAILURES" % failures)
	call_deferred("_finish", failures)

func _finish(failures: int) -> void:
	get_tree().quit(1 if failures > 0 else 0)
