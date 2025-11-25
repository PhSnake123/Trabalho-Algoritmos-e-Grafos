# res://scripts/managers/LevelManager.gd
extends Node

# Aqui você arrasta seus arquivos .tres (Fase1, Fase2, etc) pelo Inspector
# Mas como é um Autoload, você configura isso na aba Project Settings ou via código.
# Para facilitar agora, vamos carregar uma lista hardcoded de teste,
# mas idealmente você teria uma variável exportada se isso fosse um nó na cena.
var lista_fases: Array[LevelDefinition] = []

# Índice da fase atual
var indice_fase_atual: int = 0

func _ready():
	# CARREGUE SUAS FASES AQUI PARA TESTE
	# Crie os arquivos Fase1.tres na pasta resources antes de rodar!
	lista_fases.append(load("res://assets/levels/level1.tres"))
	# lista_fases.append(load("res://scripts/resources/levels/Fase2.tres"))
	pass

# Chamado pelo Main.gd para saber o que gerar
func get_dados_fase_atual() -> LevelDefinition:
	if lista_fases.is_empty():
		print("LevelManager: Nenhuma fase carregada! Retornando nulo.")
		return null
	
	if indice_fase_atual >= lista_fases.size():
		print("LevelManager: Índice de fase inválido (Fim de jogo?).")
		return null
		
	return lista_fases[indice_fase_atual]

# Chamado quando o jogador entra na saída
func avancar_para_proxima_fase():
	indice_fase_atual += 1
	
	if indice_fase_atual < lista_fases.size():
		print("LevelManager: Carregando fase ", indice_fase_atual)
		# Reinicia a cena Main, que vai ler o novo índice no _ready
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	else:
		print("LevelManager: Fim da lista de fases! Vitória!")
		# Aqui você chamaria a tela de "Zerou o Jogo" ou voltaria pro Hub
		# get_tree().change_scene_to_file("res://scenes/VictoryScreen.tscn")

# Útil para debug ou para o Hub selecionar fase
func carregar_fase_especifica(index: int):
	if index >= 0 and index < lista_fases.size():
		indice_fase_atual = index
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
