# res://scripts/BadEndingScreen.gd
extends CanvasLayer

@onready var label_gerente = $ColorRect/LabelAdmin

# Tempo para ler antes de ser chutado para o menu
var tempo_leitura_base = 4.0

func _ready():
	_iniciar_sequencia_punicao()

func _iniciar_sequencia_punicao():
	var texto = ""
	
	# Agora o match verifica o valor JÁ incrementado (1, 2, 3...)
	match Game_State.bad_ending_count:
		1:
			texto = "PERFORMANCE INACEITÁVEL.\nTEMPO LIMITE EXCEDIDO.\n\nSOLUÇÃO: DESCARTE IMEDIATO DO RECIPIENTE."
		2:
			texto = "NOVAMENTE?\nSUA INEFICIÊNCIA ESTÁ COMPROMETENDO O CRONOGRAMA.\n\nREINICIANDO O PROTOCOLO..."
		3:
			texto = "VOCÊ É O ELO MAIS FRACO DESTE SISTEMA.\nNÃO HÁ ESPAÇO PARA HESITAÇÃO NO GRAFO.\n\nDELETE."
		_:
			texto = "ERRO CRÍTICO.\nRECIPIENTE DEFEITUOSO DETECTADO.\n\nEXECUTANDO FORMAT C:..."
	
	label_gerente.text = texto
	label_gerente.visible_ratio = 0.0
	
	# Animação de digitação
	var t = create_tween()
	t.tween_property(label_gerente, "visible_ratio", 1.0, 3.0)
	
	# Espera terminar de escrever + tempo de leitura
	t.tween_interval(tempo_leitura_base)
	
	# Chama a função final
	t.tween_callback(_executar_descarte)


func _executar_descarte():
	print("BadEnding: Executando descarte do save da fase...")
	
	# (O incremento foi removido daqui pois já foi feito no _ready)
	
	# 2. Chama a cirurgia de arquivo no SaveManager
	# Isso sobrescreve o save atual com o backup do Hub + a nova contagem
	SaveManager.aplicar_punicao_e_reverter_para_hub()
	
	# 3. Reseta a memória RAM atual
	# Capturamos o valor atual (já incrementado) para não perder no reset
	var current_count = Game_State.bad_ending_count
	
	Game_State.reset_run_state() # Limpa inventário, moedas da run, etc.
	
	Game_State.bad_ending_count = current_count # Restaura a contagem de mortes
	Game_State.carregar_save_ao_iniciar = false
	
	# 4. Chuta para o Menu Principal
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
