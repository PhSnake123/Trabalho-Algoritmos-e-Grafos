# res://scripts/levels/Tutorial2.gd
extends Node

func setup_fase(_main_ref):
	print("Tutorial 3: Iniciado.")
	Game_State.is_dialogue_active = true
	# 1. Adiciona a Chave ao inventário
	# Certifique-se que o caminho do recurso está correto
	var sonar = load("res://assets/iteminfo/DRONE_SCANNER.tres")
	if sonar:
		var item = sonar.duplicate()
		item.arquivo_origem = sonar.resource_path
		Game_State.inventario_jogador.adicionar_item(item)
		print("Tutorial 2: Chave adicionada.")
	
	#Checa se o jogador já usou a chave da fase anterior
	var chave_existente = Game_State.inventario_jogador.get_item_por_tipo(ItemData.ItemTipo.CHAVE)
	
	if chave_existente:
		print("Jogador economizou a chave.")
	else:
		print("Jogador gastou a chave. Reabastecendo...")
		# Carrega o recurso da chave
		var chave_res = load("res://assets/iteminfo/chave.tres")
		if chave_res:
			var nova_chave = chave_res.duplicate()
			
			# IMPORTANTE: Aplicar o fix do ícone para o save funcionar depois
			nova_chave.arquivo_origem = chave_res.resource_path 
			
			Game_State.inventario_jogador.adicionar_item(nova_chave)
	
	_tocar_dialogo_tutorial()

func _tocar_dialogo_tutorial():
	var dados = DialogueData.new()
	dados.nome_npc = "Admin"
	var textos: Array[String] = [
		"Algumas estruturas estão obscurecidas. Áreas de memória de alta entropia.",
		"Explore-as para ordenar as partes da estrutura. Estou te enviando um Indexador.",
		"Use-o para revelar parte do caminho e auxiliá-lo a otimizar o tempo de passagem."
	]
	dados.falas = textos
	DialogueManager.iniciar_dialogo(dados)

func on_level_complete() -> bool:
	var dados = DialogueData.new()
	dados.nome_npc = "Admin"
	
	if Game_State.tempo_jogador <= Game_State.tempo_par_level:
		var textos: Array[String] = ["Perfeição. Adiante..."]
		dados.falas = textos
		DialogueManager.iniciar_dialogo(dados)
	elif Game_State.tempo_jogador <= Game_State.tempo_par_level * 2:
		var textos: Array[String] = ["Aceitável. Prossiga."]
		dados.falas = textos
		DialogueManager.iniciar_dialogo(dados)
	else:
		var textos: Array[String] = ["Preocupante..."]
		dados.falas = textos
		DialogueManager.iniciar_dialogo(dados)
	
	print("Tutorial 3: Completo. Indo para Tutorial 4...")
	await DialogueManager.dialogo_finalizado
	LevelManager.forcar_proxima_fase_direto()
	return true
