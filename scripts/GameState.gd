extends Node
class_name GameState

# --- Responsabilidade (Estado da Run) - Fase 1.3 ---
var tempo_jogador: float = 0.0
var tempo_par_level: float = 0.0  # Será definido pelo main.gd ao carregar o nível
var vida_jogador: int = 100       # Valor inicial padrão
const SAVE_TERMINAL_ITEM = preload("res://assets/iteminfo/save_terminal.tres") # Para carregar item de save

# O inventário será um Resource
# Por enquanto, apenas declaramos a variável.
var inventario_jogador: Inventory

# Arrays para rastrear o movimento e o caminho ideal
var caminho_jogador: Array[Vector2i] = []
var caminho_ideal_level: Array[Vector2i] = [] # O Dijkstra original
var player_action_history: Array[Dictionary] = [] #Armazena ações do jogador
var MAX_ACTION_HISTORY = 20 #Parametro de desfazer ações do jogador

#(Finais Múltiplos)
var optional_objectives: Dictionary = {} # Ex: {"salvou_npc": true, "usou_atalho": false}


#(Stalker e MST)
var heat_map: Array = [] # Será um grid 2D de floats, inicializado pelo Main.gd
var terminais_ativos: int = 0
var terminais_necessarios: int = 0

#Estado de entidades para save/load
var enemy_states: Dictionary = {}
var npc_states: Dictionary = {}
var interactable_states: Dictionary = {}

# Chamado quando o nó (e o jogo) inicia
func _ready():
	# Garante que tudo comece "zerado"
	reset_run_state()


# --- Funções Essenciais - Fase 1.3 ---

"""
Reseta todas as variáveis para o início de uma nova "run".
Isso será chamado pelo _ready() e pelo main.gd ao carregar um novo nível.
"""
func reset_run_state():
	tempo_jogador = 0.0
	tempo_par_level = 0.0 # O Main.gd definirá o valor certo
	vida_jogador = 100
	
	caminho_jogador.clear()
	player_action_history.clear()
	caminho_ideal_level.clear()
	optional_objectives.clear()
	
	heat_map.clear() # O Main.gd precisará (re)inicializar isso com o tamanho do mapa
	terminais_ativos = 0
	terminais_necessarios = 0
	enemy_states.clear()
	npc_states.clear()
	interactable_states.clear()
	
	# Lógica do inventário
	if inventario_jogador:
		inventario_jogador.clear_items()
	else:
		# Cria a nova instância do inventário
		inventario_jogador = Inventory.new() 
	
	# Adiciona o item de save ao inventário
	inventario_jogador.adicionar_item(SAVE_TERMINAL_ITEM)
	#(Teste) Adiciona drone de astar temporário.
	var drone_teste = load("res://assets/iteminfo/DroneAStar.tres")
	inventario_jogador.adicionar_item(drone_teste)
	#(teste) Adiciona Drone permanente
	var drone_dijkstra = load("res://assets/iteminfo/DroneDJKISTRA.tres")
	inventario_jogador.adicionar_item(drone_dijkstra.duplicate())
	# Drone A* Permanente (Teste Tecla 3)
	var drone_astar_perm = load("res://assets/iteminfo/DroneAStarPerm.tres")
	inventario_jogador.adicionar_item(drone_astar_perm.duplicate())

	print("GameState: Estado da run resetado.")

"""
Loga a posição simples para o mapa final.
Chamado por player.gd após chegar ao tile.
"""
func log_player_position(pos: Vector2i):
	if caminho_jogador.is_empty() or caminho_jogador.back() != pos:
		caminho_jogador.push_back(pos)

"""
Loga o snapshot robusto para o item de Rewind (Player-Only).
Chamado por player.gd antes de sair do tile.
"""
func log_player_action(player_snapshot: Dictionary):
	player_action_history.push_back(player_snapshot)
	# Garante que o histórico não cresça indefinidamente
	if player_action_history.size() > MAX_ACTION_HISTORY:
		player_action_history.pop_front() # Remove o snapshot mais antigo

"""
Define um "flag" para finais múltiplos.
Ex: GameState.set_objective_flag("encontrou_npc_secreto", true)
"""
func set_objective_flag(flag_nome: String, valor: bool):
	optional_objectives[flag_nome] = valor
	print("GameState: Flag de objetivo '", flag_nome, "' definida como '", valor, "'")


"""
Adiciona uma penalidade de tempo (ex: ao ser pego por inimigo).
"""
func adicionar_tempo_penalidade(segundos: float):
	if segundos <= 0:
		return
		
	tempo_jogador += segundos
	print("GameState: Penalidade de ", segundos, "s aplicada. Tempo total: ", tempo_jogador)


# --- Stalker e IA---

"""
(Placeholder) Atualiza o "calor" em uma posição específica.
Será chamada pelo Player a cada movimento.
"""
func update_heat_map(_pos: Vector2i, _amount: float):
	# A lógica real precisará que o heat_map seja um array 2D
	# e que os limites sejam checados.
	# Implementação virá junto com o NerfedStalker (Fase 4).
	
	# Lógica futura (exemplo):
	# if not heat_map.is_empty() and 0 <= pos.y and pos.y < heat_map.size():
	#    if 0 <= pos.x and pos.x < heat_map[pos.y].size():
	#        heat_map[pos.y][pos.x] += amount
	pass


"""
(Placeholder) Dissipa o "calor" do mapa ao longo do tempo.
Será chamada por um Timer global.
"""
func dissipate_heat():
	# Lógica para diminuir lentamente todos os valores no heat_map
	# Implementação virá junto com o NerfedStalker.
	pass
