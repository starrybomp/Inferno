extends CharacterBody3D

var player = null
var attacked = false
var health = 10
var max_health = 10

const SPEED = 4.0

@export var player_path: NodePath
@onready var nav_agent = $NavigationAgent3D

func _ready():
	player = get_node(player_path)
	
func hit(bullet):
	health -= player.damage
	$GPUParticles3D.emitting = true
	if health <= 0:
		$GPUParticles3D.emitting = false
		$GPUParticles3D.emitting = true
		$GPUParticles3D.amount = $GPUParticles3D.amount * 3
		queue_free()

func _process(delta):
	$Label3D.text = str(health) + "/" + str(max_health)
	velocity = Vector3.ZERO
	nav_agent.set_target_position(player.global_transform.origin)
	var next_nav_point = nav_agent.get_next_path_position()
	velocity = (next_nav_point - global_transform.origin).normalized() * SPEED
	move_and_slide()
