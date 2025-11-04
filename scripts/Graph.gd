# res://scripts/Graph.gd
class_name Graph

# Precisamos das constantes LARGURA, ALTURA, e TileType
const MapGenerator = preload("res://scripts/MapGenerator.gd")

var largura: int = MapGenerator.LARGURA
var altura: int = MapGenerator.ALTURA
var grid_logico: Array
var adjacencias = {} # Nosso dicionário de adjacências

# Construtor (como o __init__ do Python)
func _init(p_grid_logico: Array):
	self.grid_logico = p_grid_logico
	_construir_grafo()

# Constrói a lista de adjacências
func _construir_grafo():
	for y in range(altura):
		for x in range(largura):
			var vertice_atual = Vector2i(x, y)
			
			if not _e_passavel(vertice_atual):
				continue # Ignora paredes
			
			# Inicializa a lista de adjacências para este vértice
			adjacencias[vertice_atual] = []
			
			# Checa os vizinhos (N, S, L, O)
			for vizinho in _obter_vizinhos(vertice_atual):
				if _e_passavel(vizinho):
					# No seu protótipo, você tinha custos de tempo.
					# Por enquanto, nosso custo é 1 (um passo).
					var custo = 1
					adjacencias[vertice_atual].push_back([vizinho, custo])

# Retorna true se o tile for um CHÃO
func _e_passavel(pos: Vector2i) -> bool:
	return grid_logico[pos.y][pos.x] == MapGenerator.TileType.CHAO

# Retorna uma lista de vizinhos válidos (N, S, L, O)
func _obter_vizinhos(pos: Vector2i) -> Array[Vector2i]:
	var direcoes = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var vizinhos_validos: Array[Vector2i] = []
	for dir in direcoes:
		var nova_pos = pos + dir
		# Checa se está dentro dos limites do mapa
		if (nova_pos.x >= 0 and nova_pos.x < largura and
			nova_pos.y >= 0 and nova_pos.y < altura):
			vizinhos_validos.push_back(nova_pos)
	return vizinhos_validos
