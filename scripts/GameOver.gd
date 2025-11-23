extends CanvasLayer

func _ready():
	# Garante que o jogo não fique pausado se tivermos pausado antes
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Conecta os sinais dos botões (ajuste os caminhos se mudar os nomes)
	$CenterContainer/VBoxContainer/BtnTentar.pressed.connect(_on_tentar_pressed)
	$CenterContainer/VBoxContainer/BtnSair.pressed.connect(_on_sair_pressed)

func _on_tentar_pressed():
	print("GameOver: Reiniciando a run...")
	
	Game_State.reset_run_state()
	
	# CORREÇÃO: Mude para a cena do jogo (Main), não reload da atual
	# Ajuste o caminho se sua main estiver em outra pasta
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_sair_pressed():
	print("GameOver: Saindo do jogo.")
	get_tree().quit()
