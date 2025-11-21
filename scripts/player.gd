# res://scripts/player.gd
extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
var sfx_teste = preload("res://Audio/sounds/hurt.wav") 

const TILE_SIZE := 16   
const SPEED := 80.0    

# --- CONFIGURAÇÃO POKÉMON (Turn Delay) ---
const TURN_DELAY_TIME: float = 0.08 
var turn_timer: float = 0.0

var grid_pos := Vector2i(1, 1)

var moving := false
var move_dir := Vector2.ZERO
var last_facing := "down"
var target_pos := Vector2.ZERO 

@onready var main_script = get_parent()

func _ready():
	global_position = (Vector2(grid_pos) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
	target_pos = global_position 
	SaveManager.register_player(self) 

func _physics_process(delta):
	if turn_timer > 0:
		turn_timer -= delta

	if not moving:
		handle_input()
	else:
		move_towards_target(delta)

func _get_input_direction() -> Vector2:
	if Input.is_action_pressed("ui_right"): return Vector2.RIGHT
	if Input.is_action_pressed("ui_left"): return Vector2.LEFT
	if Input.is_action_pressed("ui_down"): return Vector2.DOWN
	if Input.is_action_pressed("ui_up"): return Vector2.UP
	return Vector2.ZERO

func _get_facing_from_dir(dir: Vector2) -> String:
	if dir == Vector2.RIGHT: return "right"
	if dir == Vector2.LEFT: return "left"
	if dir == Vector2.DOWN: return "down"
	if dir == Vector2.UP: return "up"
	return last_facing

func handle_input():
	var input_dir = _get_input_direction()
	
	if input_dir != Vector2.ZERO:
		var desired_facing = _get_facing_from_dir(input_dir)
		if desired_facing != last_facing:
			last_facing = desired_facing
			anim.play("idle_" + last_facing)
			turn_timer = TURN_DELAY_TIME 
		else:
			if turn_timer <= 0:
				start_moving(input_dir)
	else:
		anim.play("idle_" + last_facing)

func start_moving(dir: Vector2):
	var target_grid_pos = grid_pos + Vector2i(dir)

	if main_script.is_tile_passable(target_grid_pos):
		AudioManager.play_sfx(sfx_teste)
		
		var player_snapshot = {
			"pos": grid_pos,
			"hp": Game_State.vida_jogador,
			"time": Game_State.tempo_jogador,
			"inventory": Game_State.inventario_jogador.items.duplicate(true)
		}
		Game_State.log_player_action(player_snapshot)
		
		grid_pos = target_grid_pos
		move_dir = dir
		moving = true
		target_pos = (Vector2(grid_pos) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
		
		last_facing = _get_facing_from_dir(dir)
		anim.play("walk_" + last_facing)
	else:
		anim.play("idle_" + last_facing)
		moving = false

func move_towards_target(delta):
	var step = SPEED * delta
	var dist = target_pos - global_position

	if dist.length() <= step:
		global_position = target_pos
		
		Game_State.log_player_position(grid_pos)
		
		var tile_data: MapTileData = main_script.get_tile_data(grid_pos)
		if tile_data:
			Game_State.tempo_jogador += tile_data.custo_tempo
			print("Tempo Acumulado: ", Game_State.tempo_jogador)
			if tile_data.dano_hp > 0:
				Game_State.vida_jogador -= tile_data.dano_hp
				print("DANO: %s! Vida: %s" % [tile_data.dano_hp, Game_State.vida_jogador])
			
		main_script.update_fog(grid_pos)
		
		var next_input = _get_input_direction()
		
		if next_input != Vector2.ZERO:
			start_moving(next_input)
		else:
			moving = false
			anim.play("idle_" + last_facing)
			
	else:
		global_position += move_dir * step

func reset_state_on_load():
	moving = false
	target_pos = global_position
	move_dir = Vector2.ZERO
	turn_timer = 0.0
	if is_node_ready() and anim:
		anim.play("idle_" + last_facing)

func _usar_drone_avancado(efeito: String, tipo: ItemData.ItemTipo):
	var item = Game_State.inventario_jogador.get_item_especifico(efeito, tipo)
	if item:
		print("Player: Usando item '%s'..." % item.nome_item)
		main_script.usar_item(item)
		if item.durabilidade > 0:
			item.durabilidade -= 1
			if item.durabilidade <= 0:
				Game_State.inventario_jogador.remover_item(item)
	else:
		print("Player: Item (Efeito: %s | Tipo: %s) não encontrado." % [efeito, tipo])
		
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_1:
		_usar_drone_avancado(ItemData.EFEITO_DRONE_PATH_ASTAR, ItemData.ItemTipo.DRONE_TEMPORARIO)
	if event is InputEventKey and event.pressed and event.keycode == KEY_2:
		_usar_drone_avancado(ItemData.EFEITO_DRONE_PATH_DIJKSTRA, ItemData.ItemTipo.DRONE)
	if event is InputEventKey and event.pressed and event.keycode == KEY_3:
		_usar_drone_avancado(ItemData.EFEITO_DRONE_PATH_ASTAR, ItemData.ItemTipo.DRONE)
	if event is InputEventKey and event.pressed and event.keycode == KEY_4:
		_usar_drone_avancado(ItemData.EFEITO_DRONE_SCANNER, ItemData.ItemTipo.DRONE)
	if event is InputEventKey and event.pressed and event.keycode == KEY_5:
		_usar_drone_avancado(ItemData.EFEITO_DRONE_TERRAFORMER, ItemData.ItemTipo.DRONE)
	# -------------------------------------------------------

	if event.is_action_pressed("usar_chave"):
		var minha_pos = grid_pos
		var direcao_olhar = Vector2i.ZERO
		match last_facing:
			"up": direcao_olhar = Vector2i.UP
			"down": direcao_olhar = Vector2i.DOWN
			"left": direcao_olhar = Vector2i.LEFT
			"right": direcao_olhar = Vector2i.RIGHT
		
		var tile_alvo = minha_pos + direcao_olhar
		print("Player: Tentando usar chave em ", tile_alvo)
		main_script.tentar_abrir_porta(tile_alvo)
