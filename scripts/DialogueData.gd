class_name DialogueData
extends Resource

@export var nome_npc: String = "NPC"
@export var retrato: Texture2D # Opcional: rosto do personagem
@export_multiline var falas: Array[String] = [
	"Olá, viajante.",
	"Cuidado com os caminhos vermelhos."
]
