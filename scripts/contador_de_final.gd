extends Node

func on_level_complete() -> bool:
	var dados = DialogueData.new()
	dados.nome_npc = "Admin"
	
	if Game_State.tempo_jogador <= Game_State.tempo_par_level:
		var count_atual = Game_State.optional_objectives.get("admin_ending_count", 0)
		Game_State.optional_objectives["admin_ending_count"] = count_atual + 1
	return false
