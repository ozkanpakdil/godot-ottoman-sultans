extends RigidBody2D

signal hit_target(target: Node)

@onready var _ttl: Timer = $Timer

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	_ttl.timeout.connect(queue_free)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("targets"):
		hit_target.emit(body)
		queue_free()
		return

	# Stick into walls/ground briefly, then remove.
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	_ttl.start()
