extends Node

func _ready():
	print("--- Iniciando Teste de Bellman-Ford ---")
	
	# 1. Cria um Grid Mockado (falso) pequeno 3x3
	# 0 1 2
	# 3 4 5
	# 6 7 8
	var grid = []
	for y in range(21):
		var linha = []
		for x in range(31):
			var tile = MapTileData.new()
			tile.passavel = true
			tile.custo_tempo = 1.0 # Custo padrão
			linha.push_back(tile)
		grid.push_back(linha)
	
	# 2. Cria o Grafo
	var graph = Graph.new(grid)
	
	# 3. INJETA UMA ARESTA NEGATIVA MANUALMENTE (Hack para teste)
	# Vamos dizer que ir de (0,0) para (0,1) recupera tempo (-5)
	# O Graph.gd gera arestas baseado no grid, então precisamos mexer na 'adjacencias' direto pro teste
	# Aresta (0,0) -> (0,1) com custo -5
	var v_origem = Vector2i(0,0)
	var v_destino = Vector2i(0,1)
	
	# Procura a aresta e muda o peso
	for i in range(graph.adjacencias[v_origem].size()):
		if graph.adjacencias[v_origem][i][0] == v_destino:
			graph.adjacencias[v_origem][i][1] = -5 # Peso Negativo!
			print("Hack: Aresta (0,0)->(0,1) alterada para custo -5")

	# 4. Roda Bellman-Ford
	var bf = BellmanFord.new(graph)
	var resultado = bf.calcular_caminho(Vector2i(0,0))
	
	if resultado["ciclo_negativo"]:
		print("Ciclo negativo encontrado!")
	else:
		print("Caminho calculado com sucesso.")
		print("Custo para (0,1): ", resultado["distancias"][Vector2i(0,1)]) # Esperado: -5
		
		var caminho = bf.reconstruir_caminho(Vector2i(0,0), Vector2i(0,2))
		print("Caminho até (0,2): ", caminho)
