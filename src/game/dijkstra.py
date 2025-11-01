import heapq

class Dijkstra:
    """
    Implementação do algoritmo de Dijkstra para grafos representados como
    dicionários de adjacência.
    """
    def __init__(self, grafo):
        """
        grafo: instância da classe Grafo (ou qualquer objeto com
               atributo `adjacencias` no formato {vertice: [(vizinho, custo), ...]})
        """
        self.grafo = grafo
        self.distancias = {}
        self.predecessores = {}

    def calcular_caminho_minimo(self, inicio):
        """
        Calcula distâncias mínimas de 'inicio' para todos os vértices
        usando uma fila de prioridade (heapq).
        """
        self.distancias = {vertice: float('inf') for vertice in self.grafo.adjacencias}
        self.predecessores = {vertice: None for vertice in self.grafo.adjacencias}
        self.distancias[inicio] = 0

        heap = [(0, inicio)]  # (distancia, vertice)

        while heap:
            distancia_atual, vertice_atual = heapq.heappop(heap)

            # Se já encontramos distância melhor, ignoramos
            if distancia_atual > self.distancias[vertice_atual]:
                continue

            for vizinho, custo in self.grafo.adjacencias[vertice_atual]:
                nova_distancia = distancia_atual + custo
                if nova_distancia < self.distancias[vizinho]:
                    self.distancias[vizinho] = nova_distancia
                    self.predecessores[vizinho] = vertice_atual
                    heapq.heappush(heap, (nova_distancia, vizinho))

        return self.distancias, self.predecessores

    def reconstruir_caminho(self, inicio, fim):
        """
        Reconstrói o caminho mínimo do vértice 'inicio' até 'fim'.
        Retorna uma lista de vértices no caminho.
        """
        caminho = []
        atual = fim
        while atual is not None:
            caminho.append(atual)
            atual = self.predecessores.get(atual)
        caminho.reverse()
        if caminho[0] == inicio:
            return caminho
        return []  # caminho não existe
