-- ScoreKeeper: semua aturan poin, combo, dan hati tinggal di sini.
-- Modul ini hanya membaca dan menulis StateStore; tidak menyentuh dunia 3D.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local StateStore = require(Shared:WaitForChild("StateStore"))

local ScoreKeeper = {}

-- Waktu (os.clock) wisp terakhir dikumpulkan; dipakai untuk jendela combo.
local lastWispTime = 0

-- Dipanggil saat pemain menyentuh wisp. Menghitung poin dari combo yang
-- sedang berjalan, lalu menaikkan combo untuk wisp berikutnya.
-- Mengembalikan poin yang didapat.
function ScoreKeeper.collectWisp(): number
	local now = os.clock()
	local snapshot = StateStore.getSnapshot()

	local combo = snapshot.Combo
	if now - lastWispTime > Config.Scoring.ComboWindowSeconds then
		combo = 0
	end
	lastWispTime = now

	local multiplier = math.min(combo + 1, Config.Scoring.ComboMax)
	local waveBonus = 1
	if snapshot.Wave == #Config.Waves then
		waveBonus = Config.Scoring.WaveFiveBonus
	end
	local points = Config.Scoring.WispBasePoints * multiplier * waveBonus

	StateStore.setScore(snapshot.Score + points)
	StateStore.setCombo(combo + 1, multiplier)
	StateStore.addCollectedWisp()
	return points
end

-- Sentuhan shadow memutus combo dan menghabiskan jendela combo.
function ScoreKeeper.breakCombo()
	StateStore.setCombo(0, 1)
	lastWispTime = 0
end

-- Mengurangi satu hati; mengembalikan jumlah hati yang tersisa.
function ScoreKeeper.loseHeart(): number
	local hearts = StateStore.getSnapshot().Hearts - 1
	StateStore.setHearts(hearts)
	ScoreKeeper.breakCombo()
	return hearts
end

-- Mengembalikan permainan ke kondisi awal untuk ronde baru.
function ScoreKeeper.resetForNewGame()
	lastWispTime = 0
end

return ScoreKeeper
