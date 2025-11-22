extends CharacterBody2D
class_name Enemy

# --- ATRIBUTOS DE COMBATE (Base) ---
@export_group("Atributos de Combate")
@export var max_hp: int = 50
@export var atk: int = 10
@export var def: int = 2
@export var poise: int = 5      # Resistência a ser empurrado
@export var knockback_power: int = 3 # Poder de empurrar

# --- CONFIGURAÇÕES TÁTICAS ---
@export_group("IA e Movimento")
@export var passos_por_turno: int = 1 
@export var duracao_movimento: float = 0.15

# --- REFERÊNCIAS ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var main_ref = null
var player_ref = null

# --- ESTADO ---
var current_hp: int
var grid_pos: Vector2i = Vector2i.ZERO 

func _ready():
	current_hp = max_hp
	add_to_group("inimigos") 
	
	await get_tree().process_frame 
	grid_pos = _world_to_grid(global_position)
	position = _grid_to_world(grid_pos)
	
	if not main_ref and get_parent().has_method("get_tile_data"):
		main_ref = get_parent()
	if not player_ref and main_ref:
		player_ref = main_ref.get_node("Player")
	
	if sprite: sprite.play("default")

# --- SISTEMA DE TURNO ---
func tomar_turno():
	if current_hp <= 0: return
	if not main_ref or not player_ref: return
	
	for i in range(passos_por_turno):
		# 1. Tenta atacar se estiver adjacente
		if _checar_ataque_adjacente():
			break 
		
		# 2. Se não atacou, tenta mover
		var moveu = _tentar_mover()
		if not moveu:
			break 

# --- MOVIMENTAÇÃO ---
func _tentar_mover() -> bool:
	var caminho = main_ref.dijkstra.calcular_caminho(grid_pos, player_ref.grid_pos)
	
	if caminho.size() < 2: return false
	var proximo_tile = caminho[1] 
	
	# REGRA 1: Prioridade do Player (Se o player acabou de entrar nesse tile, não posso entrar)
	if proximo_tile == player_ref.grid_pos:
		# O player está lá. O _checar_ataque já falhou antes? 
		# Se sim, é porque algo estranho ocorreu, mas por segurança não movemos.
		return false

	# REGRA 2: Colisão com outros Inimigos (Evita empilhamento)
	if main_ref.is_tile_occupied_by_enemy(proximo_tile):
		return false # Fica parado esperando a fila andar

	# Executa Movimento
	grid_pos = proximo_tile
	_animar_movimento(grid_pos)
	return true

func _animar_movimento(target_grid: Vector2i):
	var nova_pos_world = _grid_to_world(target_grid)
	_atualizar_flip(nova_pos_world.x - global_position.x)
	var tween = create_tween()
	tween.tween_property(self, "global_position", nova_pos_world, duracao_movimento)

# --- COMBATE: ATAQUE ---
func _checar_ataque_adjacente() -> bool:
	var dist = abs(grid_pos.x - player_ref.grid_pos.x) + abs(grid_pos.y - player_ref.grid_pos.y)
	if dist == 1:
		_executar_bump_attack(player_ref)
		return true
	return false

func _executar_bump_attack(alvo):
	print("Inimigo atacou Player!")
	
	# Animação de "Bump"
	var dir_bump = (alvo.global_position - global_position).normalized() * 8
	var tween = create_tween()
	tween.tween_property(self, "position", position + dir_bump, 0.05)
	tween.tween_property(self, "position", position, 0.05)
	
	# Chama a função de receber dano no ALVO
	if alvo.has_method("receber_dano"):
		# Passamos os dados do atacante (nós) para o cálculo
		alvo.receber_dano(atk, knockback_power, grid_pos)

# --- COMBATE: RECEBER DANO ---
func receber_dano(atk_atacante: int, kb_power: int, pos_atacante: Vector2i):
	# 1. Cálculo de Dano (Atk - Def)
	var dano_final = max(0, atk_atacante - def)
	current_hp -= dano_final
	print("Inimigo recebeu %d de dano. HP: %d/%d" % [dano_final, current_hp, max_hp])
	
	# Visual de Dano (Flash Vermelho ou Shake)
	if sprite:
		var t = create_tween()
		t.tween_property(sprite, "modulate", Color.RED, 0.1)
		t.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	if current_hp <= 0:
		_morrer()
		return

	# 2. Cálculo de Knockback (KB - Poise)
	var forca_empurrão = kb_power - poise
	if forca_empurrão > 0:
		_aplicar_knockback(pos_atacante, forca_empurrão)

func _aplicar_knockback(origem_impacto: Vector2i, tiles_distancia: int):
	# Direção do empurrão no grid
	var diff = grid_pos - origem_impacto
	# Normaliza para grid (apenas 1 eixo por vez idealmente, mas clamp funciona)
	var dir_kb = Vector2i(clamp(diff.x, -1, 1), clamp(diff.y, -1, 1))
	
	var alvo_kb = grid_pos
	
	# Tenta empurrar tile por tile
	for i in range(tiles_distancia):
		var proximo_teste = alvo_kb + dir_kb
		
		# Verifica colisão com Paredes
		if not main_ref.is_tile_passable(proximo_teste):
			print("KB: Bateu na parede!")
			# Dano extra por bater na parede?
			break
			
		# Verifica colisão com Outros Inimigos (Lógica de 'Sanduíche' simplificada)
		if main_ref.is_tile_occupied_by_enemy(proximo_teste):
			print("KB: Bateu em outro inimigo!")
			# Aqui poderíamos propagar o KB para o inimigo de trás (Dominó)
			# Por enquanto, tratamos como parede
			break
			
		# Se livre, atualiza o alvo
		alvo_kb = proximo_teste
	
	if alvo_kb != grid_pos:
		grid_pos = alvo_kb
		_animar_movimento(grid_pos)

func _morrer():
	print("Inimigo derrotado!")
	# Tocar animação de morte, dropar itens, etc.
	queue_free()

# --- UTILITÁRIOS ---
func _atualizar_flip(delta_x: float):
	if not sprite: return
	if abs(delta_x) > 0.1: sprite.flip_h = (delta_x < 0)

func _world_to_grid(pos: Vector2) -> Vector2i: return Vector2i(pos / 16.0)
func _grid_to_world(g_pos: Vector2i) -> Vector2: return (Vector2(g_pos) * 16.0) + Vector2(8, 8)

# --- API PARA SALVAMENTO (GameState) ---

# [CORREÇÃO] Agora salvamos X e Y separados para o JSON não transformar em String
func get_save_data() -> Dictionary:
	return {
		"pos_x": grid_pos.x,
		"pos_y": grid_pos.y,
		"hp": current_hp
	}

func load_save_data(data: Dictionary):
	# 1. Tenta pegar no formato novo (X e Y separados)
	var x = data.get("pos_x")
	var y = data.get("pos_y")
	
	# 2. FALLBACK: Se não achou, é um save antigo bugado (String)
	if x == null or y == null:
		if data.has("grid_pos"):
			var s = str(data["grid_pos"]) # Converte pra string garantida
			# O formato costuma ser "(5, 10)"
			s = s.replace("(", "").replace(")", "").replace(" ", "")
			var parts = s.split(",")
			if parts.size() >= 2:
				x = int(parts[0])
				y = int(parts[1])
		else:
			# Se tudo falhar, mantemos onde spawamos
			x = grid_pos.x
			y = grid_pos.y
	
	grid_pos = Vector2i(x, y)
	position = _grid_to_world(grid_pos)
	current_hp = int(data["hp"])
