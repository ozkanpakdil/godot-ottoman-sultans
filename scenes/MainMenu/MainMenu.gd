extends Control

@onready var stats_label: Label = %StatsLabel
@onready var continue_button: Button = %ContinueButton
@onready var language_select: OptionButton = %LanguageSelect
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel

const LOCALE_LABELS := {
	"en": "English",
	"tr": "Türkçe",
	"zh": "中文",
	"ru": "Русский",
	"es": "Español"
}

func _ready() -> void:
	title_label.text = tr("UI_APP_NAME")
	subtitle_label.text = tr("UI_SUBTITLE")
	continue_button.text = tr("UI_CONTINUE")
	%MapButton.text = tr("UI_MAP")
	%KnowledgeButton.text = tr("UI_KNOWLEDGE_LIBRARY")
	%LeaderboardButton.text = tr("UI_LEADERBOARD_PROGRESS")
	%ExitButton.text = tr("UI_EXIT")
	%ExitButton.disabled = false
	%LanguageLabel.text = tr("UI_CHOOSE_LANGUAGE")

	_build_language_select()
	_update_stats()
	continue_button.pressed.connect(_on_continue_pressed)
	%MapButton.pressed.connect(_on_map_pressed)
	%KnowledgeButton.pressed.connect(_on_knowledge_pressed)
	%LeaderboardButton.pressed.connect(_on_leaderboard_pressed)
	%ExitButton.pressed.connect(_on_exit_pressed)
	language_select.item_selected.connect(_on_language_selected)
	%MusicMuteButton.pressed.connect(_on_music_mute_pressed)
	
	# Initialize mute button text
	var muted = MusicPlayer.is_muted()
	%MusicMuteButton.text = "🔇 Music" if muted else "🔊 Music"

func _build_language_select() -> void:
	var locales := HistoricalData.get_supported_locales()
	for code in locales:
		language_select.add_item(LOCALE_LABELS.get(code, code))
	language_select.selected = locales.find(GameManager.locale)

func _update_stats() -> void:
	stats_label.text = tr("UI_SCORE_TIME") % [GameManager.score, TimeTracker.format_time(GameManager.total_study_time)]

func _on_language_selected(index: int) -> void:
	var locales := HistoricalData.get_supported_locales()
	GameManager.set_locale(locales[index])
	SceneManager.reload_current_scene()

func _on_continue_pressed() -> void:
	SceneManager.push("res://scenes/Timeline/Timeline.tscn")

func _on_map_pressed() -> void:
	SceneManager.push("res://scenes/Map/Map.tscn")

func _on_knowledge_pressed() -> void:
	SceneManager.push("res://scenes/KnowledgeLibrary/KnowledgeLibrary.tscn")

func _on_leaderboard_pressed() -> void:
	SceneManager.push("res://scenes/Leaderboard/Leaderboard.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_music_mute_pressed() -> void:
	MusicPlayer.toggle_mute()
	var muted = MusicPlayer.is_muted()
	%MusicMuteButton.text = "🔇 Music" if muted else "🔊 Music"
