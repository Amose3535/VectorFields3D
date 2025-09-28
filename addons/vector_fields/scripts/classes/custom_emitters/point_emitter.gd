@tool
extends VectorFieldBaseEmitter3D
class_name VectorFieldPointEmitter3D
## Emitter that creates a force field centered at its position, with force decaying
## based on distance (inverse square law or linear).

#region EXPORTS
## Power of the point source. Positive values attract, negative values repel.
@export var power: float = 1.0:
	set(new_power):
		power = new_power
		notify_fields_of_update()
		
## Determines how the force decays with distance: true for Inverse Square (1/r^2), 
## false for Linear decay (1/r).
@export var inverse_square_decay: bool = true:
	set(new_decay):
		inverse_square_decay = new_decay
		notify_fields_of_update()
#endregion

# NOTE: max_distance from the base class is used here to define the limit of the force, 
# acting as the effective radius of the point source.

## Override the inherited function to define the point source behavior.
func get_vector_at_position(vector_pos : Vector3) -> Vector3:
	
	# NEW: Use the emitter's world_size to define the bounds (AABB check)
	var half_size = world_size / 2.0
	var emitter_aabb = AABB(global_position - half_size, world_size)
	if not emitter_aabb.has_point(vector_pos):
		return Vector3.ZERO
		
	# 1. Calculate the vector from the Emitter's center to the point being sampled
	var direction: Vector3 = vector_pos - global_position
	
	# 2. Get the distance (r) and the squared distance (r^2) for magnitude calculation
	var dist_sq: float = direction.length_squared()
	var dist: float = sqrt(dist_sq)
	
	# Safety check: Avoid division by zero if the point is exactly at the emitter's center.
	if dist_sq < 0.0001: 
		return Vector3.ZERO
		
	# 3. Calculate the force magnitude based on decay type
	var magnitude: float = 0.0
	
	if inverse_square_decay:
		# Inverse Square Law (e.g., gravity, electromagnetism): 1 / r^2
		magnitude = power / dist_sq
	else:
		# Linear Decay: 1 / r (often easier to control visually)
		magnitude = power / dist
		
	# 4. Combine direction and magnitude
	var final_vector = direction.normalized() * magnitude
	
	# Apply the minimum magnitude threshold filter.
	# We use length_squared() vs min_magnitude * min_magnitude for performance.
	if final_vector.length_squared() < min_magnitude * min_magnitude:
		return Vector3.ZERO
		
	return final_vector
