extends Node

# Keeps the map scene alive in the background instead of reloading it every time
# the player returns from a lesson, quiz, or other screen.

const MAP_PATH := "res://scenes/Map/Map.tscn"

var _stack: Array[Node] = []

func _ready() -> void:
	get_tree().root.tree_exiting.connect(_on_tree_exiting)

func _on_tree_exiting() -> void:
	# Free any scenes held in the stack so they don't leak at shutdown.
	_clear_stack()

func _clear_stack() -> void:
	for scene in _stack:
		if is_instance_valid(scene) and not scene.is_queued_for_deletion():
			scene.free()
	_stack.clear()

func push(scene_path: String) -> void:
	var current := get_tree().current_scene
	if current != null:
		get_tree().root.remove_child(current)
		_stack.append(current)

	var scene: Node = load(scene_path).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene

func replace(scene_path: String) -> void:
	var current := get_tree().current_scene
	if current != null:
		current.queue_free()

	var scene: Node = load(scene_path).instantiate()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene

func pop() -> void:
	var current := get_tree().current_scene
	if current != null:
		current.queue_free()

	var previous: Node = _stack.pop_back()
	if previous != null:
		get_tree().root.add_child(previous)
		get_tree().current_scene = previous
	else:
		push(MAP_PATH)

func pop_to_map() -> void:
	var current := get_tree().current_scene
	while current != null and current.scene_file_path != MAP_PATH and _stack.size() > 0:
		pop()
		current = get_tree().current_scene
	if current == null or current.scene_file_path != MAP_PATH:
		push(MAP_PATH)

func reload_current_scene() -> void:
	# Clear the stack so a fresh reload does not hold stale scene references.
	_clear_stack()
	get_tree().reload_current_scene()
