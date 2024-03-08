extends SubViewport

var screen_size: Vector2

# Called when the node enters the scene tree for the first time.
func _ready():
	screen_size = get_window().size
	size = screen_size
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
