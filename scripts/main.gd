# res://scripts/Main.gd
extends Node2D

@export var fog_enabled := true
var musica_teste = preload("res://Audio/music/Erik_Satie_Gymnopédie_No.1.ogg") 

# 1. Carrega o script de lógica
const TILE_SIZE := 16
const SAVE_POINT_TILE = preload("res://assets/tileinfo/savepoint.tres")

# 2. Referência aos nós da cena
@onready var tile_map = $TileMap
@onready var tile_map_fog = $TileMap_Fog
@onready var tile_map_path = $TileMap_Path
@onready var camera: Camera2D = $Player/Camera2D
@onready var player = $Player

# 3. IDs dos Tiles (Atlas Coordinates ou Source IDs)
const ID_PAREDE = 0
const ID_CHAO = 1
const ID_SAIDA = 2
const ID_DANO = 3
const ID_BLOCK = 4     # Porta/Bloqueio
const ID_SAVE_POINT = 5
const ID_TERMINAL = 6  # <--- ID do TileSet Source para o Terminal
const ID_SAIDA_FECHADA = 4 # Usando visual de 'Block' temporariamente para saída trancada
const ID_FOG = 0
const ID_CAMINHO = 0

# 4. Dados do mapa
var map_data = []
var fog_logic: FogOfWar
var grafo: Graph
var dijkstra: Dijkstra
var bfs: BFS
var vertice_fim: Vector2i
var save_point_pos
var camera_zoom_X = 2
var camera_zoom_Y = 2

# Variáveis para o AStar e Drones
var astar: AStar
var caminhos_ativos: Dictionary = {} 
var _proximo_id_caminho: int = 0 

# Lista de scanners rodando visualmente no momento
var scanners_ativos: Array[Dictionary] = [] 

# Variável de controle do Modo MST
var terminais_pos: Array[Vector2i] = [] 
var saida_destrancada: bool = false # Controla se a saída está acessível

# --- CONFIGURAÇÃO DE SPAWN ---
@export_group("Configuração de Spawn")
@export var cena_inimigo: PackedScene = preload("res://scenes/Enemy.tscn") # <--- ARRASTE SUA CENA AQUI
@export var cena_npc: PackedScene = preload("res://scenes/NPC.tscn")
@export var qtd_inimigos_spawn: int = 3         # Quantos inimigos criar
@export var raio_minimo_spawn: int = 15         # Distância mínima em TILES do jogador
@export var tentativas_spawn: int = 100         # Segurança para não travar o loop

func _ready():
	var vertice_inicio = Vector2i(1, 1) 
	
	SaveManager.register_main(self)
	AudioManager.play_music(musica_teste)

	# 1. GERAÇÃO DO MAPA BASE
	var map_generator = MapGenerator.new()
	map_data = map_generator.gerar_grid()
	map_generator.gerar_labirinto_dfs(map_data, 1, 1)
	map_generator.quebrar_paredes_internas(map_data, 0.3)

	# 2. CONFIGURAÇÃO DO MODO DE JOGO
	var modo_jogo = "MST" 
	print("--- MODO DE JOGO ATUAL: ", modo_jogo, " ---")
	
	# Reseta estado da saída
	saida_destrancada = false
	if modo_jogo == "NORMAL":
		saida_destrancada = true # No modo normal já começa aberta

	# Definimos os terrenos especiais
	if modo_jogo == "NORMAL":
		map_generator.adicionar_terrenos_especiais(map_data, 50, 25, vertice_inicio)
	else:
		# Modo MST: Menos portas para facilitar navegação entre terminais
		map_generator.adicionar_terrenos_especiais(map_data, 40, 20, vertice_inicio)
		
		# GERA OS TERMINAIS LÓGICOS
		terminais_pos = map_generator.adicionar_terminais(map_data, 3, vertice_inicio)
		Game_State.terminais_necessarios = terminais_pos.size()
		Game_State.terminais_ativos = 0

	# 3. CRIA O GRAFO E ALGORITMOS
	grafo = Graph.new(map_data)
	dijkstra = Dijkstra.new(grafo)
	astar = AStar.new(grafo)
	bfs = BFS.new(grafo)
	
	# 4. CÁLCULO DE OBJETIVOS E TEMPO PAR
	
	if modo_jogo == "NORMAL":
		# --- LÓGICA FASE 1/2 (Dijkstra Simples) ---
		vertice_fim = dijkstra.encontrar_vertice_final(vertice_inicio)
		print("Vértice final definido em: ", vertice_fim)
		
		if dijkstra.distancias.has(vertice_fim):
			Game_State.tempo_par_level = dijkstra.distancias[vertice_fim]
			print("Tempo PAR (Dijkstra): ", Game_State.tempo_par_level)
		else:
			print("ERRO: Saída inalcançável no modo Normal.")
			
	elif modo_jogo == "MST":
		# --- LÓGICA FASE 3 (Prim / Terminais) ---
		
		# 1. Primeiro definimos onde é a SAÍDA (longe do início)
		vertice_fim = dijkstra.encontrar_vertice_final(vertice_inicio)
		print("Modo MST: Saída definida em ", vertice_fim)
		
		# 2. Calculamos a MST incluindo TUDO (Início + Terminais + Fim)
		print("Calculando MST (Start -> Terminais -> Exit)...")
		
		var pontos_interesse = [vertice_inicio] + terminais_pos + [vertice_fim]
		var grafo_abstrato = {}
		
		for origem in pontos_interesse:
			grafo_abstrato[origem] = {}
			var resultado = dijkstra.calcular_caminho_minimo(origem)
			var dists = resultado["distancias"]
			
			for destino in pontos_interesse:
				if origem == destino: continue
				if dists.has(destino) and dists[destino] != INF:
					grafo_abstrato[origem][destino] = dists[destino]
		
		# Roda o Prim no grafo completo
		var resultado_mst = Prim.calcular_mst(grafo_abstrato) # Nova função
		var custo_mst = resultado_mst["custo"]
		
		Game_State.tempo_par_level = custo_mst
		
		print("Terminais Ativos: ", terminais_pos.size())
		print("Tempo PAR Ajustado (MST + Saída): ", custo_mst)
		dijkstra.calcular_caminho_minimo(vertice_inicio)

	# 5. LÓGICA DO SAVE POINT
	var caminho_minimo = dijkstra.reconstruir_caminho(vertice_inicio, vertice_fim)
	save_point_pos = null
	
	# Checagem de segurança extra para caminho válido
	if not caminho_minimo.is_empty() and caminho_minimo.size() > 2:
		var mid_index = (caminho_minimo.size() / 2) as int
		save_point_pos = caminho_minimo[mid_index]
		
		# Só cria se não conflitar com terminais
		if not (save_point_pos in terminais_pos):
			map_data[save_point_pos.y][save_point_pos.x] = SAVE_POINT_TILE
			print("Save Point gerado em: ", save_point_pos)
	else:
		print("AVISO: Não foi possível gerar Save Point (Caminho inválido ou curto demais).")
	
	# 6. FINALIZAÇÃO VISUAL
	_draw_map()
	_setup_camera()
	
	fog_logic = FogOfWar.new(MapGenerator.LARGURA, MapGenerator.ALTURA, 5)
	if not fog_enabled:
		tile_map_fog.hide()
	
	# Revela Save Point e Terminais na fog (facilita teste)
	if fog_enabled:
		if save_point_pos != null:
			fog_logic.fog_data[save_point_pos.y][save_point_pos.x] = false
		for t in terminais_pos:
			fog_logic.fog_data[t.y][t.x] = false

	update_fog(vertice_inicio)
	_spawnar_inimigos()
	_spawnar_npc_aleatorio()
	SaveManager.save_auto_game()
	print("Ready concluído.")

# --- [ALTERADO] LÓGICA DO DRONE SCANNER PERMANENTE ---
func _process(delta):
	# Se não tiver scanners, não gasta processamento
	if scanners_ativos.is_empty():
		return
		
	# Itera de trás para frente para poder remover itens da lista com segurança
	for i in range(scanners_ativos.size() - 1, -1, -1):
		var scanner = scanners_ativos[i]
		
		# Atualiza o timer de "passo" (velocidade da onda)
		scanner["timer_onda"] -= delta
		
		if scanner["timer_onda"] <= 0:
			scanner["timer_onda"] = 0.05 # Velocidade da onda (0.05s por tile)
			
			# --- FASE ÚNICA: EXPANDINDO ---
			# Como o efeito agora é permanente, só precisamos da lógica de expansão.
			if scanner["estado"] == "EXPANDINDO":
				var idx = scanner["index_atual"]
				var tiles = scanner["tiles_ordenados"]
				
				# Revela em blocos (batch) para ser mais fluido e performático
				var batch_size = 2 
				for _k in range(batch_size):
					if idx < tiles.size():
						var pos = tiles[idx]
						
						# Simplesmente revela permanentemente (False = Visível)
						# Não precisamos mais guardar quem estava visível antes
						fog_logic.fog_data[pos.y][pos.x] = false 
						
						idx += 1
					else:
						break
				
				scanner["index_atual"] = idx
				_draw_fog() # Atualiza visual
				
				# Se terminou de percorrer todos os tiles do raio BFS:
				if idx >= tiles.size():
					# O trabalho acabou. Removemos da lista.
					# Não há mais fases de "AGUARDANDO" ou "RECOLHENDO".
					scanners_ativos.remove_at(i)
# ---------------------------------------------------

func _draw_map():
	tile_map.clear()
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var tile: MapTileData = map_data[y][x]
			var tile_pos = Vector2i(x, y)
			
			# 1. DESENHO DA SAÍDA (Prioridade Máxima)
			if tile_pos == vertice_fim:
				if saida_destrancada:
					# Aberta (Verde/Normal)
					tile_map.set_cell(0, tile_pos, ID_SAIDA, Vector2i(0, 0))
				else:
					# Fechada (Vermelha/Bloqueio)
					tile_map.set_cell(0, tile_pos, ID_SAIDA_FECHADA, Vector2i(0, 0))
			
			# 2. DESENHO DOS TERMINAIS
			# IMPORTANTE: Certifique-se que terminal.tres tem 'tipo' = "Terminal"
			elif tile.tipo == "Terminal":
				# Se ele ainda está na lista de pendentes, desenha o terminal
				if tile_pos in terminais_pos:
					tile_map.set_cell(0, tile_pos, ID_TERMINAL, Vector2i(0, 0))
				else:
					# Se já foi ativado, vira chão normal (ou um terminal 'apagado')
					tile_map.set_cell(0, tile_pos, ID_CHAO, Vector2i(0, 0))
				
			# 3. OUTROS TILES
			elif tile.tipo == "SavePoint":
				tile_map.set_cell(0, tile_pos, ID_SAVE_POINT, Vector2i(0, 0))
			
			elif not tile.passavel:
				if tile.eh_porta:
					tile_map.set_cell(0, tile_pos, ID_BLOCK, Vector2i(0, 0))
				else:
					tile_map.set_cell(0, tile_pos, ID_PAREDE, Vector2i(0, 0))
			else:
				if tile.tipo == "Dano":
					tile_map.set_cell(0, tile_pos, ID_DANO, Vector2i(0, 0))
				else:
					tile_map.set_cell(0, tile_pos, ID_CHAO, Vector2i(0, 0))

# --- VERIFICAÇÃO DE MOVIMENTO (Atualizada para Saída Trancada) ---
func is_tile_passable(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= MapGenerator.LARGURA: return false
	if grid_pos.y < 0 or grid_pos.y >= MapGenerator.ALTURA: return false
	
	# 1. Verifica se é a saída trancada
	if grid_pos == vertice_fim and not saida_destrancada:
		var restantes = Game_State.terminais_necessarios - Game_State.terminais_ativos
		print("A saída está trancada! Ative %d terminais restantes." % restantes)
		return false # Bloqueia movimento como se fosse parede
	
	var tile: MapTileData = map_data[grid_pos.y][grid_pos.x]
	return tile.passavel

# --- SISTEMA DE NÉVOA ---

func _draw_fog():
	tile_map_fog.clear()
	var fog_source_id = ID_FOG
	var fog_atlas_coord = Vector2i(0, 0)
	
	for y in range(fog_logic.altura):
		for x in range(fog_logic.largura):
			if fog_logic.fog_data[y][x] == true:
				tile_map_fog.set_cell(0, Vector2i(x, y), fog_source_id, fog_atlas_coord)

func update_fog(player_grid_pos: Vector2i):
	processar_passo_jogador()
	if not fog_enabled: return
	
	fog_logic.revelar_area(player_grid_pos.x, player_grid_pos.y, map_data)
	_draw_fog()
	
	# --- CORREÇÃO 3: MENSAGEM DE VITÓRIA ---
	if player_grid_pos == vertice_fim and saida_destrancada:
		print(">>> PARABÉNS! VOCÊ CHEGOU À SAÍDA! <<<")
		# OS.alert("Você escapou do labirinto!\nPontuação Final: " + str(Game_State.tempo_jogador), "VITÓRIA!")
		# Aqui você pode pausar a tree se quiser:
		# get_tree().paused = true

# --- INPUTS DE AÇÃO ---
func _unhandled_input(event):
	# Atalhos de Sistema (Debug/Menu)
	if event.is_action_pressed("save"): SaveManager.save_player_game()
	if event.is_action_pressed("load"): SaveManager.load_player_game()
	if event.is_action_pressed("load_start"): SaveManager.load_auto_game()

	# Atalho do Item Save Terminal
	if event.is_action_pressed("save_terminal"):
		var item_para_usar = Game_State.inventario_jogador.get_item_por_efeito(ItemData.EFEITO_SAVE_GAME)
		if item_para_usar:
			Game_State.inventario_jogador.remover_item(item_para_usar)
			SaveManager.save_player_game()

# --- FUNÇÕES DE UTILIDADE E DRONES ---

func get_tile_data(grid_pos: Vector2i) -> MapTileData:
	if grid_pos.x < 0 or grid_pos.x >= MapGenerator.LARGURA: return null
	if grid_pos.y < 0 or grid_pos.y >= MapGenerator.ALTURA: return null
	return map_data[grid_pos.y][grid_pos.x]

func _setup_camera():
	camera.zoom = Vector2(camera_zoom_X, camera_zoom_Y)
	var map_size_pixels = Vector2(MapGenerator.LARGURA, MapGenerator.ALTURA) * TILE_SIZE
	camera.limit_left = 0; camera.limit_top = 0
	camera.limit_right = map_size_pixels.x; camera.limit_bottom = map_size_pixels.y

func _registrar_novo_caminho(caminho_completo: Array[Vector2i], cor: Color, max_tiles: int, duracao: int, temporario: bool):
	_proximo_id_caminho += 1
	var id = _proximo_id_caminho
	
	var caminho_filtrado: Array[Vector2i] = []
	var limite = caminho_completo.size()
	if max_tiles != -1 and max_tiles < limite:
		limite = max_tiles
	
	for i in range(1, limite):
		caminho_filtrado.push_back(caminho_completo[i])
	
	var visual_node = tile_map_path.duplicate()
	visual_node.name = "DronePath_" + str(id)
	visual_node.modulate = cor 
	visual_node.clear() 
	add_child(visual_node) 
	
	var path_source_id = ID_CAMINHO
	var path_atlas_coord = Vector2i(0, 0)
	for pos in caminho_filtrado:
		visual_node.set_cell(0, pos, path_source_id, path_atlas_coord)
		
	caminhos_ativos[id] = {
		"tiles": caminho_filtrado,
		"cor": cor,
		"duracao_atual": duracao,
		"duracao_max": duracao,
		"temporario": temporario,
		"node": visual_node
	}
	print("Drone: Caminho ID %s registrado." % id)

func processar_passo_jogador():
	if caminhos_ativos.is_empty(): return
	var ids_para_remover = []
	for id in caminhos_ativos:
		var dados = caminhos_ativos[id]
		if dados["temporario"]:
			dados["duracao_atual"] -= 1
			var node = dados["node"]
			if dados["duracao_atual"] <= 0:
				ids_para_remover.push_back(id)
			else:
				var alpha = float(dados["duracao_atual"]) / float(dados["duracao_max"])
				if is_instance_valid(node): node.modulate.a = alpha
	
	for id in ids_para_remover:
		_remover_caminho_visual(id)

func _remover_caminho_visual(id: int):
	if caminhos_ativos.has(id):
		var dados = caminhos_ativos[id]
		var node = dados["node"]
		if is_instance_valid(node): node.queue_free()
		caminhos_ativos.erase(id)

# --- ATIVAÇÃO DO DRONE (Ajustada para ignorar duração) ---
func ativar_drone_scanner(origem: Vector2i, alcance: int, _duracao: float):
	# 1. Usa o BFS para pegar os tiles ordenados por distância (camadas)
	var area_tiles = bfs.obter_area_alcance(origem, alcance) #
	
	print("Main: Drone Scanner ativado. Tiles encontrados: ", area_tiles.size())
	
	# 2. Cria o objeto de controle da animação
	# Simplificado: removemos listas de 'afetados' pois não vamos reverter
	var novo_scanner = {
		"tiles_ordenados": area_tiles,
		"index_atual": 0,
		"timer_onda": 0.0,
		"estado": "EXPANDINDO" 
	}
	
	scanners_ativos.push_back(novo_scanner)

#Lógica do Drone Terraformer (Limpa Lava/Lama)
func ativar_drone_terraformer(origem: Vector2i, alcance: int):
	# 1. Pega os tiles na área geométrica (independente do custo)
	var area_tiles = bfs.obter_area_alcance(origem, alcance)
	var tiles_alterados = 0
	
	print("Terraformer: Escaneando %d tiles ao redor de %s..." % [area_tiles.size(), origem])
	
	for pos in area_tiles:
		# Pega o dado atual do tile
		var tile_atual: MapTileData = map_data[pos.y][pos.x]
		
		# CRITÉRIO DE LIMPEZA:
		# É do tipo "Dano"? OU Tem custo alto (Lama)? E não é parede/porta?
		if tile_atual.passavel and (tile_atual.tipo == "Dano" or tile_atual.custo_tempo > 1.0):
			
			# 2. IMPORTANTE: Duplicar o recurso para não alterar todos os tiles iguais do mapa
			var tile_novo = tile_atual.duplicate()
			
			# 3. Aplica as mudanças (Transforma em Chão Padrão)
			tile_novo.tipo = "Chao"
			tile_novo.custo_tempo = 1.0  # Custo normal
			tile_novo.dano_hp = 0        # Sem dano
			
			# Substitui no array de dados
			map_data[pos.y][pos.x] = tile_novo
			
			# 4. Atualiza Visual (Muda a textura para Chão)
			tile_map.set_cell(0, pos, ID_CHAO, Vector2i(0,0))
			
			# 5. Atualiza Grafo (Avisa que o peso mudou!)
			if grafo:
				grafo.atualizar_aresta_dinamica(pos)
				
			tiles_alterados += 1
			
			# Efeito visual extra: revela na névoa também, já que limpamos
			if fog_enabled:
				fog_logic.fog_data[pos.y][pos.x] = false
	
	# Atualiza a névoa visualmente se mudamos algo
	if tiles_alterados > 0:
		_draw_fog()
		print("Terraformer: Sucesso! %d tiles perigosos foram neutralizados." % tiles_alterados)
	else:
		print("Terraformer: Nenhum terreno perigoso encontrado na área.")

func usar_item(item: ItemData):
	print("Main: Processando item ", item.nome_item)
	var algoritmo_para_usar = null
	var cor_caminho = Color.WHITE
	
	match item.efeito:
		ItemData.EFEITO_DRONE_PATH_ASTAR:
			algoritmo_para_usar = astar
			cor_caminho = Color.CYAN 
		ItemData.EFEITO_DRONE_PATH_DIJKSTRA:
			algoritmo_para_usar = dijkstra
			cor_caminho = Color.GREEN 
		
		# --- DRONE SCANNER (Permanente) ---
		ItemData.EFEITO_DRONE_SCANNER:
			# Executa a lógica visual
			ativar_drone_scanner(player.grid_pos, item.alcance_maximo, item.valor_efeito)
			# O 'return' aqui garante que a função pare e não tente rodar o código de caminhos abaixo
			return 
		
		ItemData.EFEITO_DRONE_TERRAFORMER:
			# O valor_efeito aqui é ignorado, pois a mudança é instantânea/permanente
			ativar_drone_terraformer(player.grid_pos, item.alcance_maximo)
			return
	
	if algoritmo_para_usar:
		var caminho = algoritmo_para_usar.calcular_caminho(player.grid_pos, vertice_fim)
		if caminho.is_empty(): return
		var eh_temporario = (item.tipo_item == ItemData.ItemTipo.DRONE_TEMPORARIO)
		var duracao = int(item.valor_efeito) if eh_temporario else -1
		var alcance = item.alcance_maximo
		_registrar_novo_caminho(caminho, cor_caminho, alcance, duracao, eh_temporario)

func get_paths_save_data() -> Dictionary:
	var save_data = {}
	for id in caminhos_ativos:
		var info = caminhos_ativos[id]
		var tiles_coords = []
		for pos in info["tiles"]: tiles_coords.push_back([pos.x, pos.y])
		save_data[str(id)] = {
			"tiles": tiles_coords,
			"cor_html": info["cor"].to_html(),
			"duracao_atual": info["duracao_atual"],
			"duracao_max": info["duracao_max"],
			"temporario": info["temporario"]
		}
	return save_data

func load_paths_save_data(data: Dictionary):
	for id in caminhos_ativos:
		var node = caminhos_ativos[id]["node"]
		if is_instance_valid(node): node.queue_free()
	caminhos_ativos.clear()
	_proximo_id_caminho = 0 
	
	for id_str in data:
		var info = data[id_str]
		var tiles_vec: Array[Vector2i] = []
		for coord in info["tiles"]: tiles_vec.push_back(Vector2i(int(coord[0]), int(coord[1])))
		var nova_cor = Color.html(info["cor_html"])
		var dur_atual = int(info["duracao_atual"])
		var dur_max = int(info["duracao_max"])
		var is_temp = bool(info["temporario"])
		
		var visual_node = tile_map_path.duplicate()
		visual_node.name = "DronePath_Load_" + id_str
		visual_node.modulate = nova_cor
		if is_temp and dur_max > 0: visual_node.modulate.a = float(dur_atual) / float(dur_max)
		else: visual_node.modulate.a = 1.0
		visual_node.clear()
		add_child(visual_node)
		
		var path_source_id = ID_CAMINHO
		var path_atlas_coord = Vector2i(0, 0)
		for pos in tiles_vec: visual_node.set_cell(0, pos, path_source_id, path_atlas_coord)

		var id_int = int(id_str)
		if id_int > _proximo_id_caminho: _proximo_id_caminho = id_int
		caminhos_ativos[id_int] = {
			"tiles": tiles_vec, "cor": nova_cor, "duracao_atual": dur_atual,
			"duracao_max": dur_max, "temporario": is_temp, "node": visual_node
		}
	print("Main: Caminhos recarregados.")
	
	# --- FUNÇÃO DEBUG: DESENHAR MST ---
func _desenhar_mst(arestas_abstratas: Array):
	print("Main: Desenhando MST Visual...")
	
	# 1. Cria um nó visual duplicado para a MST (para ter cor própria)
	var mst_visual_node = tile_map_path.duplicate()
	mst_visual_node.name = "MST_Debug_Path"
	# Cor: Dourado/Amarelo translúcido para indicar "Caminho Ouro"
	mst_visual_node.modulate = Color(1, 0.84, 0, 0.6) 
	mst_visual_node.clear()
	add_child(mst_visual_node)
	
	# 2. Configuração do Tile (Usa o mesmo do Dijkstra/Caminho)
	var path_source_id = ID_CAMINHO
	var path_atlas_coord = Vector2i(0, 0)
	
	# 3. Para cada conexão da MST (Ex: Início -> Terminal A)
	for aresta in arestas_abstratas:
		var origem = aresta[0]
		var destino = aresta[1]
		
		# Recalcula o caminho real no grid (ziguezague) entre esses dois pontos
		dijkstra.calcular_caminho_minimo(origem)
		var caminho = dijkstra.reconstruir_caminho(origem, destino)
		
		# Desenha o caminho no mapa
		for pos in caminho:
			mst_visual_node.set_cell(0, pos, path_source_id, path_atlas_coord)

# Substitua a antiga 'tentar_interagir' por esta:
func tentar_abrir_porta(grid_pos: Vector2i):
	var tile_data: MapTileData = get_tile_data(grid_pos)
	
	if not tile_data:
		return

	# Lógica de Porta
	if tile_data.eh_porta and not tile_data.passavel:
		# Busca o item específico (Resource)
		var item_chave = Game_State.inventario_jogador.get_item_por_tipo(ItemData.ItemTipo.CHAVE)
		
		if item_chave:
			print("Main: Chave encontrada: ", item_chave.nome_item)
			
			# --- CORREÇÃO: CONSUMO DO ITEM ---
			# Se durabilidade for -1, é infinita. Se for > 0, gasta.
			if item_chave.durabilidade > 0:
				item_chave.durabilidade -= 1
				print("Main: Durabilidade da chave: ", item_chave.durabilidade)
				
				if item_chave.durabilidade <= 0:
					Game_State.inventario_jogador.remover_item(item_chave)
					print("Main: Chave quebrou/foi consumida.")
			
			# Abre a porta de fato
			_abrir_porta(grid_pos)
			
		else:
			print("Main: Porta trancada. Você precisa de um Cartão de Acesso.")
			# Dica: Adicione um som de "trancado" aqui depois (AudioManager.play_sfx(...))

# Função específica para abrir a porta e atualizar o grafo
func _abrir_porta(pos: Vector2i):
	# 1. Pega a referência do tile atual (que é a porta compartilhada)
	var tile_compartilhado = map_data[pos.y][pos.x]
	
	# 2. Criamos uma DUPLICATA única desse recurso. 
	# Agora 'tile_unico' é um objeto novo na memória, separado dos outros.
	var tile_unico = tile_compartilhado.duplicate()
	
	# 3. Modificamos apenas a cópia única
	tile_unico.passavel = true
	tile_unico.custo_tempo = 1.0 
	tile_unico.eh_porta = false
	tile_unico.tipo = "Chao" # É bom mudar o tipo para evitar confusão futura
	
	# 4. Substituímos a referência no grid de dados pelo novo tile único
	map_data[pos.y][pos.x] = tile_unico
	
	# 5. Atualização Visual (Inalterado)
	tile_map.set_cell(0, pos, ID_CHAO, Vector2i(0,0))
	
	# 6. Atualização do Grafo (Inalterado)
	if grafo:
		grafo.atualizar_aresta_dinamica(pos)
	
	print("Main: Porta aberta em ", pos)

# --- FUNÇÃO DE SPAWN ---
func _spawnar_inimigos():
	if not cena_inimigo:
		print("ERRO: Cena do inimigo não definida no Main.")
		return

	var inimigos_criados = 0
	var tentativas = 0
	
	print("Iniciando spawn de %d inimigos (Raio min: %d)..." % [qtd_inimigos_spawn, raio_minimo_spawn])
	
	while inimigos_criados < qtd_inimigos_spawn and tentativas < tentativas_spawn:
		tentativas += 1
		
		# 1. Escolhe uma posição aleatória no grid
		var x = randi_range(1, MapGenerator.LARGURA - 2)
		var y = randi_range(1, MapGenerator.ALTURA - 2)
		var pos_candidata = Vector2i(x, y)
		
		# 2. Verificação de validade do tile
		var tile = get_tile_data(pos_candidata)
		if not tile or not tile.passavel or tile.tipo == "Dano":
			continue # Não spawna em parede ou lava
			
		# 3. Verificação de distância do Player (Usando distância Manhattan ou Euclidiana)
		# Como estamos em grid, Manhattan (abs(dx) + abs(dy)) é adequada, 
		# mas distance_to do Vector2i serve bem.
		var dist_player = pos_candidata.distance_to(player.grid_pos)
		
		if dist_player < raio_minimo_spawn:
			continue # Está muito perto do jogador, tenta outro
			
		# 4. Verificação de distância da Saída (Opcional, para não spawnar campando a saída)
		if pos_candidata.distance_to(vertice_fim) < 5:
			continue
			
		# --- SUCESSO: INSTANCIA O INIMIGO ---
		var novo_inimigo = cena_inimigo.instantiate()
		
		# Define a posição global baseada no grid
		# (Assume que o inimigo tem a função _grid_to_world ou calculamos aqui)
		novo_inimigo.global_position = (Vector2(pos_candidata) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
		
		# Injeta as dependências (Independência garantida aqui!)
		# Ao definir as variáveis na instância, elas pertencem SÓ a esse inimigo.
		novo_inimigo.main_ref = self
		novo_inimigo.player_ref = player
		
		# Adiciona à cena
		add_child(novo_inimigo)
		inimigos_criados += 1
		print("Inimigo %d spawnado em %s" % [inimigos_criados, pos_candidata])
	
	if inimigos_criados < qtd_inimigos_spawn:
		print("AVISO: Não foi possível spawnar todos os inimigos (Falta de espaço?). Criados: ", inimigos_criados)
		
func is_tile_occupied_by_enemy(target_pos: Vector2i) -> bool:
	var inimigos = get_tree().get_nodes_in_group("inimigos")
	for ini in inimigos:
		# Ignora inimigos mortos ou que ainda não inicializaram
		if is_instance_valid(ini) and ini.has_method("tomar_turno"):
			if ini.grid_pos == target_pos:
				return true
	return false

# --- SISTEMA DE SAVE/LOAD DE INIMIGOS ---

# 1. Coleta dados de todos os inimigos vivos
func get_enemies_state_data() -> Array:
	var enemies_data = []
	var inimigos_vivos = get_tree().get_nodes_in_group("inimigos")
	
	for inimigo in inimigos_vivos:
		# Verifica se o nó é válido e tem a função de save
		if is_instance_valid(inimigo) and inimigo.has_method("get_save_data"):
			# O inimigo.gd já tem essa função pronta (fizemos na etapa anterior)
			enemies_data.push_back(inimigo.get_save_data())
			
	print("Main: Estado de %d inimigos capturado para save." % enemies_data.size())
	return enemies_data

# 2. Recebe uma lista de dados e recria os inimigos exatamente onde estavam
func load_enemies_state_data(loaded_data: Array):
	print("Main: Recarregando %d inimigos do save..." % loaded_data.size())
	
	# A. Limpa inimigos existentes (do spawn automático ou da sessão anterior)
	var inimigos_atuais = get_tree().get_nodes_in_group("inimigos")
	for inimigo in inimigos_atuais:
		inimigo.queue_free()
	
	# B. Recria inimigos a partir dos dados
	for data in loaded_data:
		if cena_inimigo:
			var novo_inimigo = cena_inimigo.instantiate()
			
			# Configura referências ANTES de adicionar à árvore
			novo_inimigo.main_ref = self
			novo_inimigo.player_ref = player
			
			# Adiciona à cena
			add_child(novo_inimigo)
			
			# Carrega os dados específicos (HP, Posição)
			# Nota: O _ready do inimigo roda ao adicionar child, mas o load_save_data
			# vai sobrescrever a posição logo em seguida, o que é o comportamento desejado.
			novo_inimigo.load_save_data(data)

# --- NOVA FUNÇÃO DE SPAWN NPC ---
func _spawnar_npc_aleatorio():
	if not cena_npc: return
	
	var tentativas = 0
	var spawnou = false
	
	while not spawnou and tentativas < 100:
		tentativas += 1
		var x = randi_range(1, MapGenerator.LARGURA - 2)
		var y = randi_range(1, MapGenerator.ALTURA - 2)
		var pos = Vector2i(x, y)
		
		var tile = get_tile_data(pos)
		if not tile or not tile.passavel or tile.tipo == "Dano": continue
		if pos.distance_to(player.grid_pos) < 5: continue
		if pos == vertice_fim: continue
		if is_tile_occupied_by_enemy(pos): continue
		
		var npc = cena_npc.instantiate()
		
		# 1. Adiciona primeiro à cena para garantir que _ready rode
		add_child(npc)
		
		# 2. Define a posição global
		npc.global_position = (Vector2(pos) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
		npc.main_ref = self
		
		# 3. FORÇA o NPC a atualizar o grid_pos agora que a posição está certa
		# (Como o _ready já rodou no add_child com posição 0,0, precisamos corrigir)
		npc.grid_pos = pos 
		# Ou se preferir recalculando: npc.grid_pos = npc._world_to_grid(npc.global_position)
		
		spawnou = true
		print("NPC spawnado e fixado em: ", pos)

# --- NOVA FUNÇÃO DE DETECÇÃO ---
func get_npc_at_position(pos: Vector2i) -> Node2D:
	var npcs = get_tree().get_nodes_in_group("npcs")
	
	# Debug: Se a lista estiver vazia, sabemos que o problema é o Grupo
	if npcs.is_empty():
		print_debug("ERRO CRÍTICO: Nenhum NPC encontrado no grupo 'npcs'!")
		return null
		
	for n in npcs:
		# Verifica se o nó é válido
		if not is_instance_valid(n):
			continue
			
		# Verifica se tem a variável grid_pos
		if not "grid_pos" in n:
			print("AVISO: Objeto no grupo 'npcs' sem variável grid_pos: ", n.name)
			continue
			
		# Debug: Mostra onde o sistema está procurando vs onde o NPC diz estar
		# Descomente a linha abaixo se quiser ver o flood no console
		# print("Checando NPC em ", n.grid_pos, " contra alvo ", pos)
		
		if n.grid_pos == pos:
			# ACHOU!
			return n
			
	# Se chegou aqui, percorreu a lista e ninguém estava na posição 'pos'
	# print("Falha: Nenhum NPC na posição ", pos)
	return null

func is_tile_occupied_by_npc(pos: Vector2i) -> bool:
	return get_npc_at_position(pos) != null

# --- NOVA FUNÇÃO PÚBLICA (Chamada pelo Player.gd) ---
func tentar_ativar_terminal(pos: Vector2i):
	if pos in terminais_pos: 
		terminais_pos.erase(pos)
		
		Game_State.terminais_ativos += 1
		var restantes = Game_State.terminais_necessarios - Game_State.terminais_ativos
		print("TERMINAL ATIVADO! Restam: %d" % restantes)
		
		# Muda visualmente para chão (ou terminal inativo)
		tile_map.set_cell(0, pos, ID_CHAO, Vector2i(0, 0))
		
		# Checa se liberou a saída
		if restantes <= 0:
			saida_destrancada = true
			print(">>> TODOS TERMINAIS ATIVOS! SAÍDA DESTRANCADA! <<<")
			# Redesenha o mapa para mostrar a saída aberta (Verde)
			_draw_map()
	else:
		print("Este terminal já foi ativado ou é inválido.")
# --- TESTE TEMPORÁRIO BFS ---
"""func executar_teste_bfs():
	print("--- INICIANDO TESTE VISUAL DO BFS ---")
	
	# 1. Define origem e alcance
	var centro = Vector2i(1, 1) # Começa onde o player nasce
	var raio_teste = 20
	
	# 2. Roda o algoritmo
	var tiles_alcance = bfs.obter_area_alcance(centro, raio_teste)
	print("BFS: Encontrados ", tiles_alcance.size(), " tiles num raio de ", raio_teste)
	
	# 3. Desenha visualmente para conferirmos (usando o TileMap de Path)
	# Vamos usar uma cor Magenta para diferenciar dos caminhos normais
	var debug_node = tile_map_path.duplicate()
	debug_node.name = "Debug_BFS_Area"
	debug_node.modulate = Color.MAGENTA
	debug_node.modulate.a = 0.6 # Transparente
	add_child(debug_node)
	
	for pos in tiles_alcance:
		# Usamos o ID 0 (Caminho) apenas para marcar o tile
		debug_node.set_cell(0, pos, ID_CAMINHO, Vector2i(0,0))

	print("BFS: Área desenhada em Magenta.")"""
