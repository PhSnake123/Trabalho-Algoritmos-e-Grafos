class_name Prim

# Retorna um Dicionário: { "custo": float, "arestas": Array }
# Onde "arestas" é uma lista de pares [Origem, Destino]
static func calcular_mst(grafo_abstrato: Dictionary) -> Dictionary:
	if grafo_abstrato.is_empty():
		return {"custo": 0.0, "arestas": []}
	
	var vertices = grafo_abstrato.keys()
	var inicio = vertices[0]
	
	var custo_total: float = 0.0
	var visitados = {} 
	var min_dists = {} 
	var parent = {} # Rastreia as conexões (Quem é o pai de quem na árvore?)
	
	for v in vertices:
		min_dists[v] = INF
		visitados[v] = false
		parent[v] = null
	
	min_dists[inicio] = 0.0
	
	var arestas_mst = [] # Lista para guardar as conexões finais
	
	for _i in range(vertices.size()):
		var u = null
		var menor_dist = INF
		
		# 1. Escolhe o vértice mais próximo não visitado
		for v in vertices:
			if not visitados[v] and min_dists[v] < menor_dist:
				menor_dist = min_dists[v]
				u = v
		
		if u == null or min_dists[u] == INF:
			break
			
		visitados[u] = true
		custo_total += menor_dist
		
		# 2. Se 'u' tem um pai, grava essa conexão (Isso é uma aresta da MST!)
		if parent[u] != null:
			arestas_mst.push_back([parent[u], u])
		
		# 3. Relaxamento (Atualiza vizinhos)
		var vizinhos_dict = grafo_abstrato[u]
		for v in vizinhos_dict.keys():
			var peso_aresta = vizinhos_dict[v]
			if not visitados[v] and peso_aresta < min_dists[v]:
				min_dists[v] = peso_aresta
				parent[v] = u # <--- Define 'u' como a melhor conexão para 'v'

	return {"custo": custo_total, "arestas": arestas_mst}
