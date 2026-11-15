-- StateStore: SATU tempat state permainan tinggal.
-- Server yang menulis state ini; client hanya menerima salinannya
-- lewat RemoteEvent "GameState" dan tidak pernah menulis balik.
-- Bentuk state yang dikirim ke client selalu hasil getSnapshot().

local Config = require(script.Parent:WaitForChild("Config"))

local StateStore = {}

export type Phase = "Lobby" | "Playing" | "Won" | "Lost"

export type GameState = {
	Phase: Phase,
	Wave: number,
	Score: number,
	Combo: number,
	ComboMultiplier: number,
	Hearts: number,
	WispsCollected: number,
	WaveTarget: number,
	ElapsedSeconds: number,
	WaveTimeLeft: number,
	BestCombo: number,
	TotalWispsCollected: number,
}

local state: GameState = {
	Phase = "Lobby",
	Wave = 0,
	Score = 0,
	Combo = 0,
	ComboMultiplier = 1,
	Hearts = Config.Player.MaxHearts,
	WispsCollected = 0,
	WaveTarget = 0,
	ElapsedSeconds = 0,
	WaveTimeLeft = 0,
	BestCombo = 0,
	TotalWispsCollected = 0,
}

-- Mengembalikan salinan state agar pemanggil tidak bisa mengubah aslinya.
function StateStore.getSnapshot(): GameState
	return table.clone(state)
end

-- Membaca satu field tanpa menyalin seluruh tabel.
function StateStore.getField(fieldName: string)
	return state[fieldName]
end

-- Memulai permainan baru dari nol; dipanggil server saat pemain menekan Play.
function StateStore.resetForNewGame()
	state.Phase = "Playing"
	state.Wave = 1
	state.Score = 0
	state.Combo = 0
	state.ComboMultiplier = 1
	state.Hearts = Config.Player.MaxHearts
	state.WispsCollected = 0
	state.WaveTarget = Config.Waves[1].TargetWisps
	state.ElapsedSeconds = 0
	state.WaveTimeLeft = Config.Waves[1].TimeLimit
	state.BestCombo = 0
	state.TotalWispsCollected = 0
end

-- Pindah ke wave berikutnya; mengembalikan false bila sudah wave terakhir.
function StateStore.advanceWave(): boolean
	local nextWave = state.Wave + 1
	if nextWave > #Config.Waves then
		return false
	end
	state.Wave = nextWave
	state.WispsCollected = 0
	state.WaveTarget = Config.Waves[nextWave].TargetWisps
	state.WaveTimeLeft = Config.Waves[nextWave].TimeLimit
	state.Combo = 0
	state.ComboMultiplier = 1
	return true
end

function StateStore.setPhase(newPhase: Phase)
	state.Phase = newPhase
end

function StateStore.setScore(newScore: number)
	state.Score = newScore
end

function StateStore.setCombo(newCombo: number, newMultiplier: number)
	state.Combo = newCombo
	state.ComboMultiplier = newMultiplier
	if newCombo > state.BestCombo then
		state.BestCombo = newCombo
	end
end

function StateStore.setHearts(newHearts: number)
	state.Hearts = math.max(0, newHearts)
end

function StateStore.addCollectedWisp()
	state.WispsCollected += 1
	state.TotalWispsCollected += 1
end

function StateStore.addElapsedSeconds(seconds: number)
	state.ElapsedSeconds += seconds
end

function StateStore.setWaveTimeLeft(seconds: number)
	state.WaveTimeLeft = math.max(0, seconds)
end

function StateStore.resetWaveTimer()
	state.WaveTimeLeft = Config.Waves[state.Wave].TimeLimit
end

-- Jalan pintas baca yang paling sering dipakai server dan client mirror.
function StateStore.isPlaying(): boolean
	return state.Phase == "Playing"
end

function StateStore.getWaveConfig()
	return Config.Waves[state.Wave]
end

return StateStore
