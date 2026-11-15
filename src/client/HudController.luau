-- HudController: semua antarmuka pemain dibangun di sini lewat kode —
-- HUD skor/wave/hati/timer, bar progres wave, layar awal, dan layar akhir.
-- Modul ini tidak pernah mengubah state permainan; ia hanya menampilkan
-- salinan state yang dikirim server lewat RemoteEvent "GameState".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local HudController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui
local scoreLabel: TextLabel
local comboLabel: TextLabel
local waveLabel: TextLabel
local timerLabel: TextLabel
local heartsLabel: TextLabel
local progressFill: Frame
local progressLabel: TextLabel
local startScreen: Frame
local endScreen: Frame
local endTitle: TextLabel
local endStats: TextLabel
local bannerLabel: TextLabel
local hudFrame: Frame
local onPlayPressed: (() -> ())? = nil

local function makeLabel(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextScaled = false
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, name: string, text: string, size: UDim2, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Config.Palette.LanternGold
	button.TextColor3 = Color3.fromRGB(30, 20, 5)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 24
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	return button
end

local function formatTime(totalSeconds: number): string
	local minutes = math.floor(totalSeconds / 60)
	local seconds = math.floor(totalSeconds % 60)
	return string.format("%02d:%02d", minutes, seconds)
end

local function heartsText(hearts: number): string
	local filled = string.rep("♥ ", hearts)
	local empty = string.rep("♡ ", Config.Player.MaxHearts - hearts)
	return filled .. empty
end

-- Membangun seluruh UI sekali saat client masuk.
function HudController.init(playCallback: () -> ())
	onPlayPressed = playCallback

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LanternKeepHud"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	-- Bilah HUD atas (dijauhkan dari pojok kiri atas, tempat tombol menu Roblox).
	hudFrame = Instance.new("Frame")
	hudFrame.Name = "HudFrame"
	hudFrame.Size = UDim2.new(1, 0, 0, 64)
	hudFrame.Position = UDim2.new(0, 0, 0, 0)
	hudFrame.BackgroundColor3 = Color3.fromRGB(8, 10, 28)
	hudFrame.BackgroundTransparency = 0.35
	hudFrame.BorderSizePixel = 0
	hudFrame.Parent = screenGui

	scoreLabel = makeLabel(hudFrame, "ScoreLabel", "Skor 0", UDim2.new(0, 220, 0, 32), UDim2.new(0, 150, 0, 6), 24, Config.Palette.TextLight)
	comboLabel = makeLabel(hudFrame, "ComboLabel", "", UDim2.new(0, 220, 0, 24), UDim2.new(0, 150, 0, 36), 18, Config.Palette.WispTeal)
	waveLabel = makeLabel(hudFrame, "WaveLabel", "Wave -", UDim2.new(0, 160, 0, 32), UDim2.new(0.5, -80, 0, 6), 24, Config.Palette.LanternGold)
	timerLabel = makeLabel(hudFrame, "TimerLabel", "00:00", UDim2.new(0, 160, 0, 24), UDim2.new(0.5, -80, 0, 36), 18, Config.Palette.TextLight)
	heartsLabel = makeLabel(hudFrame, "HeartsLabel", heartsText(Config.Player.MaxHearts), UDim2.new(0, 180, 0, 32), UDim2.new(1, -200, 0, 16), 26, Config.Palette.HeartRed)

	-- Bar progres target wave di bawah bilah HUD.
	local progressBack = Instance.new("Frame")
	progressBack.Name = "ProgressBack"
	progressBack.Size = UDim2.new(0, 420, 0, 18)
	progressBack.Position = UDim2.new(0.5, -210, 0, 72)
	progressBack.BackgroundColor3 = Color3.fromRGB(20, 22, 48)
	progressBack.BorderSizePixel = 0
	progressBack.Parent = screenGui
	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 9)
	progressCorner.Parent = progressBack

	progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Config.Palette.WispTeal
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 9)
	fillCorner.Parent = progressFill

	progressLabel = makeLabel(screenGui, "ProgressLabel", "0 / 0 wisp", UDim2.new(0, 420, 0, 20), UDim2.new(0.5, -210, 0, 92), 16, Config.Palette.TextLight)
	progressLabel.TextXAlignment = Enum.TextXAlignment.Center

	-- Banner tengah untuk pengumuman wave ("Wave 2!" / "Wave selesai!").
	bannerLabel = makeLabel(screenGui, "BannerLabel", "", UDim2.new(0, 600, 0, 60), UDim2.new(0.5, -300, 0, 0.28, 0), 44, Config.Palette.LanternGold)
	bannerLabel.TextXAlignment = Enum.TextXAlignment.Center
	bannerLabel.TextTransparency = 1

	-- Layar awal: judul, cara main, tombol Play.
	startScreen = Instance.new("Frame")
	startScreen.Name = "StartScreen"
	startScreen.Size = UDim2.new(1, 0, 1, 0)
	startScreen.BackgroundColor3 = Color3.fromRGB(8, 10, 28)
	startScreen.BackgroundTransparency = 0.25
	startScreen.BorderSizePixel = 0
	startScreen.Parent = screenGui

	local title = makeLabel(startScreen, "Title", "LANTERN KEEP", UDim2.new(0, 700, 0, 70), UDim2.new(0.5, -350, 0, 0.16, 0), 56, Config.Palette.LanternGold)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local subtitle = makeLabel(startScreen, "Subtitle", "— WISP RUSH —", UDim2.new(0, 700, 0, 40), UDim2.new(0.5, -350, 0, 0.16, 70), 28, Config.Palette.WispTeal)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center

	local howTo = makeLabel(
		startScreen,
		"HowTo",
		"Kumpulkan wisp teal dengan menyentuhnya.\nHindari shadow wisp merah — sentuhan mereka mengambil 1 hati.\n"
			.. "Tekan SPASI untuk dash (kebal sebentar).\nSelesaikan 5 wave dan kalahkan Wisp King di wave terakhir!",
		UDim2.new(0, 700, 0, 140),
		UDim2.new(0.5, -350, 0, 0.34, 0),
		20,
		Config.Palette.TextLight
	)
	howTo.TextXAlignment = Enum.TextXAlignment.Center

	local playButton = makeButton(startScreen, "PlayButton", "▶  PLAY", UDim2.new(0, 240, 0, 64), UDim2.new(0.5, -120, 0, 0.58, 0))
	playButton.MouseButton1Click:Connect(function()
		if onPlayPressed then
			onPlayPressed()
		end
	end)

	-- Layar akhir: menang/kalah, statistik, tombol Play Again.
	endScreen = Instance.new("Frame")
	endScreen.Name = "EndScreen"
	endScreen.Size = UDim2.new(1, 0, 1, 0)
	endScreen.BackgroundColor3 = Color3.fromRGB(8, 10, 28)
	endScreen.BackgroundTransparency = 0.25
	endScreen.BorderSizePixel = 0
	endScreen.Visible = false
	endScreen.Parent = screenGui

	endTitle = makeLabel(endScreen, "EndTitle", "", UDim2.new(0, 700, 0, 70), UDim2.new(0.5, -350, 0, 0.2, 0), 52, Config.Palette.LanternGold)
	endTitle.TextXAlignment = Enum.TextXAlignment.Center
	endStats = makeLabel(endScreen, "EndStats", "", UDim2.new(0, 700, 0, 160), UDim2.new(0.5, -350, 0, 0.36, 0), 22, Config.Palette.TextLight)
	endStats.TextXAlignment = Enum.TextXAlignment.Center

	local againButton = makeButton(endScreen, "PlayAgainButton", "↻  PLAY AGAIN", UDim2.new(0, 280, 0, 64), UDim2.new(0.5, -140, 0, 0.62, 0))
	againButton.MouseButton1Click:Connect(function()
		if onPlayPressed then
			onPlayPressed()
		end
	end)

	HudController.setHudVisible(false)
end

function HudController.setHudVisible(visible: boolean)
	hudFrame.Visible = visible
	progressLabel.Visible = visible
end

-- Memperbarui semua angka HUD dari salinan state server.
function HudController.updateFromState(state)
	scoreLabel.Text = "Skor " .. tostring(state.Score)
	if state.Combo >= 2 then
		comboLabel.Text = "Combo x" .. tostring(state.ComboMultiplier) .. " (" .. tostring(state.Combo) .. ")"
	else
		comboLabel.Text = ""
	end
	waveLabel.Text = "Wave " .. tostring(state.Wave) .. " / " .. tostring(#Config.Waves)
	timerLabel.Text = formatTime(state.ElapsedSeconds) .. "  •  " .. formatTime(state.WaveTimeLeft)
	heartsLabel.Text = heartsText(state.Hearts)

	-- Bar progres wave: bergerak halus (tween) mengikuti jumlah wisp.
	local target = math.max(1, state.WaveTarget)
	local fraction = math.clamp(state.WispsCollected / target, 0, 1)
	local fillTween = TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(fraction, 0, 1, 0),
	})
	fillTween:Play()
	progressLabel.Text = tostring(state.WispsCollected) .. " / " .. tostring(state.WaveTarget) .. " wisp"

	if state.Phase == "Playing" then
		startScreen.Visible = false
		endScreen.Visible = false
		HudController.setHudVisible(true)
	elseif state.Phase == "Lobby" then
		startScreen.Visible = true
		endScreen.Visible = false
		HudController.setHudVisible(false)
	elseif state.Phase == "Won" or state.Phase == "Lost" then
		HudController.showEndScreen(state.Phase == "Won", state)
	end
end

-- Menampilkan banner tengah yang muncul lalu memudar sendiri.
function HudController.showBanner(text: string, color: Color3?)
	bannerLabel.Text = text
	bannerLabel.TextColor3 = color or Config.Palette.LanternGold
	bannerLabel.TextTransparency = 0
	local tween = TweenService:Create(bannerLabel, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { TextTransparency = 1 })
	task.delay(0.8, function()
		tween:Play()
	end)
end

-- Layar akhir dengan statistik ronde yang baru selesai.
function HudController.showEndScreen(won: boolean, state)
	endScreen.Visible = true
	HudController.setHudVisible(false)
	if won then
		endTitle.Text = "✦ KEEP TERSELAMATKAN! ✦"
		endTitle.TextColor3 = Config.Palette.LanternGold
	else
		endTitle.Text = "LENTERA PADAM..."
		endTitle.TextColor3 = Config.Palette.ShadowRed
	end
	endStats.Text = string.format(
		"Skor akhir: %d\nWave tercapai: %d / %d\nWisp terkumpul: %d\nCombo terbaik: x%d\nWaktu: %s",
		state.Score,
		state.Wave,
		#Config.Waves,
		state.TotalWispsCollected,
		state.BestCombo,
		formatTime(state.ElapsedSeconds)
	)
end

return HudController
