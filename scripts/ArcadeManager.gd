extends Node

# --- CONFIGURAÇÕES DE BALANCEAMENTO ---
const TAMANHO_INICIAL = 15 
const TAMANHO_MAXIMO = 81
const AUMENTO_POR_FASE = 2
const TOLERANCIA_INICIAL = 2.0
const TOLERANCIA_MAXIMA = 3.0

# Cura ao iniciar nova fase (1.0 = 100%, 0.5 = 50%)
const CURA_ENTRE_FASES_PCT: float = 1.0 

# Configurações MST
const CHANCE_MODO_MST = 0.3 # 50%
const TERMINAIS_MIN = 1
const TERMINAIS_MAX = 5

# Configuração de Perigos (Tiles de Dano)
const TILES_DANO_MIN = 3
const TILES_DANO_MAX = 100

# Arrays de Assets
const INIMIGOS_FACEIS = ["res://scenes/Enemy.tscn", "res://scenes/EnemyCoward.tscn"]
const INIMIGOS_DIFICEIS = ["res://scenes/EnemyMalware.tscn",
	"res://scenes/EnemyTurret.tscn"]
const BOSS_MONSTER = ["res://scenes/EnemyStalker.tscn"]
const MUSICAS_DISPONIVEIS = [
	"res://Audio/music/Erik_Satie_Gymnopédie_No.1.ogg",
	"res://Audio/music/MoonlightSonata.mp3",
	"res://Audio/music/icy.mp3",
	"res://Audio/music/adventurous.mp3",
	"res://Audio/music/Alexander Ehlers - Doomed.mp3",
	"res://Audio/music/Alexander Ehlers - Warped.mp3",
	"res://Audio/music/BossMain.wav",
	"res://Audio/music/Map.wav",
	"res://Audio/music/Mars.wav",
	"res://Audio/music/Mercury.wav",
	"res://Audio/music/Venus.wav",
	"res://Audio/music/Theme Crystalized .mp3"
]
const ITENS_PERMITIDOS = [
	"res://assets/iteminfo/potion.tres",
	"res://assets/iteminfo/SUPERpotion.tres",
	"res://assets/iteminfo/chave.tres",
	"res://assets/iteminfo/DroneTerraformer.tres",
	"res://assets/iteminfo/DroneDJKISTRA.tres",
	"res://assets/iteminfo/DroneAStar.tres",
	"res://assets/iteminfo/DroneHunter.tres",
	"res://assets/iteminfo/DroneAStarPerm.tres",
	"res://assets/iteminfo/escopeta.tres",
	"res://assets/iteminfo/boots.tres",
	"res://assets/iteminfo/DroneDJKISTRA.tres",
	"res://assets/iteminfo/DroneAStar.tres",
	"res://assets/iteminfo/DroneAStarPerm.tres",
	"res://assets/iteminfo/chave.tres",
	"res://assets/iteminfo/DroneDJKISTRA.tres",
	"res://assets/iteminfo/DroneAStar.tres",
	"res://assets/iteminfo/DroneAStarPerm.tres",
	"res://assets/iteminfo/PrimTEMP.tres",
	"res://assets/iteminfo/chave.tres",
	"res://assets/iteminfo/DroneHunter.tres",
	"res://assets/iteminfo/escopeta.tres",
	"res://assets/iteminfo/potion.tres",
	"res://assets/iteminfo/DroneDJKISTRA.tres",
	"res://assets/iteminfo/DroneAStar.tres",
	"res://assets/iteminfo/DroneAStarPerm.tres",
	"res://assets/iteminfo/PrimTEMP.tres"
]

# --- ESTADO ATUAL ---
var nivel_atual: int = 1
var pontuacao_acumulada: int = 0
var is_arcade_mode: bool = false
var current_level_resource: LevelDefinition = null 

# --- FLUXO DE JOGO ---

func iniciar_run():
	randomize()
	is_arcade_mode = true
	nivel_atual = 1
	pontuacao_acumulada = 0
	_gerar_e_armazenar_nivel()

func avancar_nivel():
	nivel_atual += 1
	#CURA ENTRE FASES ---
	var cura = int(Game_State.stats_jogador["max_hp"] * CURA_ENTRE_FASES_PCT)
	Game_State.vida_jogador = min(Game_State.stats_jogador["max_hp"], Game_State.vida_jogador + cura)
	_gerar_e_armazenar_nivel()

func finalizar_run():
	is_arcade_mode = false
	current_level_resource = null

func add_score(valor: int):
	pontuacao_acumulada += valor
	print("Arcade Score Total: ", pontuacao_acumulada)

# --- FÁBRICA DE NÍVEL ---

func _gerar_e_armazenar_nivel():
	var def = LevelDefinition.new()
	
	# 1. Identidade e Tamanho
	def.nome_fase = "Arcade Nível " + str(nivel_atual)
	var t = min(TAMANHO_INICIAL + ((nivel_atual - 1) * AUMENTO_POR_FASE), TAMANHO_MAXIMO)
	if t % 2 == 0: t += 1 
	def.tamanho = Vector2i(t, t)
	
	# 2. Configuração do Labirinto
	def.salas_qtd = randi_range(3, 3 + int(nivel_atual / 2.0))
	def.salas_tamanho_min = 3
	def.salas_tamanho_max = 6
	def.chance_quebra_paredes = randf_range(0.05, 0.2)
	def.qtd_portas = randi_range(5, 10 + nivel_atual)
	def.gerar_save_point = false
	
	# 3. Tiles de Perigo (Dano/Lama) - Aumenta com o nível
	var progressao = float(t - TAMANHO_INICIAL) / float(TAMANHO_MAXIMO - TAMANHO_INICIAL)
	var qtd_dano = int(lerpf(TILES_DANO_MIN, TILES_DANO_MAX, progressao))
	
	# Inicializa o dicionário corretamente
	def.tiles_especiais = {
		"Dano": qtd_dano,
		"Lama": randi_range(0, 5) # Um pouco de lama aleatória
	}
	
	# 4. Decidir Modo de Jogo (String Explícita)
	# 4. Decidir Modo de Jogo
	if randf() < CHANCE_MODO_MST:
		# --- MODO MST ---
		def.modo_jogo = "MST"
		
		# Calcula terminais
		var qtd_terminais = min(TERMINAIS_MIN + int((nivel_atual - 1) / 4.0), TERMINAIS_MAX)
		qtd_terminais = max(1, qtd_terminais) # Garante pelo menos 2
		
		# --- CORREÇÃO 2: DEFINE A VARIÁVEL QUE O MAIN.GD LÊ ---
		# Antes estava faltando essa linha, por isso o Main achava que eram 0 terminais.
		def.qtd_terminais = qtd_terminais 
		
		# Adiciona ao dicionário de tiles especiais para o MapGenerator saber o que spawnar
		def.tiles_especiais["Terminal"] = qtd_terminais
		def.nome_fase += " (MST)"
	else:
		# --- MODO NORMAL ---
		def.modo_jogo = "NORMAL"
		def.qtd_terminais = 0
		def.tiles_especiais["Terminal"] = 0
	
	# 5. Fog e Inimigos
	def.fog_enabled = (randf() < 0.05)
	def.lista_inimigos = _gerar_lista_inimigos(nivel_atual)
	
	# 6. Baús
	def.lista_baus_especificos = _gerar_lista_baus(nivel_atual)
	def.qtd_baus = def.lista_baus_especificos.size()
	
	# 7. Moedas
	def.qtd_moedas = 10 + (nivel_atual * 2)
	
	# 8. Tolerância de Tempo (Calculada aqui para o Main ler depois)
	def.tempo_par_tolerancia = get_time_tolerance_factor()
	
	# --- 9. NOVO: INJEÇÃO DE MÚSICA ALEATÓRIA ---
	if MUSICAS_DISPONIVEIS.size() > 0:
		var musica_path = MUSICAS_DISPONIVEIS.pick_random()
		if ResourceLoader.exists(musica_path):
			def.musica_fundo = load(musica_path)
			print("Arcade: Música selecionada -> ", musica_path.get_file())
		else:
			print("Arcade: ERRO - Música não encontrada no caminho: ", musica_path)
	
	print("--- ARCADE GERADO: ", def.nome_fase, " | Tamanho: ", def.tamanho, " | Modo: ", def.modo_jogo)
	current_level_resource = def

# --- MÉTODOS AUXILIARES ---

var spawn_boss = 0.7

func _gerar_lista_inimigos(nivel: int) -> Array[EnemySpawnData]:
	var lista: Array[EnemySpawnData] = []
	var qtd = int(nivel)
	for i in range(qtd):
		var data = EnemySpawnData.new()
		var path = INIMIGOS_FACEIS.pick_random() if nivel < 3 or randf() <= 0.7 else INIMIGOS_DIFICEIS.pick_random()
		data.inimigo_cena = load(path)
		data.quantidade = 1
		lista.append(data)
	if nivel > 6 and randf() >= spawn_boss:
		var data = EnemySpawnData.new()
		var path = BOSS_MONSTER.pick_random()
		data.inimigo_cena = load(path)
		data.quantidade = 1
		lista.append(data)
	return lista

func _gerar_lista_baus(nivel: int) -> Array[ChestSpawnData]:
	var lista: Array[ChestSpawnData] = []
	var qtd = min(2 + int(nivel / 2.0), 8)
	for i in range(qtd):
		var data = ChestSpawnData.new()
		if randf() < 0.5:
			data.item_recompensa = load(ITENS_PERMITIDOS.pick_random())
			data.qtd_moedas = 0
		else:
			data.item_recompensa = null
			data.qtd_moedas = randi_range(100, 1000)
		data.quantidade = 1
		lista.append(data)
	return lista
	
func get_time_tolerance_factor() -> float:
	if current_level_resource == null: return 1.5
	var size = current_level_resource.tamanho.x
	var t = float(size - TAMANHO_INICIAL) / float(TAMANHO_MAXIMO - TAMANHO_INICIAL)
	return lerpf(TOLERANCIA_INICIAL, TOLERANCIA_MAXIMA, t)
