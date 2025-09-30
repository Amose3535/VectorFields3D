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
#endregion




#region INTERNAL VARIABLES
var last_update_time : float = 0.0
var is_setup_correct : bool = false
var parent_node : Node3D = null
#endregion









func _ready() -> void:
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
	if not is_setup_correct or not is_instance_valid(parent_node):
		return AABB()
	
	var parent = parent_node as Node3D
	
	# Case 1: Emitters (use the pre-defined world_size parameter)
	if parent is VectorFieldBaseEmitter3D:
		var size = (parent as VectorFieldBaseEmitter3D).world_size
		var pos = parent.global_position - size / 2.0
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
			return AABB(parent.global_position, Vector3.ZERO)
			
		return merged_aabb
	
	return AABB()

## Retrieves the net vector force applied by all compatible VectorFields, integrated over the parent's volume.
func get_net_vector_force() -> Vector3:
	var body_aabb: AABB = _get_parent_world_aabb()
	
	# If the object is a point or similar to one,
	if body_aabb.size.length_squared() < point_size_treshold: 
		# return the net vector force at the global position point
		return get_net_vector_force_at_point(parent_node.global_position)
	
	var net_force: Vector3 = Vector3.ZERO
	var total_contributing_cells: int = 0
	
	var all_fields: Array[Node] = get_tree().get_nodes_in_group(VectorField3D.FIELDS_GROUP)
	
	for field_node in all_fields:
		if not field_node is VectorField3D:
			continue
			
		var field: VectorField3D = field_node as VectorField3D

		# Filtro 1: Layer
		if (field.interaction_layer & self.interaction_layer) == 0:
			continue

		# --- Calcolo della Regione di Integrazione ---
		
		# Trasforma l'AABB del corpo in coordinate locali del Field
		var field_inverse_transform = field.global_transform.inverse()
		var body_aabb_local_to_field = field_inverse_transform * body_aabb
		
		# Ottieni il range di celle che intersecano l'AABB
		var cell_range_start: Vector3i
		var cell_range_end: Vector3i
		var cell_edge = field.cube_edge # cube_edge deve essere accessibile (public)
		
		# Funzione ausiliaria nel Field per convertire AABB in range di indici
		cell_range_start = field.get_cell_index_from_local_pos(body_aabb_local_to_field.position)
		cell_range_end = field.get_cell_index_from_local_pos(body_aabb_local_to_field.position + body_aabb_local_to_field.size)
		
		# Clamping e integrazione
		for z in range(cell_range_start.z, cell_range_end.z + 1):
			for y in range(cell_range_start.y, cell_range_end.y + 1):
				for x in range(cell_range_start.x, cell_range_end.x + 1):
					var index = Vector3i(x,y,z)
					
					# 🛑 Lookup del vettore (il Field deve esporre una funzione per questo)
					var field_contribution: Vector3 = field.get_vector_at_cell_index(index)
					
					net_force += field_contribution
					total_contributing_cells += 1
					
	# Se sono state trovate celle, restituiamo la forza netta.
	# Potresti dividere per total_contributing_cells per ottenere una media, 
	# ma di solito si applica la somma (integrazione) e si lascia 
	# che la massa dell'oggetto bilanci la forza.
	return net_force

## Retrieves the net vector force applied by all compatible VectorFields 
## at a single world position (point lookup).
func get_net_vector_force_at_point(world_position: Vector3) -> Vector3:
	# Controllo di sicurezza rapido
	if not is_setup_correct:
		return Vector3.ZERO
		
	var net_force: Vector3 = Vector3.ZERO
	
	# 1. Ottiene tutti i Field
	var all_fields: Array[Node] = get_tree().get_nodes_in_group(VectorField3D.FIELDS_GROUP)
	
	# 2. Cicla e Filtra
	for field_node in all_fields:
		if not field_node is VectorField3D:
			continue
			
		var field: VectorField3D = field_node as VectorField3D

		# Filtro 1: Layer (Bitwise AND)
		if (field.interaction_layer & self.interaction_layer) == 0:
			continue

		# 3. Lookup puntuale e Somma (chiede al Field di fare il controllo AABB)
		var field_contribution: Vector3 = field.get_vector_at_global_position(world_position)
		
		net_force += field_contribution
		
	return net_force

## The function that updates the forces on the body on which it is son of.
func update_forces() -> void:
	var force_vector = get_net_vector_force()
	
	if force_vector.is_zero_approx():
		return # Nessuna forza da applicare

	if parent_node is RigidBody3D:
		# Per i corpi rigidi, applichiamo la forza al centro.
		# Se l'AABB era grande e la forza è l'integrazione, l'effetto è corretto.
		(parent_node as RigidBody3D).apply_central_force(force_vector)
		
	elif parent_node is CharacterBody3D:
		# Per i CharacterBody3D, si modifica la velocità.
		# NOTA: I CharacterBody3D non sono "spinti" ma "guidati".
		var char_body = (parent_node as CharacterBody3D)
		
		# Opzione A: Aggiungi all'accelerazione (più fisica)
		# char_body.velocity += force_vector * get_process_delta_time() # Non è _physics_process
		
		# Opzione B: Applica una forza di guida diretta (più comune nei giochi)
		# Nota: questo sovrascrive la logica di movimento del giocatore.
		# Dovresti fonderla con la logica esistente di 'velocity'.
		# Esempio semplificato:
		var current_velocity = char_body.velocity
		var target_velocity = current_velocity + force_vector
		
		# Qui potresti clampare o usare lerp per un movimento più fluido
		char_body.velocity = target_velocity.limit_length(100.0) # Limita per sicurezza
		char_body.move_and_slide() # O la tua implementazione di move_and_slide/move_and_slide_with_snap
		
	elif parent_node is VectorFieldBaseEmitter3D:
		# Se l'emitter stesso deve muoversi, si aggiorna la sua posizione/velocità.
		# (Dipende dalla tua implementazione di base dell'emitter)
		pass	


func _update_parent() -> void:
	var parent = get_parent()
	if parent is RigidBody3D or parent is CharacterBody3D or parent is VectorFieldBaseEmitter3D:
		parent_node = parent
		is_setup_correct = true
	else: 
		parent_node = Node3D.new()
		is_setup_correct = false
#endregion
