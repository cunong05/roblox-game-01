-- GameClient: entry client Lantern Keep — Wisp Rush.
-- Menghidupkan HUD, input, dan efek, lalu menghubungkan semuanya ke
-- RemoteEvent server: GameState (state masuk), PlayAgain (tombol Play),
-- dan Fx (umpan balik visual). Client tidak pernah menulis state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudController = require(script.Parent:WaitForChild("HudController"))
local InputController = require(script.Parent:WaitForChild("InputController"))
local EffectsController = require(script.Parent:WaitForChild("EffectsController"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local GameStateEvent = ReplicatedStorage:WaitForChild("GameState")
local PlayAgainEvent = ReplicatedStorage:WaitForChild("PlayAgain")
local FxEvent = ReplicatedStorage:WaitForChild("Fx")

local lastWaveSeen = 0

local function onPlayPressed()
	PlayAgainEvent:FireServer()
end

HudController.init(onPlayPressed)
InputController.init()

-- State masuk dari server: perbarui HUD dan umumkan pergantian wave.
GameStateEvent.OnClientEvent:Connect(function(state)
	HudController.updateFromState(state)
	if state.Phase == "Playing" and state.Wave ~= lastWaveSeen then
		lastWaveSeen = state.Wave
		if state.Wave == 1 and state.WispsCollected == 0 and state.ElapsedSeconds < 2 then
			HudController.showBanner("WAVE 1 — KUMPULKAN WISP!", Config.Palette.WispTeal)
		elseif state.Wave == #Config.Waves then
			HudController.showBanner("WAVE TERAKHIR — WISP KING DATANG!", Config.Palette.KingPurple)
		else
			HudController.showBanner("WAVE " .. tostring(state.Wave) .. "!", Config.Palette.LanternGold)
		end
	end
	if state.Phase ~= "Playing" then
		lastWaveSeen = 0
	end
end)

-- Pesan efek dari server: kilat, guncangan, dan semburan partikel.
FxEvent.OnClientEvent:Connect(function(kind, data)
	EffectsController.handleFx(kind, data)
	if kind == "WaveClear" then
		HudController.showBanner("WAVE SELESAI!", Config.Palette.LanternGold)
	elseif kind == "Win" then
		HudController.showBanner("KEEP TERSELAMATKAN!", Config.Palette.LanternGold)
	elseif kind == "Lose" then
		HudController.showBanner("LENTERA PADAM...", Config.Palette.ShadowRed)
	end
end)

print("Lantern Keep — Wisp Rush: client siap.")
