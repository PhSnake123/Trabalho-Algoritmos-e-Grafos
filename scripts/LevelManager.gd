# res://scripts/managers/LevelManager.gd
extends Node

# Lista de fases (Definições)
var lista_fases: Array[LevelDefinition] = []

# Índice da fase de JOGO (não conta o Hub)
var indice_fase_atual: int = 0

# Referência ao Hub
var hub_definition: LevelDefinition 

func _ready():
	# Carregue suas fases
	#lista_fases.append(load("res://assets/levels/debuglevel.tres"))
	lista_fases.append(load("res://assets/levels/tutorial1.tres"))
	lista_fases.append(load("res://assets/levels/tutorial2.tres"))
	lista_fases.append(load("res://assets/levels/tutorial3.tres"))
	lista_fases.append(load("res://assets/levels/tutorial4.tres"))
	lista_fases.append(load("res://assets/levels/tutorial5.tres"))
	lista_fases.append(load("res://assets/levels/level1.tres"))
	lista_fases.append(load("res://assets/levels/level2.tres"))
	lista_fases.append(load("res://assets/levels/level3.tres"))
	
	
	# Carregue a definição do Hub
	hub_definition = load("res://assets/levels/HubMap.tres")

# Chamado pelo Main para saber o que carregar
func get_dados_fase_atual() -> LevelDefinition:
	
	# 1. Prioridade: Modo Arcade Ativo?
	if ArcadeManager.is_arcade_mode:
		if ArcadeManager.current_level_resource != null:
			return ArcadeManager.current_level_resource
		else:
			print("ERRO CRÍTICO: Arcade Mode ativo mas sem resource gerado!")
			return null
	
	# 1. Se estamos no Hub, retorna a definição do Hub
	if Game_State.is_in_hub:
		if hub_definition:
			return hub_definition
		else:
			print("ERRO: HubDef não carregado no LevelManager!")
			return null
			
	# 3. Modo História (Fases Normais) [Deletar ou comentar o código depois do else, se for usar
	# essa versão aqui debaixo. No momento, estamos usando o outro método.
	#if indice_fase_atual >= 0 and indice_fase_atual < lista_fases.size():
	#	return lista_fases[indice_fase_atual]
	#else:
	#	print("ERRO: Índice de fase inválido: ", indice_fase_atual)
	#	return null
	
	# 2. Se não, retorna a fase da lista
	if lista_fases.is_empty():
		return null
	
	if indice_fase_atual >= lista_fases.size():
		return null # Fim de jogo
		
	return lista_fases[indice_fase_atual]

# A Lógica de Transição Inteligente (Simplificada)
func avancar_para_proxima_fase():
	print("LevelManager: Transição solicitada.")
	
	# CENÁRIO A: Estamos no HUB -> Vamos para a Próxima Fase
	if Game_State.is_in_hub:
		print("LevelManager: Saindo do Hub -> Iniciando Fase ", indice_fase_atual + 1)
		Game_State.is_in_hub = false
		
		# Avança o índice da fase apenas quando SAÍMOS do Hub
		indice_fase_atual += 1
		
		if indice_fase_atual >= lista_fases.size():
			print("VITÓRIA FINAL!")
			# get_tree().change_scene_to_file("res://scenes/VictoryScreen.tscn")
			return
		
		_carregar_cena_main()
		return

	# CENÁRIO B: Estamos numa FASE -> Vamos para o HUB
	else:
		print("LevelManager: Fase Concluída -> Indo para o Hub.")
		Game_State.is_in_hub = true
		_carregar_cena_main()

func _carregar_cena_main():
	# Reinicia a cena Main. O Main._ready() vai perguntar ao LevelManager 
	# "quem sou eu?" e o LevelManager vai responder baseado no is_in_hub.
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# LevelManager.gd

# Pula direto para a próxima fase da lista sem passar pelo Hub
func forcar_proxima_fase_direto():
	print("LevelManager: Avançando direto para a próxima fase (Tutorial)...")
	indice_fase_atual += 1
	Game_State.is_in_hub = false # Garante que não estamos no Hub
	_carregar_cena_main()

# Força a ida para o Hub
func forcar_ida_ao_hub():
	print("LevelManager: Fim do Tutorial. Transportando para o Hub...")
	Game_State.is_in_hub = true
	# Nota: Não incrementamos o índice aqui, pois o jogador vai "começar" o jogo real agora
	# ou você pode incrementar se o Hub for considerado "fase 4".
	# Geralmente, queremos apenas carregar o Hub.
	SaveManager.save_hub_backup()
	_carregar_cena_main()
