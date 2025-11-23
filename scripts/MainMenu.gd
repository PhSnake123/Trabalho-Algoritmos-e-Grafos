extends CanvasLayer
var menu_music = preload("res://Audio/music/Title.mp3")
	
func _ready():
	# Conecta os botões
	if AudioManager:
		AudioManager.play_music(menu_music)
	var vbox = $CenterContainer/VBoxContainer
	vbox.get_node("BtnNovoJogo").pressed.connect(_on_novo_jogo_pressed)
	vbox.get_node("BtnCarregar").pressed.connect(_on_carregar_pressed)
	vbox.get_node("BtnSair").pressed.connect(_on_sair_pressed)
	
	# Opcional: Verifica se existe save para habilitar o botão Carregar
	if not FileAccess.file_exists(SaveManager.SAVE_PATH_PLAYER):
		vbox.get_node("BtnCarregar").disabled = true

func _on_novo_jogo_pressed():
	print("Menu: Iniciando Novo Jogo...")
	# 1. Reseta o estado global
	Game_State.reset_run_state()
	# 2. Garante que NÃO vamos carregar save, queremos um mapa novo
	Game_State.carregar_save_ao_iniciar = false
	# 3. Vai para o jogo
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_carregar_pressed():
	print("Menu: Carregando Jogo Salvo...")
	# 1. Reseta o estado (por segurança)
	Game_State.reset_run_state()
	# 2. Levanta a bandeira: "Main, por favor carregue o disco quando acordar"
	Game_State.carregar_save_ao_iniciar = true
	# 3. Vai para o jogo
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_sair_pressed():
	get_tree().quit()
