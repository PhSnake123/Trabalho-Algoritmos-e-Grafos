class_name MapGenerator

# Carrega nossos modelos de tile
const PAREDE: MapTileData = preload("res://assets/tileinfo/parede.tres")
const CHAO: MapTileData = preload("res://assets/tileinfo/chao.tres")
const DANO: MapTileData = preload("res://assets/tileinfo/dano.tres")
const BLOCK: MapTileData = preload("res://assets/tileinfo/bloco.tres")
# NOVO: Tile específico para terminais
const TERMINAL_TILE: MapTileData = preload("res://assets/tileinfo/terminal.tres")

# Constantes de Tamanho (ajuste conforme necessário)
const LARGURA = 43 
const ALTURA = 33 

# --- GERAÇÃO BASE ---

# Retorna um Array 2D preenchido com PAREDE
func gerar_grid():
	var grid = []
	for y in range(ALTURA):
		var linha: Array[MapTileData] = []
		for x in range(LARGURA):
			linha.push_back(PAREDE)
		grid.push_back(linha)
	return grid

# Lógica de Randomized DFS para criar o labirinto
func gerar_labirinto_dfs(grid, x, y):
	var pilha = []
	pilha.push_back(Vector2i(x, y)) 
	grid[y][x] = CHAO

	while not pilha.is_empty():
		var pos_atual = pilha.back() 
		var vizinhos = _obter_vizinhos_validos(grid, pos_atual.x, pos_atual.y)

		if not vizinhos.is_empty():
			var proxima_pos = vizinhos.pick_random() 
			_cavar_caminho(grid, pos_atual, proxima_pos)
			pilha.push_back(proxima_pos)
		else:
			pilha.pop_back() 

# Quebra paredes para criar ciclos e deixar o mapa menos linear
func quebrar_paredes_internas(grid, porcentagem_quebra = 0.15):
	for y in range(1, ALTURA - 1):
		for x in range(1, LARGURA - 1):
			if grid[y][x] == PAREDE:
				if grid[y-1][x] == CHAO and grid[y+1][x] == CHAO:
					if randf() < porcentagem_quebra: 
						grid[y][x] = CHAO
				elif grid[y][x-1] == CHAO and grid[y][x+1] == CHAO:
					if randf() < porcentagem_quebra:
						grid[y][x] = CHAO

# --- POSICIONAMENTO DE OBJETOS ---

func adicionar_terrenos_especiais(grid, total_lava: int, total_portas: int, inicio_pos: Vector2i):
	var tentativas_max = LARGURA * ALTURA 
	
	# 1. LAVA
	var lava_colocada = 0
	var tentativas = 0
	while lava_colocada < total_lava and tentativas < tentativas_max:
		var x = randi_range(1, LARGURA - 2)
		var y = randi_range(1, ALTURA - 2)
		if _pode_colocar_lava(grid, x, y, inicio_pos):
			grid[y][x] = DANO
			lava_colocada += 1
		tentativas += 1
	
	# 2. PORTAS
	var portas_colocadas = 0
	tentativas = 0 
	while portas_colocadas < total_portas and tentativas < tentativas_max:
		var x = randi_range(1, LARGURA - 2)
		var y = randi_range(1, ALTURA - 2)
		if _pode_colocar_porta(grid, x, y):
			grid[y][x] = BLOCK
			portas_colocadas += 1
		tentativas += 1

# [NOVO] Função para posicionar Terminais (Fase 3)
func adicionar_terminais(grid, quantidade: int, inicio_pos: Vector2i) -> Array[Vector2i]:
	var terminais: Array[Vector2i] = []
	var tentativas_max = 1000
	var tentativas = 0
	
	print("MapGenerator: Tentando posicionar %d terminais..." % quantidade)
	
	while terminais.size() < quantidade and tentativas < tentativas_max:
		var x = randi_range(1, LARGURA - 2)
		var y = randi_range(1, ALTURA - 2)
		var pos = Vector2i(x, y)
		
		var tile_atual = grid[y][x]
		
		# Regras: Deve ser CHÃO, não ser o início, e não estar na lista ainda
		if tile_atual == CHAO and pos != inicio_pos and not (pos in terminais):
			
			# Verifica espalhamento (distância mínima 10 entre terminais)
			var muito_perto = false
			for t in terminais:
				if (abs(pos.x - t.x) + abs(pos.y - t.y)) < 10:
					muito_perto = true
					break
			
			if not muito_perto:
				# SUCESSO: Define o tile lógico como TERMINAL
				grid[y][x] = TERMINAL_TILE 
				terminais.push_back(pos)
		
		tentativas += 1
	
	print("MapGenerator: Terminais posicionados em: ", terminais)
	return terminais

# --- FUNÇÕES AUXILIARES E VALIDAÇÕES ---

func _direcoes_dfs():
	return [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]

func _coordenada_valida(x, y):
	return (x >= 0 and x < LARGURA and y >= 0 and y < ALTURA)

func _celula_eh_parede(grid, x, y):
	var tile = grid[y][x] as MapTileData
	if tile:
		return not tile.passavel
	return true

func _obter_vizinhos_validos(grid, x, y):
	var vizinhos_validos = []
	for dir in _direcoes_dfs():
		var nx = x + dir.x
		var ny = y + dir.y
		
		if _coordenada_valida(nx, ny) and _celula_eh_parede(grid, nx, ny):
			vizinhos_validos.push_back(Vector2i(nx, ny))
	
	return vizinhos_validos

func _marcar_como_chao(grid, x, y):
	grid[y][x] = CHAO

func _cavar_caminho(grid, pos1, pos2):
	var meio_x = (pos1.x + pos2.x) / 2
	var meio_y = (pos1.y + pos2.y) / 2
	grid[meio_y][meio_x] = CHAO
	_marcar_como_chao(grid, pos2.x, pos2.y)

func _contar_vizinhos(grid, x, y, tile_alvo: MapTileData) -> int:
	var contagem = 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0: continue
			
			var nx = x + dx
			var ny = y + dy
			
			if _coordenada_valida(nx, ny) and grid[ny][nx] == tile_alvo:
				contagem += 1
	return contagem

func _pode_colocar_lava(grid, x, y, inicio_pos: Vector2i) -> bool:
	var pos = Vector2i(x, y)
	if grid[y][x] != CHAO: return false
	if pos == inicio_pos: return false
	var distancia = abs(pos.x - inicio_pos.x) + abs(pos.y - inicio_pos.y)
	if distancia < 10: return false
	return true 

func _pode_colocar_porta(grid, x, y) -> bool:
	if grid[y][x] != PAREDE: return false
	if _contar_vizinhos(grid, x, y, BLOCK) > 0: return false
	
	var chao_acima = (grid[y-1][x] == CHAO)
	var chao_abaixo = (grid[y+1][x] == CHAO)
	var chao_esquerda = (grid[y][x-1] == CHAO)
	var chao_direita = (grid[y][x+1] == CHAO)
	
	var eh_parede_vertical = chao_acima and chao_abaixo
	var eh_parede_horizontal = chao_esquerda and chao_direita
	
	if eh_parede_vertical == eh_parede_horizontal: return false
	
	if eh_parede_vertical:
		if grid[y][x-1] != PAREDE or grid[y][x+1] != PAREDE: return false 
	
	if eh_parede_horizontal:
		if grid[y-1][x] != PAREDE or grid[y+1][x] != PAREDE: return false 
			
	return true
