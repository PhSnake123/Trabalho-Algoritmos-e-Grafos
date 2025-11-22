# res://scripts/DialogueManager.gd
extends CanvasLayer

# Sinais para quem quiser ouvir (ex: tocar som, liberar conquista)
signal dialogo_iniciado
signal dialogo_finalizado

# Referências aos nós da UI
# Ajuste os caminhos conforme a hierarquia que você criou no Passo 2
@onready var dialog_box = $DialogBox
@onready var name_label = $DialogBox/MarginContainer/VBoxContainer/NameLabel
@onready var text_label = $DialogBox/MarginContainer/VBoxContainer/TextLabel

# Dados do fluxo atual
var falas_atuais: Array[String] = []
var indice_atual: int = 0
var esta_ativo: bool = false
var pode_avancar: bool = false

func _ready():
	hide() # Começa escondido
	# Garante que este nó continue processando mesmo quando o jogo pausa
	process_mode = Node.PROCESS_MODE_ALWAYS

func iniciar_dialogo(dados: DialogueData):
	if not dados: return
	
	falas_atuais = dados.falas
	indice_atual = 0
	name_label.text = dados.nome_npc
	
	esta_ativo = true
	show() # Mostra a UI
	
	emit_signal("dialogo_iniciado")
	
	# PAUSA O JOGO (Main, Player, Inimigos param)
	get_tree().paused = true
	
	_mostrar_proxima_fala()

func _mostrar_proxima_fala():
	if indice_atual >= falas_atuais.size():
		_encerrar_dialogo()
		return
	
	var texto = falas_atuais[indice_atual]
	text_label.text = texto
	
	# Efeito de Digitação (Typewriter)
	text_label.visible_characters = 0
	pode_avancar = false
	
	var tween = create_tween()
	# Calcula tempo baseado no tamanho do texto (ex: 0.03s por letra)
	var duracao = texto.length() * 0.03
	tween.tween_property(text_label, "visible_characters", texto.length(), duracao)
	tween.finished.connect(func(): pode_avancar = true)
	
	indice_atual += 1

func _encerrar_dialogo():
	esta_ativo = false
	hide()
	get_tree().paused = false # DESPAUSA O JOGO
	emit_signal("dialogo_finalizado")

func _unhandled_input(event):
	if not esta_ativo: return
	
	# Se apertar Espaço/Enter/Clique
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interagir"):
		# Evita propagar o input para o jogo
		get_viewport().set_input_as_handled()
		
		if pode_avancar:
			_mostrar_proxima_fala()
		else:
			# Se ainda estiver digitando, completa o texto imediatamente
			var tween = get_tree().create_tween() # Mata o tween anterior
			tween.kill()
			text_label.visible_characters = -1 # Mostra tudo
			pode_avancar = true
