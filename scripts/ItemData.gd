# res://scripts/resources/ItemData.gd
class_name ItemData
extends Resource

# (Fase 1.1) Enum para categorizar os itens
enum ItemTipo { 
	GENERICO, 
	CHAVE, 
	POTION, 
	EQUIP, 
	OBJETIVO, 
	DRONE,
	DRONE_TEMPORARIO
}

# Variável auxiliar para persistência, já que duplicate() apaga o resource_path
var arquivo_origem: String = ""

# (Fase 1.1) Strings para definir o que um item faz
# Usamos strings para flexibilidade. O 'main.gd' ou 'player.gd'
# vai ler esta string e decidir o que fazer.
const EFEITO_CURA_HP = "CURA_HP"
const EFEITO_ABRE_PORTA = "ABRE_PORTA"
# Efeitos dos Drones
const EFEITO_DRONE_RECON_BFS = "DRONE_RECON_BFS"
const EFEITO_DRONE_PATH_DIJKSTRA = "DRONE_PATH_DIJKSTRA"
const EFEITO_DRONE_PATH_ASTAR = "DRONE_PATH_ASTAR"
const EFEITO_DRONE_PATH_BELLMAN = "DRONE_PATH_BELLMAN"
const EFEITO_DRONE_GEO_BFS = "DRONE_GEO_BFS"
const EFEITO_DRONE_ANALISE_PONTE = "DRONE_ANALISE_PONTE"
const EFEITO_SAVE_GAME = "SAVE_GAME"
const EFEITO_DRONE_SCANNER = "DRONE_SCANNER"
const EFEITO_DRONE_TERRAFORMER = "DRONE_TERRAFORMER"
# --- Propriedades do Item ---
# Estas variáveis aparecerão no Inspetor do Godot
# quando criarmos os arquivos .tres

@export var nome_item: String = "Item"

@export_multiline var descricao: String = "Uma breve descrição do item."

@export var tipo_item: ItemTipo = ItemTipo.GENERICO

@export var preco_base: int = 0

@export var efeito: String = "" # Ex: "CURA_HP" ou "DRONE_RECON_BFS"

# Um valor numérico para o efeito (ex: 20.0 para CURA_HP, ou 5.0 para raio do drone)
@export var valor_efeito: float = 0.0 

#Define o comprimento do caminho desenhado (em tiles).
# -1 = Caminho inteiro até o destino.
@export var alcance_maximo: int

# Quantas vezes pode ser usado. -1 = infinito (equipamento), 1 = consumível
@export var durabilidade: int = 1 

@export var textura_icon: Texture2D # O ícone que aparecerá no HUD
