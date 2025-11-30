extends CanvasLayer
@onready var musica_game_over: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready():
	AudioManager.stop_music()
	musica_game_over.play()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Conexões existentes
	$CenterContainer/VBoxContainer/BtnTentar.pressed.connect(_on_tentar_pressed)
	$CenterContainer/VBoxContainer/BtnSair.pressed.connect(_on_sair_pressed)
	
	# NOVAS CONEXÕES
	# (Verifique se os nomes dos nós batem com o que você criou na cena)
	$CenterContainer/VBoxContainer/BtnCarregar.pressed.connect(_on_carregar_pressed)
	$CenterContainer/VBoxContainer/BtnMenu.pressed.connect(_on_menu_pressed)
	
	var btn_hub: Button = $CenterContainer/VBoxContainer/BtnHub
	if btn_hub:
		btn_hub.pressed.connect(_on_hub_pressed)
		
		# Desabilita se não existir backup
		if not FileAccess.file_exists(SaveManager.SAVE_PATH_HUB_BACKUP):
			btn_hub.disabled = true
	
	# Opcional: Desabilita o botão Carregar se não tiver save (Reutilizando lógica do Menu)
	if not FileAccess.file_exists(SaveManager.SAVE_PATH_PLAYER):
		$CenterContainer/VBoxContainer/BtnCarregar.disabled = true

func _on_tentar_pressed():
	print("GameOver: Tentando novamente (Novo Jogo)...")
	Engine.time_scale = 1.0
	
	if FileAccess.file_exists(SaveManager.SAVE_PATH_AUTO):
		Game_State.reset_run_state() # Limpa memória suja
		Game_State.carregar_auto_save_ao_iniciar = true
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	else:
		# Fallback: Se não tem auto-save, começa tudo do zero (Novo Jogo)
		print("GameOver: AutoSave não encontrado. Iniciando nova run do zero.")
		Game_State.reset_run_state()
		Game_State.carregar_save_ao_iniciar = false
		get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- NOVO: Lógica Reutilizada do Menu Principal ---
func _on_carregar_pressed():
	print("GameOver: Carregando último save...")
	Engine.time_scale = 1.0
	
	# 1. Limpa tudo
	Game_State.reset_run_state()
	
	# 2. Levanta a bandeira para o Main.gd saber o que fazer
	Game_State.carregar_save_ao_iniciar = true
	
	# 3. Vai para o Main (ele vai ler a bandeira e puxar o SaveManager sozinho)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- NOVO: Voltar pro Menu ---
func _on_menu_pressed():
	print("GameOver: Voltando para o Menu...")
	Engine.time_scale = 1.0
	# Ajuste o caminho se seu menu estiver em outra pasta
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_sair_pressed():
	get_tree().quit()

func _on_hub_pressed():
	print("GameOver: Retornando ao Hub (Restaurando Backup)...")
	Engine.time_scale = 1.0 # Garante que o jogo despause
	Game_State.reset_run_state()
	
	# Verifica se o backup existe
	if FileAccess.file_exists(SaveManager.SAVE_PATH_HUB_BACKUP):
		# 1. Lê o conteúdo do arquivo de Backup do Hub
		var file_backup = FileAccess.open(SaveManager.SAVE_PATH_HUB_BACKUP, FileAccess.READ)
		var json_content = file_backup.get_as_text()
		file_backup.close()
		
		# 2. Sobrescreve o Save Principal (Player) com o conteúdo do Backup
		# Isso efetivamente "volta no tempo" para o estado do Hub
		var file_player = FileAccess.open(SaveManager.SAVE_PATH_PLAYER, FileAccess.WRITE)
		file_player.store_string(json_content)
		file_player.close()
		
		# 3. Configura para carregar o save normal (que agora contém os dados do Hub)
		Game_State.carregar_save_ao_iniciar = true
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	else:
		print("ERRO: Arquivo de backup não encontrado!")
