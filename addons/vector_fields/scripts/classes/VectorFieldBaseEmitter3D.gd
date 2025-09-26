# VectorFieldBaseEmitter3D.gd
extends Node3D
class_name VectorFieldBaseEmitter3D
## A base class for all emitters to inherit from.
##
## VectorFieldBaseEmitter3D allows with its highly configurable API to  make your very own emitter with very specific properties.
## VectorFieldBaseEmitter3D should be abstract considering the implementation BUT since this is actively being developed in 4.4 AND it's made to be also backwards-compatible it currently isn't.




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


## This is the function used to compute the vector contribution for a given point in space. It spits out the vector contribution as a Vector3 in magnitude form (basically local coordinates).
func get_vector_at_position(vector_pos : Vector3) -> Vector3:
	# Insert behavior in child class
	return Vector3.ZERO
