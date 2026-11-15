-- GameServer: entry server Lantern Keep — Wisp Rush.
-- Satu-satunya tempat state machine permainan berjalan:
-- Lobby -> Playing -> Won / Lost. Semua keputusan (skor, hati, wave,
-- menang, kalah) dibuat di sini; client hanya menampilkan dan meminta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local StateStore = require(Shared:WaitForChild("StateStore"))
local ScoreKeeper = require(script.Parent:WaitForChild("ScoreKeeper"))
local WaveDirector = require(script.Parent:WaitForChild("WaveDirector"))

local GameStateEvent = ReplicatedStorage:WaitForChild("GameState")
local PlayAgainEvent = ReplicatedStorage:WaitForChild("PlayAgain")
local DashEvent = ReplicatedStorage:WaitForChild("Dash")
local FxEvent = ReplicatedStorage:WaitForChild("Fx")

local invulnerableUntil: { [Player]: number } = {}
local dashReadyAt: { [Player]: number } = {}
local broadcastTimer = 0
local BROADCAST_INTERVAL = 0.25 -- kirim timer ke client 4x per detik

local function broadcastState()
	GameStateEvent:FireAllClients(StateStore.getSnapshot())
end

local function fireFx(player: Player, kind: string, data: { [string]: any }?)
	FxEvent:FireClient(player, kind, data or {})
end

local function isInvulnerable(player: Player): boolean
	return (invulnerableUntil[player] or 0) > os.clock()
end

local function markInvulnerable(player: Player, seconds: number)
	invulnerableUntil[player] = os.clock() + seconds
end

local function teleportToSpawn(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.CFrame = CFrame.new(Config.Arena.SpawnPoint)
	end
end

-- Menyalakan zona lentera bertahap: wave 1 menyalakan zona 1, wave 2
-- menambah zona 2, dan seterusnya; wave 5 menyalakan ketiganya penuh.
local function updateLanternZones(wave: number)
	local arena = workspace:FindFirstChild("Arena")
	if not arena then
		return
	end
	for zoneIndex = 1, 3 do
		local zone = arena:FindFirstChild("LanternZone" .. zoneIndex)
		local head = zone and zone:FindFirstChild("LanternHead", true)
		local light = head and head:FindFirstChildOfClass("PointLight")
		if light then
			local lit = zoneIndex <= wave
			local targetBrightness = lit and Config.Lantern.LitBrightness or Config.Lantern.UnlitBrightness
			if wave >= 5 then
				targetBrightness = Config.Lantern.KingBrightness
			end
			local targetRange = lit and Config.Lantern.LitRange or Config.Lantern.UnlitRange
			local tween = TweenService:Create(light, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Brightness = targetBrightness,
				Range = targetRange,
			})
			tween:Play()
		end
	end
end

local function endGame(won: boolean)
	if StateStore.getField("Phase") ~= "Playing" then
		return
	end
	WaveDirector.stopWave()
	StateStore.setPhase(won and "Won" or "Lost")
	for _, player in Players:GetPlayers() do
		fireFx(player, won and "Win" or "Lose", {})
	end
	broadcastState()
end

local function startWave(waveIndex: number)
	WaveDirector.startWave(waveIndex, waveHooks)
	updateLanternZones(waveIndex)
end

local waveHooks = {
	onWispTouched = function(wisp, player)
		onWispCollected(wisp, player)
	end,
	onShadowTouched = function(_, player)
		onHazardTouched(player, false)
	end,
	onKingTouched = function(_, player)
		onHazardTouched(player, true)
	end,
}

function onWispCollected(wisp: BasePart, player: Player)
	if StateStore.getField("Phase") ~= "Playing" then
		return
	end
	WaveDirector.removeWisp(wisp)
	local points = ScoreKeeper.collectWisp()
	fireFx(player, "Collect", { Points = points, Position = wisp.Position })

	local snapshot = StateStore.getSnapshot()
	if snapshot.WispsCollected >= snapshot.WaveTarget then
		if snapshot.Wave >= #Config.Waves then
			endGame(true)
			return
		end
		StateStore.advanceWave()
		for _, otherPlayer in Players:GetPlayers() do
			fireFx(otherPlayer, "WaveClear", { Wave = StateStore.getField("Wave") })
		end
		startWave(StateStore.getField("Wave"))
	end
	broadcastState()
end

function onHazardTouched(player: Player, isKing: boolean)
	if StateStore.getField("Phase") ~= "Playing" then
		return
	end
	if isInvulnerable(player) then
		return
	end
	local heartsLeft = ScoreKeeper.loseHeart()
	markInvulnerable(player, Config.Player.InvulnerableAfterHit)
	fireFx(player, "Hit", { HeartsLeft = heartsLeft })
	if isKing then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			WaveDirector.knockKingBack(root.Position)
		end
	end
	if heartsLeft <= 0 then
		endGame(false)
		return
	end
	broadcastState()
end

local function tryDash(player: Player)
	if StateStore.getField("Phase") ~= "Playing" then
		return
	end
	local now = os.clock()
	if (dashReadyAt[player] or 0) > now then
		return
	end
	dashReadyAt[player] = now + Config.Player.DashCooldown

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	markInvulnerable(player, Config.Player.InvulnerableAfterDash)
	humanoid.WalkSpeed = Config.Player.DashSpeed
	fireFx(player, "Dash", {})
	task.delay(Config.Player.DashDuration, function()
		if humanoid.Parent then
			humanoid.WalkSpeed = Config.Player.WalkSpeed
		end
	end)
end

local function startGame(player: Player)
	WaveDirector.stopWave()
	StateStore.resetForNewGame()
	ScoreKeeper.resetForNewGame()
	invulnerableUntil[player] = 0
	dashReadyAt[player] = 0
	teleportToSpawn(player)
	startWave(1)
	broadcastState()
end

PlayAgainEvent.OnServerEvent:Connect(function(player)
	startGame(player)
end)

DashEvent.OnServerEvent:Connect(function(player)
	tryDash(player)
end)

Players.PlayerAdded:Connect(function(player)
	GameStateEvent:FireClient(player, StateStore.getSnapshot())
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if StateStore.getField("Phase") == "Playing" then
			teleportToSpawn(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	invulnerableUntil[player] = nil
	dashReadyAt[player] = nil
end)

-- Loop ronde: menghitung waktu wave dan waktu total, lalu mengirim
-- pembaruan berkala ke client. Waktu wave habis = kehilangan satu hati.
RunService.Heartbeat:Connect(function(dt)
	if StateStore.getField("Phase") ~= "Playing" then
		return
	end
	StateStore.addElapsedSeconds(dt)
	local timeLeft = StateStore.getField("WaveTimeLeft") - dt
	StateStore.setWaveTimeLeft(timeLeft)
	if timeLeft <= 0 then
		StateStore.resetWaveTimer()
		local heartsLeft = ScoreKeeper.loseHeart()
		for _, player in Players:GetPlayers() do
			fireFx(player, "Timeout", { HeartsLeft = heartsLeft })
		end
		if heartsLeft <= 0 then
			endGame(false)
			return
		end
	end
	broadcastTimer += dt
	if broadcastTimer >= BROADCAST_INTERVAL then
		broadcastTimer = 0
		broadcastState()
	end
end)

print("Lantern Keep — Wisp Rush: server siap.")
