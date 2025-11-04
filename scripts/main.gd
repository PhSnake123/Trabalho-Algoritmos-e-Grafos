# res://scripts/Main.gd
extends Node2D

@export var fog_enabled := true

# 1. Carrega o script de lógica
const MapGenerator = preload("res://scripts/MapGenerator.gd")
const TILE_SIZE := 16

# 2. Referência aos nós da cena
@onready var tile_map = $TileMap
@onready var tile_map_fog = $TileMap_Fog
@onready var tile_map_path = $TileMap_Path
@onready var camera: Camera2D = $Player/Camera2D

# 3. IDs dos Tiles
const ID_PAREDE = 0
const ID_CHAO = 1
const ID_SAIDA = 2
const ID_FOG = 0
const ID_CAMINHO = 0

# 4. Dados do mapa
var map_data = []
var fog_logic: FogOfWar
var grafo: Graph
var dijkstra: Dijkstra
var vertice_fim: Vector2i
var camera_zoom_X = 3.0
var camera_zoom_Y = 3.0

# Esta função roda quando o jogo começa
func _ready():
	# 5. Cria uma instância do nosso gerador
	var map_generator = MapGenerator.new()
	
	# 6. Gera o grid de dados (lógica)
	map_data = map_generator.gerar_grid()
	map_generator.gerar_labirinto_dfs(map_data, 1, 1) # Começa a cavar em (1, 1)
	
	# 6.5. Quebra paredes para criar loops e complexidade
	map_generator.quebrar_paredes_internas(map_data, 0.15) # (Use 0.2 para 20%, etc)
	
	# 7. Cria o grafo a partir do mapa
	grafo = Graph.new(map_data)
	
	# 8. Cria o Dijkstra e encontra o ponto final
	dijkstra = Dijkstra.new(grafo)
	var vertice_inicio = Vector2i(1, 1) # Posição inicial do Player
	vertice_fim = dijkstra.encontrar_vertice_final(vertice_inicio)
	
	print("Vértice inicial definido em: ", vertice_inicio)
	print("Vértice final definido em: ", vertice_fim)
	
	# 9. Desenha o resultado visual
	_draw_map()
	
	# _desenhar_caminho_minimo(vertice_inicio, vertice_fim)
	
	_setup_camera()
	
	# 10. Cria a instância da lógica da névoa
	fog_logic = FogOfWar.new(MapGenerator.LARGURA, MapGenerator.ALTURA, 3) # Raio de visão 3

	# 11. Verifica o interruptor.
	if not fog_enabled:
		tile_map_fog.hide()
	#_draw_fog()
	# --- Fim da seção nova ---


# --- Desenha o TileMap_Fog ---
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
			var tile_tipo = map_data[y][x]
			var tile_pos = Vector2i(x, y)
			
			if tile_pos == vertice_fim:
				# Desenha a saída
				tile_map.set_cell(0, tile_pos, ID_SAIDA, Vector2i(0, 0))
			elif tile_tipo == MapGenerator.TileType.PAREDE:
				# Desenha a parede
				tile_map.set_cell(0, tile_pos, ID_PAREDE, Vector2i(0, 0))
			else:
				# Desenha o chão
				tile_map.set_cell(0, tile_pos, ID_CHAO, Vector2i(0, 0))


# Esta função será chamada pelo Player.
func is_tile_passable(grid_pos: Vector2i) -> bool:
	# (Seu código original - sem alterações)
	if grid_pos.x < 0 or grid_pos.x >= MapGenerator.LARGURA:
		return false
	if grid_pos.y < 0 or grid_pos.y >= MapGenerator.ALTURA:
		return false
	
	var tile_type = map_data[grid_pos.y][grid_pos.x]
	return tile_type == MapGenerator.TileType.CHAO

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
