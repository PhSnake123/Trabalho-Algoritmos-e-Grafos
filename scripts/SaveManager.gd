# res://scripts/SaveManager.gd
extends Node

# --- Configuração ---
# O caminho dos arquivos de save. "user://" é a pasta segura do Godot.

const SAVE_PATH_AUTO = "user://grafos_quest_auto.json"   # O save automático do início do nível
const SAVE_PATH_PLAYER = "user://grafos_quest_player.json" # O save manual do save point/item

# Configuração do Rewind Global (Item 1)
@export var snapshot_interval: float = 120.0 # 120 segundos = 2 minutos. Fácil de ajustar.
@export var max_global_snapshots: int = 5     # Quantos snapshots de 2min guardar.

# --- Referências ---
# Nós da cena principal se registrarão aqui.
var main_ref: Node2D = null
var player_ref: CharacterBody2D = null

# --- Buffers ---
# Buffer para o "Item 1" (Rewind Global)
var global_snapshot_buffer: Array[Dictionary] = []
var snapshot_timer: Timer

# --- Inicialização ---

func _ready():
	# Configura o Timer para o Rewind Global
	snapshot_timer = Timer.new()
	snapshot_timer.wait_time = snapshot_interval
	# Conecta o sinal 'timeout' do Timer à nossa função
	snapshot_timer.timeout.connect(_on_snapshot_timer_timeout)
	add_child(snapshot_timer)
	# (Não inicia o timer ainda)
	
	print("SaveManager pronto.")

# --- Funções de Registro ---
# Chamado por main.gd em seu _ready()
func register_main(node: Node2D):
	main_ref = node
	print("SaveManager: Main.gd registrado.")
	
	# Agora que o Main (e o nível) existem, podemos iniciar o timer de snapshot.
	# Isso garante que ele não rode no menu principal.
	if not snapshot_timer.is_stopped():
		snapshot_timer.stop()
	snapshot_timer.start()

# Chamado por player.gd em seu _ready()
func register_player(node: CharacterBody2D):
	player_ref = node
	print("SaveManager: Player.gd registrado.")


# ===============================================
# 1. FUNÇÕES DE "EMPACOTAR" (SERIALIZAÇÃO)
# ===============================================

# Converte o mapa (Array[Array[MapTileData]]) para JSON
func _serialize_map(map_data: Array) -> Array:
	var serialized_map = []
	for y in range(map_data.size()):
		var row: Array[Dictionary] = []
		for x in range(map_data[y].size()):
			var tile: MapTileData = map_data[y][x]
			# Converte o *Objeto* em um *Dicionário* simples
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

# Converte o inventário (Array[ItemData]) para JSON
func _serialize_inventory(items: Array[ItemData]) -> Array:
	var serialized_items = []
	for item in items:
		# Converte o *Objeto* em um *Dicionário* simples
		serialized_items.push_back({
			"nome_item": item.nome_item,
			"descricao": item.descricao,
			"tipo_item": item.tipo_item, # Enums são salvos como inteiros, é seguro.
			"efeito": item.efeito,
			"valor_efeito": item.valor_efeito,
			"durabilidade": item.durabilidade
			# Não salvamos a textura, vamos recarregá-la pelo nome/path (se necessário)
		})
	return serialized_items

# A função "Mestre" que empacota TUDO
func _get_current_game_state_dict() -> Dictionary:
	# 1. Verifica se os nós essenciais estão prontos
	if not main_ref or not player_ref:
		print("ERROR - SaveManager: Tentativa de salvar, mas main/player não estão registrados.")
		return {}

	# 2. Inicia o dicionário de dados
	var data = {}
	
	# 3. Pacote do GameState (Singleton)
	# Inclui os dicionários de estado que usaremos no futuro
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
		# Serializa o inventário
		"inventory": _serialize_inventory(Game_State.inventario_jogador.items)
	}
	
	# 4. Pacote do Player (grid_pos é Vector2i, melhor salvar x/y)
	data["player"] = {
		"grid_pos_x": player_ref.grid_pos.x,
		"grid_pos_y": player_ref.grid_pos.y,
		"last_facing": player_ref.last_facing
	}
	
	# 5. Pacote do Main/Mundo (o mais complexo)
	data["world"] = {
		"vertice_fim_x": main_ref.vertice_fim.x,
		"vertice_fim_y": main_ref.vertice_fim.y,
		# Serializa o mapa
		"map_data": _serialize_map(main_ref.map_data),
		# Fog é Array[Array[bool]], é seguro para JSON
		"fog_data": main_ref.fog_logic.fog_data,
		# --- Salva os caminhos dos drones ---
		"active_paths": main_ref.get_paths_save_data()
	}
	
	return data


# ===============================================
# 2. FUNÇÕES DE "DESEMPACOTAR" (DESERIALIZAÇÃO)
# ===============================================

# Converte o JSON de volta para Array[Array[MapTileData]]
func _deserialize_map(serialized_map: Array) -> Array:
	var map_data = []
	for y in range(serialized_map.size()):
		var row = []
		for x in range(serialized_map[y].size()):
			var tile_data: Dictionary = serialized_map[y][x]
			# Cria um *novo Objeto* a partir do *Dicionário*
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

# Converte o JSON de volta para Array[ItemData]
func _deserialize_inventory(serialized_items: Array) -> Array:
	var items = []
	for item_data in serialized_items:
		# Cria um *novo Objeto* a partir do *Dicionário*
		var new_item = ItemData.new()
		new_item.nome_item = item_data["nome_item"]
		new_item.descricao = item_data["descricao"]
		new_item.tipo_item = item_data["tipo_item"] # Enums (inteiros) são carregados corretamente
		new_item.efeito = item_data["efeito"]
		new_item.valor_efeito = item_data["valor_efeito"]
		new_item.durabilidade = item_data["durabilidade"]
		items.push_back(new_item)
	return items

# A função "Mestre" que aplica TUDO
func _apply_game_state_dict(data: Dictionary):
	# 1. Verifica se os nós essenciais estão prontos
	if not main_ref or not player_ref:
		print("ERROR - SaveManager: Tentativa de carregar, mas main/player não estão registrados.")
		return
	
	# 2. Desempacota GameState
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
	
	# Deserializa o inventário
	# (Limpa o array de itens antes de adicionar os novos)
	Game_State.inventario_jogador.items.assign(_deserialize_inventory(gs_data["inventory"]))
	
	# 3. Desempacota Player
	var p_data = data["player"]
	var new_grid_pos = Vector2i(p_data["grid_pos_x"], p_data["grid_pos_y"])
	player_ref.grid_pos = new_grid_pos
	player_ref.last_facing = p_data["last_facing"]
	
	# Teleporta o jogador (essencial!)
	player_ref.global_position = (Vector2(new_grid_pos) * main_ref.TILE_SIZE) + (Vector2.ONE * main_ref.TILE_SIZE / 2.0)
	player_ref.reset_state_on_load()
	
	# 4. Desempacota Mundo
	var w_data = data["world"]
	main_ref.vertice_fim = Vector2i(w_data["vertice_fim_x"], w_data["vertice_fim_y"])
	
	# Deserializa o mapa
	main_ref.map_data = _deserialize_map(w_data["map_data"])
	
	# Deserializa a fog
	main_ref.fog_logic.fog_data = w_data["fog_data"]
	
	# Carrega os caminhos dos drones
	# Verificamos com .has() para compatibilidade com saves antigos que não tinham isso
	if w_data.has("active_paths"):
		main_ref.load_paths_save_data(w_data["active_paths"])
	else:
		# Se for um save antigo, garante que não tenha lixo na tela
		main_ref.caminhos_ativos.clear()
		main_ref.tile_map_path.clear()
	
	# 5. --- ESSENCIAL: REDESENHA TUDO! ---
	main_ref._draw_map()
	# Redesenha a fog e revela a área do jogador
	main_ref.update_fog(player_ref.grid_pos)
	
	# 6. Limpa os históricos (essencial ao carregar um save)
	# Um save carregado é um "novo" ponto de partida.
	Game_State.caminho_jogador.clear()
	Game_State.player_action_history.clear()
	# Loga a posição carregada como o início do novo histórico
	Game_State.log_player_position(player_ref.grid_pos)

# --- Função de Save Padrão ---
func _save_game_to_path(path: String):
	print("Salvando jogo em: ", path)
	var state_dict = _get_current_game_state_dict()
	
	if state_dict.is_empty():
		print("ERROR - Falha ao salvar: Dicionário de estado está vazio.")
		return

	# Abre o arquivo para escrita
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("ERROR - Falha ao abrir arquivo de save! Erro: %s" % FileAccess.get_open_error())
		return

	# Converte o dicionário para texto JSON (com tabs para ser legível)
	var json_string = JSON.stringify(state_dict, "\t")
	
	# Salva o texto
	file.store_string(json_string)
	file.close()
	print("Jogo salvo com sucesso em ", path)

# --- Função de Load Padrão ---
func _load_game_from_path(path: String):
	print("Carregando jogo de: ", path)
	
	# 1. Verifica se o arquivo existe
	if not FileAccess.file_exists(path):
		print("Nenhum arquivo de save encontrado em ", path)
		return

	# 2. Abre para leitura
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("ERROR - Falha ao abrir arquivo de save! Erro: %s" % FileAccess.get_open_error())
		return
	
	# 3. Lê o texto
	var json_string = file.get_as_text()
	file.close()
	
	# 4. Converte de texto para Dicionário
	var parse_result = JSON.parse_string(json_string)
	
	if parse_result == null:
		print("ERROR - Falha ao ler JSON do arquivo de save. O arquivo pode estar corrompido.")
		return
		
	# 5. Aplica o estado
	_apply_game_state_dict(parse_result)
	print("Jogo carregado com sucesso.")

# ===============================================
# 3. FUNÇÕES PÚBLICAS (Save, Load, Rewind)
# ===============================================

# --- Funções de Save Públicas ---

# Chamado pelo Save Point ou Item
func save_player_game():
	_save_game_to_path(SAVE_PATH_PLAYER)

# Chamado pelo Main no início do nível
func save_auto_game():
	_save_game_to_path(SAVE_PATH_AUTO)

# --- Funções de Load Públicas ---

# Chamado pela UI de Load "Continuar"
func load_player_game():
	_load_game_from_path(SAVE_PATH_PLAYER)

# Chamado pela UI de Load "Início da Fase"
func load_auto_game():
	_load_game_from_path(SAVE_PATH_AUTO)

# --- Funções do Rewind Global (Item 1) ---

# Chamado pelo Timer
func _on_snapshot_timer_timeout():
	var snapshot = _get_current_game_state_dict()
	if snapshot.is_empty():
		return # Falha ao pegar o snapshot (provavelmente main/player não registrados)
	
	global_snapshot_buffer.push_back(snapshot)
	
	# Limita o tamanho do buffer
	if global_snapshot_buffer.size() > max_global_snapshots:
		global_snapshot_buffer.pop_front() # Remove o mais antigo
	
	print("SaveManager: Snapshot global (Rewind) capturado.")

# Chamado pelo item de Rewind Global
func apply_latest_global_snapshot():
	if global_snapshot_buffer.is_empty():
		print("Rewind Global: Nenhum snapshot disponível.")
		# Opcional: Tocar um som de "falha"
		return
	
	print("Rewind Global: Revertendo para o último snapshot...")
	
	# Pega o snapshot mais recente
	var snapshot = global_snapshot_buffer.pop_back()
	
	# Aplica
	_apply_game_state_dict(snapshot)
	
	# Ao usar um snapshot, o "futuro" é apagado.
	# Limpamos o buffer para evitar paradoxos.
	global_snapshot_buffer.clear()
	# Opcional: Reiniciar o timer
	snapshot_timer.start()
