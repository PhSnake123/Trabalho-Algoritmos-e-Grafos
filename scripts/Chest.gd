# res://scripts/Chest.gd
extends StaticBody2D

@export var sprite_fechado: Texture2D
@export var sprite_aberto: Texture2D
@onready var sprite = $Sprite2D

var grid_pos: Vector2i
var main_ref = null
var esta_aberto: bool = false

# Dados do Conteúdo
var qtd_moedas: int = 0
var item_recompensa: ItemData = null

func _ready():
	add_to_group("interagiveis") 
	add_to_group("baus")
	_atualizar_visual()

# Nova função de configuração que aceita Item OU Moedas
func configurar(pos: Vector2i, moedas: int, item: ItemData, aberto: bool):
	grid_pos = pos
	qtd_moedas = moedas
	# DUPLICATA É CRUCIAL: Itens são Resources compartilhados. 
	# Se não duplicar, um baú pode alterar o outro.
	if item:
		item_recompensa = item.duplicate()
		# Garante persistência do caminho
		if item.resource_path != "":
			item_recompensa.arquivo_origem = item.resource_path
	else:
		item_recompensa = null
		
	esta_aberto = aberto
	_atualizar_visual()

func _atualizar_visual():
	if sprite:
		sprite.texture = sprite_aberto if esta_aberto else sprite_fechado

func interagir():
	if esta_aberto: return

	print("Abrindo baú em %s..." % grid_pos)
	esta_aberto = true
	_atualizar_visual()
	
	# LÓGICA DE ENTREGA
	if item_recompensa:
		# Entrega Item
		Game_State.inventario_jogador.adicionar_item(item_recompensa)
		if main_ref:
			main_ref.spawn_floating_text(global_position + Vector2(0, -20), "%s!" % item_recompensa.nome_item, Color.CYAN)
	else:
		# Entrega Moedas
		Game_State.adicionar_moedas(qtd_moedas)
		if main_ref:
			main_ref.spawn_floating_text(global_position + Vector2(0, -20), "+%d G" % qtd_moedas, Color.GOLD)
	
	# Persistência
	if main_ref:
		main_ref.registrar_bau_aberto(grid_pos)

# --- SAVE SYSTEM ---
func get_save_data() -> Dictionary:
	var dados = {
		"pos_x": grid_pos.x,
		"pos_y": grid_pos.y,
		"aberto": esta_aberto,
		"moedas": qtd_moedas,
		"tem_item": false,
		"item_path": ""
	}
	
	# Se tiver item, salvamos o caminho dele
	if item_recompensa:
		dados["tem_item"] = true
		# Prioriza o arquivo_origem que salvamos manualmente, senão tenta o resource_path
		if item_recompensa.arquivo_origem != "":
			dados["item_path"] = item_recompensa.arquivo_origem
		else:
			dados["item_path"] = item_recompensa.resource_path
			
	return dados

func load_save_data(data: Dictionary):
	var x = data.get("pos_x")
	var y = data.get("pos_y")
	grid_pos = Vector2i(x, y)
	position = (Vector2(grid_pos) * 16.0) + Vector2(8, 8)
	
	esta_aberto = bool(data.get("aberto", false))
	qtd_moedas = int(data.get("moedas", 0))
	
	# Restaura o Item
	if data.get("tem_item", false):
		var path = data.get("item_path", "")
		if path != "" and ResourceLoader.exists(path):
			var res = load(path)
			if res:
				item_recompensa = res.duplicate()
				item_recompensa.arquivo_origem = path
	else:
		item_recompensa = null
		
	_atualizar_visual()
