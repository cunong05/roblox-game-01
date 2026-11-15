-- Lantern Keep — Wisp Rush: semua angka tuning game tinggal di sini.
-- Satu-satunya tempat yang diubah untuk menyeimbangkan permainan.

local Config = {}

-- Palet malam: indigo gelap, lentera emas hangat, wisp teal, shadow merah.
Config.Palette = {
	NightSky = Color3.fromRGB(10, 12, 34),
	ArenaFloor = Color3.fromRGB(24, 26, 54),
	WallTrim = Color3.fromRGB(255, 196, 66),
	LanternGold = Color3.fromRGB(255, 190, 80),
	WispTeal = Color3.fromRGB(64, 224, 208),
	ShadowRed = Color3.fromRGB(214, 48, 49),
	KingPurple = Color3.fromRGB(150, 80, 255),
	HeartRed = Color3.fromRGB(255, 80, 90),
	TextLight = Color3.fromRGB(235, 238, 255),
}

Config.Arena = {
	HalfSize = 55, -- area main +/- 55 stud dari tengah arena
	SpawnPoint = Vector3.new(0, 3, 40),
}

Config.Player = {
	WalkSpeed = 16,
	DashSpeed = 42,
	DashDuration = 0.35,
	DashCooldown = 3,
	InvulnerableAfterHit = 2,
	InvulnerableAfterDash = 0.6,
	MaxHearts = 3,
}

Config.Scoring = {
	WispBasePoints = 100,
	ComboWindowSeconds = 4, -- wisp berikutnya dalam jendela ini menaikkan combo
	ComboMax = 5, -- pengali combo tertinggi: x5
	WaveFiveBonus = 2, -- poin wisp di wave 5 dikali 2
}

-- Satu baris per wave: target wisp, jumlah shadow aktif, kecepatan shadow,
-- jumlah wisp aktif di arena, batas waktu wave (detik), dan raja di wave 5.
Config.Waves = {
	{ TargetWisps = 6, Shadows = 2, ShadowSpeed = 6, ActiveWisps = 4, TimeLimit = 75, King = false },
	{ TargetWisps = 8, Shadows = 3, ShadowSpeed = 7, ActiveWisps = 4, TimeLimit = 75, King = false },
	{ TargetWisps = 10, Shadows = 4, ShadowSpeed = 8, ActiveWisps = 5, TimeLimit = 90, King = false },
	{ TargetWisps = 12, Shadows = 5, ShadowSpeed = 9, ActiveWisps = 5, TimeLimit = 90, King = false },
	{ TargetWisps = 15, Shadows = 4, ShadowSpeed = 9, ActiveWisps = 6, TimeLimit = 120, King = true },
}

Config.Wisp = {
	Radius = 1.4,
	BobHeight = 0.8,
	BobSpeed = 2,
	RespawnDelay = 0.6,
}

Config.Shadow = {
	Radius = 1.6,
	ChaseRange = 60,
	WanderSpeed = 3,
}

Config.King = {
	Radius = 4,
	Speed = 10,
	KnockbackDistance = 18,
}

-- Target cahaya zona lentera: redup sebelum wave-nya tiba, terang sesudahnya.
Config.Lantern = {
	LitBrightness = 2,
	KingBrightness = 3,
	UnlitBrightness = 0.4,
	LitRange = 30,
	UnlitRange = 10,
}

return Config
