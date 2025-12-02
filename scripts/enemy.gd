extends CharacterBody2D
class_name Enemy

# --- ENUMS ---
enum EnemyAI { 
	STALKER, # Usa Dijkstra (Rápido, mas burro com lama)
	SMART    # Usa A* (Considera terreno)
}

enum BehaviorType {
	PADRAO,         # Sempre persegue (Comportamento antigo)
	SENTINELA,      # Fica parado -> Detecta (BFS) -> Vira PADRAO
	PATRULHEIRO,    # Anda Aleatório -> Detecta (BFS) -> Vira PADRAO
	TURRET          # Fica parado -> Detecta (BFS) -> Ataca de longe
}

# --- CONFIGURAÇÃO (Editor) ---
@export_group("IA e Comportamento")
@export var behavior: BehaviorType = BehaviorType.PADRAO
@export var ai_type: EnemyAI = EnemyAI.SMART # Renomeado para manter consistência
@export var raio_deteccao_bfs: int = 6
@export var passos_por_turno: int = 1
@export var duracao_movimento: float = 0.15
@export var peso_astar: float = 1.0

# --- ATRIBUTOS DE COMBATE ---
@export_group("Atributos de Combate")
@export var max_hp: int = 50
@export var atk: int = 10
@export var def: int = 2
@export var poise: int = 5
@export var knockback_power: int = 3
@onready var health_bar: ProgressBar = $HealthBar

# --- REFERÊNCIAS ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var main_ref = null
var player_ref = null

# --- ESTADO ---
var current_hp: int
var grid_pos: Vector2i = Vector2i.ZERO 
var default_sprite_pos: Vector2 = Vector2.ZERO 
var loot_moedas: int = 0 
var _alerta_ativado: bool = false # Se true, age como PADRAO (perseguição)

func _ready():
	current_hp = max_hp
	add_to_group("inimigos") 
	
	await get_tree().process_frame 
	grid_pos = _world_to_grid(global_position)
	position = _grid_to_world(grid_pos)
	
	if sprite: 
		default_sprite_pos = sprite.position 
		sprite.play("default")
	
	if not main_ref and get_parent().has_method("get_tile_data"):
		main_ref = get_parent()
	if not player_ref and main_ref:
		player_ref = main_ref.get_node("Player")
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
		health_bar.hide()

# --- SISTEMA DE TURNO (CÉREBRO) ---
func tomar_turno():
	if current_hp <= 0: return
	if not main_ref or not player_ref: return
	
	# 1. Fase de Detecção (Sensor BFS)
	# Só roda se não estiver em alerta e não for o padrão (que sempre sabe onde o player tá)
	if not _alerta_ativado and behavior != BehaviorType.PADRAO:
		_processar_deteccao()
	
	# 2. Fase de Ação (Loop de Passos)
	for i in range(passos_por_turno):
		
		# A. Turret tem lógica única (não se move)
		if behavior == BehaviorType.TURRET:
			if _alerta_ativado:
				_tentar_ataque_distancia()
			break # Turret não anda, encerra o turno
		
		# B. Verifica ataque corpo-a-corpo antes de andar
		if _checar_ataque_adjacente():
			break # Se atacou, encerra o turno (ou gasta o passo)
		
		# C. Decide Movimento
		var moveu = false
		
		if behavior == BehaviorType.PADRAO or (behavior != BehaviorType.TURRET and _alerta_ativado):
			# Modo Perseguição (Stalker/Smart)
			moveu = _tentar_mover_perseguicao()
			if moveu: _checar_dano_terreno()
			
		elif behavior == BehaviorType.PATRULHEIRO and not _alerta_ativado:
			# Modo Patrulha (Aleatório)
			moveu = _tentar_mover_aleatorio()
			# Patrulheiros geralmente não tomam dano de terreno ou evitam, 
			# mas vamos deixar tomar por enquanto.
			if moveu: _checar_dano_terreno()
			
		elif behavior == BehaviorType.SENTINELA and not _alerta_ativado:
			# Sentinela parada não faz nada
			pass
			
		# Se não conseguiu mover (bloqueado), encerra o loop para não gastar processamento
		if not moveu and (_alerta_ativado or behavior == BehaviorType.PADRAO):
			break

# --- SENSORES ---
func _processar_deteccao():
	# Otimização: Distância Manhattan rápida antes de rodar o BFS pesado
	var dist_aprox = abs(grid_pos.x - player_ref.grid_pos.x) + abs(grid_pos.y - player_ref.grid_pos.y)
	if dist_aprox > raio_deteccao_bfs + 2:
		return 

	# Roda o BFS real para ver se o player está alcançável/visível no grafo
	var area = main_ref.bfs.obter_area_alcance(grid_pos, raio_deteccao_bfs)
	
	if player_ref.grid_pos in area:
		print("%s detectou o Jogador! Modo Alerta Ativado." % name)
		_alerta_ativado = true
		main_ref.spawn_floating_text(global_position + Vector2(0, -24), "!", Color.RED)

# --- MOVIMENTAÇÃO: PERSEGUIÇÃO ---
func _tentar_mover_perseguicao() -> bool:
	var caminho = []
	if ai_type == EnemyAI.STALKER:
		caminho = main_ref.dijkstra.calcular_caminho_rapido(grid_pos, player_ref.grid_pos)
	else:
		caminho = main_ref.astar.calcular_caminho(grid_pos, player_ref.grid_pos, peso_astar)
	
	if caminho.size() < 2: return false
	var proximo_tile = caminho[1] 
	
	# Validações finais
	if proximo_tile == player_ref.grid_pos: return false
	if main_ref.is_tile_occupied_by_enemy(proximo_tile): return false
	# (Adicionar aqui checagem de NPC se necessário)

	_aplicar_movimento(proximo_tile)
	return true

# --- MOVIMENTAÇÃO: ALEATÓRIA ---
func _tentar_mover_aleatorio() -> bool:
	var vizinhos = []
	# Checa 4 direções
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var target = grid_pos + dir
		
		# Regras de patrulha: Não entra em parede, não bate em inimigo, não bate no player
		if main_ref.is_tile_passable(target) and \
		   not main_ref.is_tile_occupied_by_enemy(target) and \
		   target != player_ref.grid_pos:
			vizinhos.push_back(target)
	
	if not vizinhos.is_empty():
		var destino = vizinhos.pick_random()
		_aplicar_movimento(destino)
		return true
	
	return false

# Função comum para atualizar posição e animar
func _aplicar_movimento(target: Vector2i):
	grid_pos = target
	var nova_pos_world = _grid_to_world(grid_pos)
	_atualizar_flip(nova_pos_world.x - global_position.x)
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", nova_pos_world, duracao_movimento)

func _checar_dano_terreno():
	if not main_ref: return
	var tile_data = main_ref.get_tile_data(grid_pos)
	if tile_data and tile_data.dano_hp > 0:
		receber_dano_direto(tile_data.dano_hp) 

# --- COMBATE: ATAQUE ---
func _checar_ataque_adjacente() -> bool:
	var dist = abs(grid_pos.x - player_ref.grid_pos.x) + abs(grid_pos.y - player_ref.grid_pos.y)
	if dist == 1:
		_executar_bump_attack(player_ref)
		return true
	return false

func _executar_bump_attack(alvo):
	# Animação de encontrão
	var dir_bump = (alvo.global_position - global_position).normalized() * 8
	var tween = create_tween()
	tween.tween_property(sprite, "position", default_sprite_pos + dir_bump, 0.05)
	tween.tween_property(sprite, "position", default_sprite_pos, 0.05)
	
	if alvo.has_method("receber_dano"):
		alvo.receber_dano(atk, knockback_power, grid_pos)

func _tentar_ataque_distancia():
	print("Turret disparando!")
	
	# --- EFEITO VISUAL DO TIRO ---
	if main_ref and main_ref.has_method("criar_projetil_visual"):
		# Ajuste visual: Se o sprite tiver offset, podemos somar Vector2(0, -8) para sair do "rosto"
		main_ref.criar_projetil_visual(global_position, player_ref.global_position)
	
	# --- DANO (Mantido igual) ---
	# Pequeno delay para o dano sincronizar com a chegada do projétil (0.15s)
	await get_tree().create_timer(0.15).timeout
	
	# Verifica se o player ainda existe antes de dar dano (segurança)
	if is_instance_valid(player_ref) and player_ref.has_method("receber_dano"):
		player_ref.receber_dano(atk, 0, grid_pos)
		
	# Feedback visual na própria Turret (Recuo/Cor)
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.MAGENTA, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

# --- COMBATE: RECEBER DANO ---
func receber_dano(atk_atacante: int, kb_power: int, pos_atacante: Vector2i):
	# Se tomou dano, acorda imediatamente!
	if not _alerta_ativado:
		_alerta_ativado = true
		main_ref.spawn_floating_text(global_position + Vector2(0, -24), "!", Color.RED)

	var dano_final = max(0, atk_atacante - def)
	current_hp -= dano_final
	
	_atualizar_feedback_dano(dano_final)
	
	if main_ref and main_ref.has_method("aplicar_hit_stop"):
		main_ref.aplicar_hit_stop(0.05, 0.08)
	
	if sprite:
		var t = create_tween()
		t.tween_property(sprite, "modulate", Color.RED, 0.1)
		t.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	if current_hp <= 0:
		_morrer()
		return

	var forca_empurrao = kb_power - poise
	if forca_empurrao > 0:
		_aplicar_knockback(pos_atacante, forca_empurrao)

func _atualizar_feedback_dano(dano_valor: int):
	if health_bar:
		health_bar.value = current_hp
		health_bar.show()
	if main_ref and main_ref.has_method("spawn_floating_text"):
		var pos_visual = global_position + Vector2(0, -16)
		main_ref.spawn_floating_text(pos_visual, str(dano_valor), Color.YELLOW)

func receber_dano_direto(qtd: int):
	current_hp -= qtd
	health_bar.value = current_hp
	health_bar.show()
	if sprite:
		sprite.modulate = Color.RED
		var t = create_tween()
		t.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	if current_hp <= 0: _morrer()

# --- KNOCKBACK (Mantido igual) ---
func _aplicar_knockback(origem_impacto: Vector2i, forca_total: int):
	var diff = grid_pos - origem_impacto
	var dir_kb = Vector2i(clamp(diff.x, -1, 1), clamp(diff.y, -1, 1))
	if dir_kb == Vector2i.ZERO: return 

	var cursor_pos = grid_pos
	var passos_realizados = 0
	var bateu = false
	
	for i in range(forca_total):
		var proximo_teste = cursor_pos + dir_kb
		
		# Validações de colisão
		if not main_ref.is_tile_passable(proximo_teste):
			bateu = true; break
		elif proximo_teste == player_ref.grid_pos:
			bateu = true; break
		elif main_ref.is_tile_occupied_by_enemy(proximo_teste):
			bateu = true; break
			
		cursor_pos = proximo_teste
		passos_realizados += 1
	
	if passos_realizados > 0:
		_aplicar_movimento(cursor_pos)
	
	if bateu:
		var dano_impacto = max(1, (forca_total - passos_realizados) * 2)
		receber_dano_direto(dano_impacto)

func _morrer():
	if main_ref and main_ref.has_method("spawn_moeda") and loot_moedas > 0:
		main_ref.spawn_moeda(global_position, loot_moedas)
	queue_free()

# --- UTILITÁRIOS ---
func _atualizar_flip(delta_x: float):
	if not sprite: return
	if abs(delta_x) > 0.1: sprite.flip_h = (delta_x < 0)

func _world_to_grid(pos: Vector2) -> Vector2i: return Vector2i(pos / 16.0)
func _grid_to_world(g_pos: Vector2i) -> Vector2: return (Vector2(g_pos) * 16.0) + Vector2(8, 8)

# --- SAVE/LOAD SYSTEM ---
func get_save_data() -> Dictionary:
	return {
		"scene_path": get_scene_file_path(),
		"pos_x": grid_pos.x,
		"pos_y": grid_pos.y,
		"hp": current_hp,
		"ai_type": ai_type,
		"behavior": behavior, # [NOVO] Salva o tipo de comportamento
		"alerta": _alerta_ativado, # [NOVO] Salva se já viu o player
		"modulate_html": modulate.to_html(),
		"loot_moedas": loot_moedas,
		"stats_override": {
			"max_hp": max_hp,
			"atk": atk,
			"def": def,
			"poise": poise,
			"knockback_power": knockback_power,
			"passos_por_turno": passos_por_turno,
			"raio_deteccao": raio_deteccao_bfs
		}
	}

func load_save_data(data: Dictionary):
	# 1. Posição
	var x = data.get("pos_x")
	var y = data.get("pos_y")
	if x == null: # Fallback para saves muito antigos
		x = grid_pos.x; y = grid_pos.y
	
	grid_pos = Vector2i(x, y)
	position = _grid_to_world(grid_pos)
	
	# 2. Comportamento e IA
	if data.has("ai_type"): ai_type = int(data["ai_type"]) as EnemyAI
	if data.has("behavior"): behavior = int(data["behavior"]) as BehaviorType
	if data.has("alerta"): _alerta_ativado = bool(data["alerta"])
	
	if data.has("loot_moedas"): loot_moedas = int(data["loot_moedas"])
	if data.has("modulate_html"): modulate = Color.html(data["modulate_html"])
		
	# 3. Atributos
	if data.has("stats_override"):
		var stats = data["stats_override"]
		max_hp = int(stats.get("max_hp", max_hp))
		atk = int(stats.get("atk", atk))
		def = int(stats.get("def", def))
		poise = int(stats.get("poise", poise))
		knockback_power = int(stats.get("knockback_power", knockback_power))
		passos_por_turno = int(stats.get("passos_por_turno", passos_por_turno))
		raio_deteccao_bfs = int(stats.get("raio_deteccao", raio_deteccao_bfs))
	
	# 4. HP Atual
	if data.has("hp"): current_hp = int(data["hp"])
	else: current_hp = max_hp
		
	if current_hp < max_hp and sprite:
		sprite.modulate = Color(1, 0.8, 0.8)
