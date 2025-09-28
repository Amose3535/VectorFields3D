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
signal vf3d_updated(vf3d : VectorField3D)
#endregion



#region EXPORTS
## LOD (or level of detail) is used to compute the size of the building blocks of for VectorField3D using the formula `cube_size_side = 1/LOD`.[br]By default the minimum LOD available is 1 (hence the maximum cube size is 1*1*1  meters).
@export_range(0.1, 100, 0.1, "or_greater") var LOD : float = 1:
	set(new_lod):
		# Set every internal variable accordingly
		LOD = new_lod
		_recalculate_parameters(new_lod, vector_field_size)
		_compute_field_vectors()
		emit_signal(&"vf3d_updated",new_lod)
		if Engine.is_editor_hint():
			_redraw_mesh(draw_debug_lines,draw_vectors_only)
			

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
		_compute_field_vectors()
		emit_signal(&"vf3d_updated",new_field_size)
		if Engine.is_editor_hint():
			_redraw_mesh(draw_debug_lines,draw_vectors_only)

## Toggles future updates
@export var active : bool = true:
	set(new_activity):
		active = new_activity
		emit_signal(&"vf3d_updated",new_activity)

## InteractionLayer is the layer that defines the interaction between emitters and fields. Only emitters on the same laer as another field will be able to affect its vectors. 
@export_flags_3d_physics var interaction_layer = 1

@export_group("Debugging")
## Allows to draw or not the debug lines
@export var draw_debug_lines : bool = true:
	set(new_draw_state):
		draw_debug_lines = new_draw_state
		if Engine.is_editor_hint():
			_redraw_mesh()

@export var draw_vectors_only : bool = false:
	set(new_vec_draw_state):
		draw_vectors_only = new_vec_draw_state
		if Engine.is_editor_hint():
			_redraw_mesh(draw_debug_lines,new_vec_draw_state)

@export var bounding_box_color : Color = Color.WEB_MAROON:
	set(new_color):
		bounding_box_color = new_color
		if Engine.is_editor_hint():
			_redraw_mesh(draw_debug_lines,draw_vectors_only)

@export var grid_color : Color = Color.DARK_GRAY:
	set(new_color):
		grid_color = new_color
		if Engine.is_editor_hint():
			_redraw_mesh(draw_debug_lines,draw_vectors_only)

@export var vector_color : Color = Color.YELLOW:
	set(new_color):
		vector_color = new_color
		if Engine.is_editor_hint():
			_redraw_mesh(draw_debug_lines,draw_vectors_only)
#endregion



#region INTERNALS
## The StringName for the group containing all fields
const FIELDS_GROUP : StringName = &"VectorFields3D"
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
	# Generic logic
	# Add the current VectorField3D into a custom group
	if !is_in_group(FIELDS_GROUP):
		self.add_to_group(FIELDS_GROUP)
		emit_signal(&"vf3d_entered_group",self)
	
	# Requests notifications on transform change
	set_notify_transform(true)
	
	_clear_debug_mesh()
	_instantiate_debug_mesh()
	_recalculate_parameters(LOD, vector_field_size)
	
	# Editor logic
	if Engine.is_editor_hint():
		# In editor, use call_deferred to give enough time to the Emitters to have their _ready() and call call_group.
		call_deferred("_compute_field_vectors")
		call_deferred("_draw_debug_lines",draw_vectors_only)
		return
	
	# Runtime logic
	_compute_field_vectors() # A runtime, è sicuro calcolare subito.
	_draw_debug_lines(draw_vectors_only)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			receive_emitter_update(VectorFieldBaseEmitter3D.new())

# Called when the node is about to get deleted from tree
func _exit_tree() -> void:
	emit_signal(&"vf3d_exited_group",self)

#region INTERNAL FUNCTIONS
## The function used to recalculate the parameters
func _recalculate_parameters(new_lod=LOD, new_vector_field_size=vector_field_size):
	cube_edge = 1.0 / float(new_lod)
	world_size = Vector3(new_vector_field_size) * cube_edge
	_initialize_vector_data(new_vector_field_size) # Formats data structure to accept vectors in the new cells

## The function responsible for reformatting the vector_data variable in order to handle the different sizes
func _initialize_vector_data(_vector_field_size : Vector3i = vector_field_size):
	# 1. Caching the dimensions to prevent mid-run changes 
	var cached_size: Vector3i = vector_field_size
	
	# Clear the vector_data to ensure a fresh start
	vector_data.clear()
	
	# Initialize vector_data
	vector_data.resize(cached_size.x) # X-dimension
	for x in cached_size.x:
		vector_data[x] = []
		vector_data[x].resize(cached_size.y) # Y-dimension
		for y in cached_size.y:
			vector_data[x][y] = []
			vector_data[x][y].resize(cached_size.z) # Z-dimension
			for z in cached_size.z:
				vector_data[x][y][z] = Vector3.ZERO
	
	# Optional: Verification print (OK)
	#print("3D Grid initialized. Dimensions: %d x %d x %d. Total elements: %d."%[cached_size.x, cached_size.y, cached_size.z, cached_size.x*cached_size.y*cached_size.z])
	#print(vector_data)

## The function responsible for computing the contribution of each compatible emitter to the vector grid.
func _compute_field_vectors() -> void:
	if !is_inside_tree():
		return
	if !active:
		return
	
	# Initialize all vectors to zero
	_initialize_vector_data()
	
	# Get all emitters from the emitter group
	var all_emitters : Array[Node] = get_tree().get_nodes_in_group(VectorFieldBaseEmitter3D.EMITTER_GROUP)
	# Compute VectorField3D s AABB
	var field_size_half = world_size / 2.0
	# VectorField's center
	var field_global_center = global_transform.origin
	# VectorField's AABB in World Space
	var field_aabb = AABB(field_global_center - field_size_half, world_size)
	# Compute cell size and origin ONCE (for all emitters)
	var cell_size : Vector3 = world_size / Vector3(vector_field_size)
	var origin : Vector3 = global_position-world_size/2
	
	# Cycle in all the emitters
	for emitter in all_emitters:
		# If the node isn't of type or inherited type 'VectorFieldBaseEmitter3D', skip
		if !emitter is VectorFieldBaseEmitter3D:
			continue # NOT ok, skip to next itaration
		# If the layers don't match, skip
		if (emitter.interaction_layer & self.interaction_layer) == 0: # Bit-wise and comparison
			continue # No layer in common: skip to next iteration
			
		# 🛑 MODIFICA CRUCIALE: Usiamo la dimensione vettoriale (world_size) dell'emitter per l'AABB
		var emitter_world_size: Vector3 = (emitter as VectorFieldBaseEmitter3D).world_size
		var emitter_aabb = AABB(emitter.global_position - emitter_world_size / 2.0, emitter_world_size)
		# Se l'AABB dell'emitter e l'AABB del Field non si intersecano, salta
		if !field_aabb.intersects(emitter_aabb):
			continue # They don't intersect, continue to next emitter
		
		# Compute the emitter's contribution ---------------------------------------------------
		
		# Same thing as nested 'for's: cycle on variables x,y,z from 0 to X/Y/Z.
		for x in range(vector_field_size.x): for y in range(vector_field_size.y): for z in range(vector_field_size.z):
			# Get the offset of the cell
			var cell_offset : Vector3 = Vector3(cell_size.x*x, cell_size.y*y, cell_size.z*z)
			# Compute the global position of the center of that cell
			var cell_center_global_position : Vector3 = origin + cell_offset + cell_size/2
			# Compute contribution from cell center
			var contribution : Vector3 = (emitter as VectorFieldBaseEmitter3D).get_vector_at_position(cell_center_global_position)
			# Add contribution to vector_data
			vector_data[x][y][z] += contribution

## This function gets called through get_tree().call_group(...)
func receive_emitter_update(emitter: VectorFieldBaseEmitter3D) -> void:
	# Controlli di validità
	if not is_instance_valid(self) or not is_instance_valid(emitter):
		return
		
	print("[Field] Ricevuto aggiornamento da Emitter! -> FORZATURA RICALCOLO COMPLETO")
		
	# 1. Complete recomputation of vectors
	_compute_field_vectors()
	
	
	# 3. Update the debug mesh
	if Engine.is_editor_hint():
		_redraw_mesh(draw_debug_lines, draw_vectors_only)

## Recalculates the vector contributions only within the specified global AABB (zone_aabb).
## This is the core of the performance optimization.
func _recalculate_vectors_in_zone(zone_aabb: AABB) -> void:	
	var cube_edge_local = cube_edge
	var field_origin_local = -world_size / 2.0
	
	# --- 1. Map Global AABB to Local Grid Indices ---
	
	# Convert Global AABB to Local AABB
	var inverse_transform = global_transform.inverse()
	var zone_aabb_local = inverse_transform * zone_aabb
	
	# Calculate start index (clamp to field size)
	var min_index_float = (zone_aabb_local.position - field_origin_local) / cube_edge_local
	var start_x = max(0, int(floor(min_index_float.x)))
	var start_y = max(0, int(floor(min_index_float.y)))
	var start_z = max(0, int(floor(min_index_float.z)))
	
	# Calculate end index (clamp to field size)
	var max_index_float = (zone_aabb_local.position + zone_aabb_local.size - field_origin_local) / cube_edge_local
	var end_x = min(vector_field_size.x, int(ceil(max_index_float.x)))
	var end_y = min(vector_field_size.y, int(ceil(max_index_float.y)))
	var end_z = min(vector_field_size.z, int(ceil(max_index_float.z)))
	
	
	# --- 2. Pre-filter Emitters (same logic as _compute_field_vectors) ---
	var all_emitters = get_tree().get_nodes_in_group(VectorFieldBaseEmitter3D.EMITTER_GROUP)
	var field_aabb = AABB(global_transform.origin - world_size/2.0, world_size)
	var relevant_emitters = []
	
	for emitter in all_emitters:
		# Use the same three-way filter (Type, Layer, Field AABB intersection)
		if not emitter is VectorFieldBaseEmitter3D: continue
		if (emitter.interaction_layer & self.interaction_layer) == 0: continue
		
		# 🛑 MODIFICA CRUCIALE: Usiamo la dimensione vettoriale (world_size) dell'emitter per l'AABB
		var emitter_world_size: Vector3 = (emitter as VectorFieldBaseEmitter3D).world_size
		var emitter_aabb = AABB(emitter.global_position - emitter_world_size / 2.0, emitter_world_size)
		
		if not field_aabb.intersects(emitter_aabb): continue
		
		relevant_emitters.append(emitter)
	
	
	# --- 3. Localized Recalculation Loop ---
	var cube_edge_half = cube_edge_local / 2.0
	
	# Loop only over the calculated indices
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			for z in range(start_z, end_z):
				
				# Reset cell vector to ZERO for a fresh recalculation of ALL relevant emitters
				var net_vector = Vector3.ZERO
				
				# Calculate the global position of the cell center
				var cell_local_center = field_origin_local + Vector3(x, y, z) * cube_edge_local + Vector3.ONE * cube_edge_half
				var cell_global_pos = global_transform * cell_local_center
				
				# Calculate contribution from ALL relevant emitters for this cell
				for emitter in relevant_emitters:
					# 🛑 RIMOZIONE LOGICA SFERICA
					# Dato che l'AABB è già stato controllato, non facciamo un controllo sferico aggiuntivo,
					# ma ci affidiamo alla logica AABB-based di get_vector_at_position (che farà il check AABB)
					net_vector += (emitter as VectorFieldBaseEmitter3D).get_vector_at_position(cell_global_pos)
						
				vector_data[x][y][z] = net_vector

## Public function used to get the force vector at the specified global position.[br]
## Returns Vector3.ZERO if the point is outside the VectorField's Bounding Box.[br]
## This is what allows for the actual real usage of the VectorField3D.
func get_vector_at_global_position(global_pos: Vector3) -> Vector3:
	# 1. Calculate the Field's global Bounding Box (AABB)
	var half_world_size: Vector3 = world_size / 2.0
	var field_global_center: Vector3 = global_position
	
	# Create the AABB in world coordinates
	var field_aabb = AABB(field_global_center - half_world_size, world_size)
	
	# If the global point is NOT within the AABB, exit early.
	if not field_aabb.has_point(global_pos):
		return Vector3.ZERO
	
	# 2. Map the global position to the Field's local coordinates:
	# global_pos = global_transform*local_pos  >>>>>  local_pos = global_transform_inverse*local_pos
	var local_pos: Vector3 = global_transform.inverse() * global_pos
	
	# 3. Calculate the normalized position (ranging from 0 to 1)
	# Shift the origin from [-half_size, +half_size] to [0, world_size] and normalize.
	var normalized_pos: Vector3 = (local_pos + half_world_size) / world_size
	
	# 4. Calculate the Array indices
	var indices: Vector3i = Vector3i(
		int(floor(normalized_pos.x * vector_field_size.x)),
		int(floor(normalized_pos.y * vector_field_size.y)),
		int(floor(normalized_pos.z * vector_field_size.z))
	)
	
	# 5. Extract the indices for clarity
	var x: int = indices.x
	var y: int = indices.y
	var z: int = indices.z
	
	# Sanity check: since we already checked the AABB, this should always pass.
	if (x >= 0 and x < vector_field_size.x and
		y >= 0 and y < vector_field_size.y and
		z >= 0 and z < vector_field_size.z):
		
		# Return the vector data from the cell
		return vector_data[x][y][z]
		
	# Fallback, just in case (though highly unlikely after the AABB check)
	return Vector3.ZERO
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
	new_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	new_material.vertex_color_use_as_albedo = true
	debug_mesh.material_override = new_material

## Draw grid  + debug vectors
func _draw_debug_lines(vectors_only : bool = false) -> void:
	if not is_instance_valid(debug_mesh) or not (debug_mesh.mesh is ImmediateMesh):
		return
	
	(debug_mesh.mesh as ImmediateMesh).clear_surfaces()
	(debug_mesh.mesh as ImmediateMesh).surface_begin(Mesh.PRIMITIVE_LINES)
	# Compute offset to position the grid
	var offset = -world_size / 2.0
	# Draw the bounding box of the VectorField3D
	_draw_bounding_box(offset)
	
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
					add_line(cell_pos_local, cell_pos_local + Vector3(cube_edge, 0, 0), grid_color)
					add_line(cell_pos_local, cell_pos_local + Vector3(0, cube_edge, 0), grid_color)
					add_line(cell_pos_local, cell_pos_local + Vector3(0, 0, cube_edge), grid_color)
				
				# Draw the vector only if  not null
				if not vector_force.is_zero_approx():
					add_line_relative(cell_pos_local + (Vector3.ONE * cube_edge) / 2.0, (vector_force.normalized() * cube_edge) / 2.0, vector_color)
					nonzero_vector_flag = true
	# If no vertices were added, add one single vertex to the center of the VectorField3D to prevent error spamming in the console.
	if !nonzero_vector_flag:
		add_line(global_position,global_position,Color.BLACK,true)
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
	add_line(points[0], points[1], bounding_box_color)
	add_line(points[1], points[2], bounding_box_color)
	add_line(points[2], points[3], bounding_box_color)
	add_line(points[3], points[0], bounding_box_color)
	
	add_line(points[4], points[5], bounding_box_color)
	add_line(points[5], points[6], bounding_box_color)
	add_line(points[6], points[7], bounding_box_color)
	add_line(points[7], points[4], bounding_box_color)
	
	add_line(points[0], points[4], bounding_box_color)
	add_line(points[1], points[5], bounding_box_color)
	add_line(points[2], points[6], bounding_box_color)
	add_line(points[3], points[7], bounding_box_color)

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
