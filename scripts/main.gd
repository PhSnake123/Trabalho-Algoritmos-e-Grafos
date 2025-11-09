# res://scripts/Main.gd
extends Node2D

@export var fog_enabled := true
# --- Carrega a Musica---
var musica_teste = preload("res://Audio/music/time_for_adventure.mp3") # <-- Mude o nome do arquivo

# 1. Carrega o script de lógica
const TILE_SIZE := 16
const ID_SAVE_POINT = 5
const SAVE_POINT_TILE = preload("res://assets/tileinfo/savepoint.tres")

# 2. Referência aos nós da cena
@onready var tile_map = $TileMap
@onready var tile_map_fog = $TileMap_Fog
@onready var tile_map_path = $TileMap_Path
@onready var camera: Camera2D = $Player/Camera2D
@onready var player = $Player

# 3. IDs dos Tiles
const ID_PAREDE = 0
const ID_CHAO = 1
const ID_SAIDA = 2
const ID_DANO = 3
const ID_BLOCK = 4
const ID_FOG = 0
const ID_CAMINHO = 0

# 4. Dados do mapa
var map_data = []
var fog_logic: FogOfWar
var grafo: Graph
var dijkstra: Dijkstra
var vertice_fim: Vector2i
var save_point_pos
var camera_zoom_X = 2
var camera_zoom_Y = 2

# Esta função roda quando o jogo começa

func _ready():
	var vertice_inicio = Vector2i(1, 1) # Posição inicial do Player
	#Chamando o Save Manager
	SaveManager.register_main(self)
	#Chamando o Audio manager
	AudioManager.play_music(musica_teste)

	# 1. GERAÇÃO DO MAPA BASE
	var map_generator = MapGenerator.new()
	map_data = map_generator.gerar_grid()
	map_generator.gerar_labirinto_dfs(map_data, 1, 1)
	map_generator.quebrar_paredes_internas(map_data, 0.05)

	# 2. COLOCA OS TILES ESPECIAIS
	map_generator.adicionar_terrenos_especiais(
		map_data,
		50, # total_lava
		25,  # total_portas
		vertice_inicio # total_portas_faceis (preenchimento)
	)
	
	# 4. CRIA O GRAFO "FINAL" E O DIJKSTRA
	# Agora que o map_data está finalizado (com Portas e Lava),
	# criamos o grafo oficial que o jogo usará.
	# Como as Portas são 'passavel = false', o Dijkstra
	# calculará o caminho ao redor delas.
	grafo = Graph.new(map_data)
	dijkstra = Dijkstra.new(grafo)

	# 5. ENCONTRA O FIM E O "TEMPO PAR"
	vertice_fim = dijkstra.encontrar_vertice_final(vertice_inicio)
	
	print("Vértice inicial definido em: ", vertice_inicio)
	print("Vértice final definido em: ", vertice_fim)
	
	var tempo_minimo_par
	# Salva o "Tempo Par" (o score a ser batido)
	if dijkstra.distancias.has(vertice_fim):
		tempo_minimo_par = dijkstra.distancias[vertice_fim]
		print("Tempo PAR (sem atalhos): ", tempo_minimo_par)
	else:
		print("ERRO: Vértice final está inalcançável.")

	# --- LÓGICA DE SPAWN DO SAVE POINT ---
	var caminho_minimo = dijkstra.reconstruir_caminho(vertice_inicio, vertice_fim)

	# Reseta a variável (caso estejamos carregando um nível)
	save_point_pos = null
	
	if not caminho_minimo.is_empty() and caminho_minimo.size() > 2:
		# Pega a coordenada no meio do caminho
		var mid_index = (caminho_minimo.size() / 2) as int
		save_point_pos = caminho_minimo[mid_index]

		# "Planta" o tile de save point no nosso grid de dados
		map_data[save_point_pos.y][save_point_pos.x] = SAVE_POINT_TILE
		print("Save Point gerado em: ", save_point_pos)
	else:
		print("Aviso: Não foi possível gerar Save Point (caminho mínimo muito curto ou inexistente).")
	# --- FIM DA LÓGICA DE SPAWN ---

	# 6. DESENHA E CONFIGURA O RESTO
	_draw_map()
	#_desenhar_caminho_minimo(vertice_inicio, vertice_fim)
	_setup_camera()
	
	# 7. CONFIGURA A NÉVOA. Ajustar campo de visão mexendo no último número.
	fog_logic = FogOfWar.new(MapGenerator.LARGURA, MapGenerator.ALTURA, 10)
	if not fog_enabled:
		tile_map_fog.hide()
	# Revela a área inicial e desenha a fog
	
	# --- LÓGICA PARA REVELAR O SAVE POINT ---
	if fog_enabled and save_point_pos != null:
		# "Fura" a névoa na coordenada do save point
		fog_logic.fog_data[save_point_pos.y][save_point_pos.x] = false # false = visível
	# --- FIM DA LÓGICA DA NÉVOA ---

	update_fog(vertice_inicio)
	# --- SALVA O ESTADO INICIAL DO NÍVEL ---
	SaveManager.save_auto_game()
	print("Save automático do início da fase concluído.")
	
func _draw_fog():
	# Limpa a névoa antiga
	tile_map_fog.clear()
	
	# ID do pincel e coordenada do atlas (assumindo que seu tile de névoa é o primeiro)
	var fog_source_id = ID_FOG
	var fog_atlas_coord = Vector2i(0, 0) # Assumindo que seu tile está em (0,0) no atlas
	
	# Varre o grid de DADOS da névoa (fog_logic.fog_data)
	for y in range(fog_logic.altura):
		for x in range(fog_logic.largura):
			
			# Se fog_data[y][x] for 'true' (oculto), desenhamos a névoa
			if fog_logic.fog_data[y][x] == true:
				var tile_pos = Vector2i(x, y)
				# Pinta o tile de névoa
				tile_map_fog.set_cell(0, tile_pos, fog_source_id, fog_atlas_coord)


# --- Atualiza e Redesenha a Névoa ---
# Esta função será chamada pelo Player
func update_fog(player_grid_pos: Vector2i):
	# Não desenha a fog se o interruptor estiver ligado.
	if not fog_enabled:
		return
	# 1. Manda a lógica revelar a nova área
	# (Passamos o map_data para ele saber onde estão as paredes)
	fog_logic.revelar_area(player_grid_pos.x, player_grid_pos.y, map_data)
	
	# 2. Manda o TileMap visual redesenhar a névoa
	_draw_fog()


# Esta função "pinta" o TileMap com base nos dados
func _draw_map():
	# (Seu código original - sem alterações)
	tile_map.clear()
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var tile: MapTileData = map_data[y][x]
			var tile_pos = Vector2i(x, y)
			
			if tile_pos == vertice_fim:
				# Desenha a saída
				tile_map.set_cell(0, tile_pos, ID_SAIDA, Vector2i(0, 0))
			
			elif tile.tipo == "SavePoint":
				tile_map.set_cell(0, tile_pos, ID_SAVE_POINT, Vector2i(0, 0))
			
			elif not tile.passavel:
				if tile.eh_porta:
					# Desenha a Porta
					tile_map.set_cell(0, tile_pos, ID_BLOCK, Vector2i(0, 0))
				else:
					# Desenha a Parede padrão
					tile_map.set_cell(0, tile_pos, ID_PAREDE, Vector2i(0, 0))
			else:
				if tile.tipo == "Dano":
					# Desenha a Lava
					tile_map.set_cell(0, tile_pos, ID_DANO, Vector2i(0, 0))
				# Desenha o chão
				else:
					tile_map.set_cell(0, tile_pos, ID_CHAO, Vector2i(0, 0))


# Esta função será chamada pelo Player.
func is_tile_passable(grid_pos: Vector2i) -> bool:
	# (Seu código original - sem alterações)
	if grid_pos.x < 0 or grid_pos.x >= MapGenerator.LARGURA:
		return false
	if grid_pos.y < 0 or grid_pos.y >= MapGenerator.ALTURA:
		return false
	
	var tile: MapTileData = map_data[grid_pos.y][grid_pos.x]
	return tile.passavel

func _setup_camera():
	# 1. Define o zoom desejado
	# Valores maiores = mais perto.
	# (Tente 1.0 para 1:1, ou 2.0, 3.0 para um look mais "pixelado")
	camera.zoom = Vector2(camera_zoom_X, camera_zoom_Y)
	
	# 2. Calcula o tamanho total do mapa em pixels 
	var map_size_pixels = Vector2(MapGenerator.LARGURA, MapGenerator.ALTURA) * TILE_SIZE
	
	# 3. Define os limites da câmera
	# Isso impede que a câmera "vaze" para fora do mapa,
	# exatamente como você descreveu.
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_size_pixels.x
	camera.limit_bottom = map_size_pixels.y

func _desenhar_caminho_minimo(inicio: Vector2i, fim: Vector2i):
	# 1. Limpa o caminho antigo
	tile_map_path.clear()
	
	# 2. Pede ao Dijkstra para construir o caminho
	var caminho_encontrado = dijkstra.reconstruir_caminho(inicio, fim)
	
	if caminho_encontrado.is_empty():
		print("FALHA AO DESENHAR: Caminho mínimo não pôde ser reconstruído.")
		return
		
	# 3. Pega os dados do pincel do caminho
	var path_source_id = ID_CAMINHO
	var path_atlas_coord = Vector2i(0, 0) # Assumindo (0,0)
	
	# 4. Desenha cada tile do caminho (exceto o início e o fim)
	for i in range(1, caminho_encontrado.size() - 1):
		var pos = caminho_encontrado[i]
		tile_map_path.set_cell(0, pos, path_source_id, path_atlas_coord)

func get_tile_data(grid_pos: Vector2i) -> MapTileData:
	if grid_pos.x < 0 or grid_pos.x >= MapGenerator.LARGURA:
		return null # Fora dos limites
	if grid_pos.y < 0 or grid_pos.y >= MapGenerator.ALTURA:
		return null # Fora dos limites

	return map_data[grid_pos.y][grid_pos.x]

func _unhandled_input(event):
	# Pressiona F5 para Salvar
	if event.is_action_pressed("save"):
		SaveManager.save_player_game()

	# Pressiona F6 para Carregar
	if event.is_action_pressed("load"):
		SaveManager.load_player_game()
	
	if event.is_action_pressed("load_start"):
		SaveManager.load_auto_game() # <-- NOVO
		print("TESTE: Carregando slot AUTO (início da fase).")

	# --- LÓGICA DO ITEM DE SAVE ---
	# Pressiona "P" para usar o item "Save Terminal"
	if event.is_action_pressed("save_terminal"):
		var item_para_usar = null
		# Procura o item no inventário
		for item in Game_State.inventario_jogador.items:
			if item.efeito == ItemData.EFEITO_SAVE_GAME:
				item_para_usar = item
				break # Achou!
		
		if item_para_usar:
			print("Usando item 'Save Terminal'...")
			Game_State.inventario_jogador.remover_item(item_para_usar)
			SaveManager.save_player_game()
			# Opcional: Tocar um som de "item usado"
		else:
			print("Item 'Save Terminal' não encontrado no inventário.")
	
	# --- LÓGICA DE INTERAÇÃO DO SAVE POINT ---
	if event.is_action_pressed("interagir"):
		var player_pos = player.grid_pos
		var current_tile: MapTileData = get_tile_data(player_pos)
		print("--- DEBUG: Ação 'interagir' detectada! ---")
		if current_tile:
			print("DEBUG: Jogador está no tile tipo: '%s'" % current_tile.tipo)
			if current_tile.tipo == "SavePoint":
				SaveManager.save_player_game()
				print("JOGO SALVO (interagido com Save Point)!")
				# Opcional: Tocar um som de save, mostrar uma UI rápida
				# AudioManager.play_sfx(seu_sfx_de_save) 
			else:
				print("DEBUG: O tile não é um 'SavePoint'.")
		else:
			print("DEBUG: Erro, get_tile_data() retornou null.")
				
#Função setup camera antiga
#func _setup_camera():
#	var viewport_size = get_viewport().get_visible_rect().size
#	var map_size_pixels = Vector2(MapGenerator.LARGURA, MapGenerator.ALTURA) * TILE_SIZE
#	var scale_x = viewport_size.x / map_size_pixels.x
#	var scale_y = viewport_size.y / map_size_pixels.y
#	var zoom_level = min(scale_x, scale_y)
#	camera.zoom = Vector2(zoom_level, zoom_level)
#	var map_center_pixels = map_size_pixels / 2.0
#	camera.global_position = map_center_pixels
