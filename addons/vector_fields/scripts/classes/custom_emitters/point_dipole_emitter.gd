# PointDipoleEmitter3D.gd
@tool
extends MagneticEmitter3D
class_name PointDipoleEmitter3D
## @experimental


## Sovrascrive la funzione per calcolare il vettore di un dipolo puntiforme ideale.
func get_vector_at_position(vector_pos: Vector3) -> Vector3:
	# Il centro del dipolo ideale è la posizione del nodo.
	var r_vec: Vector3 = vector_pos - self.global_position
	var r: float = r_vec.length()
	
	if r < min_magnitude:
		return Vector3.ZERO
	
	# Preveniamo la divisione per zero e il rumore vicino allo zero
	if r < 0.001:
		return Vector3.ZERO
		
	# 1. Vettori unitari e Momento Dipolare
	var r_hat: Vector3 = r_vec.normalized()
	var m_hat: Vector3 = global_dipole_axis # Asse globale preso dal padre
	var M: float = dipole_moment
	
	# 2. Formula del dipolo magnetico ideale:
	# B = (M / r^3) * (3 * (r_hat . m_hat) * r_hat - m_hat)
	
	var r_dot_m: float = r_hat.dot(m_hat)
	
	# Fattore di decadimento (1 / r^3)
	var falloff: float = M / pow(r, 3) 
	
	# Vettore di campo (componente vettoriale)
	var B_vec: Vector3 = (3.0 * r_dot_m * r_hat) - m_hat
	
	var final_vector: Vector3 = B_vec * falloff
	
	# Applica la Dead Zone
	if final_vector.length_squared() < min_magnitude * min_magnitude:
		return Vector3.ZERO
	
	return final_vector
