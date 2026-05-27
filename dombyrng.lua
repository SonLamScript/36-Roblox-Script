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

-- =============================================================================
-- THIẾT LẬP GIAO DIỆN MENU FLUENT (ENGLISH INTERFACE)
-- =============================================================================
local Window = Fluent:CreateWindow({
    Title = "Zombie Spammer Hub",
    SubTitle = "Optimized Version",
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

-- =============================================================================
-- CÁC PHẦN TỬ ĐIỀU KHIỂN TRÊN TAB MAIN
-- =============================================================================

-- Khu vực hiện Debug 3 con Zombie đang được chọn để đánh
local DebugParagraph = Tabs.Main:AddParagraph({
    Title = "Selected Zombies Debug",
    Content = "Fetching data, please wait..."
})

-- 1. Bật/Tắt Tự Động Trang Bị Mạnh Nhất (Auto Equip Best)
local AutoEquipToggle = Tabs.Main:AddToggle("AutoEquipBest", { Title = "Auto Equip Best", Default = false })

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
    Description = "Limit the number of enemies targeted simultaneously (Recommended: 3-4).",
    Default = 4,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(Value) end
})

-- =============================================================================
-- HÀM XỬ LÝ LOGIC TỰ ĐỘNG LỌC TOP 3 ZOMBIE MẠNH NHẤT & CẬP NHẬT DEBUG UI
-- =============================================================================
local function fetchTop3Zombies()
    local success, playerData = pcall(function()
        return dataRemote:InvokeServer()
    end)
    
    if success and playerData and playerData.EquippedZombies then
        local zombies = playerData.EquippedZombies
        
        -- Sắp xếp toàn bộ Zombie đang trang bị theo EquipId giảm dần
        table.sort(zombies, function(a, b)
            local idA = tonumber(a.EquipId) or 0
            local idB = tonumber(b.EquipId) or 0
            return idA > idB
        end)
        
        -- Lọc lấy ra tối đa đúng 3 con đầu bảng (mạnh nhất)
        local top3 = {}
        for i = 1, math.min(3, #zombies) do
            table.insert(top3, zombies[i])
        end
        
        cacheEquippedZombies = top3
        
        -- Tiến hành cập nhật nội dung Text hiển thị lên Debug Paragraph trên Menu
        local debugText = ""
        if #top3 == 0 then
            debugText = "No zombies currently equipped or found!"
        else
            for index, zombie in ipairs(top3) do
                debugText = debugText .. string.format("[%d] %s (ID: %s)\n", index, tostring(zombie.Name), tostring(zombie.EquipId))
            end
        end
        -- Cắt bỏ dấu xuống dòng thừa ở cuối cùng
        debugText = debugText:sub(1, #debugText - 1)
        
        -- Cập nhật giao diện Fluent UI
        DebugParagraph:SetTitle("Selected Zombies Debug (" .. tostring(#top3) .. "/3)")
        DebugParagraph:SetContent(debugText)
        
        return top3
    end
    
    DebugParagraph:SetContent("Error: Failed to fetch data from Server.")
    return {}
end

-- Nút bấm thủ công hỗ trợ làm mới danh sách Top 3
Tabs.Main:AddButton({
    Title = "Manual Refresh Top 3",
    Description = "Forces the script to recalculate your top 3 strongest equipped zombies.",
    Callback = function()
        fetchTop3Zombies()
        Fluent:Notify({ Title = "System", Content = "Successfully optimized top 3 strongest zombies!", Duration = 3 })
    end
})

-- Lấy danh sách lần đầu tiên khi vừa chạy script để nạp UI ngay lập tức
task.spawn(fetchTop3Zombies)

-- =============================================================================
-- CÁC PHẦN TỬ ĐIỀU KHIỂN TRÊN TAB MISC
-- =============================================================================
local SpeedPlayerSlider = Tabs.Misc:AddSlider("PlayerSpeed", {
    Title = "WalkSpeed",
    Default = 16,
    Min = 16,
    Max = 300,
    Rounding = 0,
    Callback = function(Value) currentWalkSpeed = Value end
})

local JumpPlayerSlider = Tabs.Misc:AddSlider("PlayerJump", {
    Title = "JumpPower",
    Default = 50,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(Value) currentJumpPower = Value end
})

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
                    Callback = function() Fluent:Destroy() end
                },
                {
                    Title = "Cancel",
                    Callback = function() print("Destruction cancelled.") end
                }
            }
        })
    end
})

-- =============================================================================
-- LUỒNG CHẠY NGẦM KHỞI TẠO CÁC CHỨC NĂNG VÒNG LẶP (BACKGROUND LOOPS)
-- =============================================================================

-- LUỒNG 1: Vòng lặp Spam Damage chính (Chỉ lấy tối đa Top 3 Zombie từ Cache)
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
                            
                            -- Spam sát thương dồn từ danh sách tối đa 3 con mạnh nhất đã được lọc sẵn
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

-- LUỒNG 2: Vòng lặp Auto Equip Best và tự động cập nhật danh sách Top 3 + Debug UI
task.spawn(function()
    while true do
        if Fluent.Unloaded then break end
        
        if Options.AutoEquipBest.Value then
            pcall(function()
                equipBestRemote:InvokeServer()
            end)
            -- Sau khi bấm trang bị tốt nhất, gọi hàm lọc lại Top 3 để cập nhật text debug luôn
            fetchTop3Zombies()
            task.wait(5) -- Nhịp chờ 5 giây một lần
        else
            task.wait(1)
        end
    end
end)

-- LUỒNG 3: Vòng lặp giữ chỉ số WalkSpeed & JumpPower liên tục
task.spawn(function()
    while true do
        if Fluent.Unloaded then break end
        
        local character = localPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        
        if humanoid then
            if humanoid.WalkSpeed ~= currentWalkSpeed then
                humanoid.WalkSpeed = currentWalkSpeed
            end
            if humanoid.JumpPower ~= currentJumpPower then
                humanoid.UseJumpPower = true
                humanoid.JumpPower = currentJumpPower
            end
        end
        task.wait(0.1)
    end
end)

-- LUỒNG 4: Tự động đồng bộ nhẹ danh sách Pet và cập nhật Debug UI mỗi 15 giây khi không treo auto-equip
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
    Content = "Optimized script with Live Debug UI loaded successfully!",
    Duration = 5
})