class_name NPC
extends CharacterBody2D

# --- CONFIGURAÇÃO ---
@export var dialogo_data: DialogueData
@export var max_hp: int = 20
@export var destruivel: bool = false # Se true, morre/some ao chegar a 0 HP

# --- ESTADO ---
var current_hp: int
var grid_pos: Vector2i = Vector2i.ZERO
var main_ref = null

func _ready():
	current_hp = max_hp
	
	# Adiciona a grupos importantes
	add_to_group("interagiveis")
	add_to_group("npcs")
	if destruivel:
		add_to_group("aliados") # Grupo para inimigos identificarem como alvo
	
	# Ajuste de Grid
	grid_pos = _world_to_grid(global_position)
	position = _grid_to_world(grid_pos)
	
	# Bloqueia o tile no grafo (para pathfinding enxergar como parede, DEFASADO)
	#_bloquear_tile_no_mapa()

# Função chamada pelo Player (Input Interagir)
func interagir():
	print("NPC: Olá!")
	if dialogo_data:
		DialogueManager.iniciar_dialogo(dialogo_data)
		
		# Opcional: Virar para o player
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var dir = player.global_position.x - global_position.x
			if $AnimatedSprite2D:
				$AnimatedSprite2D.flip_h = (dir < 0)

# Função para o NPC sofrer dano (caso inimigos ataquem)
func receber_dano(atk_atacante: int, _kb_power: int, _pos_atacante: Vector2i):
	if not destruivel: return
	
	# Cálculo simples (sem defesa por enquanto)
	current_hp -= atk_atacante
	print("NPC %s sofreu dano! HP: %d" % [name, current_hp])
	
	# Feedback visual (Flash Vermelho)
	var sprite = $AnimatedSprite2D
	if sprite:
		var t = create_tween()
		t.tween_property(sprite, "modulate", Color.RED, 0.1)
		t.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	if current_hp <= 0:
		_morrer()

func _morrer():
	print("NPC morreu!")
	# Liberar tile no mapa para andar de novo?
	if main_ref:
		var tile = main_ref.get_tile_data(grid_pos)
		if tile: 
			tile.passavel = true
			main_ref.grafo.atualizar_aresta_dinamica(grid_pos)
	
	queue_free()

#Função defasada
"""func _bloquear_tile_no_mapa():
	if get_parent().has_method("get_tile_data"):
		main_ref = get_parent()
		var tile = main_ref.get_tile_data(grid_pos)
		if tile:
			tile.passavel = false
			# Atualiza grafo se já estiver rodando
			if main_ref.grafo:
				main_ref.grafo.atualizar_aresta_dinamica(grid_pos)
"""
# Auxiliares de Grid
func _world_to_grid(pos: Vector2) -> Vector2i: return Vector2i(pos / 16.0)
func _grid_to_world(g_pos: Vector2i) -> Vector2: return (Vector2(g_pos) * 16.0) + Vector2(8, 8)
