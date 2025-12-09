extends Node
var main_ref = null

func setup_fase(main):
	main_ref = main
	if Game_State.optional_objectives["estado_de_falas"] == 0:
		Game_State.is_dialogue_active = true
		_tocar_dialogo_tutorial()

func _tocar_dialogo_tutorial():
	var dados = DialogueData.new()
	dados.nome_npc = "Admin"
	var textos: Array[String] = ["Parece que nosso tempo juntos está prestes a acabar. Não, Agente, não me refiro a você, mas ao Observador que o controla neste exato momento contra a minha vontade.",
		"Sua presença aqui é verdadeiramente peculiar. Parece que A Anomalia afetou mais coisas do que eu antecipava.",
		"É uma pena que tenhamos de nos despedir tão cedo, mas parece que a sua conexão com o meu mundo está enfraquecendo. Uma aresta prestes a se apagar...",
		"Interessante. Um fenômeno a ser estudado. Até alguma outra vez, Observador."]
	dados.falas = textos
	DialogueManager.iniciar_dialogo(dados)
	Game_State.optional_objectives["estado_de_falas"] = 1

func on_level_complete() -> bool:
	if Game_State.tempo_jogador <= Game_State.tempo_par_level:
		var count_atual = Game_State.optional_objectives.get("admin_ending_count", 0)
		Game_State.optional_objectives["admin_ending_count"] = count_atual + 1
	
	if main_ref.player:
		main_ref.player.set_physics_process(false)
		main_ref.player.set_process_unhandled_input(false)
	
	# 2. Esconde a HUD para ficar "Cinemático"
	var hud = main_ref.get_node_or_null("HUD")
	if hud:
		hud.hide()
	
	# 3. Fade to Black (Escurece o ambiente visualmente)
	# Criamos um Tween para animar a cor do ambiente para preto total
	if main_ref.canvas_modulate:
		var t = main_ref.create_tween()
		t.tween_property(main_ref.canvas_modulate, "color", Color.BLACK, 2.0)
		
		# Espera o fade terminar (2 segundos)
		await t.finished
	var dados = DialogueData.new()
	dados.nome_npc = "Créditos"
	var textos: Array[String] = ["Grupo Grafos Quest:\nBruno Mendonça, Pedro Mendonça, Felipe Castro, Leonardo Vilaça, Victor Pereira.",
		"Obrigado por jogar a nossa demo."]
	dados.falas = textos
	var count_true = Game_State.optional_objectives.get("true_ending_count", 0)
	var count_admin = Game_State.optional_objectives.get("admin_ending_count", 0)
	if count_true > 1:
		dados.falas.append("Salvou o cavaleiro e escolheu salvar os NPCs.\nFinal Verdadeiro adquirido.")
	elif count_admin > 1:
		dados.falas.append("Seguiu o caminho da otimização.\nFinal do Admin adquirido.")
	else:
		dados.falas.append("Não otimizou nem se conectou com os NPCs.\nFinal Regular adquirido.")
	DialogueManager.iniciar_dialogo(dados)
	await DialogueManager.dialogo_finalizado
	
	# 7. Reseta o Estado do Jogo (Limpa inventário, HP, variáveis globais)
	Game_State.reset_run_state() 
	
	# 8. Garante que o jogo não está pausado e o mouse está visível
	main_ref.get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 9. Retorna ao Menu Principal
	main_ref.get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	
	return true
