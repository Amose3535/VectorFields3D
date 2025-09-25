# VectorField3D.gd
@tool
extends Node3D
class_name VectorField3D
## VectorField3D implements a vector field in Godot
##
## A VectorField3D represents a region of space split into a three-dimensional grid in which each grid cell acts as the fundamental region of forces in that space.[br]To put it simply: Each cell contains the result of the contribute of all forces in that section of space.


## LOD (or level of detail) is used to compute the size of the building blocks of for VectorField3D using the formula `cube_size_side = 1/LOD`.[br]By default the minimum LOD available is 1 (hence the maximum cube size is 1*1*1  meters).
@export_range(1.0, 10000, 1.0, "or_greater") var LOD : int = 1:
	set(new_lod):
		# Set every internal variable accordingly
		LOD = new_lod
		_recalculate_parameters(new_lod, vector_field_size)

## vector_field_size is the amount of LOD cubes each side of your VectorField3D has.[br]Example: if LOD = l and vector_field_size = (x,y,z) means i'll have a parallelepiped of dimensions (x,y,z)*(1/l) meters
@export var vector_field_size : Vector3i = Vector3i(1,1,1):
	set(new_field_size):
		# If ANY of the components are 0 or smaller then default to 1x1x1 area.
		if new_field_size.x < 1 or new_field_size.y < 1 or new_field_size.z < 1:
			push_warning("[VectorField3D] | WARN: Unable to create vector field. vector_field_size should be at least (1,1,1)!")
			vector_field_size = Vector3i.ONE
		else:
			vector_field_size = new_field_size
		# AFTER validating the new_field_size, set every internal variable
		_recalculate_parameters(LOD, new_field_size)

@export_group("Debugging")
## Allows to draw or not the debug lines
@export var draw_debug_lines : bool = true
## Determines the amount of time between updates
@export var debug_update_time : float = 0.3

#region INTERNALS
## Corresponds to the length of the edge of a cube from the VectorField3D.[br]It's directly influenced by the LOD.
var cube_edge : float = 1/LOD
## The data structure containing the vector data in local position for each cell.[br]By default, without any emitter interference, should be an n-dimensional matrix containing Vector3.ZERO's
var vector_data : Array = [[[Vector3.ZERO]]]
## The in-world size that this field occupies.
var world_size : Vector3 = Vector3(vector_field_size)*cube_edge
## The mesh that is responsible for drawing debug lines
var debug_mesh : MeshInstance3D = MeshInstance3D.new()
## The time from the last debug mesh update
var last_update_time : float = 0.0
## The mesh state of the previous update
var previous_mesh = ImmediateMesh.new()
#endregion



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Editor logic ---------------------------------------------------------------------------
	if Engine.is_editor_hint():
		_clear_debug_mesh()                             # Clear all possible debug meshes
		_instantiate_debug_mesh()                       # Instantiate a new debug mesh
		_recalculate_parameters(LOD, vector_field_size) # Recalculate parameters
		_draw_debug_lines()                             # Draw initial state of VectorField3D
		return
	# Runtime logic --------------------------------------------------------------------------
	_clear_debug_mesh()
	# Add the current VectorField3D into a custom group
	self.add_to_group("VectorFields/3D")


# Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Editor logic ---------------------------------------------------------------------------
	# Update the debug mesh only when in editor:
	if Engine.is_editor_hint():
		last_update_time += delta # Update timer
		# If the interval has expired then redraw the mesh and restart the timer
		if last_update_time >= debug_update_time:
			last_update_time -= debug_update_time
			
			# - Redraw -
			
			# Clear old surfaces
			if debug_mesh.mesh is ImmediateMesh:
				(debug_mesh.mesh as ImmediateMesh).clear_surfaces()
			# Redraw the debug lines ONLY if the draw_debug_lines param is enabled
			if draw_debug_lines:
				# TODO: Also redraw the lines ONLY if the previous mesh is the same as the new one (performance optimization)
				_draw_debug_lines()
	
	# Runtime logic --------------------------------------------------------------------------
	# Example: Update field based on emitters.
	# _update_field_from_emitters()
	# _draw_debug_lines()


## The function used to recalculate the parameters
func _recalculate_parameters(new_lod=LOD, new_vector_field_size=vector_field_size):
	cube_edge = 1.0 / float(new_lod)
	world_size = Vector3(new_vector_field_size) * cube_edge
	_format_vector_data(new_vector_field_size) # Formats data structure to accept vectors in the new cells
	# La funzione _update_field_size() non è più strettamente necessaria se usi il metodo di disegno con ImmediateMesh
	# dal momento che la scala è gestita internamente dal disegno.
	# _update_field_size()


## The function responsible for resizing and updating the grid and its cells (reaction to resizing).[br]NOTE: This affects ONLY the grid in the editor since the global position of each cell is computed at runtime and not accessed as an actual physical objecy/region of space.
func _update_field_size():
	# Ho rimosso questa funzione, in quanto il disegno nell'editor
	# si basa sulla ricreazione delle linee, non sulla scalatura del nodo.
	pass


## The function responsible for reformatting the vector_data variable in order to handle the different sizes
func _format_vector_data(_vector_field_size = vector_field_size):
	# Store the size of the vector field to prevent rewriting mid-use
	var cached_size : Vector3i = _vector_field_size
	
	# Un metodo più robusto per ridimensionare un array 3D.
	vector_data.resize(cached_size.x)
	for x in range(cached_size.x):
		if vector_data[x] == null:
			vector_data[x] = []
		vector_data[x].resize(cached_size.y)
		for y in range(cached_size.y):
			if vector_data[x][y] == null:
				vector_data[x][y] = []
			vector_data[x][y].resize(cached_size.z)
			for z in range(cached_size.z):
				# Popolare ogni cella con Vector3.ZERO
				vector_data[x][y][z] = Vector3.ZERO
	# Aggiunto un vettore di esempio per il debug
	if vector_data.size() > 0 and vector_data[0].size() > 0 and vector_data[0][0].size() > 0:
		vector_data[0][0][0] = Vector3(5, 5, 5)



#region DebugMesh functions

## The function used to delete every possible debug_mesh instance in the scene tree.
func _clear_debug_mesh() -> void:
	# Trovo e rimuovo l'istanza esistente
	for child in get_children():
		if child is MeshInstance3D and child.name == "DebugMesh":
			child.queue_free()


## The funciton used to spawn my debug mesh.
func _instantiate_debug_mesh() -> void:
	# Aggiungo un nome al nodo per poterlo identificare dopo
	debug_mesh.name = "DebugMesh"
	add_child(debug_mesh)
	
	# Crea l'ImmediateMesh
	var imm_mesh = ImmediateMesh.new()
	debug_mesh.mesh = imm_mesh
	
	# Crea il materiale per il mesh
	var new_material = StandardMaterial3D.new()
	new_material.vertex_color_use_as_albedo = true
	debug_mesh.material_override = new_material

## Disegna la griglia e i vettori di debug
func _draw_debug_lines() -> void:
	if not is_instance_valid(debug_mesh) or not (debug_mesh.mesh is ImmediateMesh):
		return
	
	(debug_mesh.mesh as ImmediateMesh).clear_surfaces()
	(debug_mesh.mesh as ImmediateMesh).surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Calcolo l'offset per centrare la griglia
	var offset = -world_size / 2.0
	
	# Disegna la scatola che rappresenta il campo
	_draw_bounding_box(offset)

	# Itera e disegna i vettori
	for x in range(vector_field_size.x):
		for y in range(vector_field_size.y):
			for z in range(vector_field_size.z):
				var cell_pos_local = Vector3(x, y, z) * cube_edge + offset
				var vector_force = vector_data[x][y][z]
				
				# Disegna la griglia (opzionale)
				draw_line(cell_pos_local, cell_pos_local + Vector3(cube_edge, 0, 0), Color.DARK_GRAY)
				draw_line(cell_pos_local, cell_pos_local + Vector3(0, cube_edge, 0), Color.DARK_GRAY)
				draw_line(cell_pos_local, cell_pos_local + Vector3(0, 0, cube_edge), Color.DARK_GRAY)
				
				# Disegna il vettore solo se non è nullo
				if not vector_force.is_zero_approx():
					draw_line_relative(cell_pos_local + Vector3.ONE * cube_edge / 2.0, vector_force, Color.YELLOW)
	
	(debug_mesh.mesh as ImmediateMesh).surface_end()

## Helper per disegnare la scatola che delimita il campo
func _draw_bounding_box(offset: Vector3):
	var size = world_size
	var points = [
		offset,
		offset + Vector3(size.x, 0, 0),
		offset + Vector3(size.x, size.y, 0),
		offset + Vector3(0, size.y, 0),
		offset + Vector3(0, 0, size.z),
		offset + Vector3(size.x, 0, size.z),
		offset + Vector3(size.x, size.y, size.z),
		offset + Vector3(0, size.y, size.z)
	]
	
	(debug_mesh.mesh as ImmediateMesh).surface_set_color(Color.WHITE)
	
	# Disegna gli spigoli della scatola
	draw_line(points[0], points[1], Color.WEB_MAROON)
	draw_line(points[1], points[2], Color.WEB_MAROON)
	draw_line(points[2], points[3], Color.WEB_MAROON)
	draw_line(points[3], points[0], Color.WEB_MAROON)
	
	draw_line(points[4], points[5], Color.WEB_MAROON)
	draw_line(points[5], points[6], Color.WEB_MAROON)
	draw_line(points[6], points[7], Color.WEB_MAROON)
	draw_line(points[7], points[4], Color.WEB_MAROON)
	
	draw_line(points[0], points[4], Color.WEB_MAROON)
	draw_line(points[1], points[5], Color.WEB_MAROON)
	draw_line(points[2], points[6], Color.WEB_MAROON)
	draw_line(points[3], points[7], Color.WEB_MAROON)
	
## Helper per aggiungere una linea al mesh corrente
func _add_line(from: Vector3, to: Vector3):
	(debug_mesh.mesh as ImmediateMesh).surface_add_vertex(from)
	(debug_mesh.mesh as ImmediateMesh).surface_add_vertex(to)

## Draws a line from a point in space "from" to a point in space "to" with a certain color "color"
func draw_line(from : Vector3, to : Vector3, color : Color = Color(1,1,1,1)):
	# Early return for points too close to eachother (comment the next line if you want to purposefully draw a point for whatever reason)
	if from.is_equal_approx(to): return
	
	# Early return if the debug_mesh mesh isn't an ImmediateMesh
	if !(debug_mesh.mesh is ImmediateMesh): return
	
	(debug_mesh.mesh as ImmediateMesh).surface_set_color(color)
	
	# Add from and to vertices (absolute coordinates)
	(debug_mesh.mesh as ImmediateMesh).surface_add_vertex(from)
	(debug_mesh.mesh as ImmediateMesh).surface_add_vertex(to)

## Draws a line in space from point "from" to point "from+to_relative" with a certain color "color"
func draw_line_relative(from : Vector3, to_relative : Vector3, color : Color) -> void:
	draw_line(from, from + to_relative, color)
#endregion
