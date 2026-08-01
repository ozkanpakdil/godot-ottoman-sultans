extends Control

# Ottoman-themed trajectory mini-game. Supports two modes:
# - "archery": played before a lesson, enemy battle flags as targets.
# - "cannon": played after a chapter test, fortress blocks as targets.

const ARROW_SCENE := preload("res://scenes/ArcheryGame/Projectile.tscn")
const CANNONBALL_SCENE := preload("res://scenes/ArcheryGame/Cannonball.tscn")
const FLAG_TARGET_SCENE := preload("res://scenes/ArcheryGame/Target.tscn")
const FORTRESS_BLOCK_SCENE := preload("res://scenes/ArcheryGame/FortressBlock.tscn")
const ARCHER_SCENE := preload("res://scenes/ArcheryGame/Archer.tscn")
const CANNON_SCENE := preload("res://scenes/ArcheryGame/Cannon.tscn")

const GRAVITY := 980.0
const MAX_DRAG := 240.0
const MAX_POWER := 1400.0
const MAX_SHOTS := 10

@onready var launcher: Marker2D = %Launcher
@onready var archer: Node2D = %Archer
@onready var success_particles: CPUParticles2D = %SuccessParticles
@onready var aim_line: Line2D = %AimLine
@onready var drag_line: Line2D = %DragLine
@onready var projectiles: Node2D = %Projectiles
@onready var targets: Node2D = %Targets
@onready var score_label: Label = %ScoreLabel
@onready var shots_label: Label = %ShotsLabel
@onready var result_label: Label = %ResultLabel
@onready var enemy_label: Label = %EnemyLabel
@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton
@onready var hint_label: Label = %HintLabel
@onready var title_label: Label = %TitleLabel

var _drag_start: Vector2 = Vector2.ZERO
var _drag_current: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _shots_left: int = MAX_SHOTS
var _score: int = 0
var _game_over: bool = false
var _celebrate_tween: Tween = null
var _archer_base_y: float = 0.0

var _mode: String = GameManager.MINI_GAME_ARCHERY
var _chapter_index: int = 0
var _sultan_index: int = 0
var _return_scene: String = ""
var _player_node: Node2D = null

func _ready() -> void:
	_read_context()
	_setup_player()
	_back_button_text()
	_update_title_and_hint()
	_update_enemy_label()
	_archer_base_y = _player_node.position.y
	_update_ui()
	_spawn_targets()
	reset_button.pressed.connect(_reset_game)
	back_button.pressed.connect(_on_back_pressed)

func _read_context() -> void:
	var ctx := GameManager.mini_game_context
	_mode = ctx.get("mode", GameManager.MINI_GAME_ARCHERY)
	_chapter_index = ctx.get("chapter_index", GameManager.current_chapter_index)
	_sultan_index = ctx.get("sultan_index", GameManager.current_sultan_index)
	_return_scene = ctx.get("return_scene", "res://scenes/Map/Map.tscn")
	GameManager.clear_mini_game_context()

func _setup_player() -> void:
	archer.queue_free()
	var scene: PackedScene = CANNON_SCENE if _mode == GameManager.MINI_GAME_CANNON else ARCHER_SCENE
	_player_node = scene.instantiate()
	_player_node.position = archer.position
	%World.add_child(_player_node)
	_player_node.name = "Player"
	# Bow/cannon muzzle offset relative to player base.
	var muzzle_offset := Vector2(18, -72) if _mode == GameManager.MINI_GAME_ARCHERY else Vector2(70, -4)
	launcher.position = _player_node.position + muzzle_offset

func _update_title_and_hint() -> void:
	if _mode == GameManager.MINI_GAME_CANNON:
		title_label.text = tr("UI_CANNON_SIEGE") if tr("UI_CANNON_SIEGE") != "UI_CANNON_SIEGE" else "Cannon Siege"
		hint_label.text = tr("UI_DRAG_TO_AIM") + " " + tr("UI_BOMBARD_THE_FORTRESS")
	else:
		title_label.text = tr("UI_ARCHERY_GAME")
		hint_label.text = tr("UI_DRAG_TO_AIM")

func _update_enemy_label() -> void:
	var sultan := GameManager.get_current_sultan()
	var battles: Array = sultan.get("battles", [])
	if battles.is_empty():
		enemy_label.text = ""
		return
	var localized: Dictionary = HistoricalData.localize_battle(battles[0])
	var battle_name: String = localized.get("name", "")
	if battle_name.is_empty():
		enemy_label.text = ""
		return
	var prefix := tr("UI_ENEMY") if tr("UI_ENEMY") != "UI_ENEMY" else "Enemy"
	enemy_label.text = "%s: %s" % [prefix, battle_name]

func _back_button_text() -> void:
	var txt := tr("UI_BACK_TO_MENU")
	if txt == "UI_BACK_TO_MENU":
		txt = tr("UI_BACK")
	back_button.text = txt

func _input(event: InputEvent) -> void:
	if _game_over:
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pos: Vector2 = event.position
		if event.is_pressed():
			_drag_start = pos
			_drag_current = pos
			_is_dragging = true
			aim_line.visible = true
			drag_line.visible = true
		else:
			if _is_dragging:
				_shoot()
			_is_dragging = false
			aim_line.visible = false
			drag_line.visible = false

	if event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_drag_current = event.position
		_update_aim_visuals()

func _update_aim_visuals() -> void:
	var raw: Vector2 = _drag_current - _drag_start
	var power: float = min(raw.length(), MAX_DRAG) / MAX_DRAG
	var direction: Vector2 = raw.normalized()
	var velocity: Vector2 = direction * power * MAX_POWER

	drag_line.clear_points()
	drag_line.add_point(_drag_start)
	drag_line.add_point(_drag_current)

	aim_line.clear_points()
	var pos: Vector2 = launcher.global_position
	aim_line.add_point(pos)
	for i in range(1, 20):
		var t: float = i * 0.05
		var p: Vector2 = pos + velocity * t + 0.5 * Vector2(0, GRAVITY) * t * t
		aim_line.add_point(p)

func _shoot() -> void:
	if _shots_left <= 0:
		return

	var raw: Vector2 = _drag_current - _drag_start
	var power: float = min(raw.length(), MAX_DRAG) / MAX_DRAG
	if power < 0.05:
		return

	var direction: Vector2 = raw.normalized()
	var velocity: Vector2 = direction * power * MAX_POWER

	_shots_left -= 1
	_update_ui()

	var projectile_scene: PackedScene = CANNONBALL_SCENE if _mode == GameManager.MINI_GAME_CANNON else ARROW_SCENE
	var projectile: RigidBody2D = projectile_scene.instantiate()
	projectile.global_position = launcher.global_position
	projectile.linear_velocity = velocity
	projectile.hit_target.connect(_on_target_hit)
	projectiles.add_child(projectile)

	if _shots_left == 0:
		_game_over = true
		result_label.text = tr("UI_GAME_OVER") % _score if tr("UI_GAME_OVER") != "UI_GAME_OVER" else "Game Over - Score: %d" % _score
		_celebrate(false)
		_record_and_navigate()

func _on_target_hit(target: Node) -> void:
	if target.is_queued_for_deletion():
		return
	_score += 100
	target.queue_free()
	_update_ui()
	if targets.get_child_count() == 1:
		_game_over = true
		result_label.text = tr("UI_VICTORY") % _score if tr("UI_VICTORY") != "UI_VICTORY" else "Fortress Breached! - Score: %d" % _score
		_celebrate(true)
		_record_and_navigate()

func _record_and_navigate() -> void:
	GameManager.record_mini_game_score(_mode, _chapter_index, _score)
	# Give the player a moment to see the result/confetti before leaving.
	await get_tree().create_timer(2.5).timeout
	if _return_scene.is_empty():
		SceneManager.pop()
	else:
		SceneManager.replace(_return_scene)

func _spawn_targets() -> void:
	for t in targets.get_children():
		t.queue_free()

	var battle_names := _pick_battle_names(6)
	var positions := _target_positions()
	var target_scene: PackedScene = FORTRESS_BLOCK_SCENE if _mode == GameManager.MINI_GAME_CANNON else FLAG_TARGET_SCENE
	for i in range(min(battle_names.size(), positions.size())):
		var target: StaticBody2D = target_scene.instantiate()
		target.position = positions[i]
		target.battle_name = battle_names[i]
		targets.add_child(target)

func _pick_battle_names(count: int) -> Array[String]:
	var current_battles: Array[String] = []
	var all_battles: Array[String] = []
	var sultan := GameManager.get_current_sultan()
	for battle in sultan.get("battles", []):
		var localized: Dictionary = HistoricalData.localize_battle(battle)
		var name_text: String = localized.get("name", "")
		if not name_text.is_empty():
			current_battles.append(name_text)

	for chapter in HistoricalData.get_chapters():
		for other_sultan in chapter.get("sultans", []):
			for battle in other_sultan.get("battles", []):
				var localized: Dictionary = HistoricalData.localize_battle(battle)
				var name_text: String = localized.get("name", "")
				if not name_text.is_empty():
					all_battles.append(name_text)

	all_battles.shuffle()
	var result: Array[String] = []
	# Ensure at least one target from the current sultan's battles.
	if not current_battles.is_empty():
		current_battles.shuffle()
		result.append(current_battles[0])

	for name in all_battles:
		if result.size() >= count:
			break
		if not name in result:
			result.append(name)
	return result

func _target_positions() -> Array[Vector2]:
	# Wall is at x = 420, top y = 740.
	return [
		Vector2(280, 560),  # front high
		Vector2(340, 720),  # front mid
		Vector2(260, 880),  # front low
		Vector2(500, 600),  # behind high (arc over wall)
		Vector2(560, 520),  # behind higher
		Vector2(520, 680),  # behind mid
	]

func _update_ui() -> void:
	score_label.text = tr("UI_SCORE") % _score
	shots_label.text = tr("UI_SHOTS") % _shots_left

func _celebrate(with_particles: bool = false) -> void:
	if _celebrate_tween != null and _celebrate_tween.is_valid():
		_celebrate_tween.kill()
	_player_node.position.y = _archer_base_y

	_celebrate_tween = create_tween().set_loops(3)
	_celebrate_tween.tween_property(_player_node, "position:y", _archer_base_y - 60, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_celebrate_tween.tween_property(_player_node, "position:y", _archer_base_y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_celebrate_tween.finished.connect(func(): _player_node.position.y = _archer_base_y)

	if with_particles:
		success_particles.emitting = true

func _reset_game() -> void:
	_score = 0
	_shots_left = MAX_SHOTS
	_game_over = false
	result_label.text = ""
	if _celebrate_tween != null and _celebrate_tween.is_valid():
		_celebrate_tween.kill()
	_player_node.position.y = _archer_base_y
	success_particles.emitting = false
	for p in projectiles.get_children():
		p.queue_free()
	_spawn_targets()
	_update_ui()

func _on_back_pressed() -> void:
	SceneManager.pop()
