extends CanvasLayer

# Reusable top-left hamburger menu for navigation and settings.

@onready var menu_button: Button = %MenuButton
@onready var menu_panel: PanelContainer = %MenuPanel
@onready var map_button: Button = %MapButton
@onready var knowledge_button: Button = %KnowledgeButton
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var achievements_button: Button = %AchievementsButton
@onready var archery_button: Button = %ArcheryButton
@onready var language_select: OptionButton = %LanguageSelect
@onready var music_mute_button: Button = %MusicMuteButton
@onready var sfx_mute_button: Button = %SfxMuteButton
@onready var exit_button: Button = %ExitButton

const LOCALE_LABELS := {
	"en": "English",
	"tr": "Türkçe",
	"zh": "中文",
	"ru": "Русский",
	"es": "Español"
}

func _ready() -> void:
	menu_button.pressed.connect(_on_menu_button_pressed)
	map_button.pressed.connect(_on_map_pressed)
	knowledge_button.pressed.connect(_on_knowledge_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	achievements_button.pressed.connect(_on_achievements_pressed)
	archery_button.pressed.connect(_on_archery_pressed)
	language_select.item_selected.connect(_on_language_selected)
	music_mute_button.pressed.connect(_on_music_mute_pressed)
	sfx_mute_button.pressed.connect(_on_sfx_mute_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	_update_texts()
	_update_mute_buttons()
	_build_language_select()

func _update_texts() -> void:
	map_button.text = tr("UI_MAP")
	knowledge_button.text = tr("UI_KNOWLEDGE_LIBRARY")
	leaderboard_button.text = tr("UI_LEADERBOARD_PROGRESS")
	achievements_button.text = tr("UI_ACHIEVEMENTS_TITLE")
	archery_button.text = tr("UI_ARCHERY_GAME")
	exit_button.text = tr("UI_EXIT")

func _build_language_select() -> void:
	language_select.clear()
	var locales := HistoricalData.get_supported_locales()
	for code in locales:
		language_select.add_item(LOCALE_LABELS.get(code, code))
	language_select.selected = locales.find(GameManager.locale)

func _update_mute_buttons() -> void:
	music_mute_button.text = "🔇" if MusicPlayer.is_muted() else "🔊"
	sfx_mute_button.text = "🔇" if GameManager.sfx_muted else "🔊"

func is_point_over_menu(pos: Vector2) -> bool:
	if menu_button.get_global_rect().has_point(pos):
		return true
	if menu_panel.visible and menu_panel.get_global_rect().has_point(pos):
		return true
	return false

func _on_menu_button_pressed() -> void:
	menu_panel.visible = not menu_panel.visible

func _hide() -> void:
	menu_panel.visible = false

func _on_map_pressed() -> void:
	_hide()
	SceneManager.pop_to_map()

func _on_knowledge_pressed() -> void:
	_hide()
	SceneManager.push("res://scenes/KnowledgeLibrary/KnowledgeLibrary.tscn")

func _on_leaderboard_pressed() -> void:
	_hide()
	SceneManager.push("res://scenes/Leaderboard/Leaderboard.tscn")

func _on_achievements_pressed() -> void:
	_hide()
	SceneManager.push("res://scenes/Achievements/Achievements.tscn")

func _on_archery_pressed() -> void:
	_hide()
	GameManager.set_mini_game_context(
		GameManager.MINI_GAME_ARCHERY,
		GameManager.current_chapter_index,
		GameManager.current_sultan_index,
		"res://scenes/Map/Map.tscn"
	)
	SceneManager.push("res://scenes/ArcheryGame/ArcheryGame.tscn")

func _on_language_selected(index: int) -> void:
	var locales := HistoricalData.get_supported_locales()
	GameManager.set_locale(locales[index])
	SceneManager.reload_current_scene()

func _on_music_mute_pressed() -> void:
	MusicPlayer.toggle_mute()
	_update_mute_buttons()

func _on_sfx_mute_pressed() -> void:
	GameManager.toggle_sfx_mute()
	_update_mute_buttons()

func _on_exit_pressed() -> void:
	get_tree().quit()
