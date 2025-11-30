# res://scripts/levels/Tutorial2.gd
extends Node

func setup_fase(_main_ref):
	print("Tutorial 5: Iniciado.")
	Game_State.is_dialogue_active = true
	var patch = load("res://assets/iteminfo/potion.tres")
	if patch:
		var item = patch.duplicate()
		item.arquivo_origem = patch.resource_path
		Game_State.inventario_jogador.adicionar_item(item)
		print("Tutorial Final: Patch de Integridade adicionado.")
	
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
		"AVISO: Setor instável. Dados corrompidos detectados.",
		"Peculiar... Isso não deveria estar aqui. Parece que esse setor foi infectado com programas nocivos.",
		"Estou anexando um Patch de Integridade ao seu Database. Use isso se você sofrer danos consideráveis. Mas seu Protocolo de Segurança deve ser robusto o suficiente para lidar com uma ameaça tão pequena.",
		"Você já está equipado com o Executável da Navalha de Occam. Este programa roda um protocolo de ataque contra ameaças próximas.",
		"Quando o inimigo estiver à sua frente, simplesmente dê um passo em direção a ele e o Executável será acionado.",
		"Quanto aos bits flutuantes, ignore-os. São apenas fragmentos de memória corrompida. O Coletor cuidará deles.",
		"Execute todos os obstáculos e atinja o resultado otimizado. Um bom Agente deve ser adaptável. Este será seu teste final."
	]
	dados.falas = textos
	DialogueManager.iniciar_dialogo(dados)

func on_level_complete() -> bool:
	print("Tutorial Final: Completo. Indo para o Setor Defeituoso...")
	LevelManager.forcar_ida_ao_hub()
	return true
