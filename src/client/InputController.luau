-- InputController: semua input pemain lewat ContextActionService, bukan
-- UserInputService.InputBegan — tombol panah Roblox memakai handler itu,
-- jadi InputBegan tidak pernah melihat tombol yang sudah diproses game.
-- Di sini hanya dash (Spasi); gerak WASD tetap ditangani kontrol bawaan Roblox.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputController = {}

local dashEvent: RemoteEvent
local lastDashRequest = 0
local DASH_REQUEST_SPAM_GUARD = 0.5 -- jangan banjiri server bila tombol ditahan

-- Mengikat Spasi ke dash; server yang memvalidasi cooldown dan kecepatan.
function InputController.init()
	dashEvent = ReplicatedStorage:WaitForChild("Dash")
	ContextActionService:BindAction("LanternKeepDash", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local now = os.clock()
		if now - lastDashRequest < DASH_REQUEST_SPAM_GUARD then
			return Enum.ContextActionResult.Sink
		end
		lastDashRequest = now
		dashEvent:FireServer()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

function InputController.unbind()
	ContextActionService:UnbindAction("LanternKeepDash")
end

return InputController
