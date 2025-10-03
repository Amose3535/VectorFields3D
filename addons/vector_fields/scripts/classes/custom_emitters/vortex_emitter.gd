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
		rotation_axis = new_axis#.normalized()
		request_update()

## How much tangential vectors are "attracted" to the center.[br]0.0 means that tangential vectors remain tangential, while 1 means that they point exactly to the center (and -1 means the opposite)
@export var center_axis_bias_strength: float = 0.0:
	set(new_strength):
		center_axis_bias_strength = new_strength
		request_update()

## Determines how the force decays with distance: true for Inverse Square (1/r^2), 
## false for Linear decay (1/r).
@export var inverse_square_decay: bool = true:
	set(new_decay):
		inverse_square_decay = new_decay
		request_update()
#endregion


# File: VectorFieldVortexEmitter3D.gd

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
	var direction_to_point: Vector3 = vector_pos - global_position
	
	# --- Calculate Radial Distance from Rotation Axis ---
	
	# 2. Project 'direction_to_point' onto the rotation axis. 
	#    This gives the vector component that lies along the axis (the 'height').
	var projection: Vector3 = rotation_axis * rotation_axis.dot(direction_to_point)
	
	# 3. The radial_vector is the perpendicular distance from the axis to the point.
	var radial_vector: Vector3 = direction_to_point - projection
	
	# 4. Get the radial distance (r) and the radial distance squared (r^2)
	var dist_sq: float = radial_vector.length_squared()
	var dist: float = sqrt(dist_sq)
	
	# Safety check: Avoid division by zero and force explosion when on the axis
	if dist_sq < 0.0001:
		return Vector3.ZERO
		
	# --- Calculate Force Magnitude and Decay ---
	
	# 5. Calculate the force magnitude based on decay type
	var magnitude: float = 0.0
	if inverse_square_decay:
		# Inverse Square Law: 1 / r^2
		magnitude = vortex_strength / dist_sq
	else:
		# Linear Decay: 1 / r
		magnitude = vortex_strength / dist
	
	# 6. Tangential Direction (the pure swirling force)
	# Cross product gives a perpendicular vector, normalized to get direction.
	var tangential_direction: Vector3 = rotation_axis.cross(radial_vector).normalized()
	
	# 7. Radial Direction (the force pointing away from the axis)
	var radial_direction: Vector3 = radial_vector.normalized()
	
	# --- Apply Bias and Combine Forces ---
	
	var final_vector: Vector3 = Vector3.ZERO
	
	# Componente 1: Tangential Force (Pure Vortex)
	final_vector += tangential_direction * magnitude
	
	# Componente 2: Radial Bias (Attraction/Repulsion to/from the center axis)
	# We use -1.0 to signify that a positive bias value means ATTRACTION (towards the center).
	final_vector += radial_direction * magnitude * center_axis_bias_strength * -1.0
	
	return final_vector
