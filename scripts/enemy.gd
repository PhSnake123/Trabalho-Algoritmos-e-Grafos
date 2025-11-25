extends CharacterBody2D
class_name Enemy

# --- TIPOS DE INTELIGÊNCIA ---
enum EnemyAI { 
	STALKER, 
	SMART    
}

@export_group("IA e Comportamento")
@export var ai_type: EnemyAI = EnemyAI.SMART
@export var passos_por_turno: int = 1 
@export var duracao_movimento: float = 0.15

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

# --- SISTEMA DE TURNO ---
func tomar_turno():
	if current_hp <= 0: return
	if not main_ref or not player_ref: return
	
	for i in range(passos_por_turno):
		if _checar_ataque_adjacente():
			break 
		
		var moveu = _tentar_mover()
		
		if moveu and ai_type != EnemyAI.STALKER:
			_checar_dano_terreno()
			
		if not moveu:
			break 

# --- MOVIMENTAÇÃO ---
func _tentar_mover() -> bool:
	var caminho = []
	if ai_type == EnemyAI.STALKER:
		caminho = main_ref.dijkstra.calcular_caminho(grid_pos, player_ref.grid_pos)
	else:
		caminho = main_ref.astar.calcular_caminho(grid_pos, player_ref.grid_pos)
	
	if caminho.size() < 2: return false
	var proximo_tile = caminho[1] 
	
	if proximo_tile == player_ref.grid_pos: return false
	if main_ref.is_tile_occupied_by_enemy(proximo_tile): return false

	grid_pos = proximo_tile
	_animar_movimento(grid_pos)
	return true

func _checar_dano_terreno():
	if not main_ref: return
	var tile_data = main_ref.get_tile_data(grid_pos)
	if tile_data and tile_data.dano_hp > 0:
		print("Inimigo pisou em terreno perigoso!")
		receber_dano_direto(tile_data.dano_hp) 

func _animar_movimento(target_grid: Vector2i):
	var nova_pos_world = _grid_to_world(target_grid)
	_atualizar_flip(nova_pos_world.x - global_position.x)
	
	# Cria tween único para movimento
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
	var dir_bump = (alvo.global_position - global_position).normalized() * 8
	var tween = create_tween()
	tween.tween_property(sprite, "position", default_sprite_pos + dir_bump, 0.05)
	tween.tween_property(sprite, "position", default_sprite_pos, 0.05)
	
	if alvo.has_method("receber_dano"):
		alvo.receber_dano(atk, knockback_power, grid_pos)

# --- COMBATE: RECEBER DANO ---
func receber_dano(atk_atacante: int, kb_power: int, pos_atacante: Vector2i):
	var dano_final = max(0, atk_atacante - def)
	current_hp -= dano_final
	print("Inimigo recebeu %d de dano. HP: %d/%d" % [dano_final, current_hp, max_hp])
	_atualizar_feedback_dano(dano_final)
	
	if sprite:
		var t = create_tween()
		t.tween_property(sprite, "modulate", Color.RED, 0.1)
		t.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	if current_hp <= 0:
		_morrer()
		return

	var forca_empurrão = kb_power - poise
	if forca_empurrão > 0:
		_aplicar_knockback(pos_atacante, forca_empurrão)

func _atualizar_feedback_dano(dano_valor: int):
	# 1. Atualiza Barra
	if health_bar:
		health_bar.value = current_hp
		health_bar.show()
	
	# 2. Texto Flutuante
	if main_ref and main_ref.has_method("spawn_floating_text"):
		# Cor Amarela para dano em inimigos
		var pos_visual = global_position + Vector2(0, -16)
		main_ref.spawn_floating_text(pos_visual, str(dano_valor), Color.YELLOW)

# --- KNOCKBACK REFATORADO (Cursor Temporário) ---
func _aplicar_knockback(origem_impacto: Vector2i, forca_total: int):
	var diff = grid_pos - origem_impacto
	var dir_kb = Vector2i(clamp(diff.x, -1, 1), clamp(diff.y, -1, 1))
	
	if dir_kb == Vector2i.ZERO: return 

	# Usamos um cursor temporário para simular o trajeto
	var cursor_pos = grid_pos
	var passos_realizados = 0
	var bateu = false
	var obstaculo = ""
	
	# Simulação Passo-a-Passo
	for i in range(forca_total):
		var proximo_teste = cursor_pos + dir_kb
		
		# Verificações
		if not main_ref.is_tile_passable(proximo_teste):
			bateu = true; obstaculo = "Parede"; break
		elif proximo_teste == player_ref.grid_pos:
			bateu = true; obstaculo = "Player"; break
		elif main_ref.is_tile_occupied_by_enemy(proximo_teste):
			bateu = true; obstaculo = "Outro Inimigo"; break
			
		# Caminho livre: avança o cursor
		cursor_pos = proximo_teste
		passos_realizados += 1
	
	# 1. Aplica o movimento real se houve deslocamento
	if passos_realizados > 0:
		print("Knockback: Recuou %d tiles." % passos_realizados)
		grid_pos = cursor_pos # Atualiza a posição lógica oficial
		_animar_movimento(grid_pos)
	
	# 2. Calcula Impacto (Força Restante)
	var forca_restante = forca_total - passos_realizados
	if bateu and forca_restante > 0:
		print("Knockback interrompido por %s! %d Força convertida em Dano." % [obstaculo, forca_restante])
		
		var dano_impacto = max(1, forca_restante * 2)
		receber_dano_direto(dano_impacto)
		
		# Visual de Impacto (Shake)
		var tween = create_tween()
		tween.tween_property(sprite, "position", default_sprite_pos + (Vector2(dir_kb) * 4), 0.05)
		tween.tween_property(sprite, "position", default_sprite_pos, 0.05)

func receber_dano_direto(qtd: int):
	current_hp -= qtd
	health_bar.value = current_hp
	health_bar.show()
	print(">> Dano Direto: %d. HP: %d" % [qtd, current_hp])
	if sprite:
		sprite.modulate = Color.RED
		var t = create_tween()
		t.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	if current_hp <= 0: _morrer()

func _morrer():
	print("Inimigo derrotado!")
	queue_free()

# --- UTILITÁRIOS ---
func _atualizar_flip(delta_x: float):
	if not sprite: return
	if abs(delta_x) > 0.1: sprite.flip_h = (delta_x < 0)

func _world_to_grid(pos: Vector2) -> Vector2i: return Vector2i(pos / 16.0)
func _grid_to_world(g_pos: Vector2i) -> Vector2: return (Vector2(g_pos) * 16.0) + Vector2(8, 8)

# --- SAVE/LOAD ---
func get_save_data() -> Dictionary:
	return { "pos_x": grid_pos.x, "pos_y": grid_pos.y, "hp": current_hp, "ai_type": ai_type }

func load_save_data(data: Dictionary):
	var x = data.get("pos_x")
	var y = data.get("pos_y")
	if x == null or y == null:
		if data.has("grid_pos"):
			var s = str(data["grid_pos"]).replace("(", "").replace(")", "").replace(" ", "")
			var parts = s.split(",")
			if parts.size() >= 2: x = int(parts[0]); y = int(parts[1])
		else: x = grid_pos.x; y = grid_pos.y
	
	grid_pos = Vector2i(x, y)
	position = _grid_to_world(grid_pos)
	current_hp = int(data["hp"])
	if data.has("ai_type"): ai_type = int(data["ai_type"]) as EnemyAI
