extends StaticBody2D

@onready var _name_label: Label = %NameLabel
@onready var _flag: Polygon2D = $Flag

var battle_name: String = "Battle" :
	set(value):
		battle_name = value
		if _name_label != null:
			_name_label.text = value

var _flag_base: PackedVector2Array = PackedVector2Array()
var _wave_offset: float = 0.0

func _ready() -> void:
	add_to_group("targets")
	_name_label.text = battle_name
	if _flag != null:
		_flag_base = _flag.polygon.duplicate()
		_wave_offset = randf() * TAU

func _process(delta: float) -> void:
	if _flag == null or _flag_base.is_empty():
		return
	_wave_offset += delta * 4.0
	var wave1: float = sin(_wave_offset) * 3.0
	var wave2: float = sin(_wave_offset + 1.2) * 2.5
	var waved: PackedVector2Array = PackedVector2Array()
	for i in range(_flag_base.size()):
		var p: Vector2 = _flag_base[i]
		# Wave the two outer/free corners (assumed to be indices 1 and 2).
		if i == 1:
			p.y += wave1
		elif i == 2:
			p.y += wave2
		waved.append(p)
	_flag.polygon = waved
