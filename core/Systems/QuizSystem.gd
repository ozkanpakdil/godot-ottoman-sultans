extends Node
class_name QuizSystem

# Quiz generation constants
const QUESTIONS_PER_CHAPTER := 4
const CHOICES_PER_QUESTION := 3

const CATEGORIES := ["chronology", "war", "family", "diplomacy"]

# Build a 4-question quiz for a given chapter based on its sultans and events.
# Each question: { "question": String, "choices": Array[String], "correct_index": int, "context": String, "category": String }
func generate_quiz(chapter_index: int) -> Array:
	var chapter := HistoricalData.get_chapter(chapter_index)
	var sultans: Array = chapter.get("sultans", [])
	var questions: Array = []

	if sultans.is_empty():
		return questions

	# Question 1: Sultan reign matching (Chronology)
	var sultan: Dictionary = sultans.pick_random()
	var sultan_name := HistoricalData.localize(sultan.get("name", "Unknown"))
	questions.append({
		"question": tr("UI_QUIZ_WHEN_DID_REIGN") % sultan_name,
		"choices": _generate_reign_choices(sultan, sultans),
		"correct_index": 0,
		"context": tr("UI_QUIZ_CONTEXT_REIGNED") % [sultan_name, sultan.get("reign", "")],
		"category": "chronology"
	})

	# Question 2: Battle/event association (War)
	var battle_sultan := _pick_sultan_with_events(sultans)
	if not battle_sultan.is_empty():
		var events: Array = battle_sultan.get("battles", [])
		var event: Dictionary = events.pick_random()
		var event_name := HistoricalData.localize(event.get("name", ""))
		var wrong_names := _collect_other_event_names(sultans, battle_sultan, event_name)
		var battle_sultan_name := HistoricalData.localize(battle_sultan.get("name", ""))
		questions.append({
			"question": tr("UI_QUIZ_WHICH_EVENT") % battle_sultan_name,
			"choices": [event_name] + wrong_names,
			"correct_index": 0,
			"context": HistoricalData.localize(event.get("description", "")),
			"category": "war"
		})

	# Question 3: Family (wife or child)
	var family_question := _generate_family_question(sultans)
	if not family_question.is_empty():
		questions.append(family_question)

	# Question 4: Diplomacy or fallback chapter-matching
	var diplomacy_question := _generate_diplomacy_question(sultans)
	if not diplomacy_question.is_empty():
		questions.append(diplomacy_question)

	# Ensure exactly QUESTIONS_PER_CHAPTER by falling back to chapter-level questions
	while questions.size() < QUESTIONS_PER_CHAPTER:
		var fallback_sultan: Dictionary = sultans.pick_random()
		var fallback_name: String = HistoricalData.localize(fallback_sultan.get("name", "Unknown"))
		var fallback_slug: String = fallback_sultan.get("slug", "")
		questions.append({
			"question": tr("UI_QUIZ_WHICH_SULTAN_IN_ERA") % HistoricalData.localize(chapter.get("title", "")),
			"choices": _generate_sultan_choices(fallback_name, fallback_slug),
			"correct_index": 0,
			"context": tr("UI_QUIZ_CONTEXT_PART_OF") % [fallback_name, HistoricalData.localize(chapter.get("title", ""))],
			"category": "chronology"
		})

	# Trim to required count and shuffle choices per question
	var result: Array = []
	for q in questions.slice(0, QUESTIONS_PER_CHAPTER):
		var shuffled: Array = (q["choices"] as Array).duplicate()
		var correct_answer: String = shuffled[0]
		shuffled.shuffle()
		result.append({
			"question": q["question"],
			"choices": shuffled,
			"correct_index": shuffled.find(correct_answer),
			"context": q["context"],
			"category": q["category"]
		})
	return result

func _generate_reign_choices(target: Dictionary, pool: Array) -> Array:
	var choices := [target.get("reign", "")]
	var target_slug: String = target.get("slug", "")
	var others: Array = pool.filter(func(s): return s.get("slug") != target_slug)
	others.shuffle()
	for s in others:
		if choices.size() >= CHOICES_PER_QUESTION:
			break
		var reign: String = s.get("reign", "")
		if reign != "" and not choices.has(reign):
			choices.append(reign)
	return choices

func _generate_sultan_choices(correct_name: String, correct_slug: String) -> Array:
	var choices := [correct_name]
	var all_sultans := HistoricalData.get_all_sultans()
	var others: Array = all_sultans.filter(func(s): return s.get("slug") != correct_slug)
	others.shuffle()
	for s in others:
		if choices.size() >= CHOICES_PER_QUESTION:
			break
		var name: String = HistoricalData.localize(s.get("name", ""))
		if name != "" and not choices.has(name):
			choices.append(name)
	return choices

func _generate_family_question(sultans: Array) -> Dictionary:
	# Prefer a sultan with children; fall back to a sultan with wives.
	var candidates := sultans.filter(func(s):
		return (HistoricalData.get_sultan_children(s) as Array).size() > 0
	)
	var question_type := "child"
	if candidates.is_empty():
		candidates = sultans.filter(func(s): return (s.get("wives", []) as Array).size() > 0)
		question_type = "wife"
	if candidates.is_empty():
		return {}

	var sultan: Dictionary = candidates.pick_random()
	var sultan_name := HistoricalData.localize(sultan.get("name", ""))
	if question_type == "child":
		var children: Array = HistoricalData.get_sultan_children(sultan)
		var child: String = str(children.pick_random())
		var wrong_children := _collect_other_family_names(sultans, sultan, child, "children")
		return {
			"question": tr("UI_QUIZ_FAMILY_CHILD") % sultan_name,
			"choices": [child] + wrong_children,
			"correct_index": 0,
			"context": tr("UI_QUIZ_FAMILY_CHILD_CONTEXT") % [child, sultan_name],
			"category": "family"
		}
	else:
		var wives: Array = sultan.get("wives", [])
		var wife: String = str(wives.pick_random())
		var wrong_wives := _collect_other_family_names(sultans, sultan, wife, "wives")
		return {
			"question": tr("UI_QUIZ_FAMILY_WIFE") % sultan_name,
			"choices": [wife] + wrong_wives,
			"correct_index": 0,
			"context": tr("UI_QUIZ_FAMILY_WIFE_CONTEXT") % [wife, sultan_name],
			"category": "family"
		}

func _generate_diplomacy_question(sultans: Array) -> Dictionary:
	var all_events: Array = HistoricalData.get_diplomatic_events()
	if all_events.is_empty():
		return {}

	# Pick an event whose sultan is in this chapter.
	var slugs: Dictionary = {}
	for s in sultans:
		slugs[s.get("slug", "")] = true
	var local_events := all_events.filter(func(e): return slugs.has(e.get("sultan_slug", "")))
	if local_events.is_empty():
		return {}

	var event: Dictionary = local_events.pick_random()
	var le := HistoricalData.localize_diplomatic_event(event)
	var correct_sultan := HistoricalData.get_sultan_by_slug(event.get("sultan_slug", ""))
	var correct_sultan_name := HistoricalData.localize(correct_sultan.get("name", ""))
	var wrong_names := _collect_other_sultan_names(sultans, correct_sultan)
	return {
		"question": tr("UI_QUIZ_DIPLOMACY") % correct_sultan_name,
		"choices": [le["name"]] + _collect_other_event_names_from_global(event),
		"correct_index": 0,
		"context": le["description"],
		"category": "diplomacy"
	}

func _collect_other_event_names_from_global(exclude_event: Dictionary) -> Array:
	var exclude_name: String = HistoricalData.localize(exclude_event.get("name", ""))
	var names: Array = []
	for e in HistoricalData.get_diplomatic_events():
		var n: String = HistoricalData.localize(e.get("name", ""))
		if n != "" and n != exclude_name and not names.has(n):
			names.append(n)
	names.shuffle()
	return names.slice(0, CHOICES_PER_QUESTION - 1)

func _collect_other_family_names(sultans: Array, exclude_sultan: Dictionary, exclude_name: String, field: String) -> Array:
	var names: Array = []
	var exclude_slug: String = exclude_sultan.get("slug", "")
	for s in sultans:
		if s.get("slug") == exclude_slug:
			continue
		for item in s.get(field, []):
			var n: String = str(item)
			if n != "" and n != exclude_name and not names.has(n):
				names.append(n)
	if names.size() < CHOICES_PER_QUESTION - 1:
		# Pad with generic plausible names so the question is still playable.
		var padding := ["Malhun Hatun", "Nilüfer Hatun", "Hürrem Sultan", "Kösem Sultan", "Turhan Hatun"]
		for p in padding:
			if names.size() >= CHOICES_PER_QUESTION - 1:
				break
			if not names.has(p) and p != exclude_name:
				names.append(p)
	names.shuffle()
	return names.slice(0, CHOICES_PER_QUESTION - 1)

func _collect_other_sultan_names(sultans: Array, exclude_sultan: Dictionary) -> Array:
	var names: Array = []
	var exclude_slug: String = exclude_sultan.get("slug", "")
	for s in sultans:
		if s.get("slug") == exclude_slug:
			continue
		var n: String = HistoricalData.localize(s.get("name", ""))
		if n != "" and not names.has(n):
			names.append(n)
	names.shuffle()
	return names.slice(0, CHOICES_PER_QUESTION - 1)

func _pick_sultan_with_events(sultans: Array) -> Dictionary:
	var candidates := sultans.filter(func(s): return (s.get("battles", []) as Array).size() > 0)
	if candidates.is_empty():
		return {}
	return candidates.pick_random()

func _collect_other_event_names(sultans: Array, exclude_sultan: Dictionary, exclude_event: String) -> Array:
	var names: Array = []
	var exclude_slug: String = exclude_sultan.get("slug", "")
	for s in sultans:
		if s.get("slug") == exclude_slug:
			continue
		for b in s.get("battles", []):
			var n: String = HistoricalData.localize(b.get("name", ""))
			if n != "" and n != exclude_event and not names.has(n):
				names.append(n)
	names.shuffle()
	return names.slice(0, CHOICES_PER_QUESTION - 1)
