# VectorFieldPointEmitter3D.gd
@tool
extends VectorFieldBaseEmitter3D
class_name VectorFieldPointEmitter3D
## A class to simulate radial point emitters.
##
## Its behavior is similar to how masses work in space or eletric charges work in electric fields.


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# WARNING (IMPORTANT!): When inheriting *ANY* emitter class ALWAYS call super._ready() at the top
	# of your ready function to maintain previous logic (by default inheriting a parent function will
	# also overwrite the parent's function code)
	super._ready() # <--- Always keep in children scripts
	
	# VectorFieldPointEmitter3D's _ready() logic here ------------------------------------------------
