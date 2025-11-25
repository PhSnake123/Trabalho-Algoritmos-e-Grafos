class_name BellmanFord

var grafo: Graph
var distancias = {}
var predecessores = {}
var tem_ciclo_negativo = false

func _init(p_grafo: Graph):
	self.grafo = p_grafo

"""
Calcula o caminho mínimo permitindo pesos negativos.
Retorna um dicionário com distâncias, predecessores e se detectou ciclo negativo.
"""
func calcular_caminho(inicio: Vector2i) -> Dictionary:
	# 1. Inicialização
	# Pega todos os vértices válidos do grafo (chaves do dicionário de adjacências)
	var vertices = grafo.adjacencias.keys()
	
	for v in vertices:
		distancias[v] = INF
		predecessores[v] = null
	
	distancias[inicio] = 0
	
	# 2. Relaxamento Repetido (V - 1 vezes)
	# O Bellman-Ford garante o caminho mínimo repetindo o processo V-1 vezes
	var num_vertices = vertices.size()
	
	# Dica de Performance para Godot: 
	# Em grids grandes (1500 vertices), isso pode travar o jogo por 1 seg.
	# Se precisar otimizar depois, pesquisem sobre o algoritmo SPFA.
	for i in range(num_vertices - 1):
		var houve_mudanca = false
		
		# Itera sobre TODAS as arestas do grafo
		for u in vertices:
			# Se u ainda é inalcançável, não podemos relaxar seus vizinhos
			if distancias[u] == INF:
				continue
				
			# Verifica vizinhos de u
			# Aresta: u -> v com peso 'peso'
			for aresta in grafo.adjacencias[u]:
				var v: Vector2i = aresta[0]
				var peso: int = aresta[1]
				
				if distancias[u] + peso < distancias[v]:
					distancias[v] = distancias[u] + peso
					predecessores[v] = u
					houve_mudanca = true
		
		# Otimização clássica: Se em uma passada nada mudou, podemos parar antes.
		if not houve_mudanca:
			break
			
	# 3. Verificação de Ciclo Negativo
	# Rodamos mais uma vez. Se ainda for possível relaxar algo, existe um ciclo negativo.
	tem_ciclo_negativo = false
	for u in vertices:
		if distancias[u] == INF:
			continue
			
		for aresta in grafo.adjacencias[u]:
			var v = aresta[0]
			var peso = aresta[1]
			
			if distancias[u] + peso < distancias[v]:
				tem_ciclo_negativo = true
				print("Bellman-Ford: Ciclo negativo detectado acessível a partir de ", inicio)
				break # Pode parar assim que achar um
		
		if tem_ciclo_negativo:
			break

	return {
		"distancias": distancias, 
		"predecessores": predecessores, 
		"ciclo_negativo": tem_ciclo_negativo
	}

"""
Reconstrói o caminho igual ao Dijkstra.
"""
func reconstruir_caminho(inicio: Vector2i, fim: Vector2i) -> Array[Vector2i]:
	if tem_ciclo_negativo:
		print("Aviso: Tentando reconstruir caminho em grafo com ciclo negativo.")
		# Dependendo da regra do jogo, você pode retornar vazio ou o caminho até o momento.
	
	var caminho: Array[Vector2i] = []
	var atual = fim
	
	if not predecessores.has(atual):
		return []
		
	while atual != null:
		caminho.push_back(atual)
		if atual == inicio:
			break
		atual = predecessores.get(atual)
	
	caminho.reverse()
	
	if caminho.is_empty() or caminho[0] != inicio:
		return []
		
	return caminho
