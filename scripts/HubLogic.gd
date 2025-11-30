# HubLogic.gd (Anexar ao HubMap)
# res://scripts/HubLogic.gd
extends Node2D

# Referências
@onready var main_ref = get_parent() # O HubMap é filho do Main

func atualizar_estado_hub():
	print("HubLogic: Verificando flags e atualizando o Hub...")
	
	# 1. VERIFICA PROGRESSÃO DE FASE
	# Exemplo: Se passou da fase 1, remove a barreira para a área de treino
	#if LevelManager.indice_fase_atual > 0:
	#	var barreira = get_node_or_null("LayerParedes/BarreiraAreaTreino")
	#	if barreira:
	#		barreira.queue_free()
	#		print("HubLogic: Barreira de treino removida.")

	# 2. VERIFICA NPCS RESGATADOS/MORTOS
	# Vamos supor que você salvou uma flag "npc_ferreiro_resgatado" no GameState
	# Exemplo: O Ferreiro só aparece se foi resgatado na Fase 1
	#var ferreiro = get_node_or_null("NpcFerreiro")
	#if ferreiro:
	#	if Game_State.optional_objectives.get("npc_ferreiro_resgatado", false):
	#		ferreiro.visible = true
			# Habilita colisão/interação se necessário
	#	else:
	#		ferreiro.visible = false
	#		ferreiro.process_mode = Node.PROCESS_MODE_DISABLED

	# 3. VERIFICA SE ALGUÉM MORREU (Exemplo do contexto anterior)
	#if Game_State.npc_states.get("npc_charles_morto", false):
	#	var charles = get_node_or_null("NpcCharles")
	#	if charles:
	#		charles.queue_free()

	# 4. CURA O JOGADOR AO ENTRAR NO HUB
	Game_State.vida_jogador = Game_State.max_vida_jogador
	print("HubLogic: Jogador curado e estado atualizado.")
