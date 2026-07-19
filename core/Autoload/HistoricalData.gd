extends Node

const DB_PATH := "res://data/historical_db.json"
const _LOCALES := ["en", "tr", "zh", "ru", "es"]

var _data: Dictionary = {}

func _ready() -> void:
	_load_database()

func _load_database() -> void:
	if not FileAccess.file_exists(DB_PATH):
		push_error("Historical database not found at " + DB_PATH)
		return
	var file := FileAccess.open(DB_PATH, FileAccess.READ)
	if file:
		var text := file.get_as_text()
		file.close()
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			_data = parsed as Dictionary
		else:
			push_error("Failed to parse historical database JSON.")

func get_data() -> Dictionary:
	return _data

func get_chapters() -> Array:
	return _data.get("chapters", []) as Array

func get_chapter(index: int) -> Dictionary:
	var chapters := get_chapters()
	if index >= 0 and index < chapters.size():
		return chapters[index] as Dictionary
	return {}

func get_sultan(chapter_index: int, sultan_index: int) -> Dictionary:
	var chapter := get_chapter(chapter_index)
	var sultans := chapter.get("sultans", []) as Array
	if sultan_index >= 0 and sultan_index < sultans.size():
		return sultans[sultan_index] as Dictionary
	return {}

func get_all_sultans() -> Array:
	var result: Array = []
	for chapter in get_chapters():
		result.append_array(chapter.get("sultans", []))
	return result

# Resolve a localized value. Accepts either a locale dictionary or a plain string.
func localize(value: Variant) -> String:
	if value is Dictionary:
		var locale := _current_lang()
		if value.has(locale) and not str(value[locale]).is_empty():
			return str(value[locale])
	# Fallback chain: English -> first non-empty
	if value.has("en") and not str(value["en"]).is_empty():
		return str(value["en"])
	for k in _LOCALES:
		if value.has(k) and not str(value[k]).is_empty():
			return str(value[k])
	return ""
	return str(value)

# Localize a battle/event entry, returning a new dictionary with plain strings.
func localize_battle(battle: Dictionary) -> Dictionary:
	return {
		"name": localize(battle.get("name", "")),
		"description": localize(battle.get("description", ""))
	}

func _current_lang() -> String:
	var loc := TranslationServer.get_locale()
	var parts := loc.split("_")
	if parts.size() > 0 and parts[0] in _LOCALES:
		return parts[0]
	return "en"

func get_supported_locales() -> PackedStringArray:
	return PackedStringArray(_LOCALES)
