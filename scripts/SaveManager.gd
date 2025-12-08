# res://scripts/SaveManager.gd
extends Node

# --- Configuração ---
const SAVE_PATH_AUTO = "user://grafos_quest_auto.json"
const SAVE_PATH_PLAYER = "user://grafos_quest_player.json"
const SAVE_PATH_HUB_BACKUP = "user://grafos_quest_hub_backup.json"
const LEADERBOARD_PATH = "user://leaderboard.json"

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
		# Tenta usar a nossa variável manual. Se estiver vazia, tenta o path nativo.
		var path_para_salvar = item.arquivo_origem
		if path_para_salvar == "" and item.resource_path != "":
			path_para_salvar = item.resource_path
			
		serialized_items.push_back({
			"resource_path": path_para_salvar, # Salvamos o caminho descoberto acima
			"nome_item": item.nome_item,
			"descricao": item.descricao,
			"tipo_item": item.tipo_item, 
			"efeito": item.efeito,
			"valor_efeito": item.valor_efeito,
			"durabilidade": item.durabilidade,
			"alcance_maximo": item.alcance_maximo
		})
	return serialized_items

func _get_current_game_state_dict() -> Dictionary:
	if not main_ref or not player_ref:
		print("ERROR - SaveManager: Falha ao salvar. Referências perdidas.")
		return {}

	var data = {}
	
	# 1. GameState Geral
	data["gamestate"] = {
		"is_in_hub": Game_State.is_in_hub,
		"bad_ending_count": Game_State.bad_ending_count,
		"tempo_jogador": Game_State.tempo_jogador,
		"caminho_jogador": _serialize_path(Game_State.caminho_jogador),
		"tempo_par_level": Game_State.tempo_par_level,
		"vida_jogador": Game_State.vida_jogador,
		"moedas": Game_State.moedas,
		"stats_jogador": Game_State.stats_jogador,
		"optional_objectives": Game_State.optional_objectives,
		"terminais_ativos": Game_State.terminais_ativos,
		"terminais_necessarios": Game_State.terminais_necessarios,
		"enemy_states": Game_State.enemy_states,
		"npc_states": Game_State.npc_states,
		"interactable_states": Game_State.interactable_states,
		"inventory": _serialize_inventory(Game_State.inventario_jogador.items),
		"indice_fase_atual": LevelManager.indice_fase_atual,
		"musica_atual_path": Game_State.musica_atual_path
	}
	
	# 2. Dados do Player (Sempre salvamos)
	data["player"] = {
		"grid_pos_x": player_ref.grid_pos.x,
		"grid_pos_y": player_ref.grid_pos.y,
		"last_facing": player_ref.last_facing
	}
	
	# 3. Dados do Mundo (BIFURCAÇÃO PARA EVITAR O ERRO)
	if Game_State.is_in_hub:
		# --- ROTA A: HUB ---
		# Salvamos apenas um marcador. Não tentamos ler fog_logic ou map_data
		# porque eles não existem ou são irrelevantes no Hub fixo.
		data["world"] = {
			"is_hub_save": true,
			"npcs_data": main_ref.get_npcs_state_data(),
			"chests_data": main_ref.get_chests_state_data()
		}
	else:
		# --- ROTA B: FASE PROCEDURAL ---
		# Aqui salvamos tudo, pois o mapa foi gerado proceduralmente
		data["world"] = {
			"vertice_fim_x": main_ref.vertice_fim.x,
			"vertice_fim_y": main_ref.vertice_fim.y,
			"saida_destrancada": main_ref.saida_destrancada,
			"map_data": _serialize_map(main_ref.map_data),
			"fog_data": main_ref.fog_logic.fog_data, # Agora seguro, pois só roda na fase
			"active_paths": main_ref.get_paths_save_data(),
			"enemies_data": main_ref.get_enemies_state_data(),
			"npcs_data": main_ref.get_npcs_state_data(),
			"chests_data": main_ref.get_chests_state_data()
		}
	
	return data

func _apply_game_state_dict(data: Dictionary):
	if not main_ref or not player_ref:
		print("ERROR - SaveManager: Falha ao carregar.")
		return
	
	var gs_data = data["gamestate"]
	Game_State.bad_ending_count = int(gs_data.get("bad_ending_count", 0))
	
	# Restaura Globais
	Game_State.is_in_hub = gs_data.get("is_in_hub", false)
	Game_State.moedas = int(gs_data.get("moedas", 0))
	
	if gs_data.has("stats_jogador"):
		Game_State.stats_jogador = gs_data["stats_jogador"]
		# Segurança para tipos numéricos (JSON às vezes transforma int em float)
		for key in Game_State.stats_jogador:
			if typeof(Game_State.stats_jogador[key]) == TYPE_FLOAT:
				Game_State.stats_jogador[key] = int(Game_State.stats_jogador[key])
	
	Game_State.tempo_jogador = float(gs_data.get("tempo_jogador", 0.0))
	
	if gs_data.has("caminho_jogador"):
		Game_State.caminho_jogador = _deserialize_path(gs_data["caminho_jogador"])
	else:
		Game_State.caminho_jogador.clear() # Só limpa se o save for antigo/vazio
	
	# Carrega caminho para printar na tela de vitória
	if gs_data.has("indice_fase_atual"):
		LevelManager.indice_fase_atual = int(gs_data["indice_fase_atual"])
	else:
		LevelManager.indice_fase_atual = 0
	
	if gs_data.has("indice_fase_atual"):
		LevelManager.indice_fase_atual = int(gs_data["indice_fase_atual"])
	else:
		LevelManager.indice_fase_atual = 0
		
	Game_State.musica_atual_path = gs_data.get("musica_atual_path", "")
	Game_State.tempo_par_level = gs_data.get("tempo_par_level", 0.0)
	Game_State.vida_jogador = gs_data.get("vida_jogador", 50)
	Game_State.optional_objectives = gs_data.get("optional_objectives", {})
	Game_State.terminais_ativos = gs_data.get("terminais_ativos", 0)
	Game_State.terminais_necessarios = gs_data.get("terminais_necessarios", 0)
	Game_State.enemy_states = gs_data.get("enemy_states", {})
	Game_State.npc_states = gs_data.get("npc_states", {})
	Game_State.interactable_states = gs_data.get("interactable_states", {})

	var itens_carregados = _deserialize_inventory(gs_data["inventory"])
	Game_State.inventario_jogador.resincronizar_itens(itens_carregados)	
	
	# Posiciona Jogador
	var p_data = data["player"]
	var new_grid_pos = Vector2i(p_data["grid_pos_x"], p_data["grid_pos_y"])
	player_ref.grid_pos = new_grid_pos
	player_ref.last_facing = p_data["last_facing"]
	player_ref.global_position = (Vector2(new_grid_pos) * main_ref.TILE_SIZE) + (Vector2.ONE * main_ref.TILE_SIZE / 2.0)
	player_ref.reset_state_on_load()
	
	var level_def = LevelManager.get_dados_fase_atual()
	
	# Se a fase tem um script lógico (ex: ending_demo.gd), precisamos recriá-lo!
	if level_def and level_def.script_logico:
		print("SaveManager: Restaurando Script Lógico (Eventos)...")
		
		# Remove script antigo se houver (para evitar duplicatas em loads seguidos)
		if main_ref.script_fase_atual and is_instance_valid(main_ref.script_fase_atual):
			main_ref.script_fase_atual.queue_free()
		
		# Instancia o nó novamente
		var script_node = level_def.script_logico.new()
		script_node.name = "LevelScript"
		main_ref.add_child(script_node)
		
		# Reconecta a referência na Main
		main_ref.script_fase_atual = script_node
		
		# (Opcional) Executa o setup novamente para reconectar variáveis internas do script
		if script_node.has_method("setup_fase"):
			script_node.setup_fase(main_ref)
	else:
		# Se não tem script, garante que a variável na Main seja null
		main_ref.script_fase_atual = null
	
	# ========================================================
	# ROTA A: CARREGAMENTO DO HUB
	# ========================================================
	if Game_State.is_in_hub:
		print("SaveManager: Detectado save no HUB.")
		
		# 1. Carrega Visual Fixo
		if LevelManager.hub_definition:
			main_ref._carregar_mapa_fixo(LevelManager.hub_definition.cena_fixa)
		
		# 2. Configura Câmera e Névoa Dummy
		main_ref._setup_camera()
		if not main_ref.fog_logic: # Cria se não existir
			main_ref.fog_logic = FogOfWar.new(main_ref.largura_atual, main_ref.altura_atual, 100)
		main_ref.fog_logic.revelar_tudo()
		if main_ref.tile_map_fog:
			main_ref.tile_map_fog.hide()

		# 3. RECUPERAÇÃO DE ENTIDADES (NPCs e Baús)
		var w_data = data["world"]
		
		# Tenta carregar NPCs do save
		if w_data.has("npcs_data") and not w_data["npcs_data"].is_empty():
			main_ref.load_npcs_state_data(w_data["npcs_data"])
		else:
			# FALLBACK: Se o save não tem NPCs (save antigo/bugado), spawna os padrões!
			print("SaveManager: Nenhum NPC no save do Hub. Spawnando padrões...")
			if LevelManager.hub_definition:
				main_ref._spawnar_npcs(LevelManager.hub_definition)
		
		# Tenta carregar Baús do save
		if w_data.has("chests_data"):
			main_ref.load_chests_state_data(w_data["chests_data"])
		
		_forcar_atualizacao_hud_geral()
		
		print("SaveManager: Hub restaurado com NPCs.")
		return 

	# ========================================================
	# ROTA B: CARREGAMENTO PROCEDURAL
	# ========================================================
	
	var w_data = data["world"]
	main_ref.vertice_fim = Vector2i(w_data["vertice_fim_x"], w_data["vertice_fim_y"])
	
	if w_data.has("saida_destrancada"):
		main_ref.saida_destrancada = w_data["saida_destrancada"]
	else:
		main_ref.saida_destrancada = false
	
	# Carrega Mapa
	main_ref.map_data = _deserialize_map(w_data["map_data"])
	
	if main_ref.map_data.size() > 0:
		main_ref.altura_atual = main_ref.map_data.size()
		main_ref.largura_atual = main_ref.map_data[0].size()
		# Reconstrói a névoa com tamanho correto antes de carregar dados
		main_ref.fog_logic = FogOfWar.new(main_ref.largura_atual, main_ref.altura_atual, 5)
	
	main_ref.fog_logic.fog_data = w_data["fog_data"]
	
	if w_data.has("chests_data"):
		main_ref.load_chests_state_data(w_data["chests_data"])
	
	# Grafo
	main_ref.grafo = Graph.new(main_ref.map_data)
	main_ref.dijkstra = Dijkstra.new(main_ref.grafo)
	main_ref.astar = AStar.new(main_ref.grafo)
	main_ref.bfs = BFS.new(main_ref.grafo)
	
	main_ref.reconstruir_dados_logicos_do_mapa()
	
	if w_data.has("active_paths"):
		main_ref.load_paths_save_data(w_data["active_paths"])
	else:
		main_ref.caminhos_ativos.clear()
		main_ref.tile_map_path.clear()
		
	if w_data.has("enemies_data"):
		main_ref.load_enemies_state_data(w_data["enemies_data"])
	
	if w_data.has("npcs_data"):
		main_ref.load_npcs_state_data(w_data["npcs_data"])
	else:
		main_ref._spawnar_npcs(LevelManager.get_dados_fase_atual())
	
	main_ref._draw_map()
	main_ref.update_fog(player_ref.grid_pos)
	main_ref._setup_camera()
	_forcar_atualizacao_hud_geral()
		
	# Game_State.caminho_jogador.clear()
	Game_State.log_player_position(player_ref.grid_pos)

func _forcar_atualizacao_hud_geral():
	# 1. Emite sinais para quem estiver ouvindo (HUD)
	if Game_State.has_signal("moedas_alteradas"):
		Game_State.moedas_alteradas.emit(Game_State.moedas)
		
	if Game_State.has_signal("municao_kill9_alterada"):
		Game_State.municao_kill9_alterada.emit(Game_State.stats_jogador["kill9_ammo"])

	if Game_State.has_signal("item_equipado_alterado"):
		Game_State.item_equipado_alterado.emit(Game_State.item_equipado)

	# 2. Busca a HUD e manda ela se redesenhar do zero
	if main_ref:
		var hud = main_ref.get_node_or_null("HUD")
		if hud and hud.has_method("forcar_atualizacao_total"):
			hud.forcar_atualizacao_total()
			print("SaveManager: HUD atualizada com sucesso.")

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

# Em SaveManager.gd

func _deserialize_inventory(serialized_items: Array) -> Array[ItemData]:
	var items: Array[ItemData] = []
	for item_data in serialized_items:
		var new_item: ItemData
		
		# TENTA CARREGAR O ARQUIVO ORIGINAL
		if item_data.has("resource_path") and item_data["resource_path"] != "":
			if ResourceLoader.exists(item_data["resource_path"]):
				# Carrega e duplica
				new_item = load(item_data["resource_path"]).duplicate()
				
				# *** O PULO DO GATO ***
				# Re-injeta o caminho na cópia para que o próximo save funcione!
				new_item.arquivo_origem = item_data["resource_path"]
			else:
				print("SaveManager: Aviso - Recurso não encontrado: ", item_data["resource_path"])
				new_item = ItemData.new()
		else:
			new_item = ItemData.new()
		
		# Aplica durabilidade e dados extras
		new_item.durabilidade = int(item_data["durabilidade"])
		
		# (Fallback para itens criados via código sem arquivo)
		if new_item.arquivo_origem == "":
			new_item.nome_item = item_data["nome_item"]
			new_item.descricao = item_data["descricao"]
			new_item.tipo_item = int(item_data["tipo_item"]) 
			new_item.efeito = item_data["efeito"]
			new_item.valor_efeito = item_data["valor_efeito"]
			if item_data.has("alcance_maximo"):
				new_item.alcance_maximo = int(item_data["alcance_maximo"])

		items.push_back(new_item)
	return items

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

# [NOVO] Serializa o dicionário de baús (Vector2i -> String)
func _serialize_baus(dict: Dictionary) -> Dictionary:
	var serialized = {}
	for pos in dict:
		# Converte chave Vector2i para String "x,y"
		var key = "%d,%d" % [pos.x, pos.y]
		serialized[key] = dict[pos]
	return serialized

# [NOVO] Deserializa o dicionário de baús (String -> Vector2i)
func _deserialize_baus(dict: Dictionary) -> Dictionary:
	var deserialized = {}
	for key in dict:
		var split = key.split(",")
		if split.size() >= 2:
			var pos = Vector2i(int(split[0]), int(split[1]))
			deserialized[pos] = dict[key]
	return deserialized

func save_hub_backup():
	print("SaveManager: Criando ponto de restauração do Hub...")
	_save_game_to_path(SAVE_PATH_HUB_BACKUP)

func load_hub_backup():
	print("SaveManager: Restaurando backup do Hub...")
	if FileAccess.file_exists(SAVE_PATH_HUB_BACKUP):
		_load_game_from_path(SAVE_PATH_HUB_BACKUP)
		return true
	else:
		print("SaveManager: Nenhum backup de Hub encontrado.")
		return false

# No final do SaveManager.gd

func aplicar_punicao_e_reverter_para_hub():
	print("SaveManager: Iniciando protocolo de punição (Revertendo para Hub)...")
	
	# 1. Verifica se existe um backup seguro do Hub
	if not FileAccess.file_exists(SAVE_PATH_HUB_BACKUP):
		print("SaveManager: ERRO CRÍTICO. Nenhum backup de Hub encontrado. Resetando save.")
		# Se não tem backup, infelizmente o jogador perde tudo ou reinicia a fase atual.
		# Por segurança, vamos apenas deletar o save do player para forçar New Game
		DirAccess.remove_absolute(SAVE_PATH_PLAYER)
		return

	# 2. Lê o arquivo de Backup do Hub (Raw Text)
	var file_read = FileAccess.open(SAVE_PATH_HUB_BACKUP, FileAccess.READ)
	var json_text = file_read.get_as_text()
	file_read.close()
	
	# 3. Converte para Dicionário para podermos editar
	var data = JSON.parse_string(json_text)
	if data == null:
		print("SaveManager: Erro ao ler JSON do Backup.")
		return

	# 4. INJETA A PUNIÇÃO
	# Pegamos o valor atual da memória (que já foi incrementado na BadEndingScreen)
	# e forçamos ele dentro do dicionário do backup antigo.
	data["gamestate"]["bad_ending_count"] = Game_State.bad_ending_count
	
	# (Opcional) Zera as moedas ganhas na fase fracassada?
	# data["gamestate"]["moedas"] = ... (Se quiser punir o bolso também)

	# 5. SOBRESCREVE o Save Principal (Player) com esse Backup Modificado
	# Agora, quando o jogador clicar em "Carregar", ele vai ler este arquivo (que é o Hub)
	var file_player = FileAccess.open(SAVE_PATH_PLAYER, FileAccess.WRITE)
	file_player.store_string(JSON.stringify(data, "\t"))
	file_player.close()
	
	# 6. Atualiza também o Backup (para manter a consistência da punição no futuro)
	var file_backup = FileAccess.open(SAVE_PATH_HUB_BACKUP, FileAccess.WRITE)
	file_backup.store_string(JSON.stringify(data, "\t"))
	file_backup.close()
	
	print("SaveManager: Punição aplicada. Save revertido para o Hub com BadEndingCount = ", Game_State.bad_ending_count)

# Converta Array[Vector2i] para Array de Arrays [[x,y], [x,y]]
func _serialize_path(caminho: Array[Vector2i]) -> Array:
	var result = []
	for pos in caminho:
		result.push_back([pos.x, pos.y])
	return result

# Converte de volta para Vector2i
func _deserialize_path(data: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p in data:
		# p é [x, y]
		result.push_back(Vector2i(int(p[0]), int(p[1])))
	return result

# --- LEADERBOARD SYSTEM (Cole no final do SaveManager.gd) ---

func get_leaderboard_data() -> Array:
	# Verifica se a constante LEADERBOARD_PATH existe. 
	# (Ela já estava definida no topo do seu arquivo original, linha 7 do source 150)
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		return [] # Retorna lista vazia se não existir arquivo
		
	var file = FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(text)
		if error == OK:
			var data = json.data
			if typeof(data) == TYPE_ARRAY:
				return data
	return []

func save_score_to_leaderboard(player_name: String, score: int):
	var board = get_leaderboard_data()
	
	# Cria a entrada
	var entry = {
		"name": player_name.substr(0, 3).to_upper(),
		"score": score
	}
	
	board.append(entry)
	
	# Ordena: Maior pontuação primeiro
	board.sort_custom(func(a, b): return a["score"] > b["score"])
	
	# Corta para manter apenas Top 10
	if board.size() > 10:
		board.resize(10)
	
	# Salva no disco
	var file = FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(board, "\t"))
		file.close()
		print("Leaderboard atualizado com sucesso!")
