# res://scripts/Chest.gd
extends StaticBody2D # Ou Area2D se não tiver colisão física

@export var sprite_fechado: Texture2D
@export var sprite_aberto: Texture2D
@onready var sprite = $Sprite2D

var grid_pos: Vector2i
var main_ref = null
var qtd_moedas: int = 20
var esta_aberto: bool = false

func _ready():
	add_to_group("interagiveis") # Importante para o Player detectar
	add_to_group("baus")
	if esta_aberto:
		sprite.texture = sprite_aberto
	else:
		sprite.texture = sprite_fechado

func configurar(pos: Vector2i, moedas: int, aberto: bool):
	grid_pos = pos
	qtd_moedas = moedas
	esta_aberto = aberto
	# Atualiza visual no _ready ou aqui se já estiver pronto

func interagir():
	if esta_aberto:
		print("Baú vazio.")
		return

	print("Abrindo baú...")
	esta_aberto = true
	if sprite_aberto:
		sprite.texture = sprite_aberto
	
	# Adiciona moedas
	Game_State.adicionar_moedas(qtd_moedas)
	
	# Feedback visual de texto subindo
	if main_ref:
		main_ref.spawn_floating_text(global_position + Vector2(0, -20), "+%d G" % qtd_moedas, Color.GOLD)
		# Importante: Atualizar o estado no Main para persistência
		main_ref.registrar_bau_aberto(grid_pos)

# Funções de Persistência completas
func get_save_data() -> Dictionary:
	return {
		"pos_x": grid_pos.x,
		"pos_y": grid_pos.y,
		"moedas": qtd_moedas,
		"aberto": esta_aberto
	}

func load_save_data(data: Dictionary):
	var x = data.get("pos_x")
	var y = data.get("pos_y")
	grid_pos = Vector2i(x, y)
	position = (Vector2(grid_pos) * 16.0) + Vector2(8, 8) # Recalcula posição visual
	
	qtd_moedas = int(data.get("moedas", 0))
	esta_aberto = bool(data.get("aberto", false))
	
	# Atualiza o sprite baseado no estado carregado
	if esta_aberto:
		$Sprite2D.texture = sprite_aberto
	else:
		$Sprite2D.texture = sprite_fechado
