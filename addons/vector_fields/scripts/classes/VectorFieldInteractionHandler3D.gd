@tool
@icon("res://addons/vector_fields/assets/images/VectorFieldInteractionHandler3DIcon/VectorFieldInteractionHandler3DIcon.svg")
extends Node
class_name VectorFieldInteractionHandler
## A class that acts as an interface component between VectorFields and Nodes in the scene.

#region EXPORTS
## The length squared of the size (Vector3) of the AABB of the parent of this handler that marks the transition between a full rigid body and a point mass.
@export var point_size_treshold : float = 0.5
## The time in seconds that elapses between recalculations of the forces and parent node.
@export var update_time_seconds : float = 0.15
## The layer flags for interaction. This node will only listen to VectorField3D's that possess the same layer/s as itself.
@export_flags_3d_physics var interaction_layer: int = 1

@export_group("Debugging")
## Variable that determines wether to show or not the debug metrics
@export var metrics_enabled : bool = false
## Variable that determines wether to show or not tick updates
@export var tick_updates : bool = false
## Variable that determines wether to show or not vector information
@export var vector_info : bool = false
#endregion




#region INTERNAL VARIABLES
var last_update_time : float = 0.0
var is_setup_correct : bool = false
var parent_node : Node3D = null
#endregion









func _ready() -> void:
	if metrics_enabled:
		print("[VectorFieldInteractionHandler] Preapping node %s"%str(self))
	# Immediately update the parent variables
	_update_parent()


func _physics_process(delta: float) -> void:
	# Ensures it will only run when not in the editor
	if Engine.is_editor_hint():
		return
	
	# Runtime Logic
	last_update_time+=delta
	if last_update_time >= update_time_seconds:
		last_update_time-=update_time_seconds
		_update_parent()
		update_forces()


func _get_configuration_warnings() -> PackedStringArray:
	var parent_node = get_parent()
	var warns : PackedStringArray
	if parent_node is RigidBody3D or parent_node is CharacterBody3D or parent_node is VectorFieldBaseEmitter3D:
		pass
	else:
		warns.append("Node is not child of RigidBody3D / CharacterBody3D / VectorFieldBaseEmitter3D")
	return warns









#region INTERNAL FUNCTIONS

## Calcola il Bounding Box Mondiale del nodo genitore, integrando i contributi dei figli (Mesh, Collisioni).
func _get_parent_world_aabb() -> AABB:
	if metrics_enabled:
		print("[VectorFieldInteractionHandler] Trying to acquire %s's AABB"%str(self))
	if not is_setup_correct or not is_instance_valid(parent_node):
		if metrics_enabled:
			print("[VectorFieldInteractionHandler] %s's AABB acquisition failed. Returning AABB()"%str(self))
		return AABB()
	
	var parent = parent_node as Node3D
	
	# Case 1: Emitters (use the pre-defined world_size parameter)
	if parent is VectorFieldBaseEmitter3D:
		var size = (parent as VectorFieldBaseEmitter3D).world_size
		var pos = parent.global_position - size / 2.0
		if metrics_enabled:
			print("[VectorFieldInteractionHandler] %s's AABB acquisition successful. Returning AABB(%s,%s)"%[str(self),str(pos),str(size)])
		return AABB(pos, size)
	
	# Case 2 & 3: RigidBody / CharacterBody3D / Node3D
	elif parent is RigidBody3D or parent is CharacterBody3D or parent is Node3D:
		var merged_aabb = AABB()
		var first_aabb_found = false
		
		# Iterate on children to get the mesh and the collision
		for child in parent.get_children():
			var child_aabb = AABB()
			var aabb_found = false
			
			# A) HANDLING MESH INSTANCE 3D (has get_aabb() directly)
			if child is MeshInstance3D:
				child_aabb = (child as MeshInstance3D).get_aabb()
				aabb_found = true
			
			# B) HANDLING COLLISION SHAPE 3D (we need to use .shape property)
			elif child is CollisionShape3D:
				var collision_shape_debug_mesh : ArrayMesh = ((child as CollisionShape3D).shape as Shape3D).get_debug_mesh()
				if is_instance_valid(collision_shape_debug_mesh):
					child_aabb = collision_shape_debug_mesh.get_aabb()
					aabb_found = true
			
			# Se abbiamo trovato un AABB valido da un figlio...
			if aabb_found:
				# Trasformiamo l'AABB del figlio in coordinate mondiali
				var world_aabb: AABB = child.global_transform * child_aabb
				
				if not first_aabb_found:
					merged_aabb = world_aabb
					first_aabb_found = true
				else:
					merged_aabb = merged_aabb.merge(world_aabb)
		
		# Se non abbiamo trovato nulla (nessuna mesh/collisione), torniamo un AABB puntiforme
		if not first_aabb_found:
			if metrics_enabled:
				print("[VectorFieldInteractionHandler] %s's AABB acquisition failed. Returning AABB(%s,%s)"%[str(self),str(parent.global_position),str(Vector3.ZERO)])
			return AABB(parent.global_position, Vector3.ZERO)
		
		
		if metrics_enabled:
			print("[VectorFieldInteractionHandler] %s's AABB acquisition sucessful. Returning merged_aabb = %s"%[str(self),str(merged_aabb)])
		return merged_aabb
	
	return AABB() # Fallback

## Retrieves the net vector force applied by all compatible VectorFields, integrated over the parent's volume.
func get_net_vector_force() -> Vector3:
	var body_aabb: AABB = _get_parent_world_aabb()
	var net_force: Vector3 = Vector3.ZERO
	var total_contributing_cells: int = 0
	var all_fields: Array[Node] = get_tree().get_nodes_in_group(VectorField3D.FIELDS_GROUP)
	
	# If the object is a point or similar to one (optimization)
	if body_aabb.size.length_squared() < point_size_treshold: 
		# return the net vector force at the global position point
		net_force = get_net_vector_force_at_point(parent_node.global_position)
		if metrics_enabled:
			if vector_info:
				print("[VectorFieldInteractionHandler] Updating forces on point mass. Net force : %s"%str(net_force))
		return net_force
	
	for field_node in all_fields:
		if not field_node is VectorField3D:
			continue
			
		var field: VectorField3D = field_node as VectorField3D
	
		# Filter 1: Layer filtering
		if (field.interaction_layer & self.interaction_layer) == 0:
			continue
	
		# --- Computing integration region ---
		
		# Turn body's AABB into local field coordinates
		var field_inverse_transform = field.global_transform.inverse()
		var body_aabb_local_to_field = field_inverse_transform * body_aabb
		
		# Obtain the range of cells that intersect AABB
		var cell_range_start: Vector3i
		var cell_range_end: Vector3i
		var cell_edge = field.cube_edge
		
		# Funzione ausiliaria nel Field per convertire AABB in range di indici
		cell_range_start = field.get_cell_index_from_local_pos(body_aabb_local_to_field.position)
		cell_range_end = field.get_cell_index_from_local_pos(body_aabb_local_to_field.position + body_aabb_local_to_field.size)
		
		# Integration
		for z in range(cell_range_start.z, cell_range_end.z + 1):
			for y in range(cell_range_start.y, cell_range_end.y + 1):
				for x in range(cell_range_start.x, cell_range_end.x + 1):
					var index = Vector3i(x,y,z)
					
					# Vector lookup
					var field_contribution: Vector3 = field.get_vector_at_cell_index(index)
					
					net_force += field_contribution
					total_contributing_cells += 1
					
	
	# If cells were found, we return the net force.
	# You could divide by total_contributing_cells to get an average,
	# but usually you apply summation (integration) and let the object's mass balance the force.
	
	if metrics_enabled:
		if vector_info:
			print("[VectorFieldInteractionHandler] Updating net force generated by %s contributing cells distributed on mass. Net force : %s"%[str(total_contributing_cells),str(net_force)])
	
	return net_force

## Retrieves the net vector force applied by all compatible VectorFields 
## at a single world position (point lookup).
func get_net_vector_force_at_point(world_position: Vector3) -> Vector3:
	if metrics_enabled:
		print("[VectorFieldInteractionHandler] Getting net vector force at point %s"%str(world_position))
	# Controllo di sicurezza rapido
	if not is_setup_correct:
		if metrics_enabled:
			print("[VectorFieldInteractionHandler] Can't get net vector force at point %s: incorrect setup"%str(world_position))
		return Vector3.ZERO
	
	var net_force: Vector3 = query_fields_at(world_position)
	
	if metrics_enabled:
		if vector_info:
			print("[VectorFieldInteractionHandler] Net force applied to point mass: %s"%str(net_force))
	
	return net_force

## The function that updates the forces on the body on which it is son of.
func update_forces() -> void:
	# Get the force vector
	var force_vector = get_net_vector_force()
	
	if force_vector.is_zero_approx():
		if metrics_enabled:
			print("[VectorFieldInteractionHandler] The force applied is zero. Not updating forces")
		return

	if parent_node is RigidBody3D:
		if metrics_enabled:
			print("[VectorFieldInteractionHandler] Updating forces on RigidBody3D %s"%str(self))
		# Apply central force for rigidbodies (integration of forces inside parent_node's AABB)
		(parent_node as RigidBody3D).apply_central_force(force_vector)
		
	elif parent_node is CharacterBody3D:
		if metrics_enabled:
			print("[VectorFieldInteractionHandler] Updating forces on CharacterBody3D %s"%str(self))
		# In the CharacterBody's case we must edit "velocity"
		# NOTE: CharacterBody3D-s aren't "pushed" but rather "guided".
		var char_body = (parent_node as CharacterBody3D)
		
		# Option A: Add to acceleration
		char_body.velocity += force_vector * get_physics_process_delta_time()
		
		# Option B: Apply direct guidance force (more common in games)
		# NOTE: This overrides the player's movement mechanics (applies a constant force).
		#var current_velocity = char_body.velocity
		#var target_velocity = current_velocity + force_vector
		#char_body.velocity = target_velocity #.limit_length(100.0) # Maybe limiting for security?
		#char_body.move_and_slide() # Do not uncomment
		
	elif parent_node is VectorFieldBaseEmitter3D:
		# If the emitter itself is moving, then update it's position
		pass

## Endpoint that can be used to lookup the contribution of all compatible fields at a specific point
func query_fields_at(pos : Vector3) -> Vector3:
	# Get all fields
	var all_fields: Array[Node] = get_tree().get_nodes_in_group(VectorField3D.FIELDS_GROUP)
	var return_force : Vector3 = Vector3.ZERO
	
	# Cycle and filter
	for field_node in all_fields:
		# Filter by node type
		if !field_node is VectorField3D:
			continue
		
		# Explicit casting for methods lookup
		var field: VectorField3D = (field_node as VectorField3D)
		
		# Filter by layer (Bitwise AND)
		if (field.interaction_layer & self.interaction_layer) == 0:
			continue
		
		# 3. Lookup puntuale e Somma (chiede al Field di fare il controllo AABB)
		var field_contribution: Vector3 = field.get_vector_at_global_position(pos)
		
		return_force += field_contribution
	return return_force

func _update_parent() -> void:
	var parent = get_parent()
	if parent is RigidBody3D or parent is CharacterBody3D or parent is VectorFieldBaseEmitter3D:
		parent_node = parent
		is_setup_correct = true
	else: 
		parent_node = Node3D.new()
		is_setup_correct = false
	
	if metrics_enabled:
		if is_setup_correct:
			print("[VectorFieldInteractionHandler] Updated %s's parent: %s."%[str(self),str(parent_node)])
		elif !is_setup_correct:
			print("[VectorFieldInteractionHandler] Couldn't update %s's parent."%[str(self)])
			
#endregion
