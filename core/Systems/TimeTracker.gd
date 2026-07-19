extends Node
class_name TimeTracker

# Periodic autosave interval in seconds
@export var autosave_interval: float = 30.0
var _elapsed: float = 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= autosave_interval:
		_elapsed = 0.0
		SaveManager.save_progress()

static func format_time(total_seconds: float) -> String:
	var seconds := int(total_seconds)
	var hours := seconds / 3600
	var minutes := (seconds % 3600) / 60
	var secs := seconds % 60
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]
	return "%02d:%02d" % [minutes, secs]
