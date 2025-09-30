@tool
extends VectorFieldBaseEmitter3D
class_name VectorFieldVortexEmitter3D
## Emitter that generates a vortex (swirling) force field around its center.

#region EXPORTS
## The strength of the vortex force. Positive values for clockwise spin (by default), 
## negative for counter-clockwise.
@export var vortex_strength: float = 1.0:
	set(new_strength):
		vortex_strength = new_strength
		request_update()
		
## The axis around which the vortex rotation occurs.
@export var rotation_axis: Vector3 = Vector3.UP:
	set(new_axis):
		# Normalize the axis to ensure it's a unit vector
		rotation_axis = new_axis.normalized()
		request_update()
		
## Determines how the force decays with distance: true for Inverse Square (1/r^2), 
## false for Linear decay (1/r).
@export var inverse_square_decay: bool = true:
	set(new_decay):
		inverse_square_decay = new_decay
		request_update()
#endregion


## Override the inherited function to define the vortex behavior.
func get_vector_at_position(vector_pos : Vector3) -> Vector3:
	if !is_inside_tree():
		return Vector3.ZERO
	# NEW: Use the emitter's world_size to define the bounds (AABB check)
	var half_size = world_size / 2.0
	var emitter_aabb = AABB(global_position - half_size, world_size)
	if not emitter_aabb.has_point(vector_pos):
		return Vector3.ZERO
	
	# 1. Calculate the vector from the Emitter's center to the point being sampled
	var direction: Vector3 = vector_pos - global_position
	
	# 2. Get the distance (r) and the squared distance (r^2)
	var dist_sq: float = direction.length_squared()
	var dist: float = sqrt(dist_sq)
	# Safety check: Avoid division by zero
	if dist_sq < 0.0001: 
		return Vector3.ZERO
	# 3. Calculate the tangential force direction
	# We use the cross product (Vector A x Vector B) to find a vector perpendicular
	# to both the direction (A) and the rotation axis (B).
	var tangential_direction: Vector3 = rotation_axis.cross(direction).normalized()
	# 4. Calculate the force magnitude based on decay type
	var magnitude: float = 0.0
	if inverse_square_decay:
		# Inverse Square Law: 1 / r^2
		magnitude = vortex_strength / dist_sq
	else:
		# Linear Decay: 1 / r
		magnitude = vortex_strength / dist
	# 5. Combine tangential direction and magnitude
	return tangential_direction * magnitude
