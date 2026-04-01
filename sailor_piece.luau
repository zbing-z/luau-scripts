--[[


THIS SCRIPT MADE BY ZBING Z
SUBSCRIBE https://www.youtube.com/@zbingz


]]

repeat
    task.wait()
until game:IsLoaded()

if getgenv().ZBINGZ_LOADED then
    return
end

getgenv().ZBINGZ_LOADED = true

--// Configs

getgenv().Config = getgenv().Config or {}
local Config = getgenv().Config
Config.TeleportOffsetX = Config.TeleportOffsetX or 0
Config.TeleportOffsetY = Config.TeleportOffsetY or 8
Config.TeleportOffsetZ = Config.TeleportOffsetZ or 0

Config.NPCPriorityType = Config.NPCPriorityType or "Closest"

Config.TweenSpeed      = Config.TweenSpeed or 60
Config.AutoStatsAmount = Config.AutoStatsAmount or 1

--// Services

local RunService          = cloneref(game:GetService("RunService"))
local Players             = cloneref(game:GetService("Players"))
local ReplicatedStorage   = cloneref(game:GetService("ReplicatedStorage"))
local VirtualInputManager = cloneref(game:GetService("VirtualInputManager"))

--// Variables

local LocalPlayer = Players.LocalPlayer

--// Switch mode state
local CurrentTarget  = nil
local LastSwitchTime = 0
local SwitchIndex    = 0

--// Maping

local WeaponTypeMap = {
    [1] = "Melee",
    [2] = "Sword",
    [3] = "Power"
}

local StatTypeMap = {
    [1] = "Melee",
    [2] = "Defense",
    [3] = "Sword",
    [4] = "Power"
}

--// Events

local RemoteEvents      = ReplicatedStorage:WaitForChild("RemoteEvents")
local QuestAcceptEvent  = RemoteEvents:WaitForChild("QuestAccept")
local QuestAbandonEvent = RemoteEvents:WaitForChild("QuestAbandon")
local AllocateStatEvent = RemoteEvents:WaitForChild("AllocateStat")
local ObservationHakiRemote = RemoteEvents:WaitForChild("ObservationHakiRemote")
local HakiRemote = RemoteEvents:WaitForChild("HakiRemote")

local CombatSystem    = ReplicatedStorage:WaitForChild("CombatSystem")
local CombatRemotes   = CombatSystem:WaitForChild("Remotes")
local RequestHitEvent = CombatRemotes:WaitForChild("RequestHit")

local AbilitySystem       = ReplicatedStorage:WaitForChild("AbilitySystem")
local AbilityRemotes      = AbilitySystem:WaitForChild("Remotes")
local RequestAbilityEvent = AbilityRemotes:WaitForChild("RequestAbility")

-- Modules
local Modules              = ReplicatedStorage:WaitForChild("Modules")
local QuestConfig          = require(Modules.QuestConfig)
local WeaponClassification = require(Modules.WeaponClassification)
local WeaponTools          = WeaponClassification.Tools

local MultiJumpModule = require(ReplicatedStorage.MultiJumpModule)
local DashModule      = require(ReplicatedStorage.DashModule)

--// Functions

-- Utility

local function Import(Owner, Repo, Version, File)
    local Tag = (Version == "latest" and "latest/download" or "download/" .. Version)

    return loadstring(game:HttpGetAsync(
        ("https://github.com/%s/%s/releases/%s/%s"):format(Owner, Repo, Tag, File)
    ), File)()
end

local function TeleportTo(cframe)
    local LocalCharacter = LocalPlayer.Character
    local LocalRootPart = LocalCharacter and LocalCharacter:FindFirstChild("HumanoidRootPart")
    if not LocalRootPart then return end

    LocalRootPart.CFrame = cframe
end

local function NormalizeName(Name)
    if not Name then return "" end

    Name = Name:gsub("[^%a]", "")

    return Name:lower()
end

local function AntiIdle()
	if getconnections then
		for i, v in pairs(getconnections(LocalPlayer.Idled)) do
			if v["Disable"] then
				v["Disable"](v)
			elseif v["Disconnect"] then
				v["Disconnect"](v)
			end
		end
	else
		LocalPlayer.Idled:Connect(function()
			VirtualInputManager:SendMouseButtonEvent(0, 0, 1, true, game, 0)
            task.wait()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 1, false, game, 0)
		end)
	end
end

local function NoClip()
    if LocalPlayer.Character then
        for _, LocalRootPart in pairs(LocalPlayer.Character:GetDescendants()) do
            if LocalRootPart:IsA("BasePart") and LocalRootPart.CanCollide then
                LocalRootPart.CanCollide = false
            end
        end
    end
end

local function AddBodyVelocity(LocalRootPart)
    if not LocalRootPart or not LocalRootPart:IsA("BasePart") then return end

    local Existing = LocalRootPart:FindFirstChildWhichIsA("BodyVelocity")
    if Existing then return end

    local BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Velocity = Vector3.new(0, 0, 0)
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.Parent = LocalRootPart
    BodyVelocity:SetAttribute("MyVelocity", true)
end

local function RemoveBodyVelocity(LocalRootPart)
    if not LocalRootPart or not LocalRootPart:IsA("BasePart") then return end

    local Existing = LocalRootPart:FindFirstChildWhichIsA("BodyVelocity")
    if Existing and Existing:GetAttribute("MyVelocity") then
        Existing:Destroy()
    end
end

local function GetXZDistance(Pos1, Pos2)
    local A = Vector3.new(Pos1.X, 0, Pos1.Z)
    local B = Vector3.new(Pos2.X, 0, Pos2.Z)
    return (A - B).Magnitude
end

-- Game Functions

local function GetPlayerLevel(Player)
    local Data = Player and Player:FindFirstChild("Data")
    local Level = Data and Data:FindFirstChild("Level")
    return Level and Level.Value
end

local function GetLocalLevel()
    return GetPlayerLevel(LocalPlayer)
end

local function GetBestQuestForLevel(Level)
    if not Level then return end

    local BestQuest, BestName
    local BestUnderLevel = -math.huge
    local LowestLevel = math.huge

    for Name, Quest in pairs(QuestConfig.RepeatableQuests) do
        local ReqLevel = Quest.recommendedLevel or 0

        if ReqLevel <= Level and ReqLevel > BestUnderLevel then
            BestUnderLevel = ReqLevel
            BestQuest = Quest
            BestName = Name
        end

        if ReqLevel < LowestLevel then
            LowestLevel = ReqLevel
            if not BestQuest then
                BestQuest = Quest
                BestName = Name
            end
        end
    end

    return BestName, BestQuest
end

local function GetBestQuest()
    return GetBestQuestForLevel(GetLocalLevel())
end

local function AcceptQuest(QuestName)
    QuestAcceptEvent:FireServer(QuestName)
end

local function CheckQuest()
    local Character = LocalPlayer.Character
    if not Character then return nil end

    local LocalRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not LocalRootPart then return nil end

    local BestQuestName, BestQuest = GetBestQuest()
    if not BestQuestName or not BestQuest then return end

    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not PlayerGui then return end

    local QuestUI = PlayerGui:FindFirstChild("QuestUI")
    local QuestFrame = QuestUI and QuestUI:FindFirstChild("Quest")
    if not QuestFrame then return end

    if QuestFrame.Visible then
        local QuestTitleLabel = QuestFrame
            :FindFirstChild("Quest")
            and QuestFrame.Quest:FindFirstChild("Holder")
            and QuestFrame.Quest.Holder:FindFirstChild("Content")
            and QuestFrame.Quest.Holder.Content:FindFirstChild("QuestInfo")
            and QuestFrame.Quest.Holder.Content.QuestInfo:FindFirstChild("QuestTitle")
            and QuestFrame.Quest.Holder.Content.QuestInfo.QuestTitle:FindFirstChild("QuestTitle")

        local CurrentTitle = QuestTitleLabel and QuestTitleLabel.Text

        if not BestQuest.title or CurrentTitle ~= BestQuest.title then
            QuestAbandonEvent:FireServer("repeatable")
            return false
        else
            return true
        end
    else
        if Config.AcceptQuestAnywhere then
            AcceptQuest(BestQuestName)
            return
        end

        local ServiceNPC = workspace.ServiceNPCs:FindFirstChild(BestQuestName)
        if not ServiceNPC then return end

        local ServiceNPCRootPart = ServiceNPC:FindFirstChild("HumanoidRootPart")

        local TargetCF

        if ServiceNPCRootPart then
            local OffsetCF = ServiceNPCRootPart.CFrame * CFrame.new(0, 0, -4)
            TargetCF = CFrame.new(OffsetCF.Position, ServiceNPCRootPart.Position)
        else
            TargetCF = ServiceNPC.WorldPivot
        end

        TeleportTo(TargetCF)
        local Distance = (LocalRootPart.Position - TargetCF.Position).Magnitude
        if Distance <= 10 then
            AcceptQuest(BestQuestName)
        end
        return false
    end
end

local function GetNpcPosition(Npc)
    if Npc.PrimaryPart then
        return Npc.PrimaryPart.Position
    elseif Npc:FindFirstChild("HumanoidRootPart") then
        return Npc.HumanoidRootPart.Position
    end
    return nil
end

local function GetTargetNpc(NpcName)
    local Character = LocalPlayer.Character
    if not Character then return nil end

    local LocalRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not LocalRootPart then return nil end

    local NPCFolder = workspace:FindFirstChild("NPCs")
    if not NPCFolder then return nil end

    local PlayerPos = LocalRootPart.Position

    local Npcs = {}

    for _, Npc in ipairs(NPCFolder:GetChildren()) do
        local NpcHumanoid = Npc:FindFirstChild("Humanoid")
        if not NpcHumanoid or NpcHumanoid.Health <= 0 then continue end

        if NormalizeName(Npc.Name) == NormalizeName(NpcName) then
            local Pos = GetNpcPosition(Npc)
            if Pos then
                table.insert(Npcs, {
                    Instance = Npc,
                    Position = Pos
                })
            end
        end
    end

    if #Npcs == 0 then return nil end

    --// Closest mode
    if not Config.NPCPriorityType or Config.NPCPriorityType == 1 then
        local ClosestNpc = nil
        local ShortestDistance = math.huge

        for _, Data in ipairs(Npcs) do
            local Dist = (Data.Position - PlayerPos).Magnitude
            if Dist < ShortestDistance then
                ShortestDistance = Dist
                ClosestNpc = Data.Instance
            end
        end

        return ClosestNpc
    end

    --// Center mode
    if Config.NPCPriorityType == 2 then
        local Center = Vector3.zero

        for _, Data in ipairs(Npcs) do
            Center += Data.Position
        end

        Center /= #Npcs

        local ClosestNpc = nil
        local ShortestDistance = math.huge

        for _, Data in ipairs(Npcs) do
            local Dist = (Data.Position - Center).Magnitude
            if Dist < ShortestDistance then
                ShortestDistance = Dist
                ClosestNpc = Data.Instance
            end
        end

        return ClosestNpc
    end

    --// Switch mode
    if Config.NPCPriorityType == 3 then
        local Now = tick()
        local SwitchTime = Config.NPCSwitchTime or 2

        if not CurrentTarget or Now - LastSwitchTime >= SwitchTime then
            LastSwitchTime = Now

            SwitchIndex += 1
            if SwitchIndex > #Npcs then
                SwitchIndex = 1
            end

            CurrentTarget = Npcs[SwitchIndex].Instance
        end

        return CurrentTarget
    end

    return nil
end

local function EquipWeapon()
    if not Config.AutoEquipWeapon then return end

    local Character = LocalPlayer.Character
    if not Character then return end

    local Humanoid = Character:FindFirstChild("Humanoid")
    if not Humanoid then return end

    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    if not Backpack then return end

    local DesiredType = WeaponTypeMap[Config.AutoEquipWeaponType]
    if not DesiredType then return end

    for _, Tool in ipairs(Backpack:GetChildren()) do
        if not Tool:IsA("Tool") then continue end

        local WeaponType = WeaponTools[Tool.Name]

        if WeaponType == DesiredType then
            Humanoid:EquipTool(Tool)
            break
        end
    end
end

local function RequestHit()
    EquipWeapon()
    RequestHitEvent:FireServer()
end

local function RequestAbility(Index)
    EquipWeapon()
    RequestAbilityEvent:FireServer(Index)
end


--// Loops

RunService.RenderStepped:Connect(function()
    if not Config.AutoMainQuest then return end
    if not CheckQuest() then return end

    local Character = LocalPlayer.Character
    if not Character then return end

    local LocalRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not LocalRootPart then return end

    local _, BestQuest = GetBestQuest()
    if not BestQuest then return end

    local NpcType = BestQuest.requirements[1].npcType
    if not NpcType then return end

    if NpcType == "SlimeWarrior" then
        NpcType = "Slime"
    end
    local TargetNPC = GetTargetNpc(NpcType)
    if not TargetNPC then
        local TargetModel
        for _, NPC in ipairs(workspace.NPCs:GetChildren()) do
            local NPCHumanoid = NPC:FindFirstChild("Humanoid")
            if not NPCHumanoid or NPCHumanoid.Health <= 0 then continue end
            if NormalizeName(NPC.Name) == NormalizeName(NpcType) then
                TargetModel = NPC
                break
            end
        end

        if not TargetModel then return end
        TeleportTo(TargetModel.WorldPivot)
        return
    end

    local TargetRootPart = TargetNPC:FindFirstChild("HumanoidRootPart")
    if not TargetRootPart then return end

    local TeleportOffset = CFrame.new(
        Config.TeleportOffsetX,
        Config.TeleportOffsetY,
        Config.TeleportOffsetZ
    )

    local OffsetPosition = (TargetRootPart.CFrame * TeleportOffset).Position
    local TargetPosition = TargetRootPart.Position
    local DestCFrame = CFrame.new(OffsetPosition, TargetPosition)

    TeleportTo(DestCFrame)
    RequestHit()

    local Distance = (LocalRootPart.Position - DestCFrame.Position).Magnitude

    if Config.AutoAbility and Distance <= 5 then
        for _, Index in ipairs(Config.AutoAbilityTypes) do
            RequestAbility(Index)
        end
    end
end)

task.spawn(function()
    while task.wait(0.3) do
        local LocalCharacter = LocalPlayer.Character
        if not LocalCharacter then continue end

        local LocalHumanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if not LocalHumanoid then continue end

        local LocalRoot = LocalCharacter.PrimaryPart or LocalCharacter:FindFirstChild("HumanoidRootPart")
        if not LocalRoot then continue end

        if Config.AutoMainQuest
        then
            AddBodyVelocity(LocalRoot)
            NoClip()
            if LocalHumanoid:GetState() ~= Enum.HumanoidStateType.Physics then
                LocalHumanoid:ChangeState(Enum.HumanoidStateType.Physics)
            end
        else
            RemoveBodyVelocity(LocalRoot)
            if LocalHumanoid:GetState() == Enum.HumanoidStateType.Physics then
                LocalHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if not Config.AutoStats then continue end

        local Character = LocalPlayer.Character
        if not Character then continue end

        local Humanoid = Character:FindFirstChild("Humanoid")
        if not Humanoid then continue end

        local Backpack = LocalPlayer:FindFirstChild("Backpack")
        if not Backpack then continue end

        for _, Index in ipairs(Config.AutoStatsTypes or {}) do
            AllocateStatEvent:FireServer(StatTypeMap[Index], Config.AutoStatsAmount)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if Config.AutoArmamentHaki then

        end

        if Config.AutoObservationHaki then
            pcall(function()
                if not LocalPlayer.PlayerGui.DodgeCounterUI.MainFrame.Visible then
                    ObservationHakiRemote:FireServer("Toggle")
                end
            end)
        end
    end
end)

--// Init

task.spawn(function()
    AntiIdle()
end)

--// Interface

local Cascade = Import("biggaboy212", "Cascade", "latest", "dist.luau")

local App = Cascade.New({
    Theme = Cascade.Themes.Dark,
    Accent = Cascade.Accents.Blue,
})

local function AddToggleRow(PageSection, title, subtitle, default, callback)
    local Row = PageSection:Row()

    Row:Left():TitleStack({
        Title = title,
        Subtitle = subtitle,
    })

    Row:Right():Toggle({
        Value = default,
        ValueChanged = callback,
    })
end

local function AddSliderRow(PageSection, title, subtitle, min, max, default, decimals, callback)
    local Row = PageSection:Row()

    Row:Left():TitleStack({
        Title = title,
        Subtitle = subtitle,
    })

    local Label = Row:Right():Label({
        Text = default
    })

    local FormatString = "%." .. tostring(decimals or 0) .. "f"

    Row:Right():Slider({
        Minimum = min,
        Maximum = max,
        Value = default,
        ValueChanged = function(self, Value)
            local FormattedValue = tonumber(string.format(FormatString, Value))

            Label.Text = tostring(FormattedValue)

            if callback then
                callback(self, FormattedValue)
            end
        end,
    })
end

local function AddPopUpButtonRow(PageSection, title, subtitle, options, default, maximum, callback)
    local Row = PageSection:Row()

    Row:Left():TitleStack({
        Title = title,
        Subtitle = subtitle,
    })

    Row:Right():PopUpButton({
        Options = options,
        Value = default,
        Maximum = maximum,
        ValueChanged = callback,
    })
end

local Window = App:Window({
    Title = "zbing z",
    Subtitle = "made by p pang",
    UIBlur = false
})

do  -- Main Section
    local Section = Window:Section({
        Title = "Main"
    })

    do  -- Main Tab
        local Tab = Section:Tab({
            Title = "Main",
            Selected = true,
            Icon = Cascade.Symbols.house,
        })

        do  -- Auto Main Quest Section
            local PageSection = Tab
                :PageSection({
                    Title = "🤖 Auto Main Quest",
                })
                :Form()

            AddToggleRow(PageSection,
                "Auto Main Quest",
                "Automation grind level for you",
                false,
                function(_, Value)
                    Config.AutoMainQuest = Value
                end
            )
        end
    end

    do  -- Utility Tab
        local Tab = Section:Tab({
            Title = "Utility",
            Icon = Cascade.Symbols.squareStack3dUp,
        })

        do  -- Auto Equip Tab
            local PageSection = Tab
                :PageSection({
                    Title = "⚔ Auto Equip",
                })
                :Form()

            AddToggleRow(PageSection,
                "Auto Equip Weapon",
                "just auto equip tool for you",
                false,
                function(_, Value)
                    Config.AutoEquipWeapon = Value
                end
            )

            AddPopUpButtonRow(PageSection, "Weapon Type", "select mode", {"Melee", "Sword", "Power"}, 1, 1, function(self, Value)
                Config.AutoEquipWeaponType = Value
            end)
        end

        do  -- Auto Stats Tab
            local PageSection = Tab
                :PageSection({
                    Title = "📊 Auto Stats",
                })
                :Form()

            AddToggleRow(PageSection,
                "Auto Stats",
                "just auto upgrade stats",
                false,
                function(_, Value)
                    Config.AutoStats = Value
                end
            )

            AddPopUpButtonRow(PageSection, "Stats Types", "select mode", {"Melee", "Defense", "Sword", "Power"}, {}, 4, function(self, Value)
                Config.AutoStatsTypes = Value
            end)

            AddSliderRow(PageSection, "Increment Amount", "Adjust increment amount", 1, 100, Config.AutoStatsAmount or 1, 0, function(self, Value)
                Config.AutoStatsAmount = Value
            end)
        end

        do  -- Haki Tab
            local PageSection = Tab
                :PageSection({
                    Title = "🏋️‍♀️ Haki",
                })
                :Form()

            AddToggleRow(PageSection,
                "Auto Armament Haki",
                "auto turn on armament haki",
                false,
                function(_, Value)
                    Config.AutoArmamentHaki = Value
                end
            )

            AddToggleRow(PageSection,
                "Auto Observation Haki",
                "auto turn on observation haki",
                false,
                function(_, Value)
                    Config.AutoObservationHaki = Value
                end
            )
        end

        do  -- Ability Tab
            local PageSection = Tab
                :PageSection({
                    Title = "🏃‍♂️ Ability",
                })
                :Form()

            AddToggleRow(PageSection,
                "Infinite Jump (You can add remote spoof by your self)",
                "infinite geppo (nah its just 1000)",
                false,
                function(_, Value)
                    if Value then
                        MultiJumpModule.Config.MaxJumps = 1000
                    else
                        MultiJumpModule.Config.MaxJumps = 6
                    end
                end
            )

            AddToggleRow(PageSection,
                "No Cooldown Dash",
                "remove cooldown from dash",
                false,
                function(_, Value)
                    if Value then
                        DashModule.Config.DashCooldown = 0
                    else
                        DashModule.Config.DashCooldown = 0.4
                    end
                end
            )
        end
    end

    do  -- Settings Tab
        local Tab = Section:Tab({
            Title = "Settings",
            Icon = Cascade.Symbols.gear,
        })

        do  -- Settings Page
            local PageSection = Tab
                :PageSection({
                    Title = "⚙ General Settings",
                })
                :Form()

            AddToggleRow(PageSection,
                "Accept Quest Anywhere",
                "Get quests without going to the NPC",
                false,
                function(_, Value)
                    Config.AcceptQuestAnywhere = Value
                end
            )

            AddPopUpButtonRow(PageSection, "Target Selection Mode", "Select mode", {"Closest", "Center", "Switch"}, 1, 1, function(self, Value)
                Config.NPCPriorityType = Value
            end)

            AddSliderRow(PageSection, "NPC Switch Time", "how long will u stay at npc", 0.1, 5, Config.NPCSwitchTime or 2, 1, function(self, Value)
                Config.NPCSwitchTime = Value
            end)
        end

        do  -- Tween Settings Page
            local PageSection = Tab
                :PageSection({
                    Title = "⚙ Offsets Settings",
                })
                :Form()

            AddSliderRow(PageSection, "X Offset", "Adjust x offset", -30, 30, Config.TeleportOffsetX, 0, function(self, Value)
                Config.TeleportOffsetX = Value
            end)

            AddSliderRow(PageSection, "Y Offset", "Adjust y offset", -30, 30, Config.TeleportOffsetY, 0, function(self, Value)
                Config.TeleportOffsetY = Value
            end)

            AddSliderRow(PageSection, "Z Offset", "Adjust z offset", -30, 30, Config.TeleportOffsetZ, 0, function(self, Value)
                Config.TeleportOffsetZ = Value
            end)
        end

        do  -- Auto Skills Page
            local PageSection = Tab
                :PageSection({
                    Title = "⚙ Auto Skills",
                })
                :Form()

            AddToggleRow(PageSection,
                "Auto Ability",
                "auto use skills",
                false,
                function(_, Value)
                    Config.AutoAbility = Value
                end
            )

            AddPopUpButtonRow(PageSection, "Ability Selection", "Select skills", {1, 2, 3, 4, 5}, {1, 2, 3, 4, 5}, 5, function(self, Value)
                Config.AutoAbilityTypes = Value
            end)
        end
    end
end
