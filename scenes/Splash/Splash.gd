extends Control

# Initial splash screen shown on desktop runs after the engine finishes loading.
# The web build already has its own HTML splash, but this scene ensures the
# game logo is the first thing seen in exported desktop builds.

const SPLASH_DELAY := 2.0
const FADE_DURATION := 0.6

@onready var splash_texture: TextureRect = %SplashTexture
@onready var timer: Timer = %Timer

func _ready() -> void:
	timer.wait_time = SPLASH_DELAY
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

func _on_timer_timeout() -> void:
	var tween := create_tween()
	tween.tween_property(splash_texture, "modulate:a", 0.0, FADE_DURATION)
	tween.finished.connect(func():
		SceneManager.replace("res://scenes/Map/Map.tscn")
	)
