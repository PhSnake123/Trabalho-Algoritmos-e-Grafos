from world import world_map
from game.player import Player
from game.fog_of_war import FogOfWar
import random

def main():
    # 1. Gerar grid
    grid = world_map.gerar_grid()
    world_map.gerar_labirinto(grid)

    # 2. Criar jogador
    jogador = Player(x=1, y=1, tempo=100, hp=100)

    # 3. Criar fog of war
    fog = FogOfWar(largura=len(grid[0]), altura=len(grid), raio_visao=3)
    fog.revelar_area(jogador.x, jogador.y, grid)

    # 4. Função de impressão com jogador
    def imprimir_com_jogador(fog, grid, jogador):
        for y in range(fog.altura):
            linha = ""
            for x in range(fog.largura):
                if jogador.x == x and jogador.y == y:
                    linha += "P "
                elif fog.fog[y][x]:
                    linha += "??"
                else:
                    linha += "  " if grid[y][x].Passavel else "██"
            print(linha)

    # 5. Exibir labirinto inicial com fog
    print("=== Labirinto Inicial com Fog of War ===")
    imprimir_com_jogador(fog, grid, jogador)

    # 6. Simular 10 passos aleatórios do jogador sem repetir casas
    movimentos_possiveis = [(0, -1), (0, 1), (-1, 0), (1, 0)]  # N, S, O, L
    visitadas = {(jogador.x, jogador.y)}

    for passo in range(10):
        random.shuffle(movimentos_possiveis)
        moved = False
        for dx, dy in movimentos_possiveis:
            nx, ny = jogador.x + dx, jogador.y + dy
            if (0 <= nx < len(grid[0]) and 0 <= ny < len(grid)
                    and grid[ny][nx].Passavel
                    and (nx, ny) not in visitadas):
                jogador.x, jogador.y = nx, ny
                fog.revelar_area(jogador.x, jogador.y, grid)
                visitadas.add((nx, ny))
                moved = True
                break  # apenas um movimento por passo

        if not moved:
            print(f"\n=== Passo {passo+1}: sem movimentos novos disponíveis ===")
        else:
            print(f"\n=== Labirinto após passo {passo+1} ===")
        imprimir_com_jogador(fog, grid, jogador)

if __name__ == "__main__":
    main()
