# VectorFieldBaseEmitter3D.gd
@tool
extends Node3D
class_name VectorFieldBaseEmitter3D
## A base class for all emitters to inherit from.
##
## VectorFieldBaseEmitter3D isn't meant to be used on its own. It's to be considered like a virtual class.[br]
## When inheriting VectorFieldBaseEmitter3D, if you want to see updates to VectorField3D's in the editor, remember to add @tool to the top of the script.
## VectorFieldBaseEmitter3D allows with its highly configurable API to  make your very own emitter with very specific properties.[br]
## VectorFieldBaseEmitter3D should be abstract considering the implementation BUT since this is actively being developed in 4.4 AND it's made to be also backwards-compatible it currently isn't.[br]

#region EXPORTS
## The interaction layer determines the fields which this emitter will interact with.
@export_flags_3d_physics var interaction_layer = 1:
	set(new_interaction_layer):
		interaction_layer=new_interaction_layer
		request_update()
		
## The maximum world size of the emitter's influence zone (the Bounding Box for force contribution).
@export var max_size : Vector3 = Vector3.ONE * 2.0: # Default size for a 2x2x2 box
	set(new_size):
		max_size = new_size.abs() # Ensure no negative values
		_recalculate_parameters(max_size)
		request_update()
		if Engine.is_editor_hint():
			_redraw_mesh()

## The minimum magnitude a vector must have to be considered non-zero. [br]
## Any vector with a magnitude below this value will be clamped to Vector3.ZERO.[br]
## This allows the creation of a zero-force sphere/ellipsoid (dead zone) around the emitter.[br]
@export var min_magnitude: float = 0.0:
	set(new_magnitude):
		min_magnitude = max(0.0, new_magnitude) # Ensures the value is not negative
		request_update()

@export_group("Debugging")
@export var draw_debug_lines : bool = true:
	set(new_draw_state):
		draw_debug_lines = new_draw_state
		if Engine.is_editor_hint():
			_redraw_mesh()
@export var bounding_box_color : Color = Color.BLUE:
	set(new_color):
		bounding_box_color = new_color
		if Engine.is_editor_hint():
			_redraw_mesh()
#endregion

#region INTERNALS
## The StringName of the group containing all emitters
const EMITTER_GROUP : StringName = &"VectorFieldEmitters3D"
## The in-world size that this VectorFieldBaseEmitter3D occupies.
var world_size : Vector3 = max_size
## The MeshInstance that is responsible for displaying the debug lines
var debug_mesh : MeshInstance3D = MeshInstance3D.new()
## The position previously used by the notification function
var old_position : Vector3 = Vector3()
## The world size previously used by the notification function
var old_size : Vector3 = Vector3()
#endregion

## VectorFieldBaseEmitter's _ready() function.[br]NOTE: Remember to always add 'super._ready()' at the top of your ready function if you plan on using it in a child script.
func _ready() -> void:
	# Requests notifications on transform change
	set_notify_transform(true)
	# Add the current VectorFieldPointEmitter into emitters Group
	if !is_in_group(EMITTER_GROUP):
		self.add_to_group(EMITTER_GROUP)
	
	# Connect tree exited signal to _on_tree_Exited
	if !tree_exited.is_connected(Callable(_on_tree_exited)):
		tree_exited.connect(Callable(_on_tree_exited))
	
	
	_clear_debug_mesh()                                               # Clear all possible debug meshes
	_instantiate_debug_mesh()                                         # Instantiate a new debug mesh
	_recalculate_parameters(max_size)                                 # Recalculate parameters using max_size
	notify_fields_of_update(self.global_position, self.world_size)    # After everything has been done, notify fields of update (node is ready)
	if Engine.is_editor_hint():
		_draw_debug_lines()                                               # Draw initial state of VectorField3D
		return
	
	# Runtime logic here
	pass

## VectorFieldBaseEmitter's _notification(what: int) function.[br]NOTE: Remember to always add 'super._notification(what)' at the top of your notification function if you plan on using it in a child script.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			var reset_rot_or_scale : bool = false
			# If the rotation and scale are already reset there's no need to set them
			if self.rotation != Vector3(0,0,0) || self.scale != Vector3(1,1,1):
				reset_rot_or_scale = true
			
			# If i need to reset the rotation or scale, do that
			if reset_rot_or_scale:
				print("[VectorFieldBaseEmitter3D] Vector field emitters can't be rotated or scaled.")
				# Get the current transform
				var current_transform = self.transform
				# Orthonormalize it and reset its basis
				current_transform = current_transform.orthonormalized()
				current_transform.basis = Basis() # (Reset rotation and scale to (1,1,1) )
				# Finally replace self.transform with the fixed one
				self.transform = current_transform
			# Otherwise...
			else:
				# Notify fields of an update and update old transform variable (only when necessary: not when trying to rotate)
				request_update()


func _enter_tree() -> void:
	if !is_inside_tree():
		return
	notify_fields_of_update(self.global_position, self.world_size)

func _on_tree_exited() -> void:
	#print("Exited tree") # OK! ( check )
	if !is_inside_tree():
		return
	notify_fields_of_update(Vector3(), Vector3(), true)


#region INTERNAL FUNCTIONS

## The function used to request an update on the fields.[br]
## On the first frame it might cause issues (untested) since the first old_position is Vector3() but other than that should be fine.
func request_update(complete : bool = false) -> void:
	if !is_inside_tree():
		return
	# Notify the fields of an update with the previous transform
	notify_fields_of_update(old_position,old_size,complete)
	# Then update it to
	old_position = self.global_position
	old_size = self.max_size

## The function that, when called is responsible for updating all parameters.
func _recalculate_parameters(new_max_size : Vector3 = max_size) -> void:
	world_size = new_max_size

## This is the function used to compute the vector contribution for a given point in space. It spits out the vector contribution as a Vector3 in magnitude form (basically local coordinates).
func get_vector_at_position(vector_pos : Vector3) -> Vector3:
	# Insert behavior in child class
	return Vector3.ZERO

## Public Function to tell the fields an update occurred
func notify_fields_of_update(pre_notification_pos : Vector3, pre_notification_world_size : Vector3, force : bool = false) -> void:
	if !is_inside_tree():
		return
	# Get the group name from the other class (assuming VectorField3D is known via autoload or script)
	const VF_GROUP = &"VectorFields3D" 
	
	var old_info = {"global_position":pre_notification_pos,"world_size":pre_notification_world_size}
	
	if !is_inside_tree():
		return
	if Engine.is_editor_hint():
		# Deferred mode call
		get_tree().call_group(VF_GROUP, &"receive_emitter_update", self, old_info, force)
	else:
		# Direct call
		get_tree().call_group(VF_GROUP, &"receive_emitter_update", self, old_info, force)
#endregion


#region DebugMesh functions

## function that first clears the old mesh and (if draw param is set to true) redraws the new one (handy when toggling draw state).
func _redraw_mesh() -> void:
	if !is_inside_tree():
		return
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
	new_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	new_material.vertex_color_use_as_albedo = true
	new_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	# Create a new surface on  which we can draw the line
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
