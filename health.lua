local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "NEXUS Hub v3.2",
    SubTitle = "by SonDz",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main Exploit", Icon = "play" }),
    Debug = Window:AddTab({ Title = "Debug", Icon = "code" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options
local isRunning = true -- Flag stop threads

do
    Tabs.Main:AddParagraph({
        Title = "NEXUS Core",
        Content = "Hệ thống tự động hóa tối ưu băng thông."
    })

    local TPToggle = Tabs.Main:AddToggle("TPZone", {Title = "Hard Spoof Position (Lock)", Default = false })
    
    local SpamDelaySlider = Tabs.Main:AddSlider("SpamDelay", {
        Title = "Remote Spam Delay",
        Description = "Kéo để chỉnh tốc độ gửi request MHP (giây)",
        Default = 0.05,
        Min = 0.01,
        Max = 1.0,
        Rounding = 2,
        Callback = function(Value) end
    })
    local SpamToggle = Tabs.Main:AddToggle("SpamMHP", {Title = "Spam Remote MHP", Default = false })
    local TouchToggle = Tabs.Main:AddToggle("TouchBtn", {Title = "Auto Touch Button16", Default = false })

    local EggAmountSlider = Tabs.Main:AddSlider("EggAmount", {
        Title = "Egg Open Amount",
        Description = "Số lượng trứng muốn mở mỗi lượt",
        Default = 50,
        Min = 1,
        Max = 100,
        Rounding = 0,
        Callback = function(Value) end
    })
    local RollToggle = Tabs.Main:AddToggle("AutoRoll", {Title = "Auto Roll Pet (Egg4)", Default = false })

    Tabs.Debug:AddParagraph({
        Title = "Developer Sandbox",
        Content = "Hot-Reloading quản lý runtime."
    })

    Tabs.Debug:AddButton({
        Title = "DESTROY GUI",
        Description = "Dọn sạch hoàn toàn thread, loop, UI để chạy bản mới fr fr",
        Callback = function()
            Window:Dialog({
                Title = "Xác nhận Hot-Reload",
                Content = "Hành động này sẽ ngắt toàn bộ loop ẩn và xóa GUI gốc sạch sẽ.",
                Buttons = {
                    {
                        Title = "Xóa Ngay",
                        Callback = function()
                            isRunning = false -- Phá loop thread
                            Fluent:Destroy() -- Xóa UI instance
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

    local runService = game:GetService("RunService")
    local lp = game:GetService("Players").LocalPlayer
    local waitFrame = runService.Heartbeat.Wait

    local mhpRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("MHP")
    local fireServer = mhpRemote.FireServer
    local firetouch = firetouchinterest

    local luckRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remote"):WaitForChild("Function"):WaitForChild("Luck"):WaitForChild("[C-S]DoLuck")
    local invokeServer = luckRemote.InvokeServer

    local TARGET_POS = Vector3.new(5137, 54, 12)

    -- Loop 1: Hard Lock Position
    task.spawn(function()
        while isRunning do
            waitFrame(runService.Heartbeat)
            if Options.TPZone and Options.TPZone.Value then
                local char = lp.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = CFrame.new(TARGET_POS)
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end
            end
        end
    end)

    -- Loop 2: Spam Remote MHP
    task.spawn(function()
        while isRunning do
            if Options.SpamMHP and Options.SpamMHP.Value then
                fireServer(mhpRemote)
                task.wait(Options.SpamDelay.Value)
            else
                task.wait(0.1)
            end
        end
    end)

    -- Loop 3: Auto Touch Button16
    task.spawn(function()
        while isRunning do
            waitFrame(runService.Heartbeat)
            if Options.TouchBtn and Options.TouchBtn.Value then
                local buttonsFolder = workspace:FindFirstChild("Buttons")
                local button = buttonsFolder and buttonsFolder:FindFirstChild("Button16")
                local char = lp.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                
                if button and root and firetouch then
                    for _ = 1, 50 do
                        firetouch(root, button, 0)
                        firetouch(root, button, 1)
                    end
                end
            end
        end
    end)

    -- Loop 4: Auto Roll Pet
    task.spawn(function()
        while isRunning do
            if Options.AutoRoll and Options.AutoRoll.Value then
                local currentAmount = Options.EggAmount.Value
                pcall(function()
                    invokeServer(luckRemote, "Egg4", currentAmount)
                end)
                task.wait(0.3)
            else
                task.wait(0.2)
            end
        end
    end)
end

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetFolder("NEXUS_FluentHub") -- FIXED: Viết hoa chữ S chuẩn hóa method của Fluent
SaveManager:SetFolder("NEXUS_FluentHub/game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()

Fluent:Notify({
    Title = "NEXUS Fixed",
    Content = "Đã sửa lỗi cú pháp 'setFolder' thành 'SetFolder'. Chạy bao mượt no cap!",
    Duration = 5
})
