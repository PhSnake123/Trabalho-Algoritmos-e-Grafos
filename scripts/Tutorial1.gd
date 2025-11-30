# res://scripts/levels/Tutorial1.gd
extends Node

func setup_fase(_main_ref):
	print("Tutorial 1: Iniciado.")
	# 1. Limpa o inventário (Começa do zero)
	Game_State.is_dialogue_active = true
	Game_State.inventario_jogador.clear_items()
	
	# 2. Admin instrui (via DialogueManager)
	# Aqui você pode criar um DialogueData via código ou carregar um .tres
	_tocar_dialogo_intro()

func _tocar_dialogo_intro():
	await get_tree().create_timer(1.0).timeout
	var dados = DialogueData.new()
	dados.nome_npc = "Admin"
	var textos: Array[String] = [
		"Inicializando protocolo de otimização...\nCodinome: Agente NP.\nReceptáculo carregado com sucesso.",
		"Seja bem vindo ao protocolo de testes, agente. Seu objetivo é simples: atravesse a estrutura até o nó de saída na menor quantidade de tempo possível.",
		"Sua performance será armazenada no visor superior e comparada com o atual tempo otimizado. Iguale ou supere-o.",
		"Sua performance não será avaliada durante o protocolo de testes, portanto, sinta-se a vontade para treinar seu algoritmo de busca. Isso é tudo."
	]
	dados.falas = textos
	DialogueManager.iniciar_dialogo(dados)

func on_level_complete() -> bool:
	print("Tutorial 1: Completo. Indo para Tutorial 2...")
	var dados = DialogueData.new()
	dados.nome_npc = "Admin"
	
	if Game_State.tempo_jogador <= Game_State.tempo_par_level:
		var textos: Array[String] = ["Excelente. Prossigamos ao próximo dataset de testes."]
		dados.falas = textos
		DialogueManager.iniciar_dialogo(dados)
	elif Game_State.tempo_jogador <= Game_State.tempo_par_level * 1.5:
		var textos: Array[String] = ["Satisfatório. Prossigamos ao próximo dataset de testes."]
		dados.falas = textos
		DialogueManager.iniciar_dialogo(dados)
	else:
		var textos: Array[String] = ["... Prossigamos ao próximo dataset de testes."]
		dados.falas = textos
		DialogueManager.iniciar_dialogo(dados)
	
	# Chama a função nova que criamos
	await DialogueManager.dialogo_finalizado
	LevelManager.forcar_proxima_fase_direto()
	return true # Retorna true para impedir a tela de vitória padrão
