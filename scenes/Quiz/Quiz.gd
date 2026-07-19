extends Control

var quiz_system: QuizSystem
var questions: Array = []
var current_index: int = 0
var correct_count: int = 0

@onready var title_label: Label = %TitleLabel
@onready var question_label: Label = %QuestionLabel
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var context_label: RichTextLabel = %ContextLabel
@onready var result_label: Label = %ResultLabel
@onready var continue_button: Button = %ContinueButton
@onready var back_to_menu_button: Button = %BackToMenuButton

func _ready() -> void:
	quiz_system = QuizSystem.new()
	add_child(quiz_system)

	var chapter := GameManager.get_current_chapter()
	title_label.text = tr("UI_CHAPTER_EVAL") % [chapter.get("id", 0), HistoricalData.localize(chapter.get("title", ""))]
	result_label.text = ""
	context_label.visible = false
	continue_button.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)

	questions = quiz_system.generate_quiz(GameManager.current_chapter_index)
	_show_question()

func _show_question() -> void:
	if current_index >= questions.size():
		_finish()
		return
	var q: Dictionary = questions[current_index]
	question_label.text = tr("UI_QUESTION_X_OF_Y") % [current_index + 1, questions.size(), q["question"]]
	context_label.visible = false

	for child in choices_box.get_children():
		child.queue_free()
	var choices: Array = q["choices"]
	for i in choices.size():
		var b := Button.new()
		b.text = choices[i]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_choice_pressed.bind(i))
		choices_box.add_child(b)

func _on_choice_pressed(choice_index: int) -> void:
	var q: Dictionary = questions[current_index]
	if choice_index == q["correct_index"]:
		correct_count += 1
		current_index += 1
		_show_question()
	else:
		# Non-punitive rule: point the player back to the passage instead of failing them.
		context_label.text = tr("UI_NOT_QUITE") + "\n" + q["context"]
		context_label.visible = true

func _finish() -> void:
	var chapter := GameManager.get_current_chapter()
	GameManager.mark_quiz_completed(chapter.get("id", 0), correct_count, questions.size())
	for child in choices_box.get_children():
		child.queue_free()
	context_label.visible = false
	question_label.text = tr("UI_CHAPTER_COMPLETE")
	result_label.text = tr("UI_ANSWERED_CORRECTLY") % [correct_count, questions.size(), correct_count * GameManager.CORRECT_ANSWER_BONUS]
	continue_button.visible = true
	if GameManager.current_chapter_index + 1 < HistoricalData.get_chapters().size():
		continue_button.text = tr("UI_CONTINUE_TO_CHAPTER") % (chapter.get("id", 0) + 1)
	else:
		continue_button.text = tr("UI_FINISH_JOURNEY")

func _on_continue_pressed() -> void:
	var next_chapter := GameManager.current_chapter_index + 1
	if next_chapter < HistoricalData.get_chapters().size():
		GameManager.set_progress(next_chapter, 0)
		get_tree().change_scene_to_file("res://scenes/Timeline/Timeline.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Leaderboard/Leaderboard.tscn")

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu/MainMenu.tscn")
