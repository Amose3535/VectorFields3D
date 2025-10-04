# MagneticEmitter3D.gd
@tool
extends VectorFieldBaseEmitter3D
class_name MagneticEmitter3D
## A class that aims to implement magnetic and ferromagnetic interactions with the upcoming MagneticInteractionHandler.
## @experimental

#region EXPORTS
@export_group("Dipole Properties")
## La potenza del campo dipolare (corrisponde al momento di dipolo magnetico).
@export var dipole_moment: float = 50.0:
	set(value):
		dipole_moment = max(0.0, value)
		request_update()

## Definisce l'asse locale (es. Vector3.FORWARD) sul quale è allineato il dipolo.
@export var local_dipole_axis: Vector3 = Vector3.FORWARD:
	set(value):
		local_dipole_axis = value.normalized()
		# Re-calcola solo i parametri interni, poi notifica il campo (tramite request_update)
		_recalculate_parameters(max_size) 
		request_update()
#endregion

#region INTERNALS
## Vettore che punta dal polo Sud al polo Nord (già in Global Space).
var global_dipole_axis: Vector3 = Vector3.FORWARD
#endregion


func _recalculate_parameters(new_max_size: Vector3 = max_size) -> void:
	if !is_inside_tree():
		return
	# Chiama la funzione base
	super._recalculate_parameters(new_max_size)
	
	# Aggiorna l'asse di dipolo in Global Space, usando la rotazione del nodo.
	global_dipole_axis = (self.global_transform.basis *local_dipole_axis).normalized()


func _notification(what: int) -> void:
	super._notification(what)
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			# Se il nodo è ruotato, dobbiamo ricalcolare l'asse e aggiornare i campi.
			# La logica di blocco rotazione è nel padre, ma se la rotazione fosse permessa, la gestirei qui.
			# Poiché il padre (VectorFieldBaseEmitter3D) resetta rotazione/scala, 
			# questo viene chiamato solo per il POSIZIONAMENTO, ma ricalcolo l'asse per sicurezza.
			
			# NOTA SULL'OTTIMIZZAZIONE: La _recalculate_parameters NON deve chiamare request_update()
			# altrimenti avremmo un doppio aggiornamento.
			_recalculate_parameters(max_size)
