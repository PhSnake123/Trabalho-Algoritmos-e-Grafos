# res://scripts/Graph.gd
class_name Graph

var largura: int
var altura: int
var grid_logico: Array
var adjacencias = {} # Nosso dicionário de adjacências

# Construtor (como o __init__ do Python)
func _init(p_grid_logico: Array):
	self.grid_logico = p_grid_logico
	# Detecta o tamanho automaticamente baseado no array que recebeu
	self.altura = grid_logico.size()
	if self.altura > 0:
		self.largura = grid_logico[0].size()
	else:
		self.largura = 0
	_construir_grafo()

# Constrói a lista de adjacências
func _construir_grafo():
	for y in range(altura):
		for x in range(largura):
			var vertice_atual = Vector2i(x, y)
			var tile_atual: MapTileData = grid_logico[y][x]
			
			# 1. Ignora este tile se ELE MESMO não for passável
			# (Isto previne que paredes sejam vértices no grafo)
			if not tile_atual.passavel:
				continue 
			
			# Se for passável, inicializa sua lista de adjacência
			adjacencias[vertice_atual] = []
			
			# 2. Olha os vizinhos
			for vizinho_pos in _obter_vizinhos(vertice_atual):
				var tile_vizinho: MapTileData = grid_logico[vizinho_pos.y][vizinho_pos.x]
				
				# 3. MUDANÇA PRINCIPAL:
				# Em vez de checar 'custo == INF', checamos se o VIZINHO é passável.
				if tile_vizinho.passavel:
					# Se pudermos ir para lá, pegue seu custo de tempo real
					var custo = tile_vizinho.custo_tempo
					adjacencias[vertice_atual].push_back([vizinho_pos, custo])
				
				# Se o vizinho não for passável (ex: Parede),
				# nós simplesmente NÃO adicionamos uma aresta.
				# O "infinito" é implícito pela *ausência* de um caminho.

# Retorna true se o tile for um CHÃO
func _e_passavel(pos: Vector2i) -> bool:
	# Converte o tipo de forma segura
	var tile: MapTileData = grid_logico[pos.y][pos.x] as MapTileData
	
	# Checa se a conversão funcionou e se o tile é passável
	if tile:
		return tile.passavel
	
	# Se a conversão falhar (tile for nulo), é seguro tratar como não-passável
	return false

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
