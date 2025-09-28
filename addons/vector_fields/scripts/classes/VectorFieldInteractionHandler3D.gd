extends Node
class_name VectorFieldInteractionHandler3D

@export var update_time_seconds : float = 0.15


var last_update_time : float = 0.0

func _physics_process(delta: float) -> void:
	last_update_time+=delta
	if last_update_time >= update_time_seconds:
		last_update_time-=update_time_seconds
		update_forces()

func update_forces() -> void:
	pass
