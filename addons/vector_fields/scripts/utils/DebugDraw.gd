# DebugDraw.gd
extends Node

## NOTE: Every physics frame the lines get cleared to prevent overlapping/duplication, hence keep in mind to 

@onready var draw_debug: MeshInstance3D = $DebugMesh

func _physics_process(delta: float) -> void:
	## For every physics process clear current instances of any surfaces.
	if draw_debug.mesh is ImmediateMesh:
		(draw_debug.mesh as ImmediateMesh).clear_surfaces()
	
	# Test: OK
	# draw_line(Vector3.UP, Vector3.DOWN, Color.RED)

## Draws a line from a point in space "from" to a point in space "to" with a certain color "color"
func draw_line(from : Vector3, to : Vector3, color : Color = Color(1,1,1,1)):
	# Early return for points too close to eachother (comment the next line if you want to purposefully draw a point for whatever reason)
	if from.is_equal_approx(to): return
	
	# Early return if the draw_debug mesh isn't an ImmediateMesh
	if !(draw_debug.mesh is ImmediateMesh): return
	
	# Create a new surface of type "primitive liens" (every two vertices a line is created)
	(draw_debug.mesh as ImmediateMesh).surface_begin(Mesh.PRIMITIVE_LINES)
	# Color the surface with "color"
	(draw_debug.mesh as ImmediateMesh).surface_set_color(color)
	
	# Add from and to vertices (absolute coordinates)
	(draw_debug.mesh as ImmediateMesh).surface_add_vertex(from)
	(draw_debug.mesh as ImmediateMesh).surface_add_vertex(to)
	
	# Finally close the surface and apply changes made to the mesh
	(draw_debug.mesh as ImmediateMesh).surface_end()

## Draws a line in space from point "from" to point "from+to_relative" with a certain color "color"
func draw_line_relative(from : Vector3, to_relative : Vector3, color : Color) -> void:
	draw_line(from, from + to_relative, color)
