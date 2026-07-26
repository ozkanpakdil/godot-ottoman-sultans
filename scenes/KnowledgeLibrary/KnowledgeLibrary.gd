extends Control

@onready var chapter_list: VBoxContainer = %ChapterList
@onready var title_label: Label = %TitleLabel
@onready var back_button: Button = %BackButton

func _ready() -> void:
	title_label.text = tr("UI_KNOWLEDGE_LIBRARY")
	back_button.text = tr("UI_BACK")
	back_button.pressed.connect(_on_back_pressed)
	_build_chapter_list()

func _build_chapter_list() -> void:
	for chapter in HistoricalData.get_chapters():
		var b := Button.new()
		b.text = tr("UI_CHAPTER_TITLE") % [chapter["id"], HistoricalData.localize(chapter["title"]), chapter["years"]]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 96)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.expand_icon = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Portrait of the chapter's first sultan as a visual cue
		var sultans: Array = chapter.get("sultans", [])
		if sultans.size() > 0:
			var p: String = sultans[0].get("portrait", "")
			if p != "" and ResourceLoader.exists(p):
				b.icon = load(p)
		b.pressed.connect(_on_chapter_pressed.bind(chapter["id"] - 1))
		chapter_list.add_child(b)

func _on_chapter_pressed(chapter_index: int) -> void:
	GameManager.set_progress(chapter_index, 0)
	get_tree().change_scene_to_file("res://scenes/Timeline/Timeline.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu/MainMenu.tscn")
