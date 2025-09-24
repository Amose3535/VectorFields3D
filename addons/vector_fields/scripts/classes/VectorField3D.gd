# VectorField3D.gd
#
extends Node3D
class_name VectorField3D
## VectorField3D implements a vector field in Godot
##
## A VectorField3D represents a region of space split into a three-dimensional grid in which each grid cell acts as the fundamental region of forces in that space.[br]To put it simply: Each cell contains the result of the contribute of all forces in that section of space.


const DEBUG_DRAW = preload("res://addons/vector_fields/scenes/utils/DebugDraw.tscn")


## LOD (or level of detail) is used to compute the size of the building blocks of for VectorField3D using the formula `cube_size_side = 1/LOD`.[br]By default the minimum LOD available is 1 (hence the maximum cube size is 1*1*1  meters).
@export_range(1.0,10000,1.0,"or_greater") var LOD : int = 1:
	set(new_lod):
		# Set every internal variable accordingly
		_recalculate_parameters(new_lod,vector_field_size)
		

## vector_field_size is the amount of LOD cubes each side of your VectorField3D has.[br]Example: if LOD = l and vector_field_size = (x,y,z) means i'll have a parallelepiped of dimensions (x,y,z)*(1/l) meters
@export var vector_field_size : Vector3i = Vector3i(1,1,1):
	set(new_field_size):
		# If ANY of the components are 0 or smaller then default to 1x1x1 area.
		if new_field_size.x < 1 or new_field_size.y < 1 or new_field_size.z < 1:
			push_warning("[VectorField3D&] | WARN: Unable to create vector field. vector_field_size should be at least (1,1,1)!")
			vector_field_size = Vector3i.ONE
		# AFTER validating the new_field_size, set every internal variable
		_recalculate_parameters(LOD,new_field_size)

#region INTERNALS
## Corresponds to the length of the edge of a cube from the VectorField3D.[br]It's directly influenced by the LOD.
var cube_edge : float = 1/LOD
## The data structure containing the vector data in local position for each cell.[br]By default, without any emitter interference, should be an n-dimensional matrix containing Vector3.ZERO's
var vector_data : Array = [[[Vector3.ZERO]]]
## The in-world size that this field occupies.
var world_size : Vector3 = Vector3(vector_field_size)*cube_edge
## The mesh that is responsible for drawing debug lines
var debug_mesh : MeshInstance3D = MeshInstance3D.new()
#endregion



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Clear all possible instances of the debug mesh from previous runs (either first editor, then game or vice versa)
	_clear_debug_mesh()
	# Add my debug mesh to the scene independenly of editor/game run.
	_instantiate_debug_mesh()
	
	# Early return. To add functionality when the node is IN editor add code between ready and if clause	
	if Engine.is_editor_hint():
		return
	
	# Add the current VectorField3D into a custom group
	self.add_to_group("VectorFields/3D")




# Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	## For every physics process clear current instances of any surfaces.
	if debug_mesh.mesh is ImmediateMesh:
			(debug_mesh.mesh as ImmediateMesh).clear_surfaces()

## The funciton used to spawn my debug mesh.
func _instantiate_debug_mesh() -> void:
	add_child(debug_mesh)                            # Add debug mesh to scene
	var new_material = StandardMaterial3D.new()      # Create material for mesh
	new_material.vertex_color_use_as_albedo = true   # Set vertex color as albedo to true
	debug_mesh.material_override = new_material      # Add meterial to mesh material_override

## The function used to delete every possible debug_mesh instance in the scene tree.
func _clear_debug_mesh() -> void:
	for child in get_children():
		if child == debug_mesh:
			child.queue_free()

## The function used to recalculate the parameters
func _recalculate_parameters(new_lod=LOD,new_vector_field_size=vector_field_size):
	cube_edge = 1.0 / new_lod
	world_size = Vector3(vector_field_size) * cube_edge
	_format_vector_data(new_vector_field_size) # Formats data structure to accept vectors in the new cells
	_update_field_size() # Updates scale and offset of grid


## The function responsible for resizing and updating the grid and its cells (reaction to resizing).[br]NOTE: This affects ONLY the grid in the editor since the global position of each cell is computed at runtime and not accessed as an actual physical objecy/region of space.
func _update_field_size():
	#var my_gizmo : EditorNode3DGizmo = EditorNode3DGizmo.new()
	#my_gizmo.add_handles(PackedVector3Array())
	#self.add_gizmo(my_gizmo)
	pass

## The function resposible for reformatting the vector_data variable in order to handle the different sizes
func _format_vector_data(_vector_field_size = vector_field_size):
	# Store the size of the vector field to prevent rewriting mid-use
	var cached_size : Vector3i = _vector_field_size
	# Set the vector_data variable to be a three-dimensional array: vector_data=[[[e1,e2,...]]], vector_data[0]=[[e1,e2,...]], vector_data[0][0]=[e1,e2,...], vector_data[0][0][0]=e1
	vector_data = [[[]]]
	# Resize the x dimension to fit the x cells
	if vector_data.size() != cached_size.x: vector_data.resize(cached_size.x)
	for x in range(cached_size.x):
		# Resize the y dimension to fit the y cells
		if vector_data[x].size() != cached_size.y: vector_data.resize(cached_size.y)
		for y in range(cached_size.y):
			# Resize the y dimension to fit the y cells
			if vector_data[x][y].size() != cached_size.z: vector_data.resize(cached_size.z)
			for z in range(cached_size.z):
				# Populate each cell with Vector3.ZERO
				vector_data[x][y][z] = Vector3.ZERO


#region DebugMesh functions

## Draws a line from a point in space "from" to a point in space "to" with a certain color "color"
func draw_line(from : Vector3, to : Vector3, color : Color = Color(1,1,1,1)):
	# Early return for points too close to eachother (comment the next line if you want to purposefully draw a point for whatever reason)
	if from.is_equal_approx(to): return
	
	# Early return if the debug_mesh mesh isn't an ImmediateMesh
	if !(debug_mesh.mesh is ImmediateMesh): return
	
	# Create a new surface of type "primitive liens" (every two vertices a line is created)
	(debug_mesh.mesh as ImmediateMesh).surface_begin(Mesh.PRIMITIVE_LINES)
	# Color the surface with "color"
	(debug_mesh.mesh as ImmediateMesh).surface_set_color(color)
	
	# Add from and to vertices (absolute coordinates)
	(debug_mesh.mesh as ImmediateMesh).surface_add_vertex(from)
	(debug_mesh.mesh as ImmediateMesh).surface_add_vertex(to)
	
	# Finally close the surface and apply changes made to the mesh
	(debug_mesh.mesh as ImmediateMesh).surface_end()

## Draws a line in space from point "from" to point "from+to_relative" with a certain color "color"
func draw_line_relative(from : Vector3, to_relative : Vector3, color : Color) -> void:
	draw_line(from, from + to_relative, color)
#endregion
