extends StaticBody2D

@onready var _name_label: Label = %NameLabel

var battle_name: String = "Battle" :
	set(value):
		battle_name = value
		if _name_label != null:
			_name_label.text = value

func _ready() -> void:
	add_to_group("targets")
	_name_label.text = battle_name
