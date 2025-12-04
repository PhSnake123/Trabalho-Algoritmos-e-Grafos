extends Control

func _ready():
	# Esconde o menu ao iniciar
	hide()

func _unhandled_input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		# Marca o input como resolvido para não propagar
		get_viewport().set_input_as_handled()
		fechar_menu()

func abrir_menu():
	show()
	# Pausa a árvore de jogo
	get_tree().paused = true
	
	# Foca no primeiro botão para navegar com teclado/controle
	var primeiro_botao = find_child("BtnContinuar", true, false)
	if primeiro_botao: primeiro_botao.grab_focus()

func fechar_menu():
	hide()
	get_tree().paused = false

# --- BOTÕES ---

func _on_btn_continuar_pressed():
	fechar_menu()

func _on_btn_carregar_pressed():
	# Confirmação simples: só carrega o último save manual
	print("PauseMenu: Carregando último save...")
	fechar_menu() # Despausa antes de carregar pra evitar bugs
	SaveManager.load_player_game()

func _on_btn_hub_pressed():
	print("PauseMenu: Retornando ao Hub...")
	fechar_menu()
	
	# Força a ida ao Hub via LevelManager (ou Main se preferir)
	# Se você tiver a função no LevelManager é melhor, senão usamos o GameState
	Game_State.is_in_hub = true
	# Reseta estados de run
	Game_State.terminais_ativos = 0
	# Recarrega a cena principal (que vai ler o is_in_hub = true e carregar o mapa fixo)
	get_tree().reload_current_scene()

func _on_btn_titulo_pressed():
	fechar_menu()
	# Garante que despausou antes de sair
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_btn_sair_pressed():
	get_tree().quit()
