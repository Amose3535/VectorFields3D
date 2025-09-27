# VectorFieldBaseEmitter3D.gd
@tool
extends Node3D
class_name VectorFieldBaseEmitter3D
## A base class for all emitters to inherit from.
##
## VectorFieldBaseEmitter3D isn't meant to be used on its own. It's to be considered like a virtual class.[br]
## When inheriting VectorFieldBaseEmitter3D, if you want to see updates to VectorField3D's in the editor, remember to add @tool to the top of the script.
## VectorFieldBaseEmitter3D allows with its highly configurable API to  make your very own emitter with very specific properties.[br]
## VectorFieldBaseEmitter3D should be abstract considering the implementation BUT since this is actively being developed in 4.4 AND it's made to be also backwards-compatible it currently isn't.[br]

## The interaction layer determines the fields which this emitter will interact with.
@export_flags_3d_physics var interaction_layer = 1
## The max distance is a radial distance used by the vector fields for optimization purposes: Every field outisde the max_distance range won't even bother considering the contribution for this emitter.[br][br]For best results it's reccomended to use a max_distance >= a distance at which the vector are 0 or really close to it.
@export var max_distance : float = 1:
	set(new_distance):
		max_distance = new_distance
		_recalculate_parameters(new_distance)
		if Engine.is_editor_hint():
			_redraw_mesh()

@export_group("Debugging") 
@export var draw_debug_lines : bool = true:
	set(new_draw_state):
		draw_debug_lines = new_draw_state
		if Engine.is_editor_hint():
			_redraw_mesh()
@export var bounding_box_color : Color = Color.BLUE:
	set(new_color):
		if Engine.is_editor_hint():
			_redraw_mesh()


#region INTERNALS
## The StringName of the group containing all emitters
const EMITTER_GROUP : StringName = &"VectorFieldEmitters3D"
## The in-world size that this VectorFieldBaseEmitter3D occupies.
var world_size : Vector3 = Vector3.ONE * max_distance * 2
## The mesh that is responsible for drawing debug lines
var debug_mesh : MeshInstance3D = MeshInstance3D.new()
#endregion

## VectorFieldBaseEmitter's _ready() function.[br]NOTE: Remember to always add 'super._ready()' at the top of your ready function if you plan on using _ready().
func _ready() -> void:
	# Add the current VectorFieldPointEmitter into emitters Group
	if !is_in_group(EMITTER_GROUP):
		self.add_to_group(EMITTER_GROUP)
	
	_clear_debug_mesh()                   # Clear all possible debug meshes
	_instantiate_debug_mesh()             # Instantiate a new debug mesh
	_recalculate_parameters(max_distance) # Recalculate parameters
	_draw_debug_lines()                   # Draw initial state of VectorField3D
	
	if Engine.is_editor_hint():
		# Editor logic here
		return
	
	# Runtime logic here
	pass


## This is the function used to compute the vector contribution for a given point in space. It spits out the vector contribution as a Vector3 in magnitude form (basically local coordinates).
func get_vector_at_position(vector_pos : Vector3) -> Vector3:
	# Insert behavior in child class
	return Vector3.ZERO


#region INTERNAL FUNCTIONS
## The function that, when called is responsible for updating all parameters.
func _recalculate_parameters(new_max_distance : float = max_distance) -> void:
	world_size = Vector3.ONE * new_max_distance * 2
#endregion


#region DebugMesh functions

## function that first clears the old mesh and (if draw param is set to true) redraws the new one (handy when toggling draw state).
func _redraw_mesh() -> void:
	# Clear old surfaces
	if debug_mesh.mesh is ImmediateMesh:
		(debug_mesh.mesh as ImmediateMesh).clear_surfaces()
	# Redraw the debug lines ONLY if the draw_debug_lines param is enabled
	if draw_debug_lines:
		# TODO: Also redraw the lines ONLY if the previous mesh is the same as the new one (performance optimization)
		_draw_debug_lines()


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


## Draw Bounding box corresponding to AABB
func _draw_debug_lines() -> void:
	if not is_instance_valid(debug_mesh) or not (debug_mesh.mesh is ImmediateMesh):
		return
	
	(debug_mesh.mesh as ImmediateMesh).clear_surfaces()
	(debug_mesh.mesh as ImmediateMesh).surface_begin(Mesh.PRIMITIVE_LINES)
	
	# Compute offset to position the grid
	var offset = -world_size / 2.0
	# Draw the bounding box of the emitter
	_draw_bounding_box(offset)
	
	# End surface
	(debug_mesh.mesh as ImmediateMesh).surface_end()

## Helper per disegnare la scatola che delimita il campo
func _draw_bounding_box(offset: Vector3, bounding_color : Color = bounding_box_color):
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
