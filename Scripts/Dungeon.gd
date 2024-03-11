@tool
extends Node3D

@onready var grid_map : GridMap = $GridMap
var player_start_pos: Vector3
var end_room_index: int
@export var start : bool = false : set = set_start
@export var startDungeon : bool = false : set = set_start_dungeon

var dun_cell_scene : PackedScene = preload("res://Scenes/cell.tscn")
var player: PackedScene = preload("res://Scenes/player.tscn")

var directions : Dictionary = {
	"up" : Vector3i.FORWARD,"down" : Vector3i.BACK,
	"left" : Vector3i.LEFT,"right" : Vector3i.RIGHT
}

func handle_none(cell:Node3D,dir:String):
	cell.call("remove_door_"+dir)
	
func handle_00(cell:Node3D,dir:String):
	cell.call("remove_wall_"+dir)
	cell.call("remove_door_"+dir)
func handle_01(cell:Node3D,dir:String):
	cell.call("remove_door_"+dir)
func handle_02(cell:Node3D,dir:String):
	cell.call("remove_wall_"+dir)
	cell.call("remove_door_"+dir)
func handle_10(cell:Node3D,dir:String):
	cell.call("remove_door_"+dir)
func handle_11(cell:Node3D,dir:String):
	cell.call("remove_wall_"+dir)
	cell.call("remove_door_"+dir)
func handle_12(cell:Node3D,dir:String):
	cell.call("remove_wall_"+dir)
	cell.call("remove_door_"+dir)
func handle_20(cell:Node3D,dir:String):
	cell.call("remove_wall_"+dir)
	cell.call("remove_door_"+dir)
func handle_21(cell:Node3D,dir:String):
	cell.call("remove_wall_"+dir)
func handle_22(cell:Node3D,dir:String):
	cell.call("remove_wall_"+dir)
	cell.call("remove_door_"+dir)

func _ready():
	generate()
	create_dungeon()
	$NavigationRegion3D.bake_navigation_mesh(false)

func set_start_dungeon(val:bool)->void:
	if Engine.is_editor_hint():
		create_dungeon()
func set_start(val:bool)->void:
	if Engine.is_editor_hint():
		generate()

@export_range(0,1) var survival_chance : float = 0.25
@export var border_size : int = 20 : set = set_border_size
func set_border_size(val : int)->void:
	border_size = val
	if Engine.is_editor_hint():
		visualize_border()

@export var room_number : int = 4
@export var room_margin : int = 1
@export var room_recursion : int = 15
@export_multiline var custom_seed : String = "" : set = set_seed 
func set_seed(val:String)->void:
	custom_seed = val
	seed(val.hash())

var room_tiles : Array[PackedVector3Array] = []
var room_positions : PackedVector3Array = []
var room_start_positions : PackedVector3Array = []
var room_scenes: Array = []

# border, mine: 



func create_dungeon():
	for c in $Mesh.get_children():
		$Mesh.remove_child(c)
		c.queue_free()
	var t : int = 0
	for cell in grid_map.get_used_cells():
		var cell_index : int = grid_map.get_cell_item(cell)
		if cell_index == 1 || cell_index == 2:
			var dun_cell : Node3D = dun_cell_scene.instantiate()
			dun_cell.position = Vector3(cell) + Vector3(0.5,0,0.5)
			$Mesh.add_child(dun_cell)
			dun_cell.set_owner($Mesh.owner)
			t += 1
			for i in 4:
				var cell_n : Vector3i = cell + directions.values()[i]
				var cell_n_index : int = grid_map.get_cell_item(cell_n)
				if cell_n_index ==-1\
				|| cell_n_index == 3:
					handle_none(dun_cell,directions.keys()[i])
				else:
					var key : String = str(cell_index) + str(cell_n_index)
					call("handle_"+key,dun_cell,directions.keys()[i])
		if t%10 == 9 : await get_tree().create_timer(0).timeout
	t = 0
	for i in range(room_positions.size()):
		t += 1
		var path: String = room_scenes[i]
		var scene = await load(path)
		var room = await scene.instantiate()
		room.position = Vector3(room_positions[i].x, room_positions[i].y + 0.5, room_positions[i].z)
		$Mesh.add_child(room)
		room.set_owner($Mesh.owner)
		if t%10 == 9 : await get_tree().create_timer(0).timeout
	var start_pos = Vector3(player_start_pos.x, player_start_pos.y + 2, player_start_pos.z)
	$Player.position = start_pos

func visualize_border():
	grid_map.clear()
	for i in range(-1,border_size+1):
		grid_map.set_cell_item( Vector3i(i,0,-1),3)
		grid_map.set_cell_item( Vector3i(i,0,border_size),3)
		grid_map.set_cell_item( Vector3i(border_size,0,i),3)
		grid_map.set_cell_item( Vector3i(-1,0,i),3)
	$DirectionalLight3D.position = Vector3(border_size / 2, 25,  border_size / 2)

func generate():
	for c in $Mesh.get_children():
		$Mesh.remove_child(c)
		c.queue_free()
	room_tiles.clear()
	room_positions.clear()
	var t : int = 0
	if custom_seed : set_seed(custom_seed)
	visualize_border()
	for i in room_number:
		t+=1
		make_room(room_recursion)
		if t%17 == 16: await get_tree().create_timer(0).timeout
	end_room_index = room_positions.size() - 1

	var rpv2 : PackedVector2Array = []
	var del_graph : AStar2D = AStar2D.new()
	var mst_graph : AStar2D = AStar2D.new()

	for p in room_positions:
		rpv2.append(Vector2(p.x,p.z))
		del_graph.add_point(del_graph.get_available_point_id(),Vector2(p.x,p.z))
		mst_graph.add_point(mst_graph.get_available_point_id(),Vector2(p.x,p.z))
	var delaunay : Array = Array(Geometry2D.triangulate_delaunay(rpv2))
	
	for i in delaunay.size()/3:
		var p1 : int = delaunay.pop_front()
		var p2 : int = delaunay.pop_front()
		var p3 : int = delaunay.pop_front()
		del_graph.connect_points(p1,p2)
		del_graph.connect_points(p2,p3)
		del_graph.connect_points(p1,p3)
	
	var visited_points : PackedInt32Array = []
	visited_points.append(randi() % room_positions.size())
	while visited_points.size() != mst_graph.get_point_count():
		var possible_connections : Array[PackedInt32Array] = []
		for vp in visited_points:
			for c in del_graph.get_point_connections(vp):
				if !visited_points.has(c):
					var con : PackedInt32Array = [vp,c]
					possible_connections.append(con)
					
		var connection : PackedInt32Array = possible_connections.pick_random()
		for pc in possible_connections:
			if rpv2[pc[0]].distance_squared_to(rpv2[pc[1]]) <\
			rpv2[connection[0]].distance_squared_to(rpv2[connection[1]]):
				connection = pc
	
		visited_points.append(connection[1])
		mst_graph.connect_points(connection[0],connection[1])
		del_graph.disconnect_points(connection[0],connection[1])
		
	var hallway_graph : AStar2D = mst_graph
	
	for p in del_graph.get_point_ids():
		for c in del_graph.get_point_connections(p):
			if c>p:
				var kill : float = randf()
				if survival_chance > kill :
					hallway_graph.connect_points(p,c)
					
	create_hallways(hallway_graph)
	
func make_room(rec: int) -> void:
	if !rec>0:
		return
	
	var desired_room
	if (room_positions.size() == 0):
		desired_room = Rooms.start_rooms.pick_random()
	else:
		desired_room = Rooms.regular_rooms.pick_random()
	var width : int = desired_room[1]
	var height : int = desired_room[2]
	
	var start_pos : Vector3i 
	start_pos.x = randi() % (border_size - width + 1)
	start_pos.z = randi() % (border_size - height + 1)
	
	for r in range(-room_margin,height+room_margin):
		for c in range(-room_margin,width+room_margin):
			var pos : Vector3i = start_pos + Vector3i(c,0,r)
			if grid_map.get_cell_item(pos) == 0:
				make_room(rec-1)
				return
	
	var room : PackedVector3Array = []
	room_scenes.append(desired_room[0])
	for r in height:
		for c in width:
			var pos : Vector3i = start_pos + Vector3i(c,0,r)
			grid_map.set_cell_item(pos,0)
			room.append(pos)
	room_tiles.append(room)
	var avg_x : float = start_pos.x + (float(width)/2)
	var avg_z : float = start_pos.z + (float(height)/2)
	var pos : Vector3 = Vector3(avg_x,0,avg_z)
	if room_positions.size() == 0:
		player_start_pos = pos
	room_positions.append(pos)
	room_start_positions.append(start_pos)
	
func create_hallways(hallway_graph: AStar2D):
	var hallways : Array[PackedVector3Array] = []
	for p in hallway_graph.get_point_ids():
		for c in hallway_graph.get_point_connections(p):
			if c>p:
				var room_from : PackedVector3Array = room_tiles[p]
				var room_to : PackedVector3Array = room_tiles[c]
				var tile_from : Vector3 = room_from[0]
				var tile_to : Vector3 = room_to[0]
				for t in room_from:
					if t.distance_squared_to(room_positions[c])<\
					tile_from.distance_squared_to(room_positions[c]):
						tile_from = t
				for t in room_to:
					if t.distance_squared_to(room_positions[p])<\
					tile_to.distance_squared_to(room_positions[p]):
						tile_to = t
				var hallway : PackedVector3Array = [tile_from,tile_to]
				hallways.append(hallway)
				grid_map.set_cell_item(tile_from,2)
				grid_map.set_cell_item(tile_to,2)
	var astar : AStarGrid2D = AStarGrid2D.new()
	astar.size = Vector2i.ONE * border_size
	astar.update()
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	
	for t in grid_map.get_used_cells_by_item(0):
		astar.set_point_solid(Vector2i(t.x,t.z))
	var _t : int = 0
	for h in hallways:
		_t +=1
		var pos_from : Vector2i = Vector2i(h[0].x,h[0].z)
		var pos_to : Vector2i = Vector2i(h[1].x,h[1].z)
		var hall : PackedVector2Array = astar.get_point_path(pos_from,pos_to)
		
		for t in hall:
			var pos : Vector3i = Vector3i(t.x,0,t.y)
			if grid_map.get_cell_item(pos) <0:
				grid_map.set_cell_item(pos,1)
		if _t%16 == 15: await get_tree().create_timer(0).timeout
	
