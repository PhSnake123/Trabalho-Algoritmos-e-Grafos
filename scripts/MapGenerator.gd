enum TileType { PAREDE, CHAO }

# 2. Constantes do 'world_map.py'
const LARGURA = 51
const ALTURA = 31

# 3. Tradução do 'gerar_grid()'
# Retorna um Array 2D preenchido com PAREDE
func gerar_grid():
	var grid = []
	for y in range(ALTURA):
		var linha = []
		for x in range(LARGURA):
			linha.push_back(TileType.PAREDE)
		grid.push_back(linha)
	return grid

# 4. Tradução do 'gerar_labirinto_dfs()'
# Esta é a sua lógica de Randomized DFS, traduzida 1-para-1
func gerar_labirinto_dfs(grid, x, y):
	var pilha = []
	pilha.push_back(Vector2i(x, y)) # Vector2i é como uma tupla (x, y) de inteiros
	grid[y][x] = TileType.CHAO

	while not pilha.is_empty():
		var pos_atual = pilha.back() # .back() é o mesmo que pilha[-1] em Python
		var vizinhos = _obter_vizinhos_validos(grid, pos_atual.x, pos_atual.y)

		if not vizinhos.is_empty():
			var proxima_pos = vizinhos.pick_random() # .pick_random() é o random.choice()
			_cavar_caminho(grid, pos_atual, proxima_pos)
			pilha.push_back(proxima_pos)
		else:
			pilha.pop_back() # .pop_back() é o pilha.pop()

# --- Funções Auxiliares (Helpers) ---

# Nota: Funções que começam com '_' são consideradas "privadas"
func _direcoes_dfs():
	return [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]

func _coordenada_valida(x, y):
	return (x >= 0 and x < LARGURA and y >= 0 and y < ALTURA)

func _celula_eh_parede(grid, x, y):
	return grid[y][x] == TileType.PAREDE

func _obter_vizinhos_validos(grid, x, y):
	var vizinhos_validos = []
	for dir in _direcoes_dfs():
		var nx = x + dir.x
		var ny = y + dir.y
		
		if _coordenada_valida(nx, ny) and _celula_eh_parede(grid, nx, ny):
			vizinhos_validos.push_back(Vector2i(nx, ny))
	
	return vizinhos_validos

func _marcar_como_chao(grid, x, y):
	grid[y][x] = TileType.CHAO

func _cavar_caminho(grid, pos1, pos2):
	var meio_x = (pos1.x + pos2.x) / 2
	var meio_y = (pos1.y + pos2.y) / 2
	grid[meio_y][meio_x] = TileType.CHAO
	_marcar_como_chao(grid, pos2.x, pos2.y)

# Esta função cria atalhos e loops, quebrando paredes internas.
func quebrar_paredes_internas(grid, porcentagem_quebra = 0.15):
	# Itera pelo grid, mas evita as bordas externas (range 1 até -1)
	for y in range(1, ALTURA - 1):
		for x in range(1, LARGURA - 1):
			
			# Se este tile for uma parede, veja se é uma "parede interna"
			if grid[y][x] == TileType.PAREDE:
				
				# Checa se é uma parede "horizontal" (chão em cima e embaixo)
				if grid[y-1][x] == TileType.CHAO and grid[y+1][x] == TileType.CHAO:
					if randf() < porcentagem_quebra: # randf() = float aleatório 0.0 a 1.0
						grid[y][x] = TileType.CHAO
				
				# Checa se é uma parede "vertical" (chão à esquerda e à direita)
				elif grid[y][x-1] == TileType.CHAO and grid[y][x+1] == TileType.CHAO:
					if randf() < porcentagem_quebra:
						grid[y][x] = TileType.CHAO
