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
	
	# 1. Cria os dados do diálogo dinamicamente
	var dialogo_compra = DialogueData.new()
	dialogo_compra.nome_npc = "Loja"
	
	var texto_desc = item_a_venda.descricao
	if texto_desc == "":
		texto_desc = "Item sem descrição."
		
	var texto_final = "%s\nPreço: %d Fragmentos." % [texto_desc, preco_final]
	
	# Configura o texto
	dialogo_compra.falas.clear()
	dialogo_compra.falas.append(texto_final)
	
	# --- CORREÇÃO: ADICIONAR AS OPÇÕES ---
	# Sem isso, o DialogueManager acha que é apenas um texto informativo e fecha.
	dialogo_compra.opcoes.clear()
	dialogo_compra.opcoes.append("Comprar")  # Índice 0
	dialogo_compra.opcoes.append("Cancelar") # Índice 1
	# -------------------------------------
	
	# 2. Inicia o Diálogo
	DialogueManager.iniciar_dialogo(dialogo_compra)
	
	# Aguarda a resposta (sinal escolha_feita do DialogueManager)
	var opcao = await DialogueManager.escolha_feita
	
	if opcao == 0: # COMPRAR (Primeira opção adicionada)
		_executar_compra()
	else: # CANCELAR (Segunda opção adicionada)
		print("Shop: Compra cancelada pelo jogador.")

func _executar_compra():
	print("Shop: Tentando comprar %s por %d moedas." % [item_a_venda.nome_item, preco_final])
	
	if Game_State.moedas >= preco_final:
		var sucesso = Game_State.gastar_moedas(preco_final)
		if sucesso:
			var item_novo = item_a_venda.duplicate()
			
			if item_a_venda.resource_path != "":
				item_novo.arquivo_origem = item_a_venda.resource_path
			elif item_a_venda.arquivo_origem != "":
				item_novo.arquivo_origem = item_a_venda.arquivo_origem
			
			Game_State.inventario_jogador.adicionar_item(item_novo)
			
			print("Shop: Compra realizada!")
			
			if main_ref and main_ref.has_method("spawn_floating_text"):
				main_ref.spawn_floating_text(global_position + Vector2(0, -20), "COMPROU!", Color.GREEN)
			
			if not infinito:
				queue_free()
	else:
		print("Shop: Dinheiro insuficiente.")
		if main_ref and main_ref.has_method("spawn_floating_text"):
			main_ref.spawn_floating_text(global_position + Vector2(0, -20), "SEM GRANA", Color.RED)

# Para o sistema de Save/Load do Main
func get_save_data():
	return {
		"filename": get_scene_file_path(),
		"pos_x": grid_pos.x,
		"pos_y": grid_pos.y,
		"item_path": item_a_venda.resource_path,
		"infinito": infinito
	}
