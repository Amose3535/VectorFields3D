@tool
extends Marker3D
class_name VectorDebugger3D
## Utility class used to debug vector data at specific point in space

## This variable determines wether future updates inside the editor are enabled or not
@export var active_in_editor : bool = false
## This variable determiens wether future updates at runtime are enabled or not
@export var active_at_runtime : bool = false
## This variable determines the interval in seconds between updates
@export var update_time : float = 1.0
## These are the layers that the debugger will interact with
@export_flags_3d_physics var interaction_layer : int = 1

var last_update_time : float = 0.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_update_debug_state(delta)

func _update_debug_state(delta : float) -> void:
	if Engine.is_editor_hint():
		if active_in_editor:
			last_update_time += delta
			if last_update_time >= update_time:
				last_update_time-= update_time
				_debug_vectors()
		return
	
	if active_at_runtime:
		last_update_time += delta
		if last_update_time >= update_time:
			last_update_time-= update_time
			_debug_vectors()
	

func _debug_vectors() -> void:
	var all_fields = get_tree().get_nodes_in_group(VectorField3D.FIELDS_GROUP)
	var vector : Vector3 = Vector3.ZERO
	for field in all_fields:
		if !field is VectorField3D:
			continue
		if ((field as VectorField3D).interaction_layer & interaction_layer) == 0:
			continue
		vector+=(field as VectorField3D).get_vector_at_global_position(self.global_position)
	print("Vector at position %s: %s"%[str(self.global_position),str(vector)])
