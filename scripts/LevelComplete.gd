extends CanvasLayer

@onready var lbl_status = $Panel/VBoxContainer/LabelStatus
@onready var lbl_tempo = $Panel/VBoxContainer/HBoxContainer/LabelTempo
@onready var lbl_moedas = $Panel/VBoxContainer/HBoxContainer/LabelMoedas
@onready var btn_prosseguir = $Panel/VBoxContainer/ButtonProsseguir
@onready var graph_panel = $Panel/VBoxContainer/GraphPanel
@export var dialogo_admin: DialogueData

func _ready():
	# 1. Configura UI (Texto e Cores) - Mantém igual
	lbl_status.text = Game_State.status_vitoria
	lbl_tempo.text = "Tempo: %d / %d" % [Game_State.tempo_jogador, Game_State.tempo_par_level]
	lbl_moedas.text = "Ganhos: $%d" % Game_State.moedas_ganhas_na_fase
	
	if Game_State.status_vitoria == "ROTA OTIMIZADA": lbl_status.modulate = Color.GREEN
	elif Game_State.status_vitoria == "ROTA INEFICIENTE": lbl_status.modulate = Color.RED
	else: lbl_status.modulate = Color.YELLOW
	
	Game_State.optional_objectives["estado_de_falas"] = 0
	
	# Conecta o botão (agora fazemos isso antes do if/else para garantir)
	btn_prosseguir.pressed.connect(_on_prosseguir)
	
	# 3. Desenha o Grafo (Mantém igual)
	_desenhar_caminho_jogador()

	# --- LÓGICA DE COMPORTAMENTO (ARCADE vs HISTÓRIA) ---
	
	if ArcadeManager.is_arcade_mode:
		# >>> MODO ARCADE <<<
		dialogo_admin = null
		
		# Botão já começa destravado e focado para agilizar
		btn_prosseguir.disabled = false
		btn_prosseguir.grab_focus()
		
	else:
		# >>> MODO HISTÓRIA <<<
		
		# 1. Trava o botão inicialmente
		btn_prosseguir.disabled = true
		
		# 2. Tenta carregar diálogo da fase
		var fase_atual = LevelManager.indice_fase_atual
		var path_especifico = "res://assets/dialogue/admin_fases/admin_fase_%d.tres" % fase_atual
		
		if ResourceLoader.exists(path_especifico):
			dialogo_admin = load(path_especifico)
			print("LevelComplete: Carregado diálogo específico da Fase ", fase_atual)
		else:
			dialogo_admin = null
			print("LevelComplete: Nenhum diálogo configurado.")
		
		# 3. Inicia o Timer para começar o diálogo
		get_tree().create_timer(0.5).timeout.connect(_iniciar_dialogo)

func _iniciar_dialogo():
	if dialogo_admin:
		DialogueManager.iniciar_dialogo(dialogo_admin)
		# Conecta ao sinal global do DialogueManager para saber quando acabou
		DialogueManager.dialogo_finalizado.connect(_on_dialogo_terminou, CONNECT_ONE_SHOT)
	else:
		# Se não tiver diálogo configurado, libera o botão direto
		btn_prosseguir.disabled = false

func _on_dialogo_terminou():
	btn_prosseguir.disabled = false
	btn_prosseguir.grab_focus()

func _on_prosseguir():
	# Verifica se estamos no Arcade
	if ArcadeManager.is_arcade_mode:
		print("LevelComplete: Modo Arcade - Calculando Bônus...")
		
		# --- CORREÇÃO: REMOVEMOS O CÁLCULO DE MOEDAS DAQUI ---
		# Os fragmentos já foram somados no GameState.adicionar_moedas()
		# Agora só calculamos o Bônus de Tempo/Velocidade.
		
		var bonus_tempo = 0
		if Game_State.tempo_jogador < Game_State.tempo_par_level:
			var diff = Game_State.tempo_par_level - Game_State.tempo_jogador
			# Exemplo: 50 pontos por segundo economizado
			bonus_tempo = int(diff * 50) 
			
		if bonus_tempo > 0:
			ArcadeManager.add_score(bonus_tempo)
			print("Arcade: Bônus de Tempo aplicado: +%d pts" % bonus_tempo)
		else:
			print("Arcade: Sem bônus de tempo.")
		
		# Avança nível
		ArcadeManager.avancar_nivel()
		get_tree().reload_current_scene()
		
	else:
		# Modo História Normal (Mantém original)
		LevelManager.avancar_para_proxima_fase()

# --- DESENHO DO GRAFO ---
func _desenhar_caminho_jogador():
	if Game_State.caminho_jogador.is_empty(): return
	
	# Cria um Line2D para desenhar as linhas
	var line = Line2D.new()
	line.width = 2.0
	line.default_color = Color.CYAN
	graph_panel.add_child(line)
	
	# Precisamos normalizar o caminho para caber no painel (300x200)
	var min_x = INF; var max_x = -INF
	var min_y = INF; var max_y = -INF
	
	# Acha os limites do mapa visitado
	for pos in Game_State.caminho_jogador:
		if pos.x < min_x: min_x = pos.x
		if pos.x > max_x: max_x = pos.x
		if pos.y < min_y: min_y = pos.y
		if pos.y > max_y: max_y = pos.y
		
	var largura_mapa = max(1, max_x - min_x)
	var altura_mapa = max(1, max_y - min_y)
	
	var panel_size = graph_panel.get_rect().size
	var padding = 20.0
	
	# Converte cada passo do grid para pixels na UI
	for pos in Game_State.caminho_jogador:
		var normalized_x = (pos.x - min_x) / float(largura_mapa)
		var normalized_y = (pos.y - min_y) / float(altura_mapa)
		
		var screen_x = padding + (normalized_x * (panel_size.x - padding * 2))
		var screen_y = padding + (normalized_y * (panel_size.y - padding * 2))
		
		line.add_point(Vector2(screen_x, screen_y))
