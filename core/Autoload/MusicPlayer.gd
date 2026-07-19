extends CanvasLayer

@onready var audio_player: AudioStreamPlayer = %AudioStreamPlayer
@onready var track_label: Label = %TrackLabel
@onready var play_button: Button = %PlayButton
@onready var next_button: Button = %NextButton

var tracks: Array = []
var current_index: int = 0

func _ready() -> void:
	_scan_tracks()
	play_button.pressed.connect(_toggle_play)
	next_button.pressed.connect(_next_track)
	audio_player.finished.connect(_on_track_finished)

	if not tracks.is_empty():
		_load_track(0)
		audio_player.play()
		_update_ui()
	else:
		visible = false

func _scan_tracks() -> void:
	var dir := DirAccess.open("res://assets/audio")
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			var ext := file.get_extension().to_lower()
			if ext in ["ogg", "mp3", "wav"]:
				tracks.append("res://assets/audio/" + file)
			file = dir.get_next()
		tracks.sort()

func _load_track(idx: int) -> void:
	if tracks.is_empty():
		return
	current_index = idx % tracks.size()
	var path: String = tracks[current_index]
	var stream := ResourceLoader.load(path, "AudioStream") as AudioStream
	if stream:
		audio_player.stream = stream
		var display_name := path.get_file().get_basename().replace("_", " ")
		track_label.text = tr("UI_MUSIC_NOW_PLAYING") + ": " + display_name

func _toggle_play() -> void:
	if tracks.is_empty():
		return
	if audio_player.playing:
		audio_player.stop()
	else:
		if audio_player.stream == null:
			_load_track(current_index)
		audio_player.play()
	_update_ui()

func _next_track() -> void:
	if tracks.is_empty():
		return
	_load_track(current_index + 1)
	audio_player.play()
	_update_ui()

func _on_track_finished() -> void:
	_load_track(current_index + 1)
	audio_player.play()

func _update_ui() -> void:
	play_button.text = tr("UI_MUSIC_PAUSE") if audio_player.playing else tr("UI_MUSIC_PLAY")
	next_button.text = tr("UI_MUSIC_NEXT")

func set_muted(muted: bool) -> void:
	audio_player.volume_db = -80.0 if muted else 0.0

func is_muted() -> bool:
	return audio_player.volume_db <= -80.0

func toggle_mute() -> void:
	set_muted(not is_muted())
