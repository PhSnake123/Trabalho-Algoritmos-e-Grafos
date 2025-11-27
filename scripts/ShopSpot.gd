# res://scripts/ShopSpot.gd
class_name ShopSpot
extends Node2D

# Configuração no Editor
@export var item_a_venda: ItemData # Arraste o Resource do item aqui (ex: Potion.tres)
@export var preco_override: int = -1 # Se quiser mudar o preço só nesta loja (-1 usa o preço base)
@export var infinito: bool = false # Se true, o item não some ao comprar (estoque infinito)

# Estado Interno
var preco_final: int = 0
var grid_pos: Vector2i = Vector2i.ZERO # Para o Player saber onde estamos
var main_ref = null # Referência ao Main (para salvar estado, se necessário)

# Referências Visuais (Você vai criar a cena no próximo passo)
@onready var sprite = $Sprite2D
@onready var label_preco = $LabelPreco

func _ready():
	add_to_group("shop_items") # Grupo importante para o Player nos encontrar
	
	# Ajusta posição no grid (igual fazemos com Inimigos/NPCs)
	await get_tree().process_frame
	grid_pos = Vector2i(global_position / 16.0)
	
	atualizar_visual()

func atualizar_visual():
	if not item_a_venda:
		hide()
		return
	
	# 1. Define o Preço
	if preco_override > -1:
		preco_final = preco_override
	else:
		preco_final = item_a_venda.preco_base
		
	# 2. Atualiza Sprite e Texto
	if item_a_venda.textura_icon:
		sprite.texture = item_a_venda.textura_icon
	
	label_preco.text = "$%d" % preco_final
	
	# Cor condicional: Se o jogador não tem dinheiro, fica vermelho (Opcional, faremos depois)
	label_preco.modulate = Color.GOLD

# Chamado pelo Player quando aperta "Interagir" neste tile
func interagir():
	if not item_a_venda: return
	
	print("Shop: Tentando comprar %s por %d moedas." % [item_a_venda.nome_item, preco_final])
	
	# 1. Verifica Saldo (Usando a função que vimos no GameState.gd)
	if Game_State.moedas >= preco_final:
		
		# 2. Tenta Gastar
		var sucesso = Game_State.gastar_moedas(preco_final)
		
		if sucesso:
			# 3. Entrega o Item
			# Importante: duplicate() para não alterar o recurso original se tiver durabilidade
			Game_State.inventario_jogador.adicionar_item(item_a_venda.duplicate())
			
			print("Shop: Compra realizada!")
			
			# Feedback Visual (Som pode vir aqui depois)
			if main_ref and main_ref.has_method("spawn_floating_text"):
				main_ref.spawn_floating_text(global_position + Vector2(0, -20), "COMPROU!", Color.GREEN)
			
			# 4. Remove da loja (se não for infinito)
			if not infinito:
				queue_free()
	else:
		print("Shop: Dinheiro insuficiente.")
		if main_ref and main_ref.has_method("spawn_floating_text"):
			main_ref.spawn_floating_text(global_position + Vector2(0, -20), "SEM GRANA", Color.RED)

# Para o sistema de Save/Load do Main (Faremos a integração depois)
func get_save_data():
	return {
		"filename": get_scene_file_path(),
		"pos_x": grid_pos.x,
		"pos_y": grid_pos.y,
		"item_path": item_a_venda.resource_path,
		"infinito": infinito
	}
