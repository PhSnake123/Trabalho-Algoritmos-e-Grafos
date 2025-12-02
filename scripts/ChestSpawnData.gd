# res://scripts/resources/ChestSpawnData.gd
class_name ChestSpawnData
extends Resource

@export_group("Conteúdo e Quantidade")
@export var item_recompensa: ItemData # Se nulo, será um baú de moedas
@export var qtd_moedas: int = 50      # Só usado se item_recompensa for null
@export var quantidade: int = 1

@export_group("Posicionamento")
# Se for (-1, -1), usa a lógica aleatória.
# CUIDADO: Se você colocar Quantidade > 1 e Posição Fixa, todos nascerão empilhados no mesmo lugar!
@export var posicao_fixa: Vector2i = Vector2i(-1, -1)
