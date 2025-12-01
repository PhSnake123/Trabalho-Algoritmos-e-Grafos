# res://scripts/GameState.gd
extends Node
class_name GameState

# --- Responsabilidade (Estado da Run) - Fase 1.3 ---
var carregar_save_ao_iniciar: bool = false # Load Manual (Player)
var carregar_auto_save_ao_iniciar: bool = false # Load Auto (Checkpoint)
var musica_atual_path: String = ""
var tempo_jogador: float = 0.0
var tempo_par_level: float = 0.0 
var vida_jogador: int
var max_vida_jogador: int
const SAVE_TERMINAL_ITEM = preload("res://assets/iteminfo/save_terminal.tres") 

var inventario_jogador: Inventory
var item_equipado: ItemData = null #NOVO Variável para item equipado
signal item_equipado_alterado(novo_item: ItemData)#NOVO VAR PARA ALTERAR ITEM EQUIPADO

#(Stalker e MST)
var heat_map: Array = [] 
var terminais_ativos: int = 0
var terminais_necessarios: int = 0

# Sistema de Economia
var moedas: int = 0
signal moedas_alteradas(novo_saldo: int)

var caminho_jogador: Array[Vector2i] = []
var caminho_ideal_level: Array[Vector2i] = [] 
var player_action_history: Array[Dictionary] = [] 
var MAX_ACTION_HISTORY = 20 
var is_dialogue_active: bool = false

# --- VARIÁVEIS DE CONTROLE DO HUB ---
var is_in_hub: bool = false # Se true, bloqueia uso de itens e save manual
var hub_desbloqueado: bool = false # Se true, o jogador sempre vai pro Hub entre fases
var total_npc_interactions: int = 0 # Contador para desbloquear o Hub

# Variáveis para a tela de vitória
var moedas_ganhas_na_fase: int = 0
var status_vitoria: String = "" # "PERFEITO", "BOM"
var falha_por_tempo: bool = false

#(Finais Múltiplos)
var optional_objectives: Dictionary = {} 
var bad_ending_count: int = 0

#Estado de entidades para save/load
var enemy_states: Dictionary = {}
var npc_states: Dictionary = {}
var interactable_states: Dictionary = {}


func _ready():
	reset_run_state()

func reset_run_state():
	tempo_jogador = 0.0
	tempo_par_level = 0.0 
	max_vida_jogador = 50
	vida_jogador = max_vida_jogador
	moedas = 0

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
	is_in_hub = false
	total_npc_interactions = 0
	
	if inventario_jogador:
		inventario_jogador.clear_items()
	else:
		inventario_jogador = Inventory.new() 

	# Define uma função auxiliar temporária para carregar e configurar o item
	var add_safe = func(path: String):
		if ResourceLoader.exists(path):
			var res = load(path)
			if res:
				var item = res.duplicate()
				# AQUI ESTÁ O FIX: Salvamos o caminho manualmente na variável nova
				item.arquivo_origem = path 
				inventario_jogador.adicionar_item(item)
			else:
				print("ERRO: Falha ao carregar recurso em ", path)
		else:
			print("ERRO: Arquivo não existe: ", path)
	
	# === [DEBUG] INJEÇÃO DE ITENS DE TESTE ===
		# Adiciona Poção e Botas automaticamente para teste
	var itens_teste = [
		"res://assets/iteminfo/potion.tres",
		"res://assets/iteminfo/boots.tres"
	]
		
	for path in itens_teste:
		if ResourceLoader.exists(path):
			var res = load(path)
			var item = res.duplicate()
			item.arquivo_origem = path # Garante que o ícone funcione no load
			Game_State.inventario_jogador.adicionar_item(item)
			print("DEBUG: Item de teste adicionado: ", item.nome_item)
	# =========================================
	
	add_safe.call("res://assets/iteminfo/save_terminal.tres")
	add_safe.call("res://assets/iteminfo/chave.tres")
	add_safe.call("res://assets/iteminfo/DroneAStar.tres")
	add_safe.call("res://assets/iteminfo/DroneDJKISTRA.tres")
	add_safe.call("res://assets/iteminfo/DroneAStarPerm.tres")
	add_safe.call("res://assets/iteminfo/DRONE_SCANNER.tres")
	add_safe.call("res://assets/iteminfo/DroneTerraformer.tres")
	
	carregar_save_ao_iniciar = false
	carregar_auto_save_ao_iniciar = false
	print("GameState: Estado da run resetado.")
	
# [NOVO] Helper Functions para Economia
func adicionar_moedas(qtd: int):
	moedas += qtd
	emit_signal("moedas_alteradas", moedas)
	print("GameState: +%d Moedas. Saldo: %d" % [qtd, moedas])

func gastar_moedas(qtd: int) -> bool:
	if moedas >= qtd:
		moedas -= qtd
		emit_signal("moedas_alteradas", moedas)
		print("GameState: -%d Moedas. Saldo: %d" % [qtd, moedas])
		return true
	else:
		print("GameState: Saldo insuficiente.")
		return false

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

func calcular_pontuacao_final():
	# Aqui vamos salvar o caminho ideal para desenhar na tela de vitória
	# Precisamos que a Main nos passe essa informação antes de morrer,
	# OU calculamos de novo na tela de vitória (já que temos o grafo salvo).
	
	# A melhor abordagem: A Main envia o array antes de trocar de cena.
	pass

func registrar_interacao_npc():
	total_npc_interactions += 1
	print("GameState: Interações com NPC: ", total_npc_interactions)
	check_hub_unlock()

func check_hub_unlock():
	if hub_desbloqueado: return # Já desbloqueou, não precisa checar
	
	# Regra: 1 Moeda OU 1 NPC
	if moedas > 0 or total_npc_interactions > 0:
		hub_desbloqueado = true
		print(">>> ROTA SECRETA (HUB) DESBLOQUEADA! <<<")
		# Opcional: Tocar um som misterioso ou salvar essa flag no disco imediatamente

var caminho_ideal_ultima_fase: Array[Vector2i] = [] # Adicione essa variável

func processar_resultado_fase(tolerancia: float):
	print("GameState: Processando resultado da fase...")
	
	# 1. Checagem de Bad Ending (Zona Vermelha)
	var limite_maximo = tempo_par_level * tolerancia
	
	if tempo_jogador > limite_maximo:
		print("GameState: Falha Crítica! Tempo %d excedeu limite %d." % [tempo_jogador, limite_maximo])
		falha_por_tempo = true
		bad_ending_count += 1
		# Não ganha moedas, não ganha nada. Apenas vergonha.
		return

	# 2. Se passou no teste, calcula vitória normal
	falha_por_tempo = false
	
	# Recompensa Base
	var base = 50 + (LevelManager.indice_fase_atual * 10)
	
	# Bônus de Tempo
	var bonus_tempo = 0
	if tempo_jogador < tempo_par_level:
		var diferenca = tempo_par_level - tempo_jogador
		bonus_tempo = int(diferenca * 2.0)
	
	# Total
	moedas_ganhas_na_fase = base + bonus_tempo
	adicionar_moedas(moedas_ganhas_na_fase)
	
	# Avaliação
	if tempo_jogador <= tempo_par_level:
		status_vitoria = "ROTA OTIMIZADA"
	elif tempo_jogador <= tempo_par_level * 1.5:
		status_vitoria = "ROTA SUB-ÓTIMA"
	else:
		status_vitoria = "ROTA INEFICIENTE" # Passou raspando, mas passou
		
	print("Vitória! Lucro: %d. Status: %s" % [moedas_ganhas_na_fase, status_vitoria])

"""
func processar_vitoria_fase():
	print("Processando vitória...")
	
	# 1. Recompensa Base
	var base = 50 + (LevelManager.indice_fase_atual * 10) # Fica mais valioso a cada fase
	
	# 2. Bônus de Tempo (Eficiência de Dijkstra)
	var bonus_tempo = 0
	if tempo_jogador < tempo_par_level:
		var diferenca = tempo_par_level - tempo_jogador
		bonus_tempo = int(diferenca * 2.0) # 2 moedas por "segundo/custo" economizado
	
	# 3. Total
	moedas_ganhas_na_fase = base + bonus_tempo
	adicionar_moedas(moedas_ganhas_na_fase)
	
	# 4. Avaliação
	if tempo_jogador <= tempo_par_level:
		status_vitoria = "ROTA OTIMIZADA"
	elif tempo_jogador <= tempo_par_level * 1.5:
		status_vitoria = "ROTA SUB-ÓTIMA"
	else:
		status_vitoria = "ROTA INEFICIENTE"
		
	print("Vitória! Base: %d, Bônus: %d. Total: %d. Status: %s" % [base, bonus_tempo, moedas_ganhas_na_fase, status_vitoria])
"""
