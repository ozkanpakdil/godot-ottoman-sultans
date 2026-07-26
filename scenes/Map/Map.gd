extends Node3D

@onready var detail_panel: PanelContainer = %DetailPanel
@onready var city_name_label: Label = %CityNameLabel
@onready var city_desc_label: Label = %CityDescLabel
@onready var years_label: Label = %YearsLabel
@onready var sultans_label: Label = %SultansLabel
@onready var events_label: Label = %EventsLabel
@onready var go_button: Button = %GoButton
@onready var back_button: Button = %BackButton
@onready var hint_label: Label = %HintLabel
@onready var camera: Camera3D = %Camera3D
@onready var hotspots: Node3D = %Hotspots
@onready var globe: Node3D = %Globe
@onready var earth: MeshInstance3D = %Earth
@onready var portrait_texture_rect: TextureRect = %PortraitTextureRect
@onready var zoom_slider: HSlider = %ZoomSlider
@onready var zoom_in_button: Button = %ZoomInButton
@onready var zoom_out_button: Button = %ZoomOutButton

const GLOBE_RADIUS := 3.0
const ROTATION_SENSITIVITY := 0.005
const ZOOM_SIZE_MIN := 0.25
const ZOOM_SIZE_MAX := 24.0
const ZOOM_START_SIZE := 3.5
const ZOOM_SENSITIVITY := 1.0
const DRAG_THRESHOLD := 4.0

var _selected_chapter_index: int = -1

var _dragging := false
var _has_dragged := false
var _drag_start_pos := Vector2.ZERO
var _last_mouse_pos := Vector2.ZERO

func _ready() -> void:
	back_button.text = tr("UI_MAP_BACK")
	go_button.text = tr("UI_GO_TO_SULTAN")
	hint_label.text = tr("UI_MAP_HINT")

	back_button.pressed.connect(_on_back_pressed)
	go_button.pressed.connect(_on_go_pressed)
	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	zoom_slider.value_changed.connect(_on_zoom_slider_changed)

	_build_earth_mesh()
	_build_hotspots()
	_center_globe_on_turkey()
	_animate_initial_zoom()
	_hide_detail()

func _build_hotspots() -> void:
	var cities := HistoricalData.get_cities()
	for i in cities.size():
		var city: Dictionary = cities[i]
		var hotspot := _create_hotspot(i, city)
		hotspots.add_child(hotspot)

func _create_hotspot(index: int, city: Dictionary) -> Area3D:
	var area := Area3D.new()
	area.name = "City%d" % index
	area.set_meta("city_index", index)

	var pos := _lat_lon_to_position(city.get("latitude", 0.0), city.get("longitude", 0.0))
	area.position = pos

	# Visual marker: glowing sphere with city color.
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.7, 0.35)
	material.emission_enabled = true
	material.emission = Color(0.85, 0.7, 0.35)
	material.emission_energy_multiplier = 1.0
	mesh.material_override = material
	area.add_child(mesh)

	# Billboard portrait of the first sultan associated with this city.
	var sultan_slug := _first_sultan_slug(city)
	if not sultan_slug.is_empty():
		var sultan := HistoricalData.get_sultan_by_slug(sultan_slug)
		var portrait_path: String = sultan.get("portrait", "")
		if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
			var portrait := _create_portrait_billboard(portrait_path)
			portrait.position.y = 0.18
			area.add_child(portrait)

	# Collision for raycasting.
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.09
	collision.shape = shape
	area.add_child(collision)

	# Subtle bob animation.
	var tween := create_tween().set_loops()
	tween.tween_property(mesh, "position:y", 0.03, 0.8).from(0.0)
	tween.tween_property(mesh, "position:y", 0.0, 0.8)

	return area

func _first_sultan_slug(city: Dictionary) -> String:
	var periods: Array = city.get("capital_periods", [])
	if periods.size() > 0:
		var slugs: Array = periods[0].get("sultan_slugs", [])
		if slugs.size() > 0:
			return str(slugs[0])
	var events: Array = city.get("events", [])
	if events.size() > 0:
		return events[0].get("sultan_slug", "")
	return ""

func _create_portrait_billboard(portrait_path: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	mesh.mesh = quad

	var material := StandardMaterial3D.new()
	material.albedo_texture = load(portrait_path)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	return mesh

func _center_globe_on_turkey() -> void:
	# Center the globe on the approximate middle of modern Turkey so the
	# Ottoman heartland is visible when the map opens.
	var center := _lat_lon_to_position(39.0, 35.0)
	var yaw := atan2(center.x, center.z)
	var pitch := atan2(center.y, sqrt(center.x * center.x + center.z * center.z))
	globe.rotate_y(-yaw)
	globe.rotate_x(pitch)

func _animate_initial_zoom() -> void:
	camera.size = ZOOM_SIZE_MAX
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "size", ZOOM_START_SIZE, 1.5)
	tween.finished.connect(_update_zoom_slider)

func _update_zoom_slider() -> void:
	var t := (ZOOM_SIZE_MAX - camera.size) / (ZOOM_SIZE_MAX - ZOOM_SIZE_MIN)
	zoom_slider.set_value_no_signal(clampf(t * 100.0, 0.0, 100.0))

func _on_zoom_slider_changed(value: float) -> void:
	var t := value / 100.0
	camera.size = ZOOM_SIZE_MAX - t * (ZOOM_SIZE_MAX - ZOOM_SIZE_MIN)

func _on_zoom_in_pressed() -> void:
	_zoom(-1.0)

func _on_zoom_out_pressed() -> void:
	_zoom(1.0)

func _build_earth_mesh() -> void:
	# Build a custom sphere with equirectangular UVs so the NASA texture and
	# the city markers share the same lat/long coordinate system.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	const rings := 64
	const segments := 32

	for j in range(segments):
		var lat1 := 90.0 - j * 180.0 / segments
		var lat2 := 90.0 - (j + 1) * 180.0 / segments
		for i in range(rings):
			var lon1 := -180.0 + i * 360.0 / rings
			var lon2 := -180.0 + (i + 1) * 360.0 / rings
			_add_sphere_quad(st, lat1, lat2, lon1, lon2)

	earth.mesh = st.commit()

	var texture := load("res://assets/UI/earth_map.jpg")
	if texture == null:
		push_error("Failed to load earth_map.jpg texture")

	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	earth.set_surface_override_material(0, material)

func _add_sphere_quad(st: SurfaceTool, lat1: float, lat2: float, lon1: float, lon2: float) -> void:
	# Two triangles forming a quad, wound counter-clockwise when viewed from outside.
	_add_sphere_vertex(st, lat1, lon1)
	_add_sphere_vertex(st, lat1, lon2)
	_add_sphere_vertex(st, lat2, lon1)

	_add_sphere_vertex(st, lat2, lon1)
	_add_sphere_vertex(st, lat1, lon2)
	_add_sphere_vertex(st, lat2, lon2)

func _add_sphere_vertex(st: SurfaceTool, lat: float, lon: float) -> void:
	var pos := _lat_lon_to_position(lat, lon)
	var normal := pos.normalized()
	var u := (lon + 180.0) / 360.0
	var v := (90.0 - lat) / 180.0
	st.set_normal(normal)
	st.set_uv(Vector2(u, v))
	st.add_vertex(pos)

func _lat_lon_to_position(lat: float, lon: float) -> Vector3:
	var lat_rad := deg_to_rad(lat)
	var lon_rad := deg_to_rad(lon)
	var x := GLOBE_RADIUS * cos(lat_rad) * sin(lon_rad)
	var y := GLOBE_RADIUS * sin(lat_rad)
	var z := GLOBE_RADIUS * cos(lat_rad) * cos(lon_rad)
	return Vector3(x, y, z)

func _input(event: InputEvent) -> void:
	# Handle zoom in _input so it works even when _unhandled_input is not reached.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-ZOOM_SENSITIVITY)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(ZOOM_SENSITIVITY)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_has_dragged = false
				_drag_start_pos = event.position
				_last_mouse_pos = event.position
			else:
				_dragging = false
				if not _has_dragged:
					_raycast_select(event.position)
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var delta: Vector2 = motion.position - _last_mouse_pos
		_last_mouse_pos = motion.position
		if motion.position.distance_to(_drag_start_pos) > DRAG_THRESHOLD:
			_has_dragged = true
		_rotate_globe(delta)

func _rotate_globe(delta: Vector2) -> void:
	globe.rotate_y(delta.x * ROTATION_SENSITIVITY)
	globe.rotate_x(delta.y * ROTATION_SENSITIVITY)

func _zoom(amount: float) -> void:
	camera.size = clampf(camera.size + amount, ZOOM_SIZE_MIN, ZOOM_SIZE_MAX)
	_update_zoom_slider()

func _raycast_select(screen_pos: Vector2) -> void:
	var viewport := get_viewport()
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.from = ray_origin
	query.to = ray_origin + ray_dir * 100.0
	query.collide_with_areas = true
	query.collision_mask = 1

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		_hide_detail()
		return

	var collider: Node = result.get("collider", null)
	if collider is Area3D and collider.has_meta("city_index"):
		_show_detail(collider.get_meta("city_index"), screen_pos)
	else:
		_hide_detail()

func _show_detail(index: int, screen_pos: Vector2 = Vector2.ZERO) -> void:
	var city: Dictionary = HistoricalData.get_city(index)
	_selected_chapter_index = city.get("chapter_index", 0)

	city_name_label.text = HistoricalData.localize(city.get("name", {}))
	city_desc_label.text = tr(city.get("description_key", ""))
	years_label.text = _build_capital_years_text(city)
	sultans_label.text = _build_sultans_text(city)
	events_label.text = _build_events_text(city)
	go_button.text = tr("UI_GO_TO_SULTAN")

	var portrait_path := _city_portrait_path(city)
	if not portrait_path.is_empty():
		portrait_texture_rect.texture = load(portrait_path)
		portrait_texture_rect.visible = true
	else:
		portrait_texture_rect.visible = false

	detail_panel.visible = true
	_position_detail_panel(screen_pos)

func _city_portrait_path(city: Dictionary) -> String:
	var slug := _first_sultan_slug(city)
	if slug.is_empty():
		return ""
	var sultan := HistoricalData.get_sultan_by_slug(slug)
	return sultan.get("portrait", "")

func _build_capital_years_text(city: Dictionary) -> String:
	var periods: Array = city.get("capital_periods", [])
	if periods.is_empty():
		return ""
	var parts: Array = []
	for p in periods:
		var start: int = p.get("start", 0)
		var end: int = p.get("end", 0)
		parts.append("%d – %d" % [start, end])
	return tr("UI_CAPITAL_PERIOD") % ", ".join(parts)

func _build_sultans_text(city: Dictionary) -> String:
	var slugs_set := {}
	for p in city.get("capital_periods", []):
		for slug in p.get("sultan_slugs", []):
			slugs_set[slug] = true
	for e in city.get("events", []):
		var slug: String = e.get("sultan_slug", "")
		if not slug.is_empty():
			slugs_set[slug] = true

	if slugs_set.is_empty():
		return ""

	var names: Array = []
	for slug in slugs_set.keys():
		var sultan := HistoricalData.get_sultan_by_slug(slug)
		if not sultan.is_empty():
			names.append(HistoricalData.localize(sultan.get("name", {})))

	if names.is_empty():
		return ""
	names.sort()
	return tr("UI_SULTANS_HERE") + "\n" + "\n".join(names)

func _build_events_text(city: Dictionary) -> String:
	var events: Array = city.get("events", [])
	if events.is_empty():
		return ""

	var lines: Array = []
	lines.append(tr("UI_KEY_EVENTS"))
	for e in events:
		var le := HistoricalData.localize_event(e)
		var year: int = e.get("year", 0)
		lines.append("%d — %s\n%s" % [year, le["name"], le["description"]])
	return "\n".join(lines)

func _position_detail_panel(screen_pos: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	detail_panel.reset_size()
	var panel_size: Vector2 = detail_panel.size

	var offset := Vector2(16.0, 16.0)
	var target := screen_pos + offset

	if target.x + panel_size.x > viewport_size.x:
		target.x = screen_pos.x - panel_size.x - offset.x
	if target.y + panel_size.y > viewport_size.y:
		target.y = screen_pos.y - panel_size.y - offset.y

	target.x = clampf(target.x, 0.0, viewport_size.x - panel_size.x)
	target.y = clampf(target.y, 0.0, viewport_size.y - panel_size.y)

	detail_panel.global_position = target

func _hide_detail() -> void:
	detail_panel.visible = false
	_selected_chapter_index = -1

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu/MainMenu.tscn")

func _on_go_pressed() -> void:
	if _selected_chapter_index < 0:
		return
	GameManager.set_progress(_selected_chapter_index, 0)
	get_tree().change_scene_to_file("res://scenes/Timeline/Timeline.tscn")
