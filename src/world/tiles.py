from dataclasses import dataclass
import math

@dataclass
class Tile:
    Tipo: str          # ex: Chao, Parede, Lama, Porta, etc
    CustoTempo: float  # peso
    DanoHp: int
    Passavel: bool

# Instâncias do tile
Parede = Tile(
    Tipo="Parede",
    CustoTempo=math.inf,
    DanoHp=0,
    Passavel=False
)

Chao = Tile(
    Tipo="Chao",
    CustoTempo=1.0,
    DanoHp=0,
    Passavel=True
)

Lama = Tile(
    Tipo="Lama",
    CustoTempo=5.0,
    DanoHp=0,
    Passavel=True
)

Lava = Tile(
    Tipo="Lava",
    CustoTempo=1.0,
    DanoHp=-20,
    Passavel=True
)

Espinhos = Tile(
    Tipo="Espinhos",
    CustoTempo=1.0,
    DanoHp=-20,
    Passavel=True
)

Porta = Tile(
    Tipo="Porta",
    CustoTempo=math.inf,
    DanoHp=0,
    Passavel=True
)

EscadaSubir = Tile(
    Tipo="Escada",
    CustoTempo=6.0,
    DanoHp=0,
    Passavel=True
)

EscadaDescer = Tile(
    Tipo="Escada",
    CustoTempo=1.0,
    DanoHp=0,
    Passavel=True
)

Torre = Tile(
    Tipo="Torre",
    CustoTempo=1.0,
    DanoHp=0,
    Passavel=True
)

Terminal = Tile(
    Tipo="Terminal",
    CustoTempo=1.0,
    DanoHp=0,
    Passavel=True
)
