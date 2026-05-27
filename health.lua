local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Khởi tạo cấu hình map động dựa trên PlaceId đa vũ trụ
local currentPlaceId = game.PlaceId
local config = {
    TargetPos = Vector3.new(5137, 54, 12),
    EggName = "Egg4",
    RebirthAmount = 1000000,
    WinValueCheck = nil
}

-- Phân tách logic đa vũ trụ map
if currentPlaceId == 76335816485479 then
    config.TargetPos = Vector3.new(4030, 132, -132)
    config.EggName = "Egg7"
    config.RebirthAmount = 10000000000
    config.WinValueCheck = 800000000000000
elseif currentPlaceId == 89953384612326 then
    config.TargetPos = Vector3.new(939, 223, 685)
    config.EggName = "Egg7"
    config.RebirthAmount = 100000000000000
    config.WinValueCheck = 4000000000000000000
end

local Window = Fluent:CreateWindow({
    Title = "Nesux Hub",
    SubTitle = "by Sondz",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "play" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "box" }),
    Debug = Window:AddTab({ Title = "Debug", Icon = "code" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options
local isRunning = true 
local oldCFrame = nil 
local cachedRebirthPart = nil
local cachedButtonPart = nil

do
    -- ==================== TAB MAIN ====================
    local AutoWin = Tabs.Main:AddToggle("AutoWin", {Title = "Auto Win", Default = false })
    
    local HealthDelaySlider = Tabs.Main:AddSlider("HealthDelay", {
        Title = "Health Delay",
        Description = "Tốc độ gửi request Health",
        Default = 0.05,
        Min = 0.01,
        Max = 1.0,
        Rounding = 2,
        Callback = function() end
    })
    local HealthToggle = Tabs.Main:AddToggle("SpamHealth", {Title = "Spam Health", Default = false })

    local TrainDelaySlider = Tabs.Main:AddSlider("TrainDelay", {
        Title = "Train Delay",
        Description = "Tốc độ gửi request Train",
        Default = 0.05,
        Min = 0.01,
        Max = 1.0,
        Rounding = 2,
        Callback = function() end
    })
    local TrainToggle = Tabs.Main:AddToggle("SpamTrain", {Title = "Spam Train", Default = false })

    local RebirthToggle = Tabs.Main:AddToggle("AutoRebirth", {Title = "Auto Rebirth", Default = false })

    local EggAmountSlider = Tabs.Main:AddSlider("EggAmount", {
        Title = "Egg Amount",
        Description = "Số lượng trứng mở mỗi lượt",
        Default = 50,
        Min = 1,
        Max = 100,
        Rounding = 0,
        Callback = function() end
    })
    local RollToggle = Tabs.Main:AddToggle("AutoRoll", {Title = "Auto Roll Pet", Default = false })

    -- ==================== TAB MISC ====================
    Tabs.Misc:AddParagraph({
        Title = "Game Optimizer & Exploit",
        Content = "Quản lý giao diện ẩn và tối ưu phần cứng treo máy."
    })

    local Disable3DToggle = Tabs.Misc:AddToggle("Disable3D", {Title = "Disable 3D Rendering", Default = false })
    local AutoBuyPackToggle = Tabs.Misc:AddToggle("AutoBuyPack", {Title = "Auto Buy Pack", Default = false })

    -- Core Services & Player Setup
    local runService = game:GetService("RunService")
    local lp = game:GetService("Players").LocalPlayer
    local waitFrame = runService.Heartbeat.Wait

    Disable3DToggle:OnChanged(function()
        pcall(function() runService:Set3dRenderingEnabled(not Options.Disable3D.Value) end)
    end)

    Tabs.Misc:AddButton({
        Title = "Toggle Hidden Market",
        Description = "Bấm để Bật/Tắt giao diện chợ ẩn",
        Callback = function()
            pcall(function()
                local pGui = lp:FindFirstChild("PlayerGui") or lp.PlayerGui
                local market = pGui.Shop.Market
                market.Visible = not market.Visible
            end)
        end
    })

    Tabs.Misc:AddButton({
        Title = "Toggle Hidden Inventory",
        Description = "Bấm để Bật/Tắt kho đồ ẩn",
        Callback = function()
            pcall(function()
                local pGui = lp:FindFirstChild("PlayerGui") or lp.PlayerGui
                local armor = pGui.Shop.Armor
                armor.Visible = not armor.Visible
            end)
        end
    })

    -- Remotes Cache
    local remotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
    local healthRemote = remotesFolder:WaitForChild("MHP")
    local trainRemote = remotesFolder:WaitForChild("Gain Hp From Tredmill")
    local rebirthRemote = game:GetService("ReplicatedStorage"):WaitForChild("RebirthRemote")
    local purchaseRemote = remotesFolder:WaitForChild("Purchase") -- FIXED: Khởi tạo remote chuẩn
    local luckRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("Function"):WaitForChild("Luck"):WaitForChild("[C-S]DoLuck")
    
    local fireServer = healthRemote.FireServer
    local invokeServer = luckRemote.InvokeServer
    local firetouch = firetouchinterest

    local trainArea = workspace:WaitForChild("Train Area")

    local function getTargetButton()
        if cachedButtonPart and cachedButtonPart.Parent then return cachedButtonPart end
        local folder = workspace:FindFirstChild("Buttons")
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child.Name == "Button16" then
                    if config.WinValueCheck then
                        local wins = child:FindFirstChild("Wins")
                        if wins and wins:IsA("ValueBase") and wins.Value == config.WinValueCheck then
                            cachedButtonPart = child
                            return child
                        end
                    else
                        cachedButtonPart = child
                        return child
                    end
                end
            end
        end
        return nil
    end

    local function getTargetRebirth()
        if cachedRebirthPart and cachedRebirthPart.Parent then return cachedRebirthPart end
        if trainArea then
            for _, child in ipairs(trainArea:GetChildren()) do
                if child.Name == "Rebirth" then
                    local amt = child:FindFirstChild("Amount")
                    if amt and amt:IsA("ValueBase") and amt.Value == config.RebirthAmount then
                        cachedRebirthPart = child
                        return child
                    end
                end
            end
        end
        return nil
    end

    AutoWin:OnChanged(function()
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if Options.AutoWin.Value then
            oldCFrame = root.CFrame 
        else
            if oldCFrame then
                task.wait(0.1)
                root.CFrame = oldCFrame 
                oldCFrame = nil
            end
        end
    end)

    -- ==================== TAB DEBUG ====================
    Tabs.Debug:AddParagraph({
        Title = "Developer Sandbox",
        Content = "Hot-Reloading quản lý runtime."
    })

    Tabs.Debug:AddButton({
        Title = "DESTROY GUI",
        Description = "Giải phóng thread ẩn và UI",
        Callback = function()
            Window:Dialog({
                Title = "Xác nhận",
                Content = "Ngắt toàn bộ vòng lặp và hủy giao diện Nesux Hub?",
                Buttons = {
                    {
                        Title = "Xóa",
                        Callback = function()
                            isRunning = false 
                            pcall(function() runService:Set3dRenderingEnabled(true) end)
                            Fluent:Destroy() 
                        end
                    },
                    {
                        Title = "Hủy",
                        Callback = function() end
                    }
                }
            })
        end
    })

    -- Loops Executor
    task.spawn(function()
        while isRunning do
            waitFrame(runService.Heartbeat)
            if Options.AutoWin and Options.AutoWin.Value then
                local char = lp.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = CFrame.new(config.TargetPos)
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    local btn = getTargetButton()
                    if btn and firetouch then
                        for _ = 1, 50 do
                            firetouch(root, btn, 0)
                            firetouch(root, btn, 1)
                        end
                    end
                end
            end
        end
    end)

    task.spawn(function()
        while isRunning do
            if Options.SpamHealth and Options.SpamHealth.Value then
                fireServer(healthRemote)
                task.wait(Options.HealthDelay.Value)
            else
                task.wait(0.1)
            end
        end
    end)

    task.spawn(function()
        while isRunning do
            if Options.SpamTrain and Options.SpamTrain.Value then
                local rbPart = getTargetRebirth()
                if rbPart then
                    trainRemote:FireServer(unpack({ rbPart }))
                end
                task.wait(Options.TrainDelay.Value)
            else
                task.wait(0.1)
            end
        end
    end)

    task.spawn(function()
        while isRunning do
            if Options.AutoRoll and Options.AutoRoll.Value then
                pcall(function() invokeServer(luckRemote, config.EggName, Options.EggAmount.Value) end)
                task.wait(0.3)
            else
                task.wait(0.2)
            end
        end
    end)

    task.spawn(function()
        while isRunning do
            if Options.AutoRebirth and Options.AutoRebirth.Value then
                pcall(function() rebirthRemote:FireServer() end)
                task.wait(0.5)
            else
                task.wait(0.1)
            end
        end
    end)

    -- Luồng Auto Buy Pack siêu tốc tích hợp micro-batching giải phóng băng thông
    local cachedPackArgs = { "Legendary" }
    task.spawn(function()
        while isRunning do
            waitFrame(runService.Heartbeat)
            if Options.AutoBuyPack and Options.AutoBuyPack.Value then
                pcall(function()
                    for _ = 1, 30 do -- Spam siêu nhanh 30 requests mỗi khung hình Heartbeat
                        purchaseRemote:FireServer(unpack(cachedPackArgs))
                    end
                end)
            end
        end
    end)
end

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("NesuxHub")
SaveManager:SetFolder("NesuxHub/game")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()
