extends SceneTree

func _init():
	pass

func _ready():
	var path = "res://assets/sultans/osman_i.jpg"
	print("ResourceLoader.exists: ", ResourceLoader.exists(path))
	var tex = load(path)
	print("Loaded texture: ", tex)
	if tex:
		print("Texture size: ", tex.get_size())
	quit()