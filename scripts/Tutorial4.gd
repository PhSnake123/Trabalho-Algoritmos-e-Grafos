# res://scripts/levels/Tutorial2.gd
extends Node
var main_ref = null

func setup_fase(main):
	print("Tutorial 4: Iniciado.")
	main_ref = main
	Game_State.is_dialogue_active = true
	var defrag = load("res://assets/iteminfo/DroneTerraformer.tres")
	if defrag:
		var item = defrag.duplicate()
		item.arquivo_origem = defrag.resource_path
		Game_State.inventario_jogador.adicionar_item(item)
		print("Tutorial 4: Defrag adicionado.")
	
	# Checa se o jogador usou o sonar na fase anterior
	var sonar_existente = Game_State.inventario_jogador.get_item_por_tipo(ItemData.ItemTipo.DRONE)
	if sonar_existente:
		print("Tutorial 4: Jogador economizou sonar.")
	else:
		print("Jogador gastou o sonar. Reabastecendo...")
		# Carrega o recurso da chave
		var sonar = load("res://assets/iteminfo/DRONE_SCANNER.tres")
		if sonar:
			var novo_sonar = sonar.duplicate()
			novo_sonar.arquivo_origem = sonar.resource_path
			Game_State.inventario_jogador.adicionar_item(novo_sonar)
	
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
			nova_chave.arquivo_origem = chave_res.resource_path
			Game_State.inventario_jogador.adicionar_item(nova_chave)
	
	_tocar_dialogo_tutorial()

func _tocar_dialogo_tutorial():
	var dados = DialogueData.new()
	dados.nome_npc = "Admin"
	var textos: Array[String] = [
		"Algumas estruturas possuem blocos de memória fragmentados. Pisar nesses blocos irá danificá-lo ou atrasá-lo.",
		"Estou te enviando um Desfragmentador. Utilize-o para desfragmentar os blocos de memória afetados numa área ao seu redor.",
		"Esta estrutura de dados é um pouco diferente comparada aos testes anteriores. A saída se encontra fechada.",
		"Para destrancá-la, você precisar ativar todas as Flags. Pise no bloco da Flag e interaja pressionando ESPAÇO. Seu visor indica quantas Flags existem na estrutura vigente, e quantas você já ativou.",
		"Errar é humano, otimizar é divino."
	]
	dados.falas = textos
	DialogueManager.iniciar_dialogo(dados)

func on_level_complete() -> bool:
	var dados = DialogueData.new()
	dados.nome_npc = "Admin"
	if Game_State.tempo_jogador <= Game_State.tempo_par_level:
		var textos: Array[String] = ["Exemplar. Você está pronto para o teste final."]
		dados.falas = textos
		DialogueManager.iniciar_dialogo(dados)
	elif Game_State.tempo_jogador <= Game_State.tempo_par_level * 2:
		var textos: Array[String] = ["Nada mal. Vamos para o último teste."]
		dados.falas = textos
		DialogueManager.iniciar_dialogo(dados)
	else:
		var textos: Array[String] = ["Talvez este Agente precise ser substituido... Executemos mais um teste."]
		dados.falas = textos
		DialogueManager.iniciar_dialogo(dados)
	
	print("Tutorial 4: Completo. Indo para Tutorial 5...")
	await DialogueManager.dialogo_finalizado
	LevelManager.forcar_proxima_fase_direto()
	return true

func on_game_over():
	print("Tutorial 4: Falha detectada. Iniciando protocolo de descarte.")
	
	# 1. Diálogo do Admin "Decepcionado"
	var dados = DialogueData.new()
	dados.nome_npc = "Admin"
	var textos: Array[String] = [
		"CRÍTICO: Sinais vitais do Agente interrompidos.",
		"Análise: Falha em transpor obstáculo básico de navegação.",
		"Veredito: Ineficiência inaceitável. O Agente não possui os requisitos mínimos.",
		"Executando limpeza de sistema... Adeus."
	]
	dados.falas= textos
	
	DialogueManager.iniciar_dialogo(dados)
	await DialogueManager.dialogo_finalizado
	
	# 2. Efeito Dramático (Tela preta ou som sumindo)
	if main_ref:
		var t = main_ref.create_tween()
		if main_ref.canvas_modulate:
			t.tween_property(main_ref.canvas_modulate, "color", Color.BLACK, 1.5)
		await t.finished
	
	# 3. PUNIÇÃO: Deleta o Save (Simula ser "Deletado" do sistema)
	# Removemos tanto o save manual quanto o auto save para ele não conseguir voltar
	# DirAccess.remove_absolute(SaveManager.SAVE_PATH_PLAYER)
	# DirAccess.remove_absolute(SaveManager.SAVE_PATH_AUTO)
	
	# 4. Chuta para o Menu Principal
	LevelManager.indice_fase_atual = 0
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
