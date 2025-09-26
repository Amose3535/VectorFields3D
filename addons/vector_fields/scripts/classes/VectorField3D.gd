# VectorField3D.gd
@tool
@icon("res://addons/vector_fields/assets/images/VectorField3DIcon/VectorField3DIcon.svg")
extends Node3D
class_name VectorField3D
## VectorField3D implements a vector field in Godot
##
## A VectorField3D represents a region of space split into a three-dimensional grid in which each grid cell acts as the fundamental region of forces in that space.[br]To put it simply: Each cell contains the result of the contribute of all forces in that section of space.

#region signals
signal vf3d_entered_group(vf3d : VectorField3D)
signal vf3d_exited_group(vf3d : VectorField3D)
signal vf3d_activity_updated(vf3d: VectorField3D, new_activity_state: bool)
signal vf3d_update_interval_updated(vf3d: VectorField3D, new_interval: float)
signal vf3d_lod_updated(vf3d: VectorField3D, new_lod: int)
signal vf3d_vector_field_size_updated(vf3d: VectorField3D, new_vf_size: Vector3i)
#endregion



#region EXPORTS
## LOD (or level of detail) is used to compute the size of the building blocks of for VectorField3D using the formula `cube_size_side = 1/LOD`.[br]By default the minimum LOD available is 1 (hence the maximum cube size is 1*1*1  meters).
@export_range(1.0, 10000, 1.0, "or_greater") var LOD : int = 1:
	set(new_lod):
		# Set every internal variable accordingly
		LOD = new_lod
		_recalculate_parameters(new_lod, vector_field_size)
		_redraw_mesh()
		emit_signal("vf3d_lod_updated",new_lod)

## vector_field_size is the amount of LOD cubes each side of your VectorField3D has.[br]Example: if LOD = l and vector_field_size = (x,y,z) means i'll have a parallelepiped of dimensions (x,y,z)*(1/l) meters.
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
		_redraw_mesh()
		emit_signal("vf3d_vector_field_size_updated",new_field_size)

## How often (in seconds) should the vector field update its vectors.
@export var update_interval : float = 0.1:
	set(new_interval):
		update_interval = new_interval
		emit_signal("vf3d_update_interval_updated",new_interval)

## Toggles future updates
@export var active : bool = true:
	set(new_activity):
		active = new_activity
		emit_signal("vf3d_activity_updated",new_activity)

## InteractionLayer is the layer that defines the interaction between emitters and fields. Only emitters on the same laer as another field will be able to affect its vectors. 
@export_flags_3d_physics var interaction_layer = 1

@export_group("Debugging")
## Allows to draw or not the debug lines
@export var draw_debug_lines : bool = true:
	set(new_draw_state):
		draw_debug_lines = new_draw_state
		_redraw_mesh(new_draw_state)

@export var draw_vectors_only : bool = false:
	set(new_vec_draw_state):
		draw_vectors_only = new_vec_draw_state
		_redraw_mesh(draw_debug_lines,new_vec_draw_state)
#endregion



#region INTERNALS
## Corresponds to the length of the edge of a cube from the VectorField3D.[br]It's directly influenced by the LOD.
var cube_edge : float = 1/LOD
## The data structure containing the vector data in local position for each cell.[br]By default, without any emitter interference, should be an n-dimensional matrix containing Vector3.ZERO's
var vector_data : Array = []
## The in-world size that this field occupies.
var world_size : Vector3 = Vector3(vector_field_size)*cube_edge
## The mesh that is responsible for drawing debug lines
var debug_mesh : MeshInstance3D = MeshInstance3D.new()
#endregion



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Add the current VectorField3D into a custom group
	if !is_in_group("VectorFields3D"):
		self.add_to_group("VectorFields3D")
		emit_signal("vf3d_entered_group") # Emit specific signal
		
		#print("Added %s to group VectorFields3D!"%self)
	# Editor logic ---------------------------------------------------------------------------
	if Engine.is_editor_hint():
		_clear_debug_mesh()                             # Clear all possible debug meshes
		_instantiate_debug_mesh()                       # Instantiate a new debug mesh
		_recalculate_parameters(LOD, vector_field_size) # Recalculate parameters
		_draw_debug_lines()                             # Draw initial state of VectorField3D
		return
	# Runtime logic --------------------------------------------------------------------------
	_clear_debug_mesh()

# Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Generic logic --------------------------------------------------------------------------
	# 1. Get emitters from emitter layer ("VectorFieldEmitters3D").
	# 2. Cycle over emitters, skipping the ones with the wrong interaction layer.
	# 3. Iterate on each cell and add to the cell the contribute of that specific emitter.
	
	
	# Editor logic ---------------------------------------------------------------------------
	if Engine.is_editor_hint():
		return
	
	# Runtime logic --------------------------------------------------------------------------
	pass

# Called when the node is about to get deleted from tree
func _exit_tree() -> void:
	emit_signal("vf3d_exited_group")

#region INTERNAL FUNCTIONS
## The function used to recalculate the parameters
func _recalculate_parameters(new_lod=LOD, new_vector_field_size=vector_field_size):
	cube_edge = 1.0 / float(new_lod)
	world_size = Vector3(new_vector_field_size) * cube_edge
	_initialize_vector_data(new_vector_field_size) # Formats data structure to accept vectors in the new cells
	# La funzione _update_field_size() non è più strettamente necessaria se usi il metodo di disegno con ImmediateMesh
	# dal momento che la scala è gestita internamente dal disegno.
	# _update_field_size()


## The function responsible for resizing and updating the grid and its cells (reaction to resizing).[br]NOTE: This affects ONLY the grid in the editor since the global position of each cell is computed at runtime and not accessed as an actual physical objecy/region of space.
func _update_field_size():
	# Ho rimosso questa funzione, in quanto il disegno nell'editor
	# si basa sulla ricreazione delle linee, non sulla scalatura del nodo.
	pass


## The function responsible for reformatting the vector_data variable in order to handle the different sizes
func _initialize_vector_data(_vector_field_size = vector_field_size):
	# 1. Caching the dimensions to prevent mid-run changes 
	#    (though const prevents this, it's good practice for non-const variables)
	var cached_size: Vector3i = vector_field_size
	
	# Clear the member array to ensure a fresh start
	vector_data.clear()

	# Get dimensions for clearer loop reading
	var dim_x := cached_size.x
	var dim_y := cached_size.y
	var dim_z := cached_size.z
	
	# 2. Loop for the X-dimension (The outermost array, containing Y-arrays)
	for x in range(dim_x):
		var array_y = [] # The middle array (Y-dimension)
		
		# 3. Loop for the Y-dimension (Containing Z-arrays)
		for y in range(dim_y):
			var array_z = [] # The innermost array (Z-dimension)
			
			# 4. Loop for the Z-dimension (Populating with values)
			for z in range(dim_z):
				# Populate the innermost array with Vector3.ZERO
				array_z.append(Vector3.ZERO)
			
			# Add the initialized Z-array to the Y-array
			array_y.append(array_z)
		
		# Add the initialized Y-array to the main 3D grid array
		vector_data.append(array_y)
	
	# Optional: Verification print (OK)
	#print("3D Grid initialized. Dimensions: %d x %d x %d. Total elements: %d."%[dim_x, dim_y, dim_z, dim_x*dim_y*dim_z])
	#print(vector_data)
#endregion


#region DebugMesh functions

## function that first clears the old mesh and (if draw param is set to true) redraws the new one (handy when toggling draw state).
func _redraw_mesh(draw : bool = true, vectors_only : bool = false) -> void:
	# Clear old surfaces
	if debug_mesh.mesh is ImmediateMesh:
		(debug_mesh.mesh as ImmediateMesh).clear_surfaces()
	# Redraw the debug lines ONLY if the draw_debug_lines param is enabled
	if draw_debug_lines:
		# TODO: Also redraw the lines ONLY if the previous mesh is the same as the new one (performance optimization)
		_draw_debug_lines(vectors_only)


## The function used to delete every possible debug_mesh instance in the scene tree.
func _clear_debug_mesh() -> void:
	# Trovo e rimuovo l'istanza esistente
	for child in get_children():
		if child is MeshInstance3D and child.name == "DebugMesh":
			child.queue_free()


## The funciton used to spawn my debug mesh.
func _instantiate_debug_mesh() -> void:
	# Add a name to the node to identify it later
	debug_mesh.name = "DebugMesh"
	add_child(debug_mesh)
	
	# Create the ImmediateMesh
	var imm_mesh = ImmediateMesh.new()
	debug_mesh.mesh = imm_mesh
	
	# Create the material for the Mesh
	var new_material = StandardMaterial3D.new()
	new_material.vertex_color_use_as_albedo = true
	debug_mesh.material_override = new_material


## Draw grid  + debug vectors
func _draw_debug_lines(vectors_only : bool = false) -> void:
	if not is_instance_valid(debug_mesh) or not (debug_mesh.mesh is ImmediateMesh):
		return
	
	(debug_mesh.mesh as ImmediateMesh).clear_surfaces()
	(debug_mesh.mesh as ImmediateMesh).surface_begin(Mesh.PRIMITIVE_LINES)
	# Compute offset to position the grid
	var offset = -world_size / 2.0
	# Draw the bounding box of the VectorField3D if it's not displaying only the vectors
	if !vectors_only: _draw_bounding_box(offset)
	
	# temporary flag to determine if there's at LEAST one nonzero vector or not
	var nonzero_vector_flag : bool = false
	
	# Iterate on the vector_field_size to find the exact x,y,z coordinates on vector_data and extract its local vector direction
	for x in range(vector_field_size.x):
		for y in range(vector_field_size.y):
			for z in range(vector_field_size.z):
				var cell_pos_local = Vector3(x, y, z) * cube_edge + offset
				var vector_force : Vector3 = vector_data[x][y][z]
				
				# Draw grid (optional)
				if !vectors_only:
					add_line(cell_pos_local, cell_pos_local + Vector3(cube_edge, 0, 0), Color.DARK_GRAY)
					add_line(cell_pos_local, cell_pos_local + Vector3(0, cube_edge, 0), Color.DARK_GRAY)
					add_line(cell_pos_local, cell_pos_local + Vector3(0, 0, cube_edge), Color.DARK_GRAY)
				
				# Draw the vector only if  not null
				if not vector_force.is_zero_approx():
					add_line_relative(cell_pos_local + (Vector3.ONE * cube_edge) / 2.0, (vector_force.normalized() * cube_edge) / 2.0, Color.YELLOW)
					nonzero_vector_flag = true
	# If no vertices were added, add one single vertex to the center of the VectorField3D to prevent error spamming in the console.
	if !nonzero_vector_flag:
		add_line(global_position,global_position,Color.BLACK,true)
	# End surface
	(debug_mesh.mesh as ImmediateMesh).surface_end()

## Helper per disegnare la scatola che delimita il campo
func _draw_bounding_box(offset: Vector3, bounding_color : Color = Color.WEB_MAROON):
	var size = world_size
	var zff : float = 0.001*3 # z-fighting fixer
	var points = [
		offset + Vector3(-zff, -zff, -zff),                           # -|-|- quadrant
		offset + Vector3(size.x+zff, -zff, -zff),                     # +|-|- quadrant
		offset + Vector3(size.x+zff, size.y+zff, -zff),               # +|+|- quadrant
		offset + Vector3(-zff, size.y+zff, -zff),                     # -|+|- quadrant
		offset + Vector3(-zff, -zff, size.z+zff),                     # -|-|+ quadrant
		offset + Vector3(size.x+zff, -zff, size.z+zff),               # +|-|+ quadrant
		offset + Vector3(size.x+zff, size.y+zff, size.z+zff),         # +|+|+ quadrant
		offset + Vector3(-zff, size.y+zff, size.z+zff)                # -|+|+ quadrant
	]
	
	(debug_mesh.mesh as ImmediateMesh).surface_set_color(Color.WHITE)
	
	# Disegna gli spigoli della scatola
	add_line(points[0], points[1], bounding_color)
	add_line(points[1], points[2], bounding_color)
	add_line(points[2], points[3], bounding_color)
	add_line(points[3], points[0], bounding_color)
	
	add_line(points[4], points[5], bounding_color)
	add_line(points[5], points[6], bounding_color)
	add_line(points[6], points[7], bounding_color)
	add_line(points[7], points[4], bounding_color)
	
	add_line(points[0], points[4], bounding_color)
	add_line(points[1], points[5], bounding_color)
	add_line(points[2], points[6], bounding_color)
	add_line(points[3], points[7], bounding_color)


## Adds a line to an open surface from a point in space "from" to a point in space "to" with a certain color "color"
func add_line(from : Vector3, to : Vector3, color : Color = Color(1,1,1,1), force : bool = false):
	# Early return for points too close to eachother (set force = true to draw a line on the same point)
	if from.is_equal_approx(to) && !force: return
	
	# Early return if the debug_mesh mesh isn't an ImmediateMesh
	if !(debug_mesh.mesh is ImmediateMesh): return
	
	(debug_mesh.mesh as ImmediateMesh).surface_set_color(color)
	
	# Add from and to vertices (absolute coordinates)
	(debug_mesh.mesh as ImmediateMesh).surface_add_vertex(from)
	(debug_mesh.mesh as ImmediateMesh).surface_add_vertex(to)

## Adds a line to an open surface in space from point "from" to point "from+to_relative" with a certain color "color"
func add_line_relative(from : Vector3, to_relative : Vector3, color : Color) -> void:
	add_line(from, from + to_relative, color)


## Adds a line to an open surface from a point in space "from" to a point in space "to" with a certain color "color"
func draw_line(from : Vector3, to : Vector3, color : Color = Color(1,1,1,1)):
	# Create a new surface on  which we can draw the line
	(debug_mesh.mesh as ImmediateMesh).surface_begin(Mesh.PRIMITIVE_LINES)
	# Early return for points too close to eachother (comment the next line if you want to purposefully draw a point for whatever reason)
	if from.is_equal_approx(to): return
	
	# Early return if the debug_mesh mesh isn't an ImmediateMesh
	if !(debug_mesh.mesh is ImmediateMesh): return
	
	(debug_mesh.mesh as ImmediateMesh).surface_set_color(color)
	
	# Add from and to vertices (absolute coordinates)
	(debug_mesh.mesh as ImmediateMesh).surface_add_vertex(from)
	(debug_mesh.mesh as ImmediateMesh).surface_add_vertex(to)
	
	# Close surface
	(debug_mesh.mesh as ImmediateMesh).surface_end()
	

## Adds a line to an open surface in space from point "from" to point "from+to_relative" with a certain color "color"
func draw_line_relative(from : Vector3, to_relative : Vector3, color : Color) -> void:
	draw_line(from, from + to_relative, color)
#endregion
