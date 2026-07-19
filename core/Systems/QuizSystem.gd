extends Node
class_name QuizSystem

# Quiz generation constants
const QUESTIONS_PER_CHAPTER := 3
const CHOICES_PER_QUESTION := 3

# Build a 3-question quiz for a given chapter based on its sultans and events.
# Each question: { "question": String, "choices": Array[String], "correct_index": int, "context": String }
func generate_quiz(chapter_index: int) -> Array:
	var chapter := HistoricalData.get_chapter(chapter_index)
	var sultans: Array = chapter.get("sultans", [])
	var questions: Array = []

	if sultans.is_empty():
		return questions

	# Question 1: Sultan reign matching
	var sultan: Dictionary = sultans.pick_random()
	var sultan_name := HistoricalData.localize(sultan.get("name", "Unknown"))
	questions.append({
		"question": tr("When did %s reign?") % sultan_name,
		"choices": _generate_reign_choices(sultan, sultans),
		"correct_index": 0,
		"context": tr("%s reigned %s.") % [sultan_name, sultan.get("reign", "")]
	})

	# Question 2: Battle/event association
	var battle_sultan := _pick_sultan_with_events(sultans)
	if not battle_sultan.is_empty():
		var events: Array = battle_sultan.get("battles", [])
		var event: Dictionary = events.pick_random()
		var event_name := HistoricalData.localize(event.get("name", ""))
		var wrong_names := _collect_other_event_names(sultans, battle_sultan, event_name)
		var battle_sultan_name := HistoricalData.localize(battle_sultan.get("name", ""))
		questions.append({
			"question": tr("Which event is associated with %s?") % battle_sultan_name,
			"choices": [event_name] + wrong_names,
			"correct_index": 0,
			"context": HistoricalData.localize(event.get("description", ""))
		})

	# Question 3: Chapter-level knowledge
	var correct_sultan_name: String = sultan_name
	var correct_sultan_slug: String = sultan.get("slug", "")
	questions.append({
		"question": tr("Which of the following sultans belonged to the era \"%s\"?") % HistoricalData.localize(chapter.get("title", "")),
		"choices": _generate_sultan_choices(correct_sultan_name, correct_sultan_slug),
		"correct_index": 0,
		"context": tr("%s was part of %s.") % [correct_sultan_name, HistoricalData.localize(chapter.get("title", ""))]
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
			"context": q["context"]
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
