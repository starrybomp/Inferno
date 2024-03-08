extends Camera3D

@onready var player_camera = $"../../../Head/Camera3D"

func _process(delta):
	global_transform = player_camera.global_transform
	fov = player_camera.fov
	global_transform.basis = player_camera.global_transform.basis
