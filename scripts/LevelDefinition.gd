class_name LevelDefinition
extends Resource

@export_group("Configuração Geral")
@export var nome_fase: String = ""
@export_multiline var texto_intro: String = ""
@export var musica_fundo: AudioStream
@export var seed_fixa: int = 0 # 0 = Aleatório

@export_group("Dimensões e Ambiente")
@export var tamanho: Vector2i = Vector2i(23, 23)
@export var fog_enabled: bool = false
# Aqui poderíamos ter um Enum para Bioma (ex: CAVERNA, LAB, FLORESTA)
@export var bioma_tipo: int = 0

@export_group("Modo de Jogo")
@export_enum("NORMAL", "MST") var modo_jogo: String = "NORMAL"
@export var tempo_par_tolerancia: float = 2.0 # Multiplicador para o Good Ending
@export var qtd_terminais: int = 0 # Apenas usado se modo == MST

@export_group("Geração Procedural")
# Configurações para o algoritmo de salas (Room generation)
@export var salas_qtd: int = 0
@export var salas_tamanho_min: int = 2
@export var salas_tamanho_max: int = 4
# Configuração para quebrar paredes (Cycles)
@export_range(0.0, 1.0) var chance_quebra_paredes: float = 0.15

@export_group("Terreno e Objetos")
# Usaremos nomes string para facilitar a leitura no Inspector, ou Enums se preferir
@export var qtd_portas: int = 10
@export var qtd_paredes_bomba: int = 0
# Dicionário: Chave (String tipo "Lava") -> Valor (Int quantidade)
@export var tiles_especiais: Dictionary = {
	"Lava": 0,
	"Lama": 0,
	"Veneno": 0
}
@export var qtd_moedas: int = 0

@export_group("Entidades - Inimigos")
# Em vez de Dictionary, usamos Array tipado com nossa nova classe
@export var lista_inimigos: Array[EnemySpawnData] = []

@export_group("Entidades - NPCs")
# O mesmo para os NPCs
@export var lista_npcs: Array[NpcSpawnData] = []
