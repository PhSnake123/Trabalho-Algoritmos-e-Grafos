# res://scripts/SaveManager.gd
extends Node

# --- Configuração ---
const SAVE_PATH_AUTO = "user://grafos_quest_auto.json"
const SAVE_PATH_PLAYER = "user://grafos_quest_player.json"

# Configuração do Rewind Global (Item 1)
@export var snapshot_interval: float = 120.0 
@export var max_global_snapshots: int = 5     

# --- Referências ---
var main_ref: Node2D = null
var player_ref: CharacterBody2D = null

# --- Buffers ---
var global_snapshot_buffer: Array[Dictionary] = []
var snapshot_timer: Timer

# --- Inicialização ---

func _ready():
	snapshot_timer = Timer.new()
	snapshot_timer.wait_time = snapshot_interval
	snapshot_timer.timeout.connect(_on_snapshot_timer_timeout)
	add_child(snapshot_timer)
	print("SaveManager pronto.")

# --- Funções de Registro ---
func register_main(node: Node2D):
	main_ref = node
	print("SaveManager: Main.gd registrado.")
	if not snapshot_timer.is_stopped():
		snapshot_timer.stop()
	snapshot_timer.start()

func register_player(node: CharacterBody2D):
	player_ref = node
	print("SaveManager: Player.gd registrado.")


# ===============================================
# 1. FUNÇÕES DE "EMPACOTAR" (SERIALIZAÇÃO)
# ===============================================

func _serialize_map(map_data: Array) -> Array:
	var serialized_map = []
	for y in range(map_data.size()):
		var row: Array[Dictionary] = []
		for x in range(map_data[y].size()):
			var tile: MapTileData = map_data[y][x]
			row.push_back({
				"tipo": tile.tipo,
				"custo_tempo": tile.custo_tempo,
				"dano_hp": tile.dano_hp,
				"passavel": tile.passavel,
				"eh_porta": tile.eh_porta,
				"eh_parede_quebravel": tile.eh_parede_quebravel
			})
		serialized_map.push_back(row)
	return serialized_map

func _serialize_inventory(items: Array[ItemData]) -> Array:
	var serialized_items = []
	for item in items:
		# [CORREÇÃO] Agora salvamos TUDO que importa, incluindo o alcance!
		serialized_items.push_back({
			"nome_item": item.nome_item,
			"descricao": item.descricao,
			"tipo_item": item.tipo_item, 
			"efeito": item.efeito,
			"valor_efeito": item.valor_efeito,
			"durabilidade": item.durabilidade,
			"alcance_maximo": item.alcance_maximo # <--- ERA ISSO QUE FALTAVA!
		})
	return serialized_items

func _get_current_game_state_dict() -> Dictionary:
	if not main_ref or not player_ref:
		print("ERROR - SaveManager: Falha ao salvar. Referências perdidas.")
		return {}

	var data = {}
	
	data["gamestate"] = {
		"tempo_jogador": Game_State.tempo_jogador,
		"tempo_par_level": Game_State.tempo_par_level,
		"vida_jogador": Game_State.vida_jogador,
		"optional_objectives": Game_State.optional_objectives,
		"terminais_ativos": Game_State.terminais_ativos,
		"terminais_necessarios": Game_State.terminais_necessarios,
		"enemy_states": Game_State.enemy_states,
		"npc_states": Game_State.npc_states,
		"interactable_states": Game_State.interactable_states,
		"inventory": _serialize_inventory(Game_State.inventario_jogador.items)
	}
	
	data["player"] = {
		"grid_pos_x": player_ref.grid_pos.x,
		"grid_pos_y": player_ref.grid_pos.y,
		"last_facing": player_ref.last_facing
	}
	
	data["world"] = {
		"vertice_fim_x": main_ref.vertice_fim.x,
		"vertice_fim_y": main_ref.vertice_fim.y,
		"map_data": _serialize_map(main_ref.map_data),
		"fog_data": main_ref.fog_logic.fog_data,
		"active_paths": main_ref.get_paths_save_data()
	}
	
	return data


# ===============================================
# 2. FUNÇÕES DE "DESEMPACOTAR" (DESERIALIZAÇÃO)
# ===============================================

func _deserialize_map(serialized_map: Array) -> Array:
	var map_data = []
	for y in range(serialized_map.size()):
		var row = []
		for x in range(serialized_map[y].size()):
			var tile_data: Dictionary = serialized_map[y][x]
			var new_tile = MapTileData.new()
			new_tile.tipo = tile_data["tipo"]
			new_tile.custo_tempo = tile_data["custo_tempo"]
			new_tile.dano_hp = tile_data["dano_hp"]
			new_tile.passavel = tile_data["passavel"]
			new_tile.eh_porta = tile_data["eh_porta"]
			new_tile.eh_parede_quebravel = tile_data["eh_parede_quebravel"]
			row.push_back(new_tile)
		map_data.push_back(row)
	return map_data

func _deserialize_inventory(serialized_items: Array) -> Array:
	var items = []
	for item_data in serialized_items:
		var new_item = ItemData.new()
		new_item.nome_item = item_data["nome_item"]
		new_item.descricao = item_data["descricao"]
		# Forçamos 'int' para garantir que o Enum funcione
		new_item.tipo_item = int(item_data["tipo_item"]) 
		new_item.efeito = item_data["efeito"]
		new_item.valor_efeito = item_data["valor_efeito"]
		new_item.durabilidade = int(item_data["durabilidade"])
		
		# [CORREÇÃO] Carrega o alcance se existir no save
		if item_data.has("alcance_maximo"):
			new_item.alcance_maximo = int(item_data["alcance_maximo"])
		else:
			new_item.alcance_maximo = 0 # Fallback para saves antigos
			
		items.push_back(new_item)
	return items

func _apply_game_state_dict(data: Dictionary):
	if not main_ref or not player_ref:
		print("ERROR - SaveManager: Falha ao carregar.")
		return
	
	var gs_data = data["gamestate"]
	Game_State.tempo_jogador = gs_data["tempo_jogador"]
	Game_State.tempo_par_level = gs_data["tempo_par_level"]
	Game_State.vida_jogador = gs_data["vida_jogador"]
	Game_State.optional_objectives = gs_data["optional_objectives"]
	Game_State.terminais_ativos = gs_data["terminais_ativos"]
	Game_State.terminais_necessarios = gs_data["terminais_necessarios"]
	Game_State.enemy_states = gs_data["enemy_states"]
	Game_State.npc_states = gs_data["npc_states"]
	Game_State.interactable_states = gs_data["interactable_states"]
	
	# AQUI O INVENTÁRIO É RECRIADO
	# Se o alcance vier 0, o drone quebra. Agora virá certo.
	Game_State.inventario_jogador.items.assign(_deserialize_inventory(gs_data["inventory"]))
	
	var p_data = data["player"]
	var new_grid_pos = Vector2i(p_data["grid_pos_x"], p_data["grid_pos_y"])
	player_ref.grid_pos = new_grid_pos
	player_ref.last_facing = p_data["last_facing"]
	
	player_ref.global_position = (Vector2(new_grid_pos) * main_ref.TILE_SIZE) + (Vector2.ONE * main_ref.TILE_SIZE / 2.0)
	player_ref.reset_state_on_load()
	
	var w_data = data["world"]
	main_ref.vertice_fim = Vector2i(w_data["vertice_fim_x"], w_data["vertice_fim_y"])
	
	main_ref.map_data = _deserialize_map(w_data["map_data"])
	main_ref.fog_logic.fog_data = w_data["fog_data"]
	
	if w_data.has("active_paths"):
		main_ref.load_paths_save_data(w_data["active_paths"])
	else:
		main_ref.caminhos_ativos.clear()
		main_ref.tile_map_path.clear()
	
	main_ref._draw_map()
	main_ref.update_fog(player_ref.grid_pos)
	
	Game_State.caminho_jogador.clear()
	Game_State.player_action_history.clear()
	Game_State.log_player_position(player_ref.grid_pos)

# --- Funções Padrão de IO (Inalteradas) ---
func _save_game_to_path(path: String):
	print("Salvando jogo em: ", path)
	var state_dict = _get_current_game_state_dict()
	if state_dict.is_empty(): return
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return
	var json_string = JSON.stringify(state_dict, "\t")
	file.store_string(json_string)
	file.close()
	print("Jogo salvo com sucesso.")

func _load_game_from_path(path: String):
	print("Carregando jogo de: ", path)
	if not FileAccess.file_exists(path): return
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: return
	var json_string = file.get_as_text()
	file.close()
	var parse_result = JSON.parse_string(json_string)
	if parse_result == null: return
	_apply_game_state_dict(parse_result)
	print("Jogo carregado com sucesso.")

# --- API Pública ---
func save_player_game(): _save_game_to_path(SAVE_PATH_PLAYER)
func save_auto_game(): _save_game_to_path(SAVE_PATH_AUTO)
func load_player_game(): _load_game_from_path(SAVE_PATH_PLAYER)
func load_auto_game(): _load_game_from_path(SAVE_PATH_AUTO)

# --- Rewind Global ---
func _on_snapshot_timer_timeout():
	var snapshot = _get_current_game_state_dict()
	if snapshot.is_empty(): return
	global_snapshot_buffer.push_back(snapshot)
	if global_snapshot_buffer.size() > max_global_snapshots:
		global_snapshot_buffer.pop_front()
	print("SaveManager: Snapshot global (Rewind) capturado.")

func apply_latest_global_snapshot():
	if global_snapshot_buffer.is_empty():
		print("Rewind Global: Nenhum snapshot.")
		return
	var snapshot = global_snapshot_buffer.pop_back()
	_apply_game_state_dict(snapshot)
	global_snapshot_buffer.clear()
	snapshot_timer.start()
