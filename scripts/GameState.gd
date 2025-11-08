extends Node
class_name GameState

# --- Responsabilidade (Estado da Run) - Fase 1.3 ---
var tempo_jogador: float = 0.0
var tempo_par_level: float = 0.0  # Será definido pelo main.gd ao carregar o nível
var vida_jogador: int = 100       # Valor inicial padrão

# O inventário será um Resource
# Por enquanto, apenas declaramos a variável.
var inventario_jogador: Resource # = preload("res://inventory.tres") (quando existir)

# Arrays para rastrear o movimento e o caminho ideal
var caminho_jogador: Array[Vector2i] = []
var caminho_ideal_level: Array[Vector2i] = [] # O Dijkstra original


#(Finais Múltiplos)
var optional_objectives: Dictionary = {} # Ex: {"salvou_npc": true, "usou_atalho": false}


#(Stalker e MST)
var heat_map: Array = [] # Será um grid 2D de floats, inicializado pelo Main.gd
var terminais_ativos: int = 0
var terminais_necessarios: int = 0


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
	caminho_ideal_level.clear()
	optional_objectives.clear()
	
	heat_map.clear() # O Main.gd precisará (re)inicializar isso com o tamanho do mapa
	terminais_ativos = 0
	terminais_necessarios = 0
	
	# Lógica do inventário (Quando Inventory.gd da Fase 1.2 existir)
	# if inventario_jogador:
	#    inventario_jogador.clear_items() 
	
	print("GameState: Estado da run resetado.")


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


# --- Novas Funções (Stalker e IA) - Fase 1.3 ---

"""
(Placeholder) Atualiza o "calor" em uma posição específica.
Será chamada pelo Player a cada movimento.
"""
func update_heat_map(pos: Vector2i, amount: float):
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
