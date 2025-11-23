# res://scripts/GameState.gd
extends Node
class_name GameState

# --- Responsabilidade (Estado da Run) - Fase 1.3 ---
var carregar_save_ao_iniciar: bool = false #NOVO
var tempo_jogador: float = 0.0
var tempo_par_level: float = 0.0 
var vida_jogador: int = 100       
const SAVE_TERMINAL_ITEM = preload("res://assets/iteminfo/save_terminal.tres") 

var inventario_jogador: Inventory
var item_equipado: ItemData = null #NOVO Variável para item equipado
signal item_equipado_alterado(novo_item: ItemData)#NOVO VAR PARA ALTERAR ITEM EQUIPADO

var caminho_jogador: Array[Vector2i] = []
var caminho_ideal_level: Array[Vector2i] = [] 
var player_action_history: Array[Dictionary] = [] 
var MAX_ACTION_HISTORY = 20 
var is_dialogue_active: bool = false

#(Finais Múltiplos)
var optional_objectives: Dictionary = {} 

#(Stalker e MST)
var heat_map: Array = [] 
var terminais_ativos: int = 0
var terminais_necessarios: int = 0

#Estado de entidades para save/load
var enemy_states: Dictionary = {}
var npc_states: Dictionary = {}
var interactable_states: Dictionary = {}

func _ready():
	reset_run_state()

func reset_run_state():
	tempo_jogador = 0.0
	tempo_par_level = 0.0 
	vida_jogador = 100
	
	caminho_jogador.clear()
	player_action_history.clear()
	caminho_ideal_level.clear()
	optional_objectives.clear()
	
	heat_map.clear() 
	terminais_ativos = 0
	terminais_necessarios = 0
	enemy_states.clear()
	npc_states.clear()
	interactable_states.clear()
	
	if inventario_jogador:
		inventario_jogador.clear_items()
	else:
		inventario_jogador = Inventory.new() 
	
	inventario_jogador.adicionar_item(SAVE_TERMINAL_ITEM)
	
	var chave_teste = load("res://assets/iteminfo/chave.tres") 
	if chave_teste:
		inventario_jogador.adicionar_item(chave_teste)
		
	var drone_teste = load("res://assets/iteminfo/DroneAStar.tres")
	if drone_teste: inventario_jogador.adicionar_item(drone_teste)
	
	var drone_dijkstra = load("res://assets/iteminfo/DroneDJKISTRA.tres")
	if drone_dijkstra: inventario_jogador.adicionar_item(drone_dijkstra.duplicate())

	var drone_astar_perm = load("res://assets/iteminfo/DroneAStarPerm.tres")
	if drone_astar_perm: inventario_jogador.adicionar_item(drone_astar_perm.duplicate())
	
	# <--- [NOVO] IMPLEMENTAÇÃO DRONE SCANNER: Item de Teste
	# Certifique-se de criar este arquivo .tres conforme as instruções anteriores
	var drone_scanner = load("res://assets/iteminfo/DRONE_SCANNER.tres")
	if drone_scanner: inventario_jogador.adicionar_item(drone_scanner.duplicate())
	
	var drone_limpeza = load("res://assets/iteminfo/DroneTerraformer.tres")
	if drone_limpeza: inventario_jogador.adicionar_item(drone_limpeza.duplicate())	
	
	# ------------------------------------------------------

	print("GameState: Estado da run resetado.")

func log_player_position(pos: Vector2i):
	if caminho_jogador.is_empty() or caminho_jogador.back() != pos:
		caminho_jogador.push_back(pos)

func log_player_action(player_snapshot: Dictionary):
	player_action_history.push_back(player_snapshot)
	if player_action_history.size() > MAX_ACTION_HISTORY:
		player_action_history.pop_front() 

func set_objective_flag(flag_nome: String, valor: bool):
	optional_objectives[flag_nome] = valor
	print("GameState: Flag de objetivo '", flag_nome, "' definida como '", valor, "'")

func adicionar_tempo_penalidade(segundos: float):
	if segundos <= 0:
		return
	tempo_jogador += segundos
	print("GameState: Penalidade de ", segundos, "s aplicada. Tempo total: ", tempo_jogador)

#Função para equipar item
func equipar_item(item: ItemData):
	item_equipado = item
	emit_signal("item_equipado_alterado", item)
	
	if item:
		print("GameState: Item equipado -> ", item.nome_item)
	else:
		print("GameState: Item desequipado (Mãos vazias).")

func update_heat_map(_pos: Vector2i, _amount: float):
	pass

func dissipate_heat():
	pass
