-- WaveDirector: mengatur semua yang muncul di arena tiap wave —
-- spawn wisp, spawn shadow wisp, gerakan kejar mereka, dan Wisp King
-- di wave terakhir. Tidak tahu apa-apa soal skor atau hati; ia hanya
-- memanggil hook yang diberikan GameServer saat sesuatu tersentuh.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local WaveDirector = {}

local arenaFolder: Folder? = nil
local wispFolder: Folder? = nil
local shadowFolder: Folder? = nil
local kingPart: BasePart? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local spawnTimer = 0
local bobClock = 0
local activeWave = 0
local hooks = nil

type WaveHooks = {
	onWispTouched: (wisp: BasePart, player: Player) -> (),
	onShadowTouched: (shadow: BasePart, player: Player) -> (),
	onKingTouched: (king: BasePart, player: Player) -> (),
}

local function randomArenaPosition(minY: number, maxY: number): Vector3
	local half = Config.Arena.HalfSize - 6
	return Vector3.new(
		math.random(-half, half),
		math.random(minY, maxY),
		math.random(-half, half)
	)
end

local function playerFromTouch(otherPart: BasePart): Player?
	local character = otherPart:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	return game:GetService("Players"):GetPlayerFromCharacter(character)
end

local function makeGlowBall(name: string, radius: number, color: Color3, parent: Instance): BasePart
	local ball = Instance.new("Part")
	ball.Name = name
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	ball.Color = color
	ball.Material = Enum.Material.Neon
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanTouch = true
	ball.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 2
	light.Range = 12
	light.Parent = ball

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(color)
	sparkles.LightEmission = 1
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(0.6, 1)
	sparkles.Size = NumberSequence.new(0.6)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.Parent = ball
	return ball
end

local function spawnWisp()
	if not wispFolder then
		return
	end
	local wisp = makeGlowBall("Wisp", Config.Wisp.Radius, Config.Palette.WispTeal, wispFolder)
	wisp.Position = randomArenaPosition(2, 4)
	wisp:SetAttribute("BaseY", wisp.Position.Y)
	wisp:SetAttribute("BobPhase", math.random() * math.pi * 2)

	wisp.Touched:Connect(function(otherPart)
		local player = playerFromTouch(otherPart)
		if player and hooks then
			hooks.onWispTouched(wisp, player)
		end
	end)
end

local function spawnShadow()
	if not shadowFolder then
		return
	end
	local shadow = makeGlowBall("ShadowWisp", Config.Shadow.Radius, Config.Palette.ShadowRed, shadowFolder)
	shadow.Position = randomArenaPosition(2, 4)
	shadow:SetAttribute("WanderTarget", randomArenaPosition(2, 4))

	shadow.Touched:Connect(function(otherPart)
		local player = playerFromTouch(otherPart)
		if player and hooks then
			hooks.onShadowTouched(shadow, player)
		end
	end)
end

local function spawnKing()
	if not shadowFolder then
		return
	end
	kingPart = makeGlowBall("WispKing", Config.King.Radius, Config.Palette.KingPurple, shadowFolder)
	kingPart.Position = Vector3.new(0, 5, -45)
	local crownLight = kingPart:FindFirstChildOfClass("PointLight")
	if crownLight then
		crownLight.Range = 24
		crownLight.Brightness = 3
	end

	kingPart.Touched:Connect(function(otherPart)
		local player = playerFromTouch(otherPart)
		if player and hooks and kingPart then
			hooks.onKingTouched(kingPart, player)
		end
	end)
end

local function nearestPlayerRoot(position: Vector3): BasePart?
	local nearest: BasePart? = nil
	local nearestDistance = math.huge
	for _, player in game:GetService("Players"):GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local distance = (root.Position - position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearest = root
			end
		end
	end
	return nearest
end

local function stepShadows(dt: number, waveConfig)
	if not shadowFolder then
		return
	end
	for _, shadow in shadowFolder:GetChildren() do
		if shadow:IsA("BasePart") then
			local target = nearestPlayerRoot(shadow.Position)
			local moveTarget: Vector3
			local speed: number
			if target and (target.Position - shadow.Position).Magnitude <= Config.Shadow.ChaseRange then
				moveTarget = target.Position
				speed = waveConfig.ShadowSpeed
			else
				moveTarget = shadow:GetAttribute("WanderTarget") :: Vector3
				speed = Config.Shadow.WanderSpeed
				if (moveTarget - shadow.Position).Magnitude < 3 then
					shadow:SetAttribute("WanderTarget", randomArenaPosition(2, 4))
				end
			end
			local direction = moveTarget - shadow.Position
			if direction.Magnitude > 0.01 then
				local step = direction.Unit * math.min(speed * dt, direction.Magnitude)
				shadow.Position += Vector3.new(step.X, 0, step.Z)
			end
		end
	end
end

local function stepKing(dt: number)
	if not kingPart or not kingPart.Parent then
		return
	end
	local target = nearestPlayerRoot(kingPart.Position)
	if not target then
		return
	end
	local direction = target.Position - kingPart.Position
	if direction.Magnitude > 0.01 then
		local step = direction.Unit * math.min(Config.King.Speed * dt, direction.Magnitude)
		kingPart.Position += Vector3.new(step.X, 0, step.Z)
	end
end

local function stepWisps(dt: number)
	if not wispFolder then
		return
	end
	bobClock += dt
	for _, wisp in wispFolder:GetChildren() do
		if wisp:IsA("BasePart") then
			local baseY = wisp:GetAttribute("BaseY") :: number
			local phase = wisp:GetAttribute("BobPhase") :: number
			local y = baseY + math.sin(bobClock * Config.Wisp.BobSpeed + phase) * Config.Wisp.BobHeight
			wisp.Position = Vector3.new(wisp.Position.X, y, wisp.Position.Z)
		end
	end
end

-- Memulai satu wave: membersihkan arena lalu mengisi wisp dan shadow
-- sesuai tabel Config.Waves. Hook dipanggil saat pemain menyentuh sesuatu.
function WaveDirector.startWave(waveIndex: number, waveHooks: WaveHooks)
	WaveDirector.stopWave()
	activeWave = waveIndex
	hooks = waveHooks
	local waveConfig = Config.Waves[waveIndex]

	arenaFolder = workspace:FindFirstChild("Arena")
	if not arenaFolder then
		arenaFolder = Instance.new("Folder")
		arenaFolder.Name = "Arena"
		arenaFolder.Parent = workspace
	end
	wispFolder = Instance.new("Folder")
	wispFolder.Name = "Wisps"
	wispFolder.Parent = arenaFolder
	shadowFolder = Instance.new("Folder")
	shadowFolder.Name = "Shadows"
	shadowFolder.Parent = arenaFolder

	for _ = 1, waveConfig.ActiveWisps do
		spawnWisp()
	end
	for _ = 1, waveConfig.Shadows do
		spawnShadow()
	end
	if waveConfig.King then
		spawnKing()
	end

	spawnTimer = 0
	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		stepWisps(dt)
		stepShadows(dt, waveConfig)
		stepKing(dt)
		-- Jaga jumlah wisp aktif tetap sesuai tabel wave.
		spawnTimer += dt
		if wispFolder and #wispFolder:GetChildren() < waveConfig.ActiveWisps and spawnTimer >= Config.Wisp.RespawnDelay then
			spawnTimer = 0
			spawnWisp()
		end
	end)
end

-- Menghapus satu wisp dari arena setelah dikumpulkan.
function WaveDirector.removeWisp(wisp: BasePart)
	wisp:Destroy()
end

-- Menyingkirkan Wisp King dari pemain setelah menyentuh (tanpa menghapusnya).
function WaveDirector.knockKingBack(fromPosition: Vector3)
	if not kingPart or not kingPart.Parent then
		return
	end
	local away = kingPart.Position - fromPosition
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.01 then
		away = Vector3.new(0, 0, 1)
	end
	local destination = kingPart.Position + away.Unit * Config.King.KnockbackDistance
	destination = Vector3.new(
		math.clamp(destination.X, -Config.Arena.HalfSize, Config.Arena.HalfSize),
		kingPart.Position.Y,
		math.clamp(destination.Z, -Config.Arena.HalfSize, Config.Arena.HalfSize)
	)
	local tween = TweenService:Create(kingPart, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = destination })
	tween:Play()
end

-- Menghentikan wave yang sedang berjalan dan membersihkan semua bagiannya.
function WaveDirector.stopWave()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if wispFolder then
		wispFolder:Destroy()
		wispFolder = nil
	end
	if shadowFolder then
		shadowFolder:Destroy()
		shadowFolder = nil
	end
	kingPart = nil
	activeWave = 0
	hooks = nil
end

function WaveDirector.getActiveWave(): number
	return activeWave
end

return WaveDirector
