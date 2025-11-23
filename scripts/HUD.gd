extends CanvasLayer

# Referências aos nós da UI (ajuste os caminhos se tiver mudado nomes)
@onready var label_hp = $Control/BarraSuperior/HBoxContainer/LabelHP
@onready var label_timer = $Control/BarraSuperior/HBoxContainer/LabelTimer
@onready var label_terminais = $Control/BarraSuperior/HBoxContainer/LabelTerminais
@onready var icone_ativo = $Control/ItemEquipado/IconeAtivo
@onready var inventory_container = $Control/ContainerInventario
@export var limite_aceitavel_multiplier: float = 2.0
var total_HP = Game_State.vida_jogador

func _ready():
	# Conecta ao sinal do GameState para saber quando o item muda
	# (Verifique se você adicionou o sinal 'item_equipado_alterado' no GameState na etapa anterior)
	if Game_State.has_signal("item_equipado_alterado"):
		Game_State.item_equipado_alterado.connect(_on_item_equipado_mudou)
	
	# Atualiza a primeira vez (caso comece com item)
	_on_item_equipado_mudou(Game_State.item_equipado)
	
	# Garante que o inventário comece fechado
	inventory_container.hide()

func _process(_delta):
	# 1. Atualiza HP
	label_hp.text = "HP: %d" % Game_State.vida_jogador
	if Game_State.vida_jogador > (total_HP/2):
		label_hp.modulate = Color.GREEN
	elif (Game_State.vida_jogador <= (total_HP/2)) and (Game_State.vida_jogador > total_HP*0.25):
		label_hp.modulate = Color.YELLOW
	elif Game_State.vida_jogador <=total_HP*0.25:
		label_hp.modulate = Color.RED
	
	label_terminais.text = "Terminais: %d/%d" % [Game_State.terminais_ativos, Game_State.terminais_necessarios]

	# 3. ATUALIZA O TEMPO (PASSOS / PAR) COM CORES
	var atual = int(Game_State.tempo_jogador)
	var par = int(Game_State.tempo_par_level)
	
	label_timer.text = "%d / %d" % [atual, par]
	
	if atual <= par:
		# Azul Claro (Dentro da meta perfeita)
		label_timer.modulate = Color(0.2, 0.6, 1.0)
	elif atual <= (par * limite_aceitavel_multiplier):
		# Amarelo (Acima do PAR, mas aceitável)
		label_timer.modulate = Color.ANTIQUE_WHITE
	else:
		# Vermelho (Estourou o limite)
		label_timer.modulate = Color.FIREBRICK

func _input(event):
	# Toggle do Inventário (Tecla TAB ou I)
	if event.is_action_pressed("inventory_toggle") or (event is InputEventKey and event.pressed and event.keycode == KEY_TAB):
		if inventory_container.visible:
			inventory_container.hide()
			# Opcional: Despausar o jogo
			# get_tree().paused = false
		else:
			inventory_container.show()
			# Opcional: Pausar o jogo enquanto escolhe item
			# get_tree().paused = true

func _on_item_equipado_mudou(item: ItemData):
	if not item:
		icone_ativo.texture = null
		icone_ativo.modulate = Color.TRANSPARENT
		return
	
	# Se tiver ícone real, usa ele
	if item.textura_icon:
		icone_ativo.texture = item.textura_icon
		icone_ativo.modulate = Color.WHITE
	else:
		# FALLBACK: Gera o quadrado colorido igual ao InventorySlot
		var placeholder = GradientTexture2D.new()
		placeholder.width = 64
		placeholder.height = 64
		icone_ativo.texture = placeholder
		
		# Define cor baseada no tipo (copiando a logica do slot)
		match item.tipo_item:
			ItemData.ItemTipo.CHAVE: icone_ativo.modulate = Color.GOLD
			ItemData.ItemTipo.DRONE: icone_ativo.modulate = Color.CYAN
			ItemData.ItemTipo.POTION: icone_ativo.modulate = Color.RED
			_: icone_ativo.modulate = Color.GRAY

# Adicione no final do script HUD.gd

func forcar_atualizacao_total():
	# 1. Atualiza o Slot do Item Equipado (garante que mostre o item real ou vazio)
	_on_item_equipado_mudou(Game_State.item_equipado)
	
	# 2. Força o Inventário a se reconstruir com a lista nova
	# Acessamos o nó InventoryUI e chamamos o método de atualizar grid
	var inventory_ui = $Control/ContainerInventario/InventoryUI
	if inventory_ui:
		inventory_ui._atualizar_grid()
		
	print("HUD: Visual atualizado após Load.")
