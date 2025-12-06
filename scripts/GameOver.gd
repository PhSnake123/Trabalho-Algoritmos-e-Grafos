extends CanvasLayer

@onready var musica_game_over: AudioStreamPlayer2D = $AudioStreamPlayer2D

# Referências da UI NORMAL (O CenterContainer que já existia)
@onready var container_normal = $ContainerNormal

# Referências da UI ARCADE (O Panel que criamos agora)
@onready var panel_arcade = $PanelArcade
@onready var lbl_score = $PanelArcade/VBoxContainer/LblScore
@onready var input_name = $PanelArcade/VBoxContainer/HBoxContainer/InputName
@onready var btn_submit = $PanelArcade/VBoxContainer/HBoxContainer/BtnSubmit
@onready var vbox_lista = $PanelArcade/VBoxContainer/VBoxListaLeaderboard
@onready var btn_voltar_menu = $PanelArcade/VBoxContainer/BtnVoltarMenu

func _ready():
	AudioManager.stop_music()
	musica_game_over.play()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# --- DECISÃO DE MODO ---
	if ArcadeManager.is_arcade_mode:
		_setup_arcade_mode()
	else:
		_setup_normal_mode()

func _setup_normal_mode():
	# Esconde Arcade, Mostra Normal
	if panel_arcade: panel_arcade.hide()
	container_normal.show()
	
	# Conexões Normais (Reutilizando seus nós existentes)
	# Nota: Ajuste os caminhos abaixo se você mudou a estrutura do ContainerNormal
	var vbox = $ContainerNormal/VBoxContainer
	vbox.get_node("BtnTentar").pressed.connect(_on_tentar_pressed)
	vbox.get_node("BtnSair").pressed.connect(_on_sair_pressed)
	vbox.get_node("BtnCarregar").pressed.connect(_on_carregar_pressed)
	vbox.get_node("BtnMenu").pressed.connect(_on_menu_pressed)
	
	# Lógica do Hub e Load Button
	if not FileAccess.file_exists(SaveManager.SAVE_PATH_PLAYER):
		vbox.get_node("BtnCarregar").disabled = true
		
	var btn_hub = vbox.get_node("BtnHub")
	if btn_hub:
		btn_hub.pressed.connect(_on_hub_pressed)
		if not FileAccess.file_exists(SaveManager.SAVE_PATH_HUB_BACKUP):
			btn_hub.disabled = true

func _setup_arcade_mode():
	# Esconde Normal, Mostra Arcade
	container_normal.hide()
	panel_arcade.show()
	
	# Atualiza Texto de Pontuação
	lbl_score.text = "PONTUAÇÃO FINAL: %d" % ArcadeManager.pontuacao_acumulada
	
	# Configura Input
	input_name.text = "AAA"
	input_name.grab_focus()
	
	# Conecta Botões Arcade
	btn_submit.pressed.connect(_on_submit_pressed)
	btn_voltar_menu.pressed.connect(_on_menu_pressed)
	
	# Mostra a lista atual
	_atualizar_lista_visual()

func _on_submit_pressed():
	var nome = input_name.text.strip_edges()
	if nome == "": nome = "UNK"
	
	# Salva
	SaveManager.save_score_to_leaderboard(nome, ArcadeManager.pontuacao_acumulada)
	
	# Atualiza visual e trava
	_atualizar_lista_visual()
	input_name.editable = false
	btn_submit.disabled = true
	btn_submit.text = "SALVO!"

func _atualizar_lista_visual():
	# Limpa filhos antigos
	for child in vbox_lista.get_children():
		child.queue_free()
		
	var data = SaveManager.get_leaderboard_data()
	
	if data.is_empty():
		var l = Label.new()
		l.text = "Sem pontuações ainda."
		vbox_lista.add_child(l)
		return
		
	# Cria Labels
	for i in range(data.size()):
		var entry = data[i]
		var l = Label.new()
		l.text = "%d. %s  -  %d" % [i+1, entry["name"], entry["score"]]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Destaca o jogador atual
		if entry["score"] == ArcadeManager.pontuacao_acumulada and entry["name"] == input_name.text.to_upper():
			l.modulate = Color.YELLOW
			
		vbox_lista.add_child(l)

# --- FUNÇÕES DE AÇÃO (Reutilizadas) ---

func _on_tentar_pressed():
	print("GameOver: Tentando novamente...")
	Engine.time_scale = 1.0
	Game_State.reset_run_state()
	Game_State.carregar_auto_save_ao_iniciar = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_carregar_pressed():
	print("GameOver: Carregando último save...")
	Engine.time_scale = 1.0
	Game_State.reset_run_state()
	Game_State.carregar_save_ao_iniciar = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_menu_pressed():
	Engine.time_scale = 1.0
	ArcadeManager.finalizar_run() # Limpa o modo arcade
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_sair_pressed():
	get_tree().quit()

func _on_hub_pressed():
	print("GameOver: Restaurando Hub...")
	Engine.time_scale = 1.0
	Game_State.reset_run_state()
	if FileAccess.file_exists(SaveManager.SAVE_PATH_HUB_BACKUP):
		var file_backup = FileAccess.open(SaveManager.SAVE_PATH_HUB_BACKUP, FileAccess.READ)
		var json_content = file_backup.get_as_text()
		file_backup.close()
		
		var file_player = FileAccess.open(SaveManager.SAVE_PATH_PLAYER, FileAccess.WRITE)
		file_player.store_string(json_content)
		file_player.close()
		
		Game_State.carregar_save_ao_iniciar = true
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
