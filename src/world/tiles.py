from dataclasses import dataclass
import math
@dataclass
class Tile:
    tipo: str #ex: chao, parede, lama, porta, etc
    custo_tempo: float #peso
    dano_hp: int
    passavel: bool

#Instancias do tile:
parede = Tile(
    tipo = "Parede",
    custo_tempo = math.inf,
    dano_hp = 0,
    passavel = False
)

chao = Tile(
    tipo = "Chao",
    custo_tempo = 1.0,
    dano_hp = 0,
    passavel = True
)

lama = Tile(
    tipo = "Lama",
    custo_tempo = 5.0,
    dano_hp = 0,
    passavel = True
)

lava = Tile(
    tipo = "Lava",
    custo_tempo = 1.0,
    dano_hp = -20,
    passavel = True
)

espinhos = Tile(
    tipo = "Espinhos",
    custo_tempo = 1.0,
    dano_hp = -20,
    passavel = True
)

porta = Tile(
    tipo = "Porta",
    custo_tempo = math.inf,
    dano_hp = 0,
    passavel = True
)

escada_subir = Tile(
    tipo = "Escada",
    custo_tempo = 6.0,
    dano_hp = 0,
    passavel = True
)

escada_descer = Tile(
    tipo = "Escada",
    custo_tempo = 1.0,
    dano_hp = 0,
    passavel = True
)

torre = Tile(
    tipo = "Torre",
    custo_tempo = 1.0,
    dano_hp = 0,
    passavel = True
)

terminal = Tile(
    tipo = "Terminal",
    custo_tempo = 1.0,
    dano_hp = 0,
    passavel = True
)

