extends SceneTree

func _init():
	pass

func _ready() -> void:
	# Load the Timeline scene and test portrait loading
	var scene = load("res://scenes/Timeline/Timeline.tscn")
	var timeline = scene.instantiate()
	root.add_child(timeline)
	
	# Wait a frame for _ready to run
	await process_frame
	
	# Check if portrait loaded
	var portrait_rect = timeline.get_node("MarginContainer/VBoxContainer/PortraitRect")
	print("PortraitRect texture: ", portrait_rect.texture)
	print("PortraitRect visible: ", portrait_rect.visible)
	
	quit()