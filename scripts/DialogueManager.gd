extends CanvasLayer

signal dialogo_iniciado
signal dialogo_finalizado
signal escolha_feita(indice: int) # NOVO: Retorna 0 para opção 1, 1 para opção 2...

@onready var name_label = $DialogBox/MarginContainer/VBoxContainer/NameLabel
@onready var text_label = $DialogBox/MarginContainer/VBoxContainer/TextLabel
# Referências novas (ajuste os caminhos conforme sua cena):
@onready var buttons_container = $DialogBox/MarginContainer/VBoxContainer/ButtonsContainer
@onready var btn_1 = $DialogBox/MarginContainer/VBoxContainer/ButtonsContainer/Button
@onready var btn_2 = $DialogBox/MarginContainer/VBoxContainer/ButtonsContainer/Button2

var falas_atuais: Array[String] = []
var opcoes_atuais: Array[String] = [] # NOVO
var indice_atual: int = 0
var esta_ativo: bool = false
var pode_avancar: bool = false
var aguardando_escolha: bool = false # NOVO

func _ready():
	hide()
	buttons_container.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Conectar sinais dos botões via código para garantir
	btn_1.pressed.connect(func(): _on_botao_pressionado(0))
	btn_2.pressed.connect(func(): _on_botao_pressionado(1))

func iniciar_dialogo(dados: DialogueData):
	if not dados: return
	if esta_ativo: return 
	
	falas_atuais = dados.falas
	opcoes_atuais = dados.opcoes # Copia as opções
	indice_atual = 0
	name_label.text = dados.nome_npc
	
	esta_ativo = true
	aguardando_escolha = false
	buttons_container.hide() # Garante que começa escondido
	
	show()
	emit_signal("dialogo_iniciado")
	get_tree().paused = true 
	
	_mostrar_proxima_fala()

func _mostrar_proxima_fala():
	if indice_atual >= falas_atuais.size():
		# ACABARAM AS FALAS. TEM ESCOLHA?
		if opcoes_atuais.size() > 0:
			_mostrar_opcoes()
		else:
			_encerrar_dialogo()
		return
	
	var texto = falas_atuais[indice_atual]
	text_label.text = texto
	
	# Typewriter (igual ao seu original)
	text_label.visible_characters = 0
	pode_avancar = false
	
	var tween = create_tween()
	var tempo_total = texto.length() * 0.03
	tween.tween_property(text_label, "visible_characters", texto.length(), tempo_total)
	tween.finished.connect(func(): pode_avancar = true)
	
	indice_atual += 1

func _mostrar_opcoes():
	pode_avancar = false # Trava o "Enter/Espaço"
	aguardando_escolha = true
	
	# Configura textos dos botões
	if opcoes_atuais.size() >= 1:
		btn_1.text = opcoes_atuais[0]
		btn_1.show()
	
	if opcoes_atuais.size() >= 2:
		btn_2.text = opcoes_atuais[1]
		btn_2.show()
	else:
		btn_2.hide()
		
	buttons_container.show()
	
	# Foca no primeiro botão para permitir navegação por teclado
	btn_1.grab_focus()

func _on_botao_pressionado(index: int):
	buttons_container.hide()
	aguardando_escolha = false
	_encerrar_dialogo()
	# Emite qual botão foi apertado PARA QUEM CHAMOU
	emit_signal("escolha_feita", index)

func _encerrar_dialogo():
	esta_ativo = false
	hide()
	get_tree().paused = false
	emit_signal("dialogo_finalizado")

func _input(event):
	if not esta_ativo: return
	if aguardando_escolha: return # Se tiver escolha, ignora o Enter, só aceita clique nos botões
	
	if event.is_action_pressed("interagir") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if pode_avancar:
			_mostrar_proxima_fala()
		else:
			var tweens = get_tree().get_processed_tweens()
			for t in tweens: t.kill()
			text_label.visible_characters = -1
			pode_avancar = true
