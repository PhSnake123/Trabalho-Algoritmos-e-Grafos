<div align="center">

# Grafos Quest

> *"Otimizar é eliminar o humano. Nós somos o erro no sistema."*

![Godot Engine](https://img.shields.io/badge/Godot-v4.5-%23478cbf?logo=godot-engine&logoColor=white)
![Status](https://img.shields.io/badge/Status-Em_Desenvolvimento-orange)
![License](https://img.shields.io/badge/License-MIT-green)

<div align="center">
  <img src="https://media.discordapp.net/attachments/420419746044051457/1443045401363222578/grafoslogo.png?ex=6927a442&is=692652c2&hm=3ae1ec8d98f25bd3cc31d2a397e69b7ab1e4205856c4d5b1494458f38cbd7ab2&=&format=webp&quality=lossless&width=1376&height=848" alt="logo" width="600">
</div>

> *Logo provisório gerado pelo Gemini.*
</div>

---

## Sobre o Projeto

**Grafos Quest** é um Dungeon Crawler procedural desenvolvido em **Godot 4.5** como trabalho acadêmico para a disciplina de Algoritmos e Grafos da Universidade Federal do Rio de Janeiro, aplicando conceitos teóricos em mecânicas de gameplay.

Em um futuro distópico onde a realidade foi substituída por um "Grafo Perfeito", você joga como uma anomalia: uma aresta errante tentando atravessar labirintos de dados, salvar fragmentos corrompidos e desafiar a tirania da otimização absoluta de uma realidade em que tudo é produtividade.

O código deste projeto foi gerado com auxílio do Gemini Pro 3. Assets gráficos e musicais foram retirados dos websites:

https://kenney.nl/assets

https://opengameart.org/

https://itch.io/

https://incompetech.com/

https://freesound.org/

---

## Mecânicas e Algoritmos

O projeto foi feito para ilustrar possíveis aplicações práticas de algoritmos de grafos:

### Geração Procedural e Navegação
* **DFS (Depth-First Search):** Utilizado na geração procedural para escavar o labirinto, garantindo que cada nível seja único, denso e totalmente conectado.
* **Dijkstra:** Calcula o custo mínimo de movimento pelo mapa inteiro do vértice de início ao vértice de saída. Define o "Tempo PAR" (a meta de eficiência) e controla a IA dos inimigos do tipo "Stalker".
* **A\* (A-Star):** Utilizado por alguns itens Drones e IA de inimigos que evitam dano de terreno. Traça um caminho ótimo para o jogador e inimigos em tempo real, utilizando uma heurística que pondera distância vs. perigo.
* **BFS (Breadth-First Search):** Utilizado na **Fog of War** e no sistema de Drones de Área (Scanner/Terraformer) para calcular alcance radial ignorando paredes.

### Árvore Geradora Mínima (MST)
Em fases especiais (Modo MST), o objetivo muda: o jogador deve reconectar terminais isolados com o menor custo total possível. O jogo utiliza internamente o **algoritmo de Prim** para validar a solução ótima e gerar o desafio.

Os algoritmos de grafo acima são utilizados em quase todos os aspectos do jogo: a IA dos inimigos, itens, geração de mapas, posicionamento do save point, cálculo do tempo mínimo, etc.

---

## Como Jogar

<div align="center">
  <img src="https://media.discordapp.net/attachments/420419746044051457/1443049195828285591/image.png?ex=6927a7ca&is=6926564a&hm=459c62f0f3de1d74ae61b9cefdcc807b0a07da24229b59d978371c207e2671b6&=&format=webp&quality=lossless" alt="Gameplay Demo" width="600">
</div>

1.  **Mova-se:** Use as setas ou `WASD`. O jogo é baseado em turnos: inimigos só se movem quando você se move.
2.  **Otimize:** Cada passo conta. Seu objetivo é bater o **Tempo PAR** calculado pelo algoritmo de Djikstra.
3.  **Sobreviva:** Inimigos possuem IAs distintas. Use o terreno e itens disponíveis ao seu favor.
4.  **Hackeie:** Use seu inventário de Drones para revelar caminhos, limpar terrenos perigosos, calcular rotas de fuga e mais.
5.  **Escolhas:** Salvar NPCs custa tempo e eficiência. Você buscará otimizar o caminho ou salvar os necessitados?

---

## Arquitetura Técnica

O código foi arquitetado em conjunto com o Gemini Pro 3, focando em **Data-Driven Design** e modularidade:

* **`LevelManager`:** Singleton responsável por carregar fases, aplicar paletas de cores, configurar a música e gerenciar a progressão.
* **`MapGenerator`:** Classe pura que manipula arrays de dados para criar o grid lógico antes de renderizar, permitindo a inserção de salas e rotas alternativas.
* **`SaveManager`:** Sistema robusto que persiste o estado do mundo, inventário e flags narrativas utilizando Dicionários e Resources. É o **Banco de Dados** do jogo.
* **`Graph.gd`:** A representação matemática do mundo, convertendo o TileMap em uma lista de adjacências ponderada para uso nos algoritmos de busca. Cada fase é um grafo.

---

## 👥 Equipe de Desenvolvimento

Bruno da Cruz Mendonça

Pedro Henrique da Cruz Mendonça

Felipe Castro

Leonardo Vilaça

Victor Pereira

<div align="center">

###

</div>