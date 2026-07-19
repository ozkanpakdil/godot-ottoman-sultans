extends Control

const TIMELINE_START := 1299
const TIMELINE_END := 1922

@onready var chapter_label: Label = %ChapterLabel
@onready var header_label: Label = %HeaderLabel
@onready var portrait_rect: TextureRect = %PortraitRect
@onready var content_label: RichTextLabel = %ContentLabel
@onready var year_label: Label = %YearLabel
@onready var chronology_meter: ProgressBar = %ChronologyMeter
@onready var video_button: Button = %VideoButton
@onready var back_button: Button = %BackButton
@onready var forward_button: Button = %ForwardButton
@onready var quiz_button: Button = %QuizButton
@onready var scroll: ScrollContainer = %ContentScroll

func _ready() -> void:
	chronology_meter.min_value = TIMELINE_START
	chronology_meter.max_value = TIMELINE_END
	back_button.pressed.connect(_on_back_pressed)
	forward_button.pressed.connect(_on_forward_pressed)
	quiz_button.pressed.connect(_on_quiz_pressed)
	video_button.pressed.connect(_on_video_pressed)
	%MenuButton.pressed.connect(_on_menu_pressed)
	_render_sultan()

func _render_sultan() -> void:
	var chapter := GameManager.get_current_chapter()
	var sultan := GameManager.get_current_sultan()
	if sultan.is_empty():
		return

	chapter_label.text = tr("UI_CHAPTER_TITLE") % [chapter.get("id", 0), HistoricalData.localize(chapter.get("title", "")), chapter.get("years", "")]
	header_label.text = "%s\n%s" % [HistoricalData.localize(sultan.get("name", "")), sultan.get("reign", "")]
	year_label.text = tr("UI_YEAR_PROGRESS") % sultan.get("start_year", TIMELINE_START)
	chronology_meter.value = sultan.get("start_year", TIMELINE_START)
	content_label.text = _build_content(sultan)
	scroll.scroll_vertical = 0

	_load_portrait(sultan.get("portrait", ""))

	var video_id: String = sultan.get("video_id", "")
	video_button.visible = video_id != ""
	if video_id != "":
		video_button.text = tr("UI_WATCH") % HistoricalData.localize(sultan.get("video_title", ""))

	var sultans: Array = chapter.get("sultans", [])
	var is_last_sultan := GameManager.current_sultan_index == sultans.size() - 1
	quiz_button.visible = is_last_sultan
	forward_button.visible = not is_last_sultan
	back_button.disabled = GameManager.current_chapter_index == 0 and GameManager.current_sultan_index == 0
	back_button.text = tr("UI_BACK")
	forward_button.text = tr("UI_FORWARD")
	quiz_button.text = tr("UI_TAKE_CHAPTER_TEST")

func _load_portrait(path: String) -> void:
	if path == "":
		portrait_rect.visible = false
		return
	var res := load(path)
	if res is Texture2D:
		portrait_rect.texture = res
		portrait_rect.visible = true
	else:
		portrait_rect.visible = false

func _build_content(sultan: Dictionary) -> String:
	var lines: Array = []
	lines.append(HistoricalData.localize(sultan.get("summary", "")))
	lines.append("")

	var wives: Array = sultan.get("wives", [])
	if not wives.is_empty():
		lines.append("[b]" + tr("UI_SPOUSES") + "[/b]")
		for w in wives:
			lines.append("  • %s" % w)
		lines.append("")

	var battles: Array = sultan.get("battles", [])
	if not battles.is_empty():
		lines.append("[b]" + tr("UI_KEY_EVENTS") + "[/b]")
		for b in battles:
			var lb := HistoricalData.localize_battle(b)
			lines.append("  • [b]%s[/b] — %s" % [lb["name"], lb["description"]])
	return "\n".join(lines)

func _on_back_pressed() -> void:
	if not GameManager.retreat_sultan():
		# Move to the previous chapter's last sultan
		var prev_chapter := GameManager.current_chapter_index - 1
		if prev_chapter < 0:
			return
		var sultans: Array = HistoricalData.get_chapter(prev_chapter).get("sultans", [])
		GameManager.set_progress(prev_chapter, sultans.size() - 1)
	_render_sultan()

func _on_forward_pressed() -> void:
	GameManager.advance_sultan()
	_render_sultan()

func _on_quiz_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Quiz/Quiz.tscn")

func _on_video_pressed() -> void:
	var sultan := GameManager.get_current_sultan()
	var video_id: String = sultan.get("video_id", "")
	if video_id != "":
		OS.shell_open("https://www.youtube.com/watch?v=" + video_id)

func _on_menu_pressed() -> void:
	SaveManager.save_progress()
	get_tree().change_scene_to_file("res://scenes/MainMenu/MainMenu.tscn")
