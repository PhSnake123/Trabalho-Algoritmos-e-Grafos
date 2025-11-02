class FogOfWar:
    """Controla a névoa de guerra no mapa respeitando paredes, com visão circular + linear em cruz."""

    def __init__(self, largura, altura, raio_visao=3):
        self.largura = largura
        self.altura = altura
        self.raio_visao = raio_visao
        self.fog = [[True for _ in range(largura)] for _ in range(altura)]

    def revelar_area(self, pos_x, pos_y, grid):
        """Revela tiles ao redor do jogador com visão circular + cruz linear."""

        def revelar_circular(cx, cy):
            """Revela mini-área de raio 1 ao redor de (cx, cy), respeitando mapa."""
            for dy in [-1, 0, 1]:
                for dx in [-1, 0, 1]:
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < self.largura and 0 <= ny < self.altura:
                        self.fog[ny][nx] = False

        # --- 1. Visão circular imediata do jogador ---
        revelar_circular(pos_x, pos_y)

        # --- 2. Visão linear em cruz ---
        direcoes = [(0, -1), (0, 1), (-1, 0), (1, 0)]  # N, S, O, L
        for dx, dy in direcoes:
            for passo in range(1, self.raio_visao + 1):
                nx, ny = pos_x + dx * passo, pos_y + dy * passo

                if not (0 <= nx < self.largura and 0 <= ny < self.altura):
                    break  # fora do mapa

                # V atual
                self.fog[ny][nx] = False

                if grid[ny][nx].Passavel:
                    # V passável: revela mini-cruz adjacente
                    for adx, ady in [(0, -1), (0, 1), (-1, 0), (1, 0)]:
                        ax, ay = nx + adx, ny + ady
                        if 0 <= ax < self.largura and 0 <= ay < self.altura:
                            self.fog[ay][ax] = False
                else:
                    # V é parede: revela apenas a si mesmo
                    break

    def esta_visivel(self, x, y):
        if 0 <= x < self.largura and 0 <= y < self.altura:
            return not self.fog[y][x]
        return False

    def imprimir_fog(self, grid, jogador=None):
        for y in range(self.altura):
            linha = ""
            for x in range(self.largura):
                if jogador and jogador.x == x and jogador.y == y:
                    linha += "P "
                elif self.fog[y][x]:
                    linha += "??"
                else:
                    linha += "  " if grid[y][x].Passavel else "██"
            print(linha)
