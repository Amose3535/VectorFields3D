# VectorFieldBoxEmitter3D.gd
@tool
extends VectorFieldBaseEmitter3D
class_name VectorFieldBoxEmitter3D
## Emitter that applies a constant target vector to all points falling within its AABB defined by world_size.

#region EXPORTS
## The constant vector applied to all cells inside the emitter's AABB.
@export var target_vector: Vector3 = Vector3.FORWARD:
	set(new_vector):
		target_vector = new_vector
		# Notifiy the fields that an update occurred
		notify_fields_of_update()
#endregion

# NOTE: The max_distance property inherited from the base class is not strictly
# used here for the AABB size, but it is necessary for the VectorField3D to 
# calculate the initial bounding box for optimization purposes. 
# We'll calculate the final bounds based on the custom world_size.

# The world_size variable in the base class should be used to define the box dimensions.
# Remember that in VectorFieldBaseEmitter3D, world_size is defined as:
# var world_size : Vector3 = Vector3.ONE * max_distance * 2

## Override the inherited function to define the box's force field behavior.
func get_vector_at_position(vector_pos : Vector3) -> Vector3:
	# 1. Calcoliamo la mezza dimensione (half_size) per centrare la scatola attorno a global_position.
	var half_size = world_size / 2.0
	
	# 2. Creiamo un AABB in coordinate globali:
	#    Posizione AABB (angolo MIN) = Centro Globale - Mezza Dimensione
	#    Dimensione AABB (SIZE) = Dimensione Totale
	var emitter_aabb = AABB(global_position - half_size, world_size)
	
	# 3. Usiamo la funzione ottimizzata has_point() per il check.
	if emitter_aabb.has_point(vector_pos):
		return target_vector
	else:
		return Vector3.ZERO
