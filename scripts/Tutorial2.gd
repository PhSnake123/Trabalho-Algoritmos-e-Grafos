# res://scripts/levels/Tutorial2.gd
extends Node

func setup_fase(_main_ref):
	print("Tutorial 2: Iniciado.")
	Game_State.is_dialogue_active = true
	# 1. Adiciona a Chave ao inventário
	# Certifique-se que o caminho do recurso está correto
	var chave_res = load("res://assets/iteminfo/chave.tres")
	if chave_res:
		var item = chave_res.duplicate()
		item.arquivo_origem = chave_res.resource_path
		Game_State.inventario_jogador.adicionar_item(item)
		print("Tutorial 2: Chave adicionada.")
	
	_tocar_dialogo_tutorial()

func _tocar_dialogo_tutorial():
	await get_tree().create_timer(1.0).timeout
	var dados = DialogueData.new()
	dados.nome_npc = "Admin"
	var textos: Array[String] = [
		"Algumas arestas estão bloqueadas.",
		"Enviei um decodificador ao seu Banco de Dados. No seu terminal, pressione \"I\" ou \"Tab\" e clique no ícone. Mantenha seu pointer nele para ler a descrição do programa.",
		"Use-o apertando \"E\" em seu terminal para abrir o caminho e otimizar o tempo de passagem."
	]
	dados.falas = textos
	DialogueManager.iniciar_dialogo(dados)

func on_level_complete() -> bool:
	var dados = DialogueData.new()
	dados.nome_npc = "Admin"
	
	if Game_State.tempo_jogador <= Game_State.tempo_par_level:
		var textos: Array[String] = ["Muito promissor. Prossigamos..."]
		dados.falas = textos
		DialogueManager.iniciar_dialogo(dados)
	elif Game_State.tempo_jogador <= Game_State.tempo_par_level * 1.5:
		var textos: Array[String] = ["Abaixo das expectativas, mas aceitável o suficiente. Prossigamos..."]
		dados.falas = textos
		DialogueManager.iniciar_dialogo(dados)
	else:
		var textos: Array[String] = ["
						Mesmo com um decodificador, você está apresentando resultados assim?\n Preocupante... Prossigamos."]
		dados.falas = textos
		DialogueManager.iniciar_dialogo(dados)
	
	print("Tutorial 2: Completo. Indo para Tutorial 3...")
	await DialogueManager.dialogo_finalizado
	LevelManager.forcar_proxima_fase_direto()
	return true
