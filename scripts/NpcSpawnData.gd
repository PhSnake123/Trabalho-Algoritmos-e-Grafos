# res://scripts/resources/NpcSpawnData.gd
class_name NpcSpawnData
extends Resource

@export var npc_cena: PackedScene # Onde você arrasta a donzela
@export var flag_necessaria: String = "" # A condição (se vazio, nasce sempre)
# Posição fixa para mapas manuais (Hub). 
# Se for Vector2i(-1, -1), o sistema ignora e tenta aleatório (útil se quiser aleatório no Hub).
@export var pos_fixa: Vector2i = Vector2i(-1, -1)
