extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

const TILE_SIZE := 16   # Tamanho de 1 tile
const SPEED := 80.0    # Velocidade (pixels por segundo)

var grid_pos := Vector2i(1, 1)

var moving := false
var move_dir := Vector2.ZERO
var last_facing := "down"
var target_pos := Vector2.ZERO # Alvo em pixels

@onready var main_script = get_parent()

func _ready():
	global_position = (Vector2(grid_pos) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
	target_pos = global_position # Define o alvo inicial
	main_script.call_deferred("update_fog", grid_pos)


func _physics_process(delta):
	# Se não estamos nos movendo, cheque por input
	if not moving:
		handle_input()
	# Senão (se estamos nos movendo), continue o movimento
	else:
		move_towards_target(delta)


func handle_input():
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		input_dir = Vector2.RIGHT
		last_facing = "right"
	elif Input.is_action_pressed("ui_left"):
		input_dir = Vector2.LEFT
		last_facing = "left"
	elif Input.is_action_pressed("ui_down"):
		input_dir = Vector2.DOWN
		last_facing = "down"
	elif Input.is_action_pressed("ui_up"):
		input_dir = Vector2.UP
		last_facing = "up"

	if input_dir != Vector2.ZERO:
		start_moving(input_dir)
	else:
		anim.play("idle_" + last_facing)


func start_moving(dir: Vector2):
	var target_grid_pos = grid_pos + Vector2i(dir)

	if main_script.is_tile_passable(target_grid_pos):
		grid_pos = target_grid_pos
		move_dir = dir
		moving = true
		target_pos = (Vector2(grid_pos) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
		anim.play("walk_" + last_facing)
	else:
		anim.play("idle_" + last_facing)


func move_towards_target(delta):
	var step = SPEED * delta
	var dist = target_pos - global_position

	if dist.length() <= step:
		# O jogador chegou ao destino
		global_position = target_pos
		moving = false
		anim.play("idle_" + last_facing)
		
		# --- Atualiza a névoa ---
		# Avisa o Main que chegamos em um novo tile
		main_script.update_fog(grid_pos)
	else:
		global_position += move_dir * step
