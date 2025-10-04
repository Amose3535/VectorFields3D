# RodDipoleEmitter3D.gd
@tool
extends MagneticEmitter3D
class_name RodDipoleEmitter3D
## @experimental

#region EXPORTS
@export_group("Rod Dipole Specific")
## La distanza (in metri) tra il polo Nord e il polo Sud.
@export var pole_separation: float = 0.5:
	set(value):
		pole_separation = max(0.001, value) # Minimo per evitare problemi
		_recalculate_parameters(max_size) 
		request_update()
#endregion

#region INTERNALS
## Posizione globale del polo Nord
var north_pole_pos: Vector3 = Vector3.ZERO
## Posizione globale del polo Sud
var south_pole_pos: Vector3 = Vector3.ZERO
#endregion


func _recalculate_parameters(new_max_size: Vector3 = max_size) -> void:
	# Chiama la funzione base per aggiornare world_size e global_dipole_axis
	super._recalculate_parameters(new_max_size)
	
	# Aggiorna le posizioni dei poli (SPECIFICO del Rod)
	var half_sep = pole_separation / 2.0
	var center = self.global_position
	
	# global_dipole_axis è già aggiornato da MagneticEmitter3D
	north_pole_pos = center + global_dipole_axis * half_sep
	south_pole_pos = center - global_dipole_axis * half_sep


## Sovrascrive la funzione per calcolare il vettore come la somma di due cariche magnetiche opposte.
func get_vector_at_position(vector_pos: Vector3) -> Vector3:
	
	var total_force: Vector3 = Vector3.ZERO
	
	# 1. Polo Nord (sorgente, forza repulsiva/uscente)
	# La forza di ciascun polo è divisa per 2 per mantenere dipole_moment come forza totale
	var force_magnitude = dipole_moment / 2.0 
	
	var r_n_vec: Vector3 = vector_pos - north_pole_pos
	var r_n_sq: float = r_n_vec.length_squared() # Usiamo length_squared per l'inverso del quadrato
	
	if r_n_sq > 0.0001: 
		# Forza del polo Nord (repulsiva): Forza = +Momento * r_hat / r^2
		var force_n: Vector3 = r_n_vec.normalized() * (force_magnitude / r_n_sq)
		total_force += force_n
		
	# 2. Polo Sud (pozzo, forza attrattiva/entrante)
	var r_s_vec: Vector3 = vector_pos - south_pole_pos
	var r_s_sq: float = r_s_vec.length_squared()
	
	if r_s_sq > 0.0001:
		# Forza del polo Sud (attrattiva): Forza = -Momento * r_hat / r^2
		# Nota: sottraiamo il vettore per ottenere l'attrazione verso il polo Sud.
		var force_s: Vector3 = -r_s_vec.normalized() * (force_magnitude / r_s_sq)
		total_force += force_s
		
	# 3. Applica la Dead Zone
	if total_force.length_squared() < min_magnitude * min_magnitude:
		return Vector3.ZERO
		
	return total_force
