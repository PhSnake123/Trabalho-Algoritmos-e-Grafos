extends CanvasLayer
var menu_music = preload("res://Audio/music/Title.mp3")

func _ready():
	if AudioManager:
		AudioManager.play_music(menu_music)
	
	var vbox = $CenterContainer/VBoxContainer
	
	# Conexões
	vbox.get_node("BtnNovoJogo").pressed.connect(_on_novo_jogo_pressed)
	vbox.get_node("BtnCarregar").pressed.connect(_on_carregar_pressed)
	vbox.get_node("BtnSair").pressed.connect(_on_sair_pressed)
	
	if vbox.has_node("BtnArcade"):
		vbox.get_node("BtnArcade").pressed.connect(_on_arcade_pressed)
		
	# --- NOVO BOTÃO ---
	if vbox.has_node("BtnLeaderboard"):
		vbox.get_node("BtnLeaderboard").pressed.connect(_on_leaderboard_pressed)
	
	if not FileAccess.file_exists(SaveManager.SAVE_PATH_PLAYER):
		vbox.get_node("BtnCarregar").disabled = true

func _on_novo_jogo_pressed():
	Game_State.reset_run_state()
	if LevelManager: LevelManager.indice_fase_atual = 0
	Game_State.carregar_save_ao_iniciar = false
	Game_State.carregar_auto_save_ao_iniciar = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_carregar_pressed():
	Game_State.reset_run_state()
	Game_State.carregar_save_ao_iniciar = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_arcade_pressed():
	Game_State.reset_run_state()
	ArcadeManager.iniciar_run()
	Game_State.carregar_save_ao_iniciar = false
	Game_State.carregar_auto_save_ao_iniciar = false
	Game_State.is_in_hub = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- FUNÇÃO DO LEADERBOARD ---
func _on_leaderboard_pressed():
	# Cria um Popup simples via código para não precisar editar a cena demais
	var popup = AcceptDialog.new()
	popup.title = "RANKING ARCADE (TOP 10)"
	add_child(popup)
	
	var data = SaveManager.get_leaderboard_data()
	var texto = ""
	
	if data.is_empty():
		texto = "Nenhum registro encontrado."
	else:
		for i in range(data.size()):
			var e = data[i]
			texto += "%d. %s ...... %d\n" % [i+1, e["name"], e["score"]]
			
	popup.dialog_text = texto
	popup.popup_centered()

func _on_sair_pressed():
	get_tree().quit()
