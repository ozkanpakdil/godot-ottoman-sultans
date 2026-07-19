extends Control

@onready var chapter_list: VBoxContainer = %ChapterList
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
	%LeaderboardButton.text = tr("UI_LEADERBOARD_PROGRESS")
	%ChapterPromptLabel.text = tr("UI_OR_BEGIN_CHAPTER")
	%LanguageLabel.text = tr("UI_CHOOSE_LANGUAGE")

	_build_language_select()
	_build_chapter_list()
	_update_stats()
	continue_button.pressed.connect(_on_continue_pressed)
	%LeaderboardButton.pressed.connect(_on_leaderboard_pressed)
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

func _build_chapter_list() -> void:
	for chapter in HistoricalData.get_chapters():
		var b := Button.new()
		b.text = tr("UI_CHAPTER_TITLE") % [chapter["id"], HistoricalData.localize(chapter["title"]), chapter["years"]]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Small portrait of the chapter's first sultan as a visual cue
		var sultans: Array = chapter.get("sultans", [])
		if sultans.size() > 0:
			var p: String = sultans[0].get("portrait", "")
			if p != "" and ResourceLoader.exists(p):
				b.icon = load(p)
				b.expand_icon = true
				b.custom_minimum_size = Vector2(0, 72)
		b.pressed.connect(_on_chapter_pressed.bind(chapter["id"] - 1))
		chapter_list.add_child(b)

func _update_stats() -> void:
	stats_label.text = tr("UI_SCORE_TIME") % [GameManager.score, TimeTracker.format_time(GameManager.total_study_time)]

func _on_language_selected(index: int) -> void:
	var locales := HistoricalData.get_supported_locales()
	GameManager.set_locale(locales[index])
	get_tree().reload_current_scene()

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Timeline/Timeline.tscn")

func _on_chapter_pressed(chapter_index: int) -> void:
	GameManager.set_progress(chapter_index, 0)
	get_tree().change_scene_to_file("res://scenes/Timeline/Timeline.tscn")

func _on_leaderboard_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Leaderboard/Leaderboard.tscn")

func _on_music_mute_pressed() -> void:
	MusicPlayer.toggle_mute()
	var muted = MusicPlayer.is_muted()
	%MusicMuteButton.text = "🔇 Music" if muted else "🔊 Music"
