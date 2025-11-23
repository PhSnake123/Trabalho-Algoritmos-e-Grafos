extends CanvasLayer

@onready var sprite = $CursorSprite
#Controle de tamanho pelo Inspetor (padrão 1.0 = 100%)
# Se quiser metade do tamanho, coloque x:0.5, y:0.5 no Inspetor
@export var base_scale: Vector2 = Vector2(2.0, 2.0)

func _ready():
	# Esconde o cursor padrão do sistema operacional
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	# Garante que o sprite comece tocando
	sprite.play("default")

func _process(_delta):
	# O sprite segue a posição real do mouse na tela
	sprite.global_position = sprite.get_viewport().get_mouse_position()
	
	# --- Lógica de Animação de Clique (Opcional) ---
	if Input.is_action_just_pressed("ui_click") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if sprite.sprite_frames.has_animation("click"):
			sprite.play("click")
		else:
			# Efeito visual simples de "esmagar" se não tiver animação de click
			sprite.scale = base_scale * 0.8
			
	elif Input.is_action_just_released("ui_click") or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if sprite.sprite_frames.has_animation("default"):
			sprite.play("default")
		sprite.scale = base_scale

# Garante que o cursor apareça de volta se o nó for deletado
func _exit_tree():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
