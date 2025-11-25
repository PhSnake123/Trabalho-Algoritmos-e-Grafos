extends Control

# Precisamos carregar a cena do Slot para criar cópias
const SLOT_SCENE = preload("res://scenes/InventorySlot.tscn")

@onready var grid_container = $GridContainer

func _ready():
	# Conecta aos sinais do inventário global
	# Assim, se o player pegar algo, a tela atualiza sozinha
	Game_State.inventario_jogador.item_adicionado.connect(_on_inventory_updated)
	Game_State.inventario_jogador.item_removido.connect(_on_inventory_updated)
	
	# Renderiza a primeira vez
	_atualizar_grid()

func _atualizar_grid():
	# 1. Limpa tudo que existe (método bruto, mas seguro para MVP)
	for child in grid_container.get_children():
		child.queue_free()
	
	# 2. Cria um slot para cada item no inventário
	for item in Game_State.inventario_jogador.items:
		var novo_slot = SLOT_SCENE.instantiate()
		grid_container.add_child(novo_slot)
		
		# Configura o slot
		novo_slot.set_item(item)
		
		# Conecta o clique do slot à nossa função de equipar
		novo_slot.slot_clicked.connect(_on_slot_clicked)

# Esse parâmetro extra 'item' vem do sinal, mas não usamos aqui pois recriamos tudo
func _on_inventory_updated(_item):
	_atualizar_grid()

func _on_slot_clicked(item: ItemData):
	# AQUI ACONTECE A MÁGICA DO ZELDA
	# Avisamos o GameState que esse é o item ativo agora
	Game_State.equipar_item(item)
	
	# (Opcional) Tocar um som de "Select"
	# (Opcional) Fechar o inventário automaticamente se quiser
	# hide()
