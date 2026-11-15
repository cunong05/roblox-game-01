-- EffectsController: semua umpan balik visual — tanpa asset suara eksternal.
-- Camera shake saat terkena, kilat merah di layar, semburan partikel saat
-- wisp terkumpul, dan kilat emas saat menang. Semua efek hanya lokal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local EffectsController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local shakeStrength = 0
local shakeConnection: RBXScriptConnection? = nil
local flashFrame: Frame
local goldFrame: Frame

local function ensureOverlayFrames()
	if flashFrame then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LanternKeepEffects"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = playerGui

	flashFrame = Instance.new("Frame")
	flashFrame.Name = "HitFlash"
	flashFrame.Size = UDim2.new(1, 0, 1, 0)
	flashFrame.BackgroundColor3 = Config.Palette.ShadowRed
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.Parent = gui

	goldFrame = Instance.new("Frame")
	goldFrame.Name = "WinFlash"
	goldFrame.Size = UDim2.new(1, 0, 1, 0)
	goldFrame.BackgroundColor3 = Config.Palette.LanternGold
	goldFrame.BackgroundTransparency = 1
	goldFrame.BorderSizePixel = 0
	goldFrame.Parent = gui
end

-- Guncangan kamera yang melemah sendiri; memanggil lagi menumpuk kekuatannya.
function EffectsController.shakeCamera(strength: number)
	shakeStrength = math.min(shakeStrength + strength, 1.5)
	if shakeConnection then
		return
	end
	shakeConnection = RunService.RenderStepped:Connect(function()
		if shakeStrength <= 0.01 then
			shakeStrength = 0
			if shakeConnection then
				shakeConnection:Disconnect()
				shakeConnection = nil
			end
			return
		end
		if camera then
			local offset = Vector3.new(
				(math.random() - 0.5) * shakeStrength,
				(math.random() - 0.5) * shakeStrength,
				0
			)
			camera.CFrame *= CFrame.new(offset)
		end
		shakeStrength *= 0.88
	end)
end

-- Kilat merah penuh layar yang memudar cepat.
function EffectsController.flashRed()
	ensureOverlayFrames()
	flashFrame.BackgroundTransparency = 0.45
	local tween = TweenService:Create(flashFrame, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	tween:Play()
end

-- Kilat emas penuh layar untuk kemenangan.
function EffectsController.flashGold()
	ensureOverlayFrames()
	goldFrame.BackgroundTransparency = 0.35
	local tween = TweenService:Create(goldFrame, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	tween:Play()
end

-- Semburan partikel teal di posisi wisp yang baru dikumpulkan.
function EffectsController.playCollectBurst(position: Vector3)
	local burst = Instance.new("Part")
	burst.Name = "CollectBurst"
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.new(0.5, 0.5, 0.5)
	burst.Position = position
	burst.Anchored = true
	burst.CanCollide = false
	burst.Transparency = 1
	burst.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Config.Palette.WispTeal)
	emitter.LightEmission = 1
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Size = NumberSequence.new(0.8)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = burst
	emitter:Emit(18)

	task.delay(1.2, function()
		burst:Destroy()
	end)
end

-- Menerjemahkan pesan efek dari server menjadi efek lokal.
function EffectsController.handleFx(kind: string, data: { [string]: any })
	if kind == "Hit" then
		EffectsController.flashRed()
		EffectsController.shakeCamera(0.8)
	elseif kind == "Timeout" then
		EffectsController.flashRed()
	elseif kind == "Dash" then
		EffectsController.shakeCamera(0.25)
	elseif kind == "Collect" then
		-- Semburan tepat di posisi wisp yang dikumpulkan bila server
		-- mengirimnya; bila tidak, jatuh ke posisi di atas kepala pemain.
		local burstPosition = data.Position
		if typeof(burstPosition) ~= "Vector3" then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			burstPosition = root and root:IsA("BasePart") and (root.Position + Vector3.new(0, 2, 0)) or Vector3.zero
		end
		EffectsController.playCollectBurst(burstPosition)
	elseif kind == "Win" then
		EffectsController.flashGold()
	elseif kind == "Lose" then
		EffectsController.flashRed()
		EffectsController.shakeCamera(1)
	end
end

return EffectsController
