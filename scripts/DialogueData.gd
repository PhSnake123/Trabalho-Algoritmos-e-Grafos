class_name DialogueData
extends Resource

@export var nome_npc: String = "NPC"
@export var retrato: Texture2D # Opcional: rosto do personagem
@export_multiline var falas: Array[String] = []
# NOVO: Lista de opções. Ex: ["Aceitar", "Recusar"]
# Se estiver vazio, o diálogo encerra normalmente.
@export var opcoes: Array[String] = []
