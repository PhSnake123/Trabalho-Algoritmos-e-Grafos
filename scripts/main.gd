# res://scripts/Main.gd
extends Node2D

@export var fog_enabled := true
var musica_teste = preload("res://Audio/music/Erik_Satie_Gymnopédie_No.1.ogg")
const HUD_SCENE = preload("res://scenes/HUD.tscn")
const FLOATING_LABEL_SCENE = preload("res://scenes/FloatingLabel.tscn")
@export var cena_moeda: PackedScene # <--- ARRASTE A CENA DA MOEDA AQUI
@export var cena_bau: PackedScene   # <--- ARRASTE A CENA DO BAÚ AQUI

# 1. Carrega o script de lógica
const TILE_SIZE := 16
const SAVE_POINT_TILE = preload("res://assets/tileinfo/savepoint.tres")
var script_fase_atual: Node = null

# 2. Referência aos nós da cena
@onready var tile_map = $TileMap
@onready var tile_map_fog = $TileMap_Fog
@onready var tile_map_path = $TileMap_Path
@onready var camera: Camera2D = $Player/Camera2D
@onready var player = $Player
@onready var canvas_modulate: CanvasModulate = $CanvasModulate 
@onready var world_env: WorldEnvironment = $WorldEnvironment

# 3. IDs dos Tiles (Atlas Coordinates ou Source IDs)
const ID_PAREDE = 0
const ID_CHAO = 1
const ID_SAIDA = 2
const ID_DANO = 3
const ID_BLOCK = 4     # Porta/Bloqueio
const ID_SAVE_POINT = 5
const ID_TERMINAL = 6
const ID_SAIDA_FECHADA = 4 # Usando visual de 'Block' temporariamente para saída trancada
const ID_LAMA = 7
const ID_FOG = 0
const ID_CAMINHO = 0
var largura_atual: int = 23
var altura_atual: int = 23

# REGISTRO VISUAL ---
# Mapeia o 'tipo' (string) do dado lógico para o 'ID' (int) do TileSet visual
var visual_registry = {
	"Chao": ID_CHAO,
	"Dano": ID_DANO,
	"Lama": ID_LAMA,
	"FakeWall": ID_PAREDE, # O truque visual: Logica=Fake, Visual=Parede
	"SavePoint": ID_SAVE_POINT,
	"Terminal": ID_TERMINAL
}

# Controle de Baús para persistência
# Chave: Vector2i (posição), Valor: bool (true = aberto)
var estado_baus: Dictionary = {}

# 4. Dados do mapa
var map_data = []
var fog_logic: FogOfWar
var grafo: Graph
var dijkstra: Dijkstra
var bfs: BFS
var vertice_fim: Vector2i
var save_point_pos
var camera_zoom_X = 3
var camera_zoom_Y = 3

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
	
	# 1. Configurações Básicas
	SaveManager.register_main(self)
	Engine.time_scale = 1.0
	
	# Instancia o HUD e adiciona à cena
	var hud = HUD_SCENE.instantiate()
	hud.name = "HUD" # Nomeamos para facilitar encontrar depois
	add_child(hud)

	# 2. DECISÃO: QUAL TIPO DE INICIALIZAÇÃO?
	
	# CASO A: LOAD MANUAL (Player clicou em Carregar no Menu)
	if Game_State.carregar_save_ao_iniciar:
		print("Main: LOAD MANUAL detectado...")
		await get_tree().process_frame # Espera um frame para segurança
		_inicializar_via_load(false) # false = NÃO é auto save
		Game_State.carregar_save_ao_iniciar = false

	# CASO B: LOAD AUTOMÁTICO (Checkpoint / Tentar Novamente do Game Over)
	elif Game_State.carregar_auto_save_ao_iniciar:
		print("Main: LOAD AUTOMÁTICO (Checkpoint) detectado...")
		await get_tree().process_frame
		_inicializar_via_load(true) # true = É auto save
		Game_State.carregar_auto_save_ao_iniciar = false
		
	# CASO C: NOVO JOGO (Geração Procedural)
	else:
		print("Main: Iniciando NOVO JOGO via LevelManager...")
		_inicializar_novo_jogo(vertice_inicio)

	print("Ready concluído.")

func _inicializar_via_load(is_auto: bool):
	# 1. Inicializa Névoa com tamanho padrão TEMPORÁRIO
	fog_logic = FogOfWar.new(23, 23, 5)
	
	# 2. Carrega o jogo (Decide qual arquivo ler)
	if is_auto:
		SaveManager.load_auto_game()
	else:
		SaveManager.load_player_game()
	
	# --- CORREÇÃO: SINCRONIZAR COM O LEVEL DEFINITION ---
	var level_data = LevelManager.get_dados_fase_atual()
	
	if level_data:
		fog_enabled = level_data.fog_enabled
		if canvas_modulate:
			canvas_modulate.color = level_data.cor_ambiente
		if world_env and world_env.environment:
			world_env.environment.glow_intensity = level_data.intensidade_glow
		if tile_map:
			tile_map.modulate = level_data.cor_tilemap
			
	# 3. Atualiza as dimensões do Main baseadas no mapa carregado
	if map_data.size() > 0:
		altura_atual = map_data.size()
		largura_atual = map_data[0].size()
		
		# Atualiza as dimensões internas do FogOfWar
		fog_logic.largura = largura_atual
		fog_logic.altura = altura_atual
		_draw_fog() # Força redesenho para cobrir tudo corretamente
	
	if not fog_enabled: 
		tile_map_fog.hide()
	else: 
		tile_map_fog.show()
	
	_setup_camera()
	
	# Recupera o HUD que criamos no _ready para atualizar ele
	var hud = get_node_or_null("HUD")
	if hud:
		hud.forcar_atualizacao_total()
	
	if AudioManager:
		if Game_State.musica_atual_path != "":
			var stream = load(Game_State.musica_atual_path)
			if stream: 
				AudioManager.play_music(stream)
			else:
				AudioManager.music_player.stop()

func _inicializar_novo_jogo(vertice_inicio: Vector2i):
	# 1. PEGAR DADOS DA FASE ATUAL
	var level_data: LevelDefinition = LevelManager.get_dados_fase_atual()
	
	if not level_data:
		print("Main: Rodando sem LevelDefinition. Usando padrões de teste.")
		level_data = LevelDefinition.new() 
	
	print("Main: Gerando Fase - ", level_data.nome_fase)
	
	fog_enabled = level_data.fog_enabled
	
	# Define a flag global do Hub
	if level_data.cena_fixa != null:
		Game_State.is_in_hub = true
	else:
		Game_State.is_in_hub = false
	
	# --- CONFIGURAÇÃO ESTÉTICA ---
	if canvas_modulate: canvas_modulate.color = level_data.cor_ambiente
	if world_env and world_env.environment: world_env.environment.glow_intensity = level_data.intensidade_glow
	if tile_map: tile_map.modulate = level_data.cor_tilemap	
	
	if AudioManager:
		if level_data.musica_fundo:
			AudioManager.play_music(level_data.musica_fundo)
			Game_State.musica_atual_path = level_data.musica_fundo.resource_path
		else:
			AudioManager.music_player.stop()

	# --- GERAÇÃO DO MAPA ---
	
	if level_data.cena_fixa:
		# >>> ROTA A: MAPA FIXO (HUB) <<<
		_carregar_mapa_fixo(level_data.cena_fixa)
		
		# Define início e fim "dummy"
		vertice_fim = Vector2i(999, 999) 
		saida_destrancada = false
		
		# Spawn configurado no .tres
		player.grid_pos = level_data.player_spawn_pos
		player.global_position = (Vector2(level_data.player_spawn_pos) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
		
		# === SPAWNAR NPCS NO HUB ===
		_spawnar_npcs(level_data) 
				
		# Configura câmera e Fog Dummy para o Hub
		_setup_camera()
		fog_logic = FogOfWar.new(largura_atual, altura_atual, 100)
		fog_logic.revelar_tudo() # Agora essa função existe!
		if tile_map_fog: tile_map_fog.hide()

		# === AUTO SAVE DO HUB ===
		# Esperamos um frame para garantir que tudo (posições, hp) esteja atualizado
		await get_tree().process_frame
		print("Main: Entrou no Hub. Salvando progresso...")
		
		# 1. Salva o jogo normal (para continuar de onde parou)
		SaveManager.save_player_game()
		
		# 2. Salva o BACKUP DE SEGURANÇA (para o Bad Ending)
		SaveManager.save_hub_backup()
		
	else:
		# >>> ROTA B: MAPA PROCEDURAL <<<
		#1. Zera o cronômetro.
		Game_State.tempo_jogador = 0.0
		
		# 2. Limpa o rastro do grafo (O bug da tela de vitória)
		Game_State.caminho_jogador.clear()
		
		# 3. Limpa o histórico de "Desfazer" (para não dar erro de array)
		Game_State.player_action_history.clear()
		
		# 4. Registra a posição inicial (1,1) como o primeiro ponto do novo gráfico
		Game_State.log_player_position(vertice_inicio)
		
		#5. Reseta numero de terminais
		Game_State.terminais_ativos = 0
		
		var map_generator = MapGenerator.new()
		
		map_data = map_generator.gerar_grid(level_data.tamanho.x, level_data.tamanho.y)
		largura_atual = level_data.tamanho.x
		altura_atual = level_data.tamanho.y
		
		if level_data.seed_fixa != 0: seed(level_data.seed_fixa)
		else: randomize()
			
		map_generator.gerar_labirinto_dfs(map_data, 1, 1)
		
		if level_data.salas_qtd > 0:
			map_generator.criar_salas_no_labirinto(map_data, level_data.salas_qtd, level_data.salas_tamanho_min, level_data.salas_tamanho_max)
			
		if level_data.chance_quebra_paredes > 0:
			map_generator.quebrar_paredes_internas(map_data, level_data.chance_quebra_paredes)
			
		var modo_jogo = level_data.modo_jogo
		Game_State.terminais_necessarios = 0 
		var config_tiles = level_data.tiles_especiais
		var qtd_portas = level_data.qtd_portas
		
		map_generator.aplicar_tiles_especiais(map_data, config_tiles, qtd_portas, vertice_inicio)
		
		if modo_jogo == "MST":
			terminais_pos = map_generator.adicionar_terminais(map_data, level_data.qtd_terminais, vertice_inicio)
			Game_State.terminais_necessarios = terminais_pos.size()
			saida_destrancada = false
		else:
			saida_destrancada = true

		grafo = Graph.new(map_data)
		dijkstra = Dijkstra.new(grafo)
		astar = AStar.new(grafo)
		bfs = BFS.new(grafo)
		
		if modo_jogo == "NORMAL":
			vertice_fim = dijkstra.encontrar_vertice_final(vertice_inicio)
			if dijkstra.distancias.has(vertice_fim):
				Game_State.tempo_par_level = dijkstra.distancias[vertice_fim]
			else:
				print("ERRO: Saída inalcançável.")
				
		elif modo_jogo == "MST":
			vertice_fim = dijkstra.encontrar_vertice_final(vertice_inicio)
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
			
			var resultado_mst = Prim.calcular_mst(grafo_abstrato) 
			Game_State.tempo_par_level = resultado_mst["custo"]
			dijkstra.calcular_caminho_minimo(vertice_inicio)
		
		dijkstra.calcular_caminho_minimo(vertice_inicio)
		var caminho_otimo = dijkstra.reconstruir_caminho(vertice_inicio, vertice_fim)
		
		# INSERÇÃO DE SAVE POINT (Modificado)
		if level_data.gerar_save_point:
			if caminho_otimo.size() > 2:
				var meio_index = int(caminho_otimo.size() / 2)
				var pos_meio = caminho_otimo[meio_index]
				map_data[pos_meio.y][pos_meio.x] = SAVE_POINT_TILE.duplicate()
				save_point_pos = pos_meio
				if fog_enabled and fog_logic:
					fog_logic.fog_data[pos_meio.y][pos_meio.x] = false
		else:
			print("Main: Save Point desativado para esta fase.")
		
		# --- FINALIZAÇÃO VISUAL ---
		_draw_map()
		_setup_camera()
		
		fog_logic = FogOfWar.new(largura_atual, altura_atual, 5)
		if not fog_enabled: tile_map_fog.hide()
		else: tile_map_fog.show()
		
		if save_point_pos != null and fog_enabled:
			fog_logic.fog_data[save_point_pos.y][save_point_pos.x] = false
		for t in terminais_pos:
			if fog_enabled: fog_logic.fog_data[t.y][t.x] = false

		update_fog(vertice_inicio)
		
		# Spawns do Procedural
		_spawnar_inimigos(level_data)
		_spawnar_baus(level_data)
		_spawnar_moedas_no_mapa(level_data)
		_spawnar_npcs(level_data) # Procedural também chama aqui no final
		
		if level_data.script_logico:
			# Instancia o script como um Node
			var script_node = Node.new()
			script_node.set_script(level_data.script_logico)
			script_node.name = "LevelScript"
			add_child(script_node)
			script_fase_atual = script_node
			
			# Opcional: Chama uma função de setup se existir
			if script_fase_atual.has_method("setup_fase"):
				script_fase_atual.setup_fase(self)
		
		SaveManager.save_auto_game()

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
	
	# Listas para guardar onde vamos aplicar os terrenos (Autotile)
	var celulas_parede: Array[Vector2i] = []
	
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var tile: MapTileData = map_data[y][x]
			var tile_pos = Vector2i(x, y)
			
			# --- [CORREÇÃO] 1. PRIORIDADE TOTAL: SAÍDA ---
			# Se este tile é a saída, desenhamos o sprite específico e pulamos o resto.
			if tile_pos == vertice_fim:
				var visual_saida = ID_SAIDA if saida_destrancada else ID_SAIDA_FECHADA
				tile_map.set_cell(0, tile_pos, visual_saida, Vector2i(0, 0))
				continue # Pula o processamento de parede/chão para este tile
			
			# --- 2. PRIORIDADE: TERMINAIS (Modo MST) ---
			if tile.tipo == "Terminal":
				# Se ainda está na lista de ativos, desenha o terminal
				if tile_pos in terminais_pos:
					tile_map.set_cell(0, tile_pos, ID_TERMINAL, Vector2i(0, 0))
					continue
			
			# --- 3. TILES COMUNS ---
			if not tile.passavel:
				if tile.eh_porta:
					# Portas continuam sendo um tile fixo
					tile_map.set_cell(0, tile_pos, ID_BLOCK, Vector2i(0, 0))
				else:
					# Paredes vão para a lista do Terrain Connect
					celulas_parede.append(tile_pos)
			else:
				# Lógica padrão do chão
				var tipo_string = tile.tipo
				if visual_registry.has(tipo_string):
					var id_visual = visual_registry[tipo_string]
					tile_map.set_cell(0, tile_pos, id_visual, Vector2i(0, 0))

	# --- A MÁGICA DO AUTOTILE ---
	
	var terrain_set_id = 0
	var terrain_id_parede = 0 
	
	if not celulas_parede.is_empty():
		tile_map.set_cells_terrain_connect(0, celulas_parede, terrain_set_id, terrain_id_parede)

"""
func _draw_map():
	tile_map.clear()
	
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var tile: MapTileData = map_data[y][x]
			var tile_pos = Vector2i(x, y)
			
			# 1. PRIORIDADES ESPECIAIS (Saída e Terminais Ativos)
			
			# Saída (Sempre desenha por cima de tudo se for a posição final)
			if tile_pos == vertice_fim:
				var visual_saida = ID_SAIDA if saida_destrancada else ID_SAIDA_FECHADA
				tile_map.set_cell(0, tile_pos, visual_saida, Vector2i(0, 0))
				continue # Pula o resto, já desenhamos
			
			# Terminais (Lógica de Estado)
			if tile.tipo == "Terminal":
				# Se está na lista 'terminais_pos', ainda precisa ser ativado -> Desenha Terminal
				if tile_pos in terminais_pos:
					tile_map.set_cell(0, tile_pos, ID_TERMINAL, Vector2i(0, 0))
				else:
					# Já foi ativado -> Vira chão (ou terminal apagado se tiver sprite pra isso)
					tile_map.set_cell(0, tile_pos, ID_CHAO, Vector2i(0, 0))
				continue
			
			# 2. TILES COMUNS (Paredes e Chão Variado)
			
			if not tile.passavel:
				# Se não passa, é Parede ou Porta Trancada
				if tile.eh_porta:
					tile_map.set_cell(0, tile_pos, ID_BLOCK, Vector2i(0, 0))
				else:
					tile_map.set_cell(0, tile_pos, ID_PAREDE, Vector2i(0, 0))
			else:
				# Se é passável, consultamos o REGISTRO VISUAL
				var tipo_string = tile.tipo
				
				if visual_registry.has(tipo_string):
					var id_visual = visual_registry[tipo_string]
					tile_map.set_cell(0, tile_pos, id_visual, Vector2i(0, 0))
				else:
					# Fallback: Se criou um tipo novo e esqueceu de registrar, desenha chão e avisa
					tile_map.set_cell(0, tile_pos, ID_CHAO, Vector2i(0, 0))
"""

# --- VERIFICAÇÃO DE MOVIMENTO (Atualizada para Saída Trancada) ---
func is_tile_passable(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= largura_atual: return false
	if grid_pos.y < 0 or grid_pos.y >= altura_atual: return false
	
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
		# 1. Salva os dados da run atual para a tela de pontuação
		Game_State.calcular_pontuacao_final()
		dijkstra.calcular_caminho_minimo(Vector2i(1,1)) # Recalcula do início
		Game_State.caminho_ideal_ultima_fase = dijkstra.reconstruir_caminho(Vector2i(1,1), vertice_fim)
		
		# 2. Carrega a tela de pontuação (que ainda vamos criar)
		# get_tree().change_scene_to_file("res://scenes/ui/LevelComplete.tscn")
		
		# 3. TEMPORÁRIO (Só para testar se o LevelManager funciona):
		# LevelManager.avancar_para_proxima_fase()
		
		
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
	if grid_pos.x < 0 or grid_pos.x >= largura_atual: return null
	if grid_pos.y < 0 or grid_pos.y >= altura_atual: return null
	return map_data[grid_pos.y][grid_pos.x]

func _setup_camera():
	camera.zoom = Vector2(camera_zoom_X, camera_zoom_Y)
	var map_size_pixels = Vector2(largura_atual, altura_atual) * TILE_SIZE
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
			var caminho = dijkstra.calcular_caminho_rapido(player.grid_pos, vertice_fim)
			if not caminho.is_empty():
				# Registra visualmente (Duração, cor verde, etc)
				var eh_temporario = (item.tipo_item == ItemData.ItemTipo.DRONE_TEMPORARIO)
				var duracao = int(item.valor_efeito) if eh_temporario else -1
				_registrar_novo_caminho(caminho, Color.GREEN, item.alcance_maximo, duracao, eh_temporario)
		
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
		
		ItemData.EFEITO_ABRE_PORTA:
			var minha_pos = player.grid_pos
			var direcao_olhar = Vector2i.ZERO
			match player.last_facing:
				"up": direcao_olhar = Vector2i.UP
				"down": direcao_olhar = Vector2i.DOWN
				"left": direcao_olhar = Vector2i.LEFT
				"right": direcao_olhar = Vector2i.RIGHT
			
			var tile_alvo = minha_pos + direcao_olhar
			var tile_data = get_tile_data(tile_alvo)
			
			# Só abrimos se for porta E não for passável (trancada)
			# Não gastamos o item aqui, deixamos o Player.gd gastar
			if tile_data and tile_data.eh_porta and not tile_data.passavel:
				_abrir_porta(tile_alvo)
				print("Main: Porta destrancada com item equipado.")
			else:
				print("Main: Nenhuma porta trancada à frente.")
			
			return
		
		# --- IMPLEMENTAÇÃO DO SAVE TERMINAL ---
		ItemData.EFEITO_SAVE_GAME:
			print("Main: Salvando jogo via Terminal Portátil...")
			if item.durabilidade > 0: # Se não for infinito (-1)
				item.durabilidade -= 1
				if item.durabilidade <= 0:
					Game_State.inventario_jogador.remover_item(item)
					Game_State.equipar_item(null)
				SaveManager.save_player_game()
			
			# Feedback visual simples (opcional)
			#var label_feedback = preload("res://scenes/ui/FloatingLabel.tscn").instantiate()
			# Se você não tiver o FloatingLabel pronto, pode comentar as linhas abaixo
			#if label_feedback:
			#	label_feedback.position = player.global_position + Vector2(0, -20)
			#	label_feedback.set_text("JOGO SALVO!")
			#	label_feedback.set_color(Color.GREEN)
			#	add_child(label_feedback)
			
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
					if Game_State.item_equipado == item_chave:
						Game_State.equipar_item(null)
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
func _spawnar_inimigos(level_data: LevelDefinition):
	if level_data.lista_inimigos.is_empty():
		return

	print("Main: Iniciando spawn de inimigos GARANTIDO...")
	
	for spawn_data in level_data.lista_inimigos:
		# 1. Checa a Flag Secreta
		if spawn_data.flag_secreta != "":
			if Game_State.optional_objectives.get(spawn_data.flag_secreta, false) != true:
				continue 
		
		# 2. Loop de Quantidade
		var qtd = spawn_data.quantidade
		
		for i in range(qtd):
			# CHAMA A FUNÇÃO DE SPAWN GARANTIDO
			# O raio_minimo_spawn vem das variáveis exportadas no topo do Main.gd
			var pos_final = _encontrar_posicao_spawn_garantida(raio_minimo_spawn, [])
			
			if pos_final != Vector2i(-1, -1):
				# Instancia
				if spawn_data.inimigo_cena:
					var novo_inimigo = spawn_data.inimigo_cena.instantiate()
					novo_inimigo.global_position = (Vector2(pos_final) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
					novo_inimigo.main_ref = self
					novo_inimigo.player_ref = player
					
					# Define grid_pos se existir
					if "grid_pos" in novo_inimigo:
						novo_inimigo.grid_pos = pos_final
					
					# --- 1. APLICA A INTELIGÊNCIA ---
					novo_inimigo.ai_type = spawn_data.ai_type
					
					# --- 2. APLICA A COR (VISUAL) ---
					if spawn_data.cor_modulate != Color.WHITE:
						novo_inimigo.modulate = spawn_data.cor_modulate
					
					# --- 3. APLICA OVERRIDES DE ATRIBUTOS ---
					if spawn_data.hp_maximo > 0:
						novo_inimigo.max_hp = spawn_data.hp_maximo
						novo_inimigo.current_hp = spawn_data.hp_maximo
						
					if spawn_data.ataque > -1:
						novo_inimigo.atk = spawn_data.ataque
						
					if spawn_data.defesa > -1:
						novo_inimigo.def = spawn_data.defesa
						
					if spawn_data.poise > -1:
						novo_inimigo.poise = spawn_data.poise
						
					if spawn_data.knockback > -1:
						novo_inimigo.knockback_power = spawn_data.knockback
					
					if spawn_data.passos_por_turno > -1:
						novo_inimigo.passos_por_turno = spawn_data.passos_por_turno
					
					if "loot_moedas" in novo_inimigo:
						novo_inimigo.loot_moedas = spawn_data.moedas_drop
					
					add_child(novo_inimigo)
			else:
				print("AVISO CRÍTICO: Mapa totalmente lotado! Impossível spawnar inimigo %d." % i)
				
func is_tile_occupied_by_enemy(target_pos: Vector2i) -> bool:
	# FIX DE SEGURANÇA 
	# Se a cena estiver sendo trocada ou deletada, paramos aqui para evitar crash.
	if not is_inside_tree():
		return false

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

# NOVA FUNÇÃO DE SPAWN DE NPV

func _spawnar_npcs(level_data: LevelDefinition):
	if level_data.lista_npcs.is_empty():
		return
		
	print("Main: Spawnando NPCs configurados (Garantido)...")
	
	for npc_data in level_data.lista_npcs:
		# Lógica de Flag
		if npc_data.flag_necessaria != "":
			if Game_State.optional_objectives.get(npc_data.flag_necessaria, false) != true:
				continue
		
		var pos_final = Vector2i(-1, -1) # Inicia como inválido
		
		# --- DECISÃO: FIXO OU ALEATÓRIO? ---
		
		# Se tivermos uma posição fixa definida (Hub), usamos ela direto
		if npc_data.pos_fixa != Vector2i(-1, -1):
			pos_final = npc_data.pos_fixa
		else:
			# LÓGICA ALEATÓRIA GARANTIDA
			# Raio 5 é suficiente para NPCs não nascerem colados no jogador
			pos_final = _encontrar_posicao_spawn_garantida(5, [])
		
		# --- INSTANCIAÇÃO ---
		if pos_final != Vector2i(-1, -1):
			if npc_data.npc_cena:
				var npc = npc_data.npc_cena.instantiate()
				add_child(npc)
				
				# Centraliza no tile
				npc.global_position = (Vector2(pos_final) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
				npc.main_ref = self
				
				if "grid_pos" in npc:
					npc.grid_pos = pos_final
				
				print("NPC ", npc.name, " spawnado em ", pos_final)
		else:
			print("ERRO CRÍTICO: Não foi possível encontrar local para o NPC!")

# ANTIGA FUNÇÃO SEM MAPA FIXO
"""
func _spawnar_npcs(level_data: LevelDefinition):
	if level_data.lista_npcs.is_empty():
		return
		
	print("Main: Spawnando NPCs configurados...")
	
	for npc_data in level_data.lista_npcs:
		# Lógica de Flag (Ex: só spawna Donzela se "missao_aceita" for true)
		if npc_data.flag_necessaria != "":
			if Game_State.optional_objectives.get(npc_data.flag_necessaria, false) != true:
				continue
		
		# Tenta spawnar (1 tentativa de encontrar lugar válido costuma bastar, ou um loop pequeno)
		var spawnou = false
		var tentativas = 0
		
		while not spawnou and tentativas < 100:
			tentativas += 1
			var x = randi_range(1, level_data.tamanho.x - 2)
			var y = randi_range(1, level_data.tamanho.y - 2)
			var pos = Vector2i(x, y)
			
			var tile = get_tile_data(pos)
			if not tile or not tile.passavel or tile.tipo == "Dano": continue
			if pos.distance_to(player.grid_pos) < 5: continue
			if pos == vertice_fim: continue
			# Evita spawnar em cima de inimigos ou outros NPCs
			if is_tile_occupied_by_enemy(pos) or is_tile_occupied_by_npc(pos): continue
			
			if npc_data.npc_cena:
				var npc = npc_data.npc_cena.instantiate()
				add_child(npc)
				npc.global_position = (Vector2(pos) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
				npc.main_ref = self
				if "grid_pos" in npc:
					npc.grid_pos = pos
				
				spawnou = true
				print("NPC ", npc.name, " spawnado em ", pos)
			else:
				break
"""


# 1. Coleta dados de todos os NPCs vivos
func get_npcs_state_data() -> Array:
	var npc_data_list = []
	var npcs_vivos = get_tree().get_nodes_in_group("npcs")
	
	for npc in npcs_vivos:
		if is_instance_valid(npc) and npc.has_method("get_save_data"):
			npc_data_list.push_back(npc.get_save_data())
			
	print("Main: Estado de %d NPCs capturado." % npc_data_list.size())
	return npc_data_list

# 2. Recria os NPCs a partir do Save
func load_npcs_state_data(loaded_data: Array):
	print("Main: Recarregando NPCs...")
	
	# A. Limpa NPCs existentes da cena atual
	var npcs_atuais = get_tree().get_nodes_in_group("npcs")
	for n in npcs_atuais:
		n.queue_free()
	
	# B. Recria um por um
	for data in loaded_data:
		var scene_path = data.get("filename")
		# Se não salvou o path, usa o padrão da variável exportada
		var cena_para_instanciar = load(scene_path) if scene_path else cena_npc
		
		if cena_para_instanciar:
			var novo_npc = cena_para_instanciar.instantiate()
			
			# Injeção de Dependência
			novo_npc.main_ref = self
			
			add_child(novo_npc)
			
			# Aplica os dados salvos
			novo_npc.load_save_data(data)
		else:
			print("ERRO: Não foi possível carregar a cena do NPC: ", scene_path)

# --- NOVA FUNÇÃO DE DETECÇÃO ---
func get_npc_at_position(pos: Vector2i) -> Node2D:
	var npcs = get_tree().get_nodes_in_group("npcs")
	
	# Debug: Se a lista estiver vazia, sabemos que o problema é o Grupo
	if npcs.is_empty():
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

		# 1. Pega a referência do tile atual (que pode estar compartilhada)
		var tile_original = map_data[pos.y][pos.x]
		tile_original.tipo = "Chao" 
		# (Opcional) tile_unico.custo_tempo = 1.0
		# substitui o tile no Grid Lógico
		map_data[pos.y][pos.x] = tile_original
		
		# ---------------------------------------------------

		Game_State.terminais_ativos += 1
		var restantes = Game_State.terminais_necessarios - Game_State.terminais_ativos
		print("TERMINAL ATIVADO! Restam: %d" % restantes)
		
		# Atualiza o visual (TileMap)
		tile_map.set_cell(0, pos, ID_CHAO, Vector2i(0, 0))
		
		if restantes <= 0:
			saida_destrancada = true
			print(">>> TODOS TERMINAIS ATIVOS! SAÍDA DESTRANCADA! <<<")
			_draw_map()
	else:
		print("Este terminal já foi ativado ou é inválido.")
# Adicione no Main.gd

# --- FIX DO LOAD (Modo MST) ---
func reconstruir_dados_logicos_do_mapa():
	print("Main: Reconstruindo lógica de Terminais e Objetivos...")
	
	# 1. Limpa a lista atual (que pode estar suja/desatualizada)
	terminais_pos.clear()
	
	# 2. Varre o mapa carregado procurando por tiles do tipo "Terminal"
	for y in range(altura_atual):
		for x in range(largura_atual):
			var tile = map_data[y][x]
			
			# Se o tile é um terminal, significa que ele AINDA NÃO foi ativado
			# (Pois quando ativamos, transformamos ele em "Chao" na linha 81 do Main)
			if tile.tipo == "Terminal":
				terminais_pos.push_back(Vector2i(x, y))
	
	# 2. Recalcula os "ativos" baseado na realidade física do mapa
	# Se precisamos de 3 e achamos 2 no mapa, então 1 está ativo. Matemática pura.
	var encontrados = terminais_pos.size()
	Game_State.terminais_ativos = Game_State.terminais_necessarios - encontrados
	
	print("Main: Lista de Terminais reconstruída. Restantes: ", terminais_pos.size())

# Função para criar feedback visual (Dano/Cura/Tempo)
func spawn_floating_text(world_pos: Vector2, valor: String, cor: Color):
	var label_inst = FLOATING_LABEL_SCENE.instantiate()
	add_child(label_inst)
	label_inst.global_position = world_pos
	label_inst.set_text(valor, cor)	
	
# [Main.gd] - Cole isso após as outras funções de spawn, mantendo a identação correta.

func _spawnar_baus(level_data: LevelDefinition):
	if level_data.qtd_baus <= 0:
		return
	
	print("Main: Spawnando %d baús..." % level_data.qtd_baus)
	
	# 1. Instancia o gerador apenas para usar a matemática de encontrar becos
	# (Assumindo que MapGenerator tem o script que ajustamos)
	var map_gen = MapGenerator.new()
	map_gen.largura = largura_atual
	map_gen.altura = altura_atual
	
	# Precisamos passar o grid atual, a saída e o player para ele não spawnar neles
	var becos = map_gen.encontrar_becos_sem_saida(map_data, vertice_fim, player.grid_pos)
	
	# 2. Embaralha a lista de becos para variar onde os baús caem a cada run (se a seed permitir)
	becos.shuffle()
	
	var colocados = 0
	
	for pos in becos:
		if colocados >= level_data.qtd_baus:
			break
		
		# Verificação de segurança: Só coloca se o tile for Chão comum
		# (Evita colocar em cima de Terminais ou SavePoints que também ficam no chão)
		var tile = map_data[pos.y][pos.x]
		if tile.tipo != "Chao":
			continue
		
		# Instancia o Baú
		if cena_bau:
			var bau = cena_bau.instantiate()
			# Centraliza no tile: (Coord * 16) + (Metade do Tile 8)
			bau.position = (Vector2(pos) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
			
			# Passa a referência do Main para o Baú poder chamar funções de volta
			bau.main_ref = self
			add_child(bau)
			
			# Configura estado (verificando se já foi aberto neste save)
			# Se não existir no dicionário, assume false (fechado)
			var is_aberto = estado_baus.get(pos, false)
			
			# Chama a função de configuração do script do Baú
			bau.configurar(pos, level_data.moedas_por_bau, is_aberto)
			
			colocados += 1
		else:
			print("ERRO: cena_bau não atribuída no Inspector do Main!")
			break
	
	print("Main: %d baús colocados em becos sem saída." % colocados)

# Chamado pelo script do Baú quando o jogador interage
func registrar_bau_aberto(pos: Vector2i):
	estado_baus[pos] = true
	print("Main: Baú em %s registrado como aberto." % pos)

# Chamado pelo script do Inimigo quando morre
func spawn_moeda(pos_world: Vector2, valor: int):
	if not cena_moeda:
		print("AVISO: cena_moeda não atribuída no Main.")
		return
	
	var moeda = cena_moeda.instantiate()
	moeda.position = pos_world
	
	moeda.main_ref = self
	
	# Configura o valor antes de adicionar à cena
	if moeda.has_method("configurar"):
		moeda.configurar(valor)
	
	# 'call_deferred' é vital aqui: como isso acontece durante a morte (física),
	# adicionar corpos físicos imediatamente pode causar erros no Godot.
	call_deferred("add_child", moeda)

# Retorna o nó do baú se houver um nessa posição
func get_chest_at_position(pos: Vector2i) -> Node2D:
	var baus = get_tree().get_nodes_in_group("baus")
	for b in baus:
		if is_instance_valid(b) and "grid_pos" in b:
			if b.grid_pos == pos:
				return b
	return null

# Verifica se a posição tem um baú (usado para bloquear movimento)
func is_tile_occupied_by_chest(pos: Vector2i) -> bool:
	return get_chest_at_position(pos) != null

func get_chests_state_data() -> Array:
	var chests_data = []
	var baus = get_tree().get_nodes_in_group("baus")
	
	for b in baus:
		if is_instance_valid(b) and b.has_method("get_save_data"):
			chests_data.push_back(b.get_save_data())
			
	print("Main: Estado de %d baús capturado." % chests_data.size())
	return chests_data

func load_chests_state_data(loaded_data: Array):
	print("Main: Recarregando baús do save...")
	
	# 1. Limpa baús existentes (para não duplicar)
	var baus_atuais = get_tree().get_nodes_in_group("baus")
	for b in baus_atuais:
		b.queue_free()
	
	# 2. Recria baseados no save
	for data in loaded_data:
		if cena_bau:
			var novo_bau = cena_bau.instantiate()
			novo_bau.main_ref = self
			add_child(novo_bau)
			
			# Carrega posição e estado (aberto/fechado)
			novo_bau.load_save_data(data)

# res://scripts/Main.gd

func _spawnar_moedas_no_mapa(level_data: LevelDefinition):
	# 1. Pega o valor configurado no Inspector (.tres)
	# Se a variável no LevelDefinition for 'qtd_moedas', use ela.
	# (Verifique se no LevelDefinition.gd a variável chama 'qtd_moedas' mesmo)
	var qtd_desejada = level_data.qtd_moedas 
	
	# 2. Se for 0, sai imediatamente. Isso resolve o problema do Tutorial 1.
	if qtd_desejada <= 0:
		print("Main: Nenhuma moeda configurada para esta fase.")
		return
	
	print("Main: Tentando espalhar %d moedas..." % qtd_desejada)
	
	var moedas_criadas = 0
	var tentativas = 0
	var max_tentativas = qtd_desejada * 100 # Segurança contra loop infinito
	
	# 3. Loop até criar a quantidade exata pedida
	while moedas_criadas < qtd_desejada and tentativas < max_tentativas:
		tentativas += 1
		
		# Sorteia uma posição
		var x = randi_range(1, largura_atual - 2)
		var y = randi_range(1, altura_atual - 2)
		var pos = Vector2i(x, y)
		
		# --- VALIDAÇÕES ---
		var tile = get_tile_data(pos)
		if not tile or tile.tipo != "Chao": continue # Só spawna em chão
		if pos == Vector2i(1, 1) or pos == vertice_fim: continue # Não spawna no início/fim
		
		# Não spawna em cima de outras coisas
		if is_tile_occupied_by_chest(pos): continue
		if is_tile_occupied_by_enemy(pos): continue
		if is_tile_occupied_by_npc(pos): continue
		
		# Verifica se JÁ TEM UMA MOEDA ali (para não empilhar)
		# Como moedas não tem grupo específico no seu código atual, 
		# uma checagem simples de distância ou lista temporária resolve.
		var ja_tem_moeda = false
		for m in get_tree().get_nodes_in_group("coletaveis"): # Supondo que moedas estão nesse grupo
			if is_instance_valid(m) and Vector2i(m.position / TILE_SIZE) == pos:
				ja_tem_moeda = true
				break
		if ja_tem_moeda: continue

		# --- SPAWN ---
		# Valor padrão 1, ou você pode adicionar 'valor_moeda' no LevelDefinition depois
		spawn_moeda((Vector2(pos) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0), 1)
		moedas_criadas += 1
				
	print("Main: Sucesso. %d moedas espalhadas." % moedas_criadas)

# --- SISTEMA DE MAPA FIXO (HUB) ---

# Em Main.gd

func _carregar_mapa_fixo(cena_packed: PackedScene):
	print("Main: Carregando mapa fixo (Modo Hub)...")
	
	# Limpa mapa anterior se houver
	if map_data.size() > 0:
		tile_map.clear()
	
	var mapa_instancia = cena_packed.instantiate()
	add_child(mapa_instancia)
	move_child(mapa_instancia, 0) 
	
	# 1. Busca as camadas pelo nome exato que definimos
	var layer_chao = mapa_instancia.get_node_or_null("LayerChao")
	var layer_paredes = mapa_instancia.get_node_or_null("LayerParedes")
	
	# Fallback
	if not layer_chao and mapa_instancia is TileMapLayer:
		layer_chao = mapa_instancia
	
	if not layer_chao:
		print("ERRO: HubMap precisa ter um nó chamado 'LayerChao'.")
		return

	# 2. Detecta tamanho baseado no chão
	var rect = layer_chao.get_used_rect()
	largura_atual = rect.end.x + 5 
	altura_atual = rect.end.y + 5
	
	# 3. Inicializa tudo como PAREDE (Vazio = Parede)
	map_data = []
	for y in range(altura_atual):
		var linha = []
		for x in range(largura_atual):
			var tile = MapTileData.new()
			tile.passavel = false 
			tile.tipo = "Parede"
			linha.push_back(tile)
		map_data.push_back(linha)
	
	# 4. Processa o CHÃO (Torna passável)
	for coords in layer_chao.get_used_cells():
		if _dentro_do_mapa(coords):
			var tile = map_data[coords.y][coords.x]
			tile.passavel = true
			tile.tipo = "Chao"
			tile.custo_tempo = 1.0

	# 5. Processa as PAREDES/DECORAÇÃO (Torna intransponível)
	if layer_paredes:
		for coords in layer_paredes.get_used_cells():
			if _dentro_do_mapa(coords):
				var tile = map_data[coords.y][coords.x]
				tile.passavel = false 
				tile.tipo = "Parede" 
	
	# Esconde o procedural
	tile_map.hide()
	
	# === LÓGICA DO HUB ===
	if mapa_instancia.has_method("atualizar_estado_hub"):
		mapa_instancia.atualizar_estado_hub()
	
	# === [FIX] AJUSTA CÂMERA ===
	_setup_camera()
	
	print("Main: Hub carregado e processado.")

func _dentro_do_mapa(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < largura_atual and pos.y >= 0 and pos.y < altura_atual

# Retorna o nó do ShopSpot se houver um nessa posição
func get_shop_at_position(pos: Vector2i) -> Node2D:
	# O ShopSpot.gd já se adiciona ao grupo "shop_items" no _ready
	var shops = get_tree().get_nodes_in_group("shop_items")
	
	for shop in shops:
		if is_instance_valid(shop) and "grid_pos" in shop:
			if shop.grid_pos == pos:
				return shop
	return null

# Função de "Game Juice" para impacto
func aplicar_hit_stop(time_scale: float, duracao_real: float):
	# 1. Desacelera ou para o tempo
	Engine.time_scale = time_scale
	
	# 2. Espera um pouquinho (usando tempo real, ignorando a escala de tempo do jogo)
	# create_timer(tempo, process_always, process_in_physics, ignore_time_scale)
	await get_tree().create_timer(duracao_real, true, false, true).timeout
	
	# 3. Volta ao normal
	Engine.time_scale = 1.0

func chegou_saida(player_grid_pos: Vector2i):
	if player_grid_pos == vertice_fim and saida_destrancada:
		print(">>> JOGADOR ALCANÇOU A SAÍDA! <<<")
		
		# --- HOOK: PERGUNTA PRO SCRIPT DA FASE SE ELE QUER ASSUMIR ---
		if script_fase_atual and script_fase_atual.has_method("on_level_complete"):
			
			var assumiu_controle = await script_fase_atual.on_level_complete()
			
			if assumiu_controle:
				return # O script cuidou de tudo, a Main não faz mais nada.
		
		# Pega a tolerância do LevelDefinition (ou usa padrão)
		var level_data = LevelManager.get_dados_fase_atual()
		var tolerancia = level_data.tempo_par_tolerancia if level_data else 2.0
		
		# 1. Processa o resultado
		Game_State.processar_resultado_fase(tolerancia)
		
		# 2. Decide qual tela mostrar
		if Game_State.falha_por_tempo:
			# BAD ENDING: Instancia a tela de punição
			var tela_bad = load("res://scenes/BadEndingScreen.tscn").instantiate()
			add_child(tela_bad)
		else:
			# VITÓRIA: Instancia a tela de sucesso
			var tela_vitoria = load("res://scenes/LevelComplete.tscn").instantiate()
			add_child(tela_vitoria)
		
		# 3. Trava o Player
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)	

# Adicione esta função utilitária no Main.gd
func _encontrar_posicao_spawn_garantida(raio_minimo_ideal: int, evitar_posicoes: Array[Vector2i]) -> Vector2i:
	var tentativas = 0
	var max_tentativas_boas = 50
	
	# 1. TENTATIVA IDEAL (Respeita o raio mínimo configurado)
	while tentativas < max_tentativas_boas:
		var x = randi_range(1, largura_atual - 2)
		var y = randi_range(1, altura_atual - 2)
		var pos = Vector2i(x, y)
		
		if _eh_spawn_valido(pos, raio_minimo_ideal, evitar_posicoes):
			return pos
		tentativas += 1
	
	# 2. TENTATIVA MÉDIA (Reduz o raio pela metade)
	tentativas = 0
	var raio_reduzido = int(raio_minimo_ideal / 2.0)
	while tentativas < max_tentativas_boas:
		var x = randi_range(1, largura_atual - 2)
		var y = randi_range(1, altura_atual - 2)
		var pos = Vector2i(x, y)
		
		if _eh_spawn_valido(pos, raio_reduzido, evitar_posicoes):
			return pos
		tentativas += 1
		
	# 3. DESESPERO (Hard Fix: Pega qualquer chão longe 2 tiles do player)
	# Varre o mapa todo procurando vagas
	var candidatos = []
	for y in range(1, altura_atual - 1):
		for x in range(1, largura_atual - 1):
			var pos = Vector2i(x, y)
			# Raio mínimo de 2 só para não spawnar COLADO no player
			if _eh_spawn_valido(pos, 2, evitar_posicoes):
				candidatos.push_back(pos)
	
	if candidatos.size() > 0:
		return candidatos.pick_random()
	
	return Vector2i(-1, -1) # Mapa 100% cheio, impossível spawnar

func _eh_spawn_valido(pos: Vector2i, raio: int, evitar: Array[Vector2i]) -> bool:
	# Regras Básicas: Chão e sem Dano
	var tile = get_tile_data(pos)
	if not tile or not tile.passavel or tile.tipo == "Dano": return false
	
	# Regra de Distância do Player
	if pos.distance_to(player.grid_pos) < raio: return false
	
	# Regra de Distância da Saída (Fixo 3 tiles pra não bloquear)
	if pos.distance_to(vertice_fim) < 3: return false
	
	# Regra de Ocupação (Lista de evitar)
	if pos in evitar: return false
	
	# Regras de Entidades Vivas
	if is_tile_occupied_by_enemy(pos): return false
	if is_tile_occupied_by_npc(pos): return false
	if is_tile_occupied_by_chest(pos): return false
	
	return true

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
