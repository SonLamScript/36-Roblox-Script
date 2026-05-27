local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

-- Các Remote điều khiển game
local damageRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClientToServer"):WaitForChild("DamageEnemy")
local dataRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClientToServer"):WaitForChild("GetPlayerData")

local cacheEquippedZombies = {} 
local zombieDropdownNames = {}

-- Biến lưu trữ thông số của Tab Misc
local currentWalkSpeed = 16
local currentJumpPower = 50

-- Hàm lấy danh sách Folder quái động theo thời gian thực
local function getCurrentEnemyFolder()
    return Workspace:FindFirstChild("LocalEnemies_" .. localPlayer.Name)
end

-- =============================================================================
-- THIẾT LẬP GIAO DIỆN MENU FLUENT (BỔ SUNG TAB MISC)
-- =============================================================================
local Window = Fluent:CreateWindow({
    Title = "Zombie Spammer Hub",
    SubTitle = "Clean Version",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main Features", Icon = "swords" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "sliders" }), -- Tab Misc mới
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- Hàm đồng bộ dữ liệu Zombie từ Server
local function fetchZombiesFromServer()
    local success, playerData = pcall(function()
        return dataRemote:InvokeServer()
    end)
    if success and playerData and playerData.EquippedZombies then
        cacheEquippedZombies = playerData.EquippedZombies
        return playerData.EquippedZombies
    end
    return {}
end

-- =============================================================================
-- CÁC PHẦN TỬ ĐIỀU KHIỂN TRÊN TAB MAIN
-- =============================================================================

-- 1. Bật/Tắt Tấn Công Thường (Auto Attack)
local AutoAttackToggle = Tabs.Main:AddToggle("AutoAttack", { Title = "Auto Damage Spam", Default = false })

-- 2. Cài đặt cấu hình nhịp độ và mục tiêu
local SpeedSlider = Tabs.Main:AddSlider("AttackSpeed", {
    Title = "Attack Speed (Delay)",
    Description = "Interval between enemy scans (seconds).",
    Default = 0.05,
    Min = 0.02,
    Max = 0.5,
    Rounding = 2,
    Callback = function(Value) end
})

local TargetSlider = Tabs.Main:AddSlider("MaxTargets", {
    Title = "Max Targets At Once",
    Description = "Limit the number of enemies targeted simultaneously (Recommended: 3-4).",
    Default = 4,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(Value) end
})

-- 3. Bộ lọc danh sách Pet
local ZombieDropdown = Tabs.Main:AddDropdown("ZombieFilter", {
    Title = "Select Zombies to Attack",
    Values = {},
    Multi = true,
    Default = {}
})

local function updateDropdownList()
    local zombies = fetchZombiesFromServer()
    table.clear(zombieDropdownNames)
    
    local selectedTable = {}
    for _, z in pairs(zombies) do
        if z.Name and not table.find(zombieDropdownNames, z.Name) then
            table.insert(zombieDropdownNames, z.Name)
            selectedTable[z.Name] = true
        end
    end
    
    ZombieDropdown:SetValues(zombieDropdownNames)
    ZombieDropdown:SetValue(selectedTable)
end

Tabs.Main:AddButton({
    Title = "Refresh Zombie List",
    Callback = function()
        updateDropdownList()
        Fluent:Notify({ Title = "System", Content = "Zombie inventory updated successfully!", Duration = 3 })
    end
})

task.spawn(updateDropdownList)

-- =============================================================================
-- CÁC PHẦN TỬ ĐIỀU KHIỂN TRÊN TAB MISC (MỚI)
-- =============================================================================

-- 1. Thanh chỉnh WalkSpeed
local SpeedPlayerSlider = Tabs.Misc:AddSlider("PlayerSpeed", {
    Title = "WalkSpeed",
    Description = "Modify your character's movement speed.",
    Default = 16,
    Min = 16,
    Max = 300,
    Rounding = 0,
    Callback = function(Value)
        currentWalkSpeed = Value
    end
})

-- 2. Thanh chỉnh JumpPower
local JumpPlayerSlider = Tabs.Misc:AddSlider("PlayerJump", {
    Title = "JumpPower",
    Description = "Modify your character's jump height.",
    Default = 50,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(Value)
        currentJumpPower = Value
    end
})

-- 3. Nút HỦY GUI vô cùng quan trọng (DESTROY GUI)
Tabs.Misc:AddButton({
    Title = "DESTROY GUI",
    Description = "Completely unloads the script, UI, and background loops for testing.",
    Callback = function()
        Window:Dialog({
            Title = "Confirm Destruction",
            Content = "Are you sure you want to completely destroy this GUI? All background tasks will stop immediately.",
            Buttons = {
                {
                    Title = "Confirm",
                    Callback = function()
                        Fluent:Destroy() -- Gọi hàm hủy gốc của thư viện Fluent để dọn sạch UI
                    end
                },
                {
                    Title = "Cancel",
                    Callback = function()
                        print("Destruction cancelled.")
                    end
                }
            }
        })
    end
})


-- =============================================================================
-- VÒNG LẶP CHẠY LUỒNG ATTACK SPAM CHÍNH
-- =============================================================================
task.spawn(function()
    while true do
        -- [QUAN TRỌNG]: Tự động ngắt và bẻ gãy vòng lặp nếu nút Destroy được bấm
        if Fluent.Unloaded then break end

        local attackEnabled = Options.AutoAttack.Value
        local attackDelay = Options.AttackSpeed.Value
        local maxTargets = Options.MaxTargets.Value
        local selectedFilter = Options.ZombieFilter.Value

        if attackEnabled then
            local currentFolder = getCurrentEnemyFolder()
            
            if currentFolder then
                local targetedCount = 0
                
                for _, enemy in ipairs(currentFolder:GetChildren()) do
                    if enemy:IsA("Model") and enemy:GetAttribute("UnderAttack") == true then
                        local enemyId = enemy:GetAttribute("EnemyId") or enemy:GetAttribute("enemyId")
                        
                        if enemyId then
                            targetedCount = targetedCount + 1
                            local idNum = tonumber(enemyId) or enemyId
                            
                            -- Bắn Remote gây sát thương thường dựa trên các Pet được chọn
                            if #cacheEquippedZombies > 0 then
                                for _, zombie in pairs(cacheEquippedZombies) do
                                    if zombie.Name and zombie.EquipId and selectedFilter[zombie.Name] == true then
                                        damageRemote:FireServer({
                                            {
                                                name = zombie.Name,
                                                enemyId = idNum,
                                                equipId = tonumber(zombie.EquipId)
                                            }
                                        })
                                    end
                                end
                            end
                            
                            -- Ngắt quét nếu đạt số lượng mục tiêu giới hạn trong lượt này
                            if targetedCount >= maxTargets then
                                break
                            end
                        end
                    end
                end
            end
        end
        
        task.wait(attackDelay)
    end
end)

-- Luồng ngầm tự động áp dụng WalkSpeed và JumpPower liên tục
task.spawn(function()
    while true do
        if Fluent.Unloaded then break end -- Tự bẻ gãy khi đóng GUI
        
        local character = localPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        
        if humanoid then
            -- Liên tục kiểm tra và khóa thông số theo thanh trượt slider đã cấu hình
            if humanoid.WalkSpeed ~= currentWalkSpeed then
                humanoid.WalkSpeed = currentWalkSpeed
            end
            if humanoid.JumpPower ~= currentJumpPower then
                humanoid.UseJumpPower = true
                humanoid.JumpPower = currentJumpPower
            end
        end
        task.wait(0.1) -- Nhịp kiểm tra nhẹ để tránh overload hiệu năng máy
    end
end)

-- Luồng đồng bộ ngầm túi đồ tự động (15 giây / lần)
task.spawn(function()
    while task.wait(15) do
        if Fluent.Unloaded then break end -- Tự bẻ gãy khi đóng GUI
        
        if Options.AutoAttack.Value == false then
            fetchZombiesFromServer()
        end
    end
end)

-- Quản lý cấu hình lưu trữ của Fluent
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentZombieHub")
SaveManager:SetFolder("FluentZombieHub/game-config")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()

Fluent:Notify({
    Title = "Zombie Spammer",
    Content = "Script loaded successfully! UI Toggle key: LeftControl",
    Duration = 5
})
