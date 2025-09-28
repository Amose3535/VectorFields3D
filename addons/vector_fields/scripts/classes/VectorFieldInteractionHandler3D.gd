@tool
@icon("res://addons/vector_fields/assets/images/VectorFieldInteractionHandler3DIcon/VectorFieldInteractionHandler3DIcon.svg")
extends Node
class_name VectorFieldInteractionHandler3D
## A class that acts as an interface component between VectorFields and Nodes in the scene.

@export var update_time_seconds : float = 0.15


var last_update_time : float = 0.0

func _physics_process(delta: float) -> void:
	# Ensures it will only run when not in the editor
	if Engine.is_editor_hint():
		return
	
	# Runtime Logic
	last_update_time+=delta
	if last_update_time >= update_time_seconds:
		last_update_time-=update_time_seconds
		update_forces()

func _get_configuration_warnings() -> PackedStringArray:
	var parent_node = get_parent()
	if parent_node is RigidBody3D or parent_node is CharacterBody3D or parent_node is VectorFieldBaseEmitter3D:
		return []
	else:
		return PackedStringArray(["Node is not child of RigidBody3D / CharacterBody3D / VectorFieldBaseEmitter3D"])

## The function that updates the forces on the body on which it is son of.
func update_forces() -> void:
	pass
