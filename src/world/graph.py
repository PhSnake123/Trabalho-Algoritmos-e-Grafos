from collections import defaultdict


class Grafo:
    def __init__(self, grid):
        """
        Constrói um grafo a partir de um grid de tiles.
        Cada célula passável vira um vértice.
        """
        self.grid = grid
        self.largura = len(grid[0])
        self.altura = len(grid)
        self.adjacencias = defaultdict(list)
        self.construir_grafo()

    def construir_grafo(self):
        """Cria a lista de adjacência do grafo considerando custos de tiles."""
        for y in range(self.altura):
            for x in range(self.largura):
                if not self.e_passavel(x, y):
                    continue  # Ignora paredes

                for vizinho in self.obter_vizinhos(x, y):
                    nx, ny = vizinho
                    custo = self.grid[ny][nx].custo_tempo
                    self.adjacencias[(x, y)].append(((nx, ny), custo))

    def e_passavel(self, x, y):
        """Retorna True se o tile é passável."""
        return self.grid[y][x].passavel

    def obter_vizinhos(self, x, y):
        """Retorna coordenadas de vizinhos passáveis (N, S, L, O)."""
        direcoes = [(0, -1), (0, 1), (-1, 0), (1, 0)]
        vizinhos_validos = []

        for dx, dy in direcoes:
            nx, ny = x + dx, y + dy
            if 0 <= nx < self.largura and 0 <= ny < self.altura:
                if self.e_passavel(nx, ny):
                    vizinhos_validos.append((nx, ny))

        return vizinhos_validos

# Função utilitária para imprimir o grafo (opcional)
def imprimir_grafo(grafo):
    for vertice, arestas in grafo.adjacencias.items():
        print(f"{vertice}: {arestas}")
