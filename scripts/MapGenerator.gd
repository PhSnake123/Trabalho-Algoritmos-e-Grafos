class_name MapGenerator

# Carrega nossos modelos de tile
const PAREDE: MapTileData = preload("res://assets/tileinfo/parede.tres")
const CHAO: MapTileData = preload("res://assets/tileinfo/chao.tres")
const DANO: MapTileData = preload("res://assets/tileinfo/dano.tres")
const BLOCK: MapTileData = preload("res://assets/tileinfo/bloco.tres")
# NOVO: Tile específico para terminais
const TERMINAL_TILE: MapTileData = preload("res://assets/tileinfo/terminal.tres")

# Constantes de Tamanho (ajuste conforme necessário)
var largura = 23
var altura = 23 

const TILE_REGISTRY = {
	"Dano": preload("res://assets/tileinfo/dano.tres"),
	"Lama": preload("res://assets/tileinfo/lama.tres"),
	# "Veneno": preload("res://assets/tileinfo/veneno.tres") # Exemplo futuro
}

# --- GERAÇÃO BASE ---

# Retorna um Array 2D preenchido com PAREDE
func gerar_grid(p_largura: int, p_altura: int):
	self.largura = p_largura
	self.altura = p_altura
	
	var grid = []
	for y in range(self.altura):
		var linha: Array[MapTileData] = []
		for x in range(self.largura):
			linha.push_back(PAREDE) # Começa tudo parede
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
	for y in range(1, self.altura - 1):
		for x in range(1, self.largura - 1):
			if grid[y][x] == PAREDE:
				if grid[y-1][x] == CHAO and grid[y+1][x] == CHAO:
					if randf() < porcentagem_quebra: 
						grid[y][x] = CHAO
				elif grid[y][x-1] == CHAO and grid[y][x+1] == CHAO:
					if randf() < porcentagem_quebra:
						grid[y][x] = CHAO

# --- POSICIONAMENTO DE OBJETOS ---

# Função genérica que aceita qualquer tile configurado no Registry
# (Adaptada para o MapGenerator sem Padding)
func aplicar_tiles_especiais(grid, config_tiles: Dictionary, total_portas: int, inicio_pos: Vector2i):
	
	# 1. LIDA COM O DICIONÁRIO (Lava, Lama, etc)
	for nome_tile in config_tiles:
		var quantidade = config_tiles[nome_tile]
		
		# Verifica se conhecemos esse tile no TILE_REGISTRY
		if TILE_REGISTRY.has(nome_tile):
			var recurso_tile = TILE_REGISTRY[nome_tile]
			var colocados = 0
			var tentativas = 0
			var tentativas_max = self.largura * self.altura
			
			# Tenta colocar a quantidade pedida
			while colocados < quantidade and tentativas < tentativas_max:
				tentativas += 1
				
				# Sorteia posição (USANDO LIMITES DO MAPA ATUAL)
				var x = randi_range(1, self.largura - 2)
				var y = randi_range(1, self.altura - 2)
				
				# Só coloca se for CHÃO
				if grid[y][x] == CHAO: 
					# Verifica proximidade do início (segurança)
					# (Reutilizamos a lógica que já existia no _pode_colocar_lava para verificar distância)
					var pos = Vector2i(x, y)
					if pos == inicio_pos: continue
					var distancia = abs(pos.x - inicio_pos.x) + abs(pos.y - inicio_pos.y)
					if distancia < 10: continue
					
					# Aplica o tile novo
					grid[y][x] = recurso_tile.duplicate()
					colocados += 1
		else:
			if quantidade > 0:
				print("AVISO: Tile '%s' solicitado no LevelDefinition mas não registrado no MapGenerator." % nome_tile)

	# 2. LIDA COM PORTAS
	var portas_colocadas = 0
	var tentativas = 0 
	var tentativas_max_porta = self.largura * self.altura
	
	while portas_colocadas < total_portas and tentativas < tentativas_max_porta:
		tentativas += 1
		var x = randi_range(1, self.largura - 2)
		var y = randi_range(1, self.altura - 2)
		
		if _pode_colocar_porta(grid, x, y):
			grid[y][x] = BLOCK.duplicate()
			portas_colocadas += 1

# --- FUNÇÕES AUXILIARES E VALIDAÇÕES ---

func _direcoes_dfs():
	return [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]

func _coordenada_valida(x, y):
	return (x >= 0 and x < self.largura and y >= 0 and y < self.altura)

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

# Cria espaços abertos (salas) em cima do labirinto já gerado
func criar_salas_no_labirinto(grid, quantidade_salas: int, tamanho_min: int, tamanho_max: int):
	var salas_criadas = 0
	var tentativas = 0
	var max_tentativas = quantidade_salas * 5
	
	while salas_criadas < quantidade_salas and tentativas < max_tentativas:
		tentativas += 1
		
		# Escolhe largura e altura aleatórias para a sala
		var w = randi_range(tamanho_min, tamanho_max)
		var h = randi_range(tamanho_min, tamanho_max)
		
		# Escolhe posição aleatória (garantindo margem das bordas)
		var x = randi_range(2, self.largura - w - 2)
		var y = randi_range(2, self.altura - h - 2)
		
		# Opcional: Verificar se não sobrepõe muito outra sala (para não virar um salão gigante)
		# Mas para o MVP, deixar sobrepor cria formatos interessantes.
		
		# "Esculpe" a sala: Transforma tudo naquele retângulo em CHAO
		for i in range(y, y + h):
			for j in range(x, x + w):
				grid[i][j] = CHAO
		
		salas_criadas += 1
		print("Sala %d criada em (%d, %d) com tamanho %dx%d" % [salas_criadas, x, y, w, h])

func _eh_chao_valido(grid, x, y):
	if not _coordenada_valida(x, y): return false
	return grid[y][x].passavel and grid[y][x].tipo != "FakeWall"

func adicionar_terminais(grid, quantidade: int, inicio_pos: Vector2i) -> Array[Vector2i]:
	var terminais: Array[Vector2i] = []
	var tentativas_max = 500 # Tentativas "bonitas"
	var tentativas = 0
	
	print("MapGenerator: Tentando posicionar %d terminais (Modo Ideal)..." % quantidade)
	
	# --- FASE 1: TENTATIVA IDEAL (Com distanciamento) ---
	while terminais.size() < quantidade and tentativas < tentativas_max:
		var x = randi_range(1, self.largura - 2)
		var y = randi_range(1, self.altura - 2)
		var pos = Vector2i(x, y)
		
		# Regras estritas: Distância > 10
		if _eh_posicao_valida_para_terminal(grid, pos, inicio_pos, terminais, 10):
			grid[y][x] = TERMINAL_TILE.duplicate()
			terminais.push_back(pos)
		
		tentativas += 1
	
	# --- FASE 2: HARD FIX (Modo Pânico) ---
	if terminais.size() < quantidade:
		print("MapGenerator: AVISO - Falha no spawn ideal. Iniciando FORCE SPAWN para %d terminais restantes." % (quantidade - terminais.size()))
		
		# 1. Coleta TODOS os chãos válidos do mapa
		var candidatos: Array[Vector2i] = []
		for y in range(1, self.altura - 1):
			for x in range(1, self.largura - 1):
				var pos = Vector2i(x, y)
				# Se é chão E não é o início E não é um terminal já colocado
				if grid[y][x] == CHAO and pos != inicio_pos and not (pos in terminais):
					candidatos.push_back(pos)
		
		# 2. Embaralha para não ficar linear
		candidatos.shuffle()
		
		# 3. Preenche o que falta
		while terminais.size() < quantidade and not candidatos.is_empty():
			var pos = candidatos.pop_back()
			
			grid[pos.y][pos.x] = TERMINAL_TILE.duplicate()
			
			terminais.push_back(pos)
			print("MapGenerator: Terminal forçado em ", pos)

	if terminais.size() < quantidade:
		print("MapGenerator: ERRO CRÍTICO. Não há chão suficiente no mapa para os terminais!")
	else:
		print("MapGenerator: Terminais posicionados com sucesso: ", terminais)
		
	return terminais

# Função auxiliar para limpar o código
func _eh_posicao_valida_para_terminal(grid, pos: Vector2i, inicio: Vector2i, lista_atual: Array, dist_min: int) -> bool:
	if grid[pos.y][pos.x] != CHAO: return false
	if pos == inicio: return false
	if pos in lista_atual: return false
	
	# Verifica distância do player
	if (abs(pos.x - inicio.x) + abs(pos.y - inicio.y)) < dist_min: return false
	
	# Verifica distância dos outros terminais
	for t in lista_atual:
		if (abs(pos.x - t.x) + abs(pos.y - t.y)) < dist_min: return false
		
	return true

# Retorna lista de Vector2i que são "pontas soltas" no labirinto
func encontrar_becos_sem_saida(grid: Array, exit_pos: Vector2i, player_pos: Vector2i) -> Array[Vector2i]:
	var becos: Array[Vector2i] = []

	# Itera ignorando as bordas externas (que são sempre parede)
	for y in range(1, self.altura - 1):
		for x in range(1, self.largura - 1):
			# Só analisa chão
			var tile = grid[y][x] as MapTileData
			if not tile.passavel:
				continue
			
			var pos = Vector2i(x, y)
			
			# Ignora posições críticas (Início e Fim)
			# Não queremos bloquear a saída ou spawnar um baú na cabeça do player
			if pos == exit_pos or pos == player_pos:
				continue
			
			# Conta vizinhos passáveis (Cardeais: Cima, Baixo, Esq, Dir)
			var vizinhos_livres = 0
			
			# Checagem direta nos vizinhos (o loop já evita index out of bounds)
			if grid[y-1][x].passavel: vizinhos_livres += 1
			if grid[y+1][x].passavel: vizinhos_livres += 1
			if grid[y][x-1].passavel: vizinhos_livres += 1
			if grid[y][x+1].passavel: vizinhos_livres += 1
			
			# Se só tem 1 vizinho (o caminho de onde veio), é um Beco Sem Saída
			if vizinhos_livres == 1:
				becos.push_back(pos)
				
	return becos

"""
Mecânica deletada por introduzir muitos bugs. Talves se tivéssemos mais tempo...

func criar_sala_secreta(grid) -> Vector2i:
	print("MapGenerator: Forçando criação de Sala Secreta...")
	
	# Dimensões da sala
	var w = 3
	var h = 3
	
	# Tenta encontrar um lugar válido perto das bordas
	# Tentamos 4 cantos ou bordas aleatórias
	var tentativas = 0
	while tentativas < 20:
		tentativas += 1
		
		# Escolhe uma posição encostada em uma das bordas (com margem de 1 para parede externa)
		var x = randi_range(1, self.largura - w - 2)
		var y = randi_range(1, self.altura - h - 2)
		
		# Vamos forçar ser numa borda? 
		# 50% chance de grudar no X, 50% no Y para garantir "Outer Walls"
		if randf() > 0.5:
			x = 1 if randf() > 0.5 else self.largura - w - 1
		else:
			y = 1 if randf() > 0.5 else self.altura - h - 1
			
		# Centro da sala
		var centro = Vector2i(x + 1, y + 1)
		
		# 1. ESCAVAÇÃO E ISOLAMENTO
		# Preenche a área + borda de segurança com PAREDES primeiro (reset local)
		for i in range(y - 1, y + h + 1):
			for j in range(x - 1, x + w + 1):
				if _coordenada_valida(j, i):
					grid[i][j] = PAREDE
					
		# Agora escava o miolo com CHÃO (A sala em si)
		for i in range(y, y + h):
			for j in range(x, x + w):
				if _coordenada_valida(j, i):
					# Cria um novo tile de chão para garantir propriedades limpas
					grid[i][j] = CHAO.duplicate()
		
		# 2. CRIAR A ENTRADA FALSA
		# Procura um vizinho que seja CHÃO do labirinto principal para conectar
		var possiveis_entradas = []
		
		# Verifica o perímetro da sala
		for i in range(y, y + h):
			# Esquerda e Direita
			if _eh_chao_valido(grid, x - 2, i): possiveis_entradas.push_back(Vector2i(x - 1, i)) # Parede da esquerda
			if _eh_chao_valido(grid, x + w + 1, i): possiveis_entradas.push_back(Vector2i(x + w, i)) # Parede da direita
			
		for j in range(x, x + w):
			# Cima e Baixo
			if _eh_chao_valido(grid, j, y - 2): possiveis_entradas.push_back(Vector2i(j, y - 1))
			if _eh_chao_valido(grid, j, y + h + 1): possiveis_entradas.push_back(Vector2i(j, y + h))
			
		if possiveis_entradas.size() > 0:
			var pos_entrada = possiveis_entradas.pick_random()
			
			# Cria a Parede Falsa
			# Duplicamos a PAREDE visualmente, mas mudamos a lógica
			var fake_wall = PAREDE.duplicate()
			fake_wall.tipo = "FakeWall"
			fake_wall.passavel = true # O segredo!
			fake_wall.custo_tempo = 1.0 # Sem custo extra (ou 0 se preferir)
			
			grid[pos_entrada.y][pos_entrada.x] = fake_wall
			
			print("MapGenerator: Sala Secreta criada em ", centro, " Entrada em: ", pos_entrada)
			
			# Coloca algo no meio da sala? (Ex: Chão diferente ou vazio por enquanto)
			return centro
	
	print("MapGenerator: Falha crítica ao posicionar sala secreta.")
	return Vector2i.ZERO
	"""
