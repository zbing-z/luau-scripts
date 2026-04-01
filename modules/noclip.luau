--===== Config =====--
local Noclip = {
    ["Connection"]      = nil
}

--===== Services =====--
local Players    = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))

--===== Variables =====--
local Stepped     = RunService.Stepped
local LocalPlayer = Players.LocalPlayer

--===== Functions =====--
Noclip.Start = function()
    Noclip.Connection = Stepped:Connect(function()
        local LocalCharacter = LocalPlayer.Character
        if not LocalCharacter then return end

        local LocalHumanoid = LocalCharacter:FindFirstChild("Humanoid")
        if not LocalHumanoid then return end

        for _, PART in ipairs(LocalCharacter:GetDescendants()) do
            if not PART:IsA("BasePart") then continue end
            PART.CanCollide = false
        end
    end)
end

Noclip.Stop = function()
    if Noclip.Connection then
        Noclip.Connection:Disconnect()
        Noclip.Connection = nil
    end
end

return Noclip
