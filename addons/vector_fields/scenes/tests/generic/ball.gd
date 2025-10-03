extends RigidBody3D

@onready var IH : VectorFieldInteractionHandler = $"VectorFieldInteractionHandler"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	apply_impulse(Vector3(mass*sqrt((5.5*IH.query_fields_at(global_position).length())/(mass)),-0.5,0))
