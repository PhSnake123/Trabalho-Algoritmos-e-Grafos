# res://scripts/resources/Inventory.gd
class_name Inventory
extends Resource

# (Fase 1.2)
# Estes sinais são para a UI (Fase 5).
# Quando um item for adicionado, a UI vai ouvir este sinal
# e adicionar um ícone novo na tela.
signal item_adicionado(item: ItemData)
signal item_removido(item: ItemData)
signal inventario_resincronizado

# O array que armazena os dados dos nossos itens.
# Ao usar @export, poderemos ver os itens no Inspetor (ótimo para debug).
@export var items: Array[ItemData] = []


# --- Funções Principais do Inventário ---

"""
Adiciona um item (Resource) ao array e avisa a UI.
"""
func adicionar_item(item: ItemData):
	if not item:
		print("WARNING - Inventory: Tentativa de adicionar item nulo.")
		return
		
	items.push_back(item)
	item_adicionado.emit(item)
	print("Inventory: '", item.nome_item, "' adicionado.")


"""
Remove um item do array e avisa a UI.
"""
func remover_item(item: ItemData):
	if not item:
		print("WARNING - Inventory: Tentativa de remover item nulo.")
		return
		
	if items.has(item):
		items.erase(item)
		item_removido.emit(item)
		print("Inventory: '", item.nome_item, "' removido.")
	else:
		print("WARNING - Inventory: Tentativa de remover '", item.nome_item, "' que não existe.")


"""
Limpa todos os itens. (Usado no reset_run_state)
"""
func clear_items():
	items.clear()
	# (Opcional: emitir sinais de remoção para a UI aqui)
	print("Inventory: Inventário limpo.")


# --- Funções de Busca (Helpers) ---

"""
Verifica se o inventário contém pelo menos um item de um tipo específico.
Ex: tem_item_por_tipo(ItemData.ItemTipo.CHAVE)
"""
func tem_item_por_tipo(tipo: ItemData.ItemTipo) -> bool:
	for item in items:
		if item.tipo_item == tipo:
			return true # Encontrou!
	return false # Não encontrou


"""
Retorna o *primeiro* item encontrado de um tipo específico.
Útil para pegar a chave para abrir a porta.
"""
func get_item_por_tipo(tipo: ItemData.ItemTipo) -> ItemData:
	for item in items:
		if item.tipo_item == tipo:
			return item # Retorna o Resource ItemData
	return null # Não encontrou

"""
Retorna o primeiro item que possui um efeito específico.
Ex: get_item_por_efeito(ItemData.EFEITO_DRONE_PATH_ASTAR)
"""
func get_item_por_efeito(efeito_desejado: String) -> ItemData:
	for item in items:
		if item.efeito == efeito_desejado:
			return item # Retorna o Resource correto
	return null # Não encontrou item com esse efeito	

"""
Retorna item filtrando por Efeito E Tipo.
Útil para distinguir Drone A* (Temporário) de Drone A* 	(Permanente).
"""
func get_item_especifico(efeito: String, tipo: ItemData.ItemTipo) -> ItemData:
	for item in items:
		if item.efeito == efeito and item.tipo_item == tipo:
			return item
	return null
	
func resincronizar_itens(novos_itens: Array[ItemData]):
	items = novos_itens
	# Avisa quem estiver ouvindo (UI) que a lista foi totalmente trocada
	inventario_resincronizado.emit()
	print("Inventory: Lista de itens resincronizada via Load.")
