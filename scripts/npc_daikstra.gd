extends NPC

# Variáveis para armazenar os dados dos diálogos
var dialogo_inicial: DialogueData
var dialogo_repetido: DialogueData

func _ready():
	# Chama o _ready da classe pai (NPC) para configurar grupos e HP
	super._ready()
	
	# --- CONFIGURAÇÃO DOS DIÁLOGOS VIA CÓDIGO ---
	
	# 1. Diálogo da Primeira Vez
	dialogo_inicial = DialogueData.new()
	dialogo_inicial.nome_npc = "Daikstra"
	dialogo_inicial.falas = [
		"Curioso...", 
		"Você é a segunda pessoa a chegar aqui desde a criação do Setor Defeituoso.",
		"Seja bem vindo. Meu nome é Daikstra, acho que você pode me chamar de um vendedor ou algo do tipo.",
		"Sinta-se a vontade para examinar meus itens. Tenho certeza que encontrará algo útil.",
		"Hum? Você quer saber como eu cheguei aqui? É uma longa história, e não muito importante...",
		"De qualquer forma, me avise quando quiser sair. Passar bem, Agente."
	]
	# Define as opções [0 = Ir, 1 = Ficar]
	dialogo_inicial.opcoes = ["Preciso ir ao próximo setor.", "Quero ficar aqui um pouco mais."]

	# 2. Diálogo Repetido (Segunda vez em diante)
	dialogo_repetido = DialogueData.new()
	dialogo_repetido.nome_npc = "Daikstra"
	dialogo_repetido.falas = [
		"Ainda por aqui?",
		"O Admin não espera por ninguém. Otimize seu tempo."
	]
	dialogo_repetido.opcoes = ["Preciso ir ao próximo setor.", "Quero ficar aqui."]

# Sobrescrevemos a função interagir do NPC.gd
func interagir():
	if Game_State.is_dialogue_active: return
	
	print("Guardião: Interagindo. Escolhas anteriores: ", escolhas)
	
	# 1. Decide qual diálogo usar baseado na variável 'escolhas' (que vem do NPC.gd)
	var dialogo_atual: DialogueData
	
	if LevelManager.indice_fase_atual > 4 or escolhas > 0:
		dialogo_atual = dialogo_repetido
	else:
		dialogo_atual = dialogo_inicial
	
	# 2. Inicia o diálogo usando seu DialogueManager
	DialogueManager.iniciar_dialogo(dialogo_atual)
	
	# 3. Aguarda o sinal de que o jogador clicou num botão
	# O DialogueManager emite 'escolha_feita(indice)'
	var indice_escolhido = await DialogueManager.escolha_feita
	
	# 4. Processa a escolha
	match indice_escolhido:
		0: # "Quero ir pra próxima fase"
			print("Guardião: Iniciando transferência...")
			LevelManager.avancar_para_proxima_fase()
			
		1: # "Quero ficar aqui"
			print("Guardião: Jogador decidiu ficar.")
			# Incrementamos 'escolhas'. Como herda de NPC, isso será salvo no JSON
			# via 'get_save_data' que salva a var 'escolhas' como 'estado_interacao'
			escolhas += 1
