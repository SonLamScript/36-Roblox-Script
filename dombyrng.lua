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
local equipBestRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClientToServer"):WaitForChild("EquipBestZombies")

local cacheEquippedZombies = {} 

-- Biến lưu trữ thông số của Tab Misc
local currentWalkSpeed = 16
local currentJumpPower = 50

-- Hàm lấy danh sách Folder quái động theo thời gian thực
local function getCurrentEnemyFolder()
    return Workspace:FindFirstChild("LocalEnemies_" .. localPlayer.Name)
end

-- Hàm lấy danh sách Folder Pet ngoài sân theo thời gian thực
local function getCurrentZombiePetsFolder()
    return Workspace:FindFirstChild("ZombiePets_" .. localPlayer.Name)
end

-- =============================================================================
-- THIẾT LẬP GIAO DIỆN MENU FLUENT
-- =============================================================================
local Window = Fluent:CreateWindow({
    Title = "Zombie Spammer Hub",
    SubTitle = "Clean & Optimized",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main Features", Icon = "swords" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "sliders" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- 1. Bật/Tắt Tự Động Trang Bị Mạnh Nhất (Auto Equip Best)
local AutoEquipToggle = Tabs.Main:AddToggle("AutoEquipBest", { Title = "Auto Equip Best (Every 3 Mins)", Default = false })

-- 2. Bật/Tắt Tấn Công Thường (Auto Attack)
local AutoAttackToggle = Tabs.Main:AddToggle("AutoAttack", { Title = "Auto Damage Spam", Default = false })

-- 3. Cài đặt cấu hình nhịp độ và mục tiêu
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
    Description = "Limit the number of enemies targeted simultaneously.",
    Default = 4,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(Value) end
})

-- =============================================================================
-- HÀM TỰ ĐỘNG XÁC ĐỊNH TOP 3 ZOMBIE MẠNH NHẤT THEO DAMAGE ATTR
-- =============================================================================
local function fetchTop3Zombies()
    local success, playerData = pcall(function()
        return dataRemote:InvokeServer()
    end)
    
    if success and playerData and playerData.EquippedZombies then
        local serverZombies = playerData.EquippedZombies
        local petsFolder = getCurrentZombiePetsFolder()
        
        local damageMap = {}
        if petsFolder then
            for _, pet in ipairs(petsFolder:GetChildren()) do
                if pet:IsA("Model") then
                    local dmgAttr = pet:GetAttribute("Damage") or 0
                    if not damageMap[pet.Name] or dmgAttr > damageMap[pet.Name] then
                        damageMap[pet.Name] = tonumber(dmgAttr) or 0
                    end
                end
            end
        end

        for _, zombie in pairs(serverZombies) do
            zombie.ActualDamage = damageMap[zombie.Name] or 0
        end
        
        table.sort(serverZombies, function(a, b)
            if a.ActualDamage == b.ActualDamage then
                return (tonumber(a.EquipId) or 0) > (tonumber(b.EquipId) or 0)
            end
            return a.ActualDamage > b.ActualDamage
        end)
        
        local top3 = {}
        for i = 1, math.min(3, #serverZombies) do
            table.insert(top3, serverZombies[i])
        end
        
        cacheEquippedZombies = top3
        return top3
    end
    return {}
end

-- Nút bấm làm mới thủ công (Giữ lại để bạn dùng khi cần ép cập nhật gấp)
Tabs.Main:AddButton({
    Title = "Manual Refresh Top 3",
    Description = "Forces the script to recalculate top 3 zombies immediately.",
    Callback = function()
        fetchTop3Zombies()
        Fluent:Notify({ Title = "System", Content = "Successfully sorted top 3 zombies by real damage!", Duration = 3 })
    end
})

task.spawn(fetchTop3Zombies)

-- =============================================================================
-- CÁC PHẦN TỬ ĐIỀU KHIỂN TRÊN TAB MISC
-- =============================================================================
local SpeedPlayerSlider = Tabs.Misc:AddSlider("PlayerSpeed", { Title = "WalkSpeed", Default = 16, Min = 16, Max = 300, Rounding = 0, Callback = function(Value) currentWalkSpeed = Value end })
local JumpPlayerSlider = Tabs.Misc:AddSlider("PlayerJump", { Title = "JumpPower", Default = 50, Min = 50, Max = 300, Rounding = 0, Callback = function(Value) currentJumpPower = Value end })

Tabs.Misc:AddButton({
    Title = "DESTROY GUI",
    Description = "Completely unloads the script, UI, and background loops for testing.",
    Callback = function()
        Window:Dialog({
            Title = "Confirm Destruction",
            Content = "Are you sure you want to completely destroy this GUI? All background tasks will stop immediately.",
            Buttons = {
                { Title = "Confirm", Callback = function() Fluent:Destroy() end },
                { Title = "Cancel", Callback = function() print("Destruction cancelled.") end }
            }
        })
    end
})

-- =============================================================================
-- CÁC VÒNG LẶP CHẠY NGẦM KHÔNG ĐỂ LẠI LOG (BACKGROUND LOOPS)
-- =============================================================================

-- VÒNG LẶP 1: Spam Damage chính
task.spawn(function()
    while true do
        if Fluent.Unloaded then break end

        local attackEnabled = Options.AutoAttack.Value
        local attackDelay = Options.AttackSpeed.Value
        local maxTargets = Options.MaxTargets.Value

        if attackEnabled and #cacheEquippedZombies > 0 then
            local currentFolder = getCurrentEnemyFolder()
            
            if currentFolder then
                local targetedCount = 0
                
                for _, enemy in ipairs(currentFolder:GetChildren()) do
                    if enemy:IsA("Model") and enemy:GetAttribute("UnderAttack") == true then
                        local enemyId = enemy:GetAttribute("EnemyId") or enemy:GetAttribute("enemyId")
                        
                        if enemyId then
                            targetedCount = targetedCount + 1
                            local idNum = tonumber(enemyId) or enemyId
                            
                            for _, zombie in pairs(cacheEquippedZombies) do
                                if zombie.Name and zombie.EquipId then
                                    damageRemote:FireServer({
                                        {
                                            name = zombie.Name,
                                            enemyId = idNum,
                                            equipId = tonumber(zombie.EquipId)
                                        }
                                    })
                                end
                            end
                            
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

-- VÒNG LẶP 2: Auto Equip Best chạy mỗi 3 phút (180 giây)
task.spawn(function()
    while true do
        if Fluent.Unloaded then break end
        
        if Options.AutoEquipBest.Value then
            pcall(function() equipBestRemote:InvokeServer() end)
            fetchTop3Zombies()
            task.wait(180) 
        else
            task.wait(1)
        end
    end
end)

-- VÒNG LẶP 3: Giữ chỉ số WalkSpeed & JumpPower liên tục
task.spawn(function()
    while true do
        if Fluent.Unloaded then break end
        
        local character = localPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        
        if humanoid then
            if humanoid.WalkSpeed ~= currentWalkSpeed then humanoid.WalkSpeed = currentWalkSpeed end
            if humanoid.JumpPower ~= currentJumpPower then
                humanoid.UseJumpPower = true
                humanoid.JumpPower = currentJumpPower
            end
        end
        task.wait(0.1)
    end
end)

-- VÒNG LẶP 4: Tự động quét nhẹ danh sách Pet dựa trên map mới mỗi 15 giây
task.spawn(function()
    while task.wait(15) do
        if Fluent.Unloaded then break end
        if Options.AutoAttack.Value == false and Options.AutoEquipBest.Value == false then
            fetchTop3Zombies()
        end
    end
end)

-- Bàn giao cấu hình cho SaveManager
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
    Content = "Script loaded successfully! Clean & Optimized.",
    Duration = 5
})