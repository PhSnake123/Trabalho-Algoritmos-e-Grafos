class_name NPC
extends Node2D

# O arquivo de dados que criamos na etapa anterior (arraste o .tres aqui no Inspetor)
@export var dialogo_data: DialogueData

# Referências
var main_ref = null
var grid_pos: Vector2i = Vector2i.ZERO

func _ready():
	# Adiciona a este grupo para que a Main consiga encontrá-lo sem saber quem ele é
	add_to_group("interagiveis")
	
	# Ajusta posição no grid (igual aos inimigos)
	await get_tree().process_frame
	grid_pos = Vector2i(global_position / 16.0)
	
	# Centraliza visualmente no tile
	global_position = (Vector2(grid_pos) * 16.0) + Vector2(8, 8)
	
	# Opcional: Se o NPC for "sólido", avisa a Main que este tile é uma parede
	# (Isso evita que o player ande "em cima" do NPC)
	_bloquear_tile_no_mapa()

func _bloquear_tile_no_mapa():
	if get_parent().has_method("get_tile_data"):
		main_ref = get_parent()
		var tile = main_ref.get_tile_data(grid_pos)
		if tile:
			# Tornamos o tile intransponível para o pathfinding
			tile.passavel = false
			# (Opcional) Se tiver Dijkstra rodando, teria que atualizar o grafo aqui
			if main_ref.grafo:
				main_ref.grafo.atualizar_aresta_dinamica(grid_pos)

# Esta é a função mágica que a Main vai chamar genericamente
func interagir():
	if dialogo_data:
		print("NPC: Iniciando conversa...")
		# Chama nosso Singleton
		DialogueManager.iniciar_dialogo(dialogo_data)
		
		# Aqui você pode adicionar lógica extra de forma modular.
		# Ex: Virar o sprite para olhar para o player
	else:
		print("NPC: Estou sem 'DialogueData' configurado!")
