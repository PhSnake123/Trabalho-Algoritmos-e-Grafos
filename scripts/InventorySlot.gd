extends PanelContainer
class_name InventorySlot

signal slot_clicked(item_data: ItemData)

@onready var icon_rect: TextureRect = $MarginContainer/Icon
@onready var qtd_label: Label = $MarginContainer/Quantity

var my_item: ItemData = null

func _ready():
	# Configura o cursor para virar "mãozinha" quando passar em cima
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clear_slot()

func set_item(item: ItemData):
	my_item = item
	
	# 1. Configura Ícone
	if item.textura_icon:
		icon_rect.texture = item.textura_icon
		icon_rect.modulate = Color.WHITE
	else:
		# Fallback (Quadrado colorido) se não tiver imagem
		icon_rect.texture = null
		var placeholder = GradientTexture2D.new()
		placeholder.width = 32
		placeholder.height = 32
		icon_rect.texture = placeholder
		
		match item.tipo_item:
			ItemData.ItemTipo.CHAVE: icon_rect.modulate = Color.GOLD
			ItemData.ItemTipo.DRONE: icon_rect.modulate = Color.CYAN
			ItemData.ItemTipo.POTION: icon_rect.modulate = Color.RED
			_: icon_rect.modulate = Color.GRAY
	
	# 2. Configura Quantidade
	if item.durabilidade > 1:
		qtd_label.text = str(item.durabilidade)
		qtd_label.show()
	else:
		qtd_label.hide()
	
	# Tooltip
	tooltip_text = "%s\n%s" % [item.nome_item, item.descricao]

func clear_slot():
	my_item = null
	icon_rect.texture = null
	icon_rect.modulate = Color.TRANSPARENT
	qtd_label.hide()
	tooltip_text = ""

# AQUI ESTÁ A CORREÇÃO DO ERRO:
# Detectamos o clique diretamente no Painel
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if my_item:
			accept_event() # Diz para o Godot que consumimos o clique
			slot_clicked.emit(my_item)
