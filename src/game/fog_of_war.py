from collections import deque
from math import sqrt

class FogOfWar:
    """Controla a névoa de guerra no mapa respeitando paredes, com visão circular + linear."""

    def __init__(self, largura, altura, raio_visao=3):
        self.largura = largura
        self.altura = altura
        self.raio_visao = raio_visao
        # True = coberto, False = visível
        self.fog = [[True for _ in range(largura)] for _ in range(altura)]

    def revelar_area(self, pos_x, pos_y, grid):
        """
        Revela tiles ao redor da posição do jogador sem atravessar paredes.
        1. Revelação circular imediata (diagonais incluídas) de raio 1.
        2. Revelação linear em N/S/L/O até raio_visao (default 3), respeitando paredes.
        """
        # --- Revelação circular ---
        for dy in [-1, 0, 1]:
            for dx in [-1, 0, 1]:
                nx, ny = pos_x + dx, pos_y + dy
                if 0 <= nx < self.largura and 0 <= ny < self.altura:
                    self.fog[ny][nx] = False

        # --- Revelação linear ---
        direcoes = [(0, -1), (0, 1), (-1, 0), (1, 0)]  # N, S, O, L
        for dx, dy in direcoes:
            for passo in range(1, self.raio_visao + 1):
                nx, ny = pos_x + dx * passo, pos_y + dy * passo
                if 0 <= nx < self.largura and 0 <= ny < self.altura:
                    self.fog[ny][nx] = False
                    if not grid[ny][nx].Passavel:
                        break  # parede bloqueia visão linear
                else:
                    break  # fora do mapa

    def esta_visivel(self, x, y):
        """Retorna True se a célula já foi revelada."""
        if 0 <= x < self.largura and 0 <= y < self.altura:
            return not self.fog[y][x]
        return False

    def imprimir_fog(self, grid):
        """Imprime o grid com a névoa no console."""
        for y in range(self.altura):
            linha = ""
            for x in range(self.largura):
                if self.fog[y][x]:
                    linha += "??"
                else:
                    linha += "  " if grid[y][x].Passavel else "██"
            print(linha)
