# res://scripts/resources/NpcSpawnData.gd
class_name NpcSpawnData
extends Resource

@export var npc_cena: PackedScene # Onde você arrasta a donzela
@export var flag_necessaria: String = "" # A condição (se vazio, nasce sempre)
