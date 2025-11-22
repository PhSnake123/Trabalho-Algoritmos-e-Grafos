# res://scripts/DialogueManager.gd
extends CanvasLayer

signal dialogo_iniciado
signal dialogo_finalizado

@onready var dialog_box = $DialogBox
@onready var name_label = $DialogBox/MarginContainer/VBoxContainer/NameLabel
@onready var text_label = $DialogBox/MarginContainer/VBoxContainer/TextLabel

var falas_atuais: Array[String] = []
var indice_atual: int = 0
var esta_ativo: bool = false
var pode_avancar: bool = false

func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS # Essencial para rodar durante o pause

func iniciar_dialogo(dados: DialogueData):
	if not dados: return
	if esta_ativo: return # Evita abrir duas vezes
	
	falas_atuais = dados.falas
	indice_atual = 0
	name_label.text = dados.nome_npc
	
	esta_ativo = true
	show()
	
	emit_signal("dialogo_iniciado")
	get_tree().paused = true # Pausa o jogo
	
	_mostrar_proxima_fala()

func _mostrar_proxima_fala():
	if indice_atual >= falas_atuais.size():
		_encerrar_dialogo()
		return
	
	var texto = falas_atuais[indice_atual]
	text_label.text = texto
	
	# Typewriter Effect
	text_label.visible_characters = 0
	pode_avancar = false
	
	# Mata tween anterior se houver
	var tween = create_tween()
	var tempo_total = texto.length() * 0.03
	tween.tween_property(text_label, "visible_characters", texto.length(), tempo_total)
	tween.finished.connect(func(): pode_avancar = true)
	
	indice_atual += 1

func _encerrar_dialogo():
	esta_ativo = false
	hide()
	get_tree().paused = false
	emit_signal("dialogo_finalizado")

func _input(event):
	if not esta_ativo: return
	
	# Captura o input de interação para avançar
	if event.is_action_pressed("interagir") or event.is_action_pressed("ui_accept"):
		# Consome o evento para que o Player não ataque/interaja logo depois de fechar
		get_viewport().set_input_as_handled()
		
		if pode_avancar:
			_mostrar_proxima_fala()
		else:
			# Pula a animação de digitação
			var tweens = get_tree().get_processed_tweens()
			for t in tweens: t.kill() # Mata animação atual
			text_label.visible_characters = -1
			pode_avancar = true
