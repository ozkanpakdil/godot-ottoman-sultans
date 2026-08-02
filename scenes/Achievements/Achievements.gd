extends Control

@onready var category_list: VBoxContainer = %CategoryList
@onready var badge_list: VBoxContainer = %BadgeList

func _ready() -> void:
	%TitleLabel.text = tr("UI_ACHIEVEMENTS_TITLE")
	_build_category_list()
	_build_badge_list()

func _build_category_list() -> void:
	for child in category_list.get_children():
		child.queue_free()

	for category in GameManager.CATEGORIES:
		var stats: Dictionary = GameManager.category_stats.get(category, {"correct": 0, "total": 0})
		var correct: int = stats.get("correct", 0)
		var total: int = stats.get("total", 0)
		var level: int = GameManager.get_category_badge_level(category)

		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.07, 0.11, 0.95)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.85, 0.7, 0.35, 1)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		card.add_theme_stylebox_override("panel", style)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		card.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		margin.add_child(vbox)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 12)
		vbox.add_child(header)

		var icon := Label.new()
		icon.text = GameManager.CATEGORY_ICONS.get(category, "")
		icon.add_theme_font_size_override("font_size", 28)
		header.add_child(icon)

		var name_label := Label.new()
		name_label.text = GameManager.get_category_display_name(category)
		name_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.35, 1))
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(name_label)

		var progress := ProgressBar.new()
		progress.min_value = 0
		progress.max_value = GameManager.BADGE_THRESHOLDS[-1]
		progress.value = correct
		progress.custom_minimum_size = Vector2(0, 24)
		vbox.add_child(progress)

		var stats_label := Label.new()
		stats_label.text = tr("UI_CATEGORY_STATS") % [correct, total]
		stats_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(stats_label)

		var badge_label := Label.new()
		if level >= 0:
			var badge_id: String = GameManager.BADGE_TITLES[category][level]
			badge_label.text = tr("UI_CURRENT_BADGE") % GameManager.get_badge_display_name(badge_id)
		else:
			badge_label.text = tr("UI_NO_BADGE_YET")
		badge_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(badge_label)

		category_list.add_child(card)

func _build_badge_list() -> void:
	for child in badge_list.get_children():
		child.queue_free()

	if GameManager.earned_badges.is_empty():
		var empty := Label.new()
		empty.text = tr("UI_NO_BADGES_YET")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 16)
		badge_list.add_child(empty)
		return

	for badge_id in GameManager.earned_badges:
		var entry := Label.new()
		entry.text = "🏅 " + GameManager.get_badge_display_name(badge_id)
		entry.add_theme_font_size_override("font_size", 18)
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		badge_list.add_child(entry)


