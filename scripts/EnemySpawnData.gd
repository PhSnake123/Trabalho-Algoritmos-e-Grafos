# res://scripts/resources/EnemySpawnData.gd
class_name EnemySpawnData
extends Resource

@export_group("Básico")
@export var inimigo_cena: PackedScene 
@export var quantidade: int = 1       
@export var flag_secreta: String = "" 
@export_enum("Padrão da Cena:-1", "Stalker (Dijkstra):0", "Smart (A*):1") var ai_type: int = -1
@export_enum("Padrão da Cena:-1", "Padrão:0", "Sentinela:1", "Patrulheiro:2", "Turret:3") var behavior: int = -1
@export var raio_deteccao: int = -1 # -1 usa o padrão do script do inimigo

# Economia
@export_group("Economia")
@export var moedas_drop: int = 5 # Valor fixo que o inimigo dropa

@export_group("Customização Visual")
# Se for Branco (1,1,1,1), o inimigo mantém a cor original.
@export var cor_modulate: Color = Color.WHITE

@export_group("Override de Atributos (-1 = Padrão)")
# Definimos -1 como "Não mexa nisso, use o valor da cena original"
@export var hp_maximo: int = -1
@export var ataque: int = -1
@export var defesa: int = -1
@export var poise: int = -1
@export var knockback: int = -1
@export var passos_por_turno: int = -1
