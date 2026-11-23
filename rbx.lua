--[[
    ========================================================================
    AkioHub v1.2.0 - Ultimate Roblox Companion (Full Merged Edition)
    Developer : Akio
    Design    : iOS-Inspired Black & White Glassmorphism UI
    Modules   : Full Companion Suite + Auto Farm High Altitude Platform
    Architecture: Single-File Modular Luau (GitHub Raw Loadstring Ready)
    ========================================================================
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local StartTick = tick()
local StartTimeStr = os.date("%H:%M:%S")

--// Prevent Duplicate Execution
local UI_NAME = "AkioHub_Companion_v1_2"
local function GetParentGui()
    if gethui then
        return gethui()
    elseif syn and syn.protect_gui then
        local sg = Instance.new("ScreenGui")
        syn.protect_gui(sg)
        sg.Parent = CoreGui
        return sg
    else
        local ok, result = pcall(function()
            return CoreGui
        end)
        if ok and result then
            return result
        end
        return LocalPlayer:WaitForChild("PlayerGui")
    end
end

local TargetParent = GetParentGui()
if not TargetParent:IsA("ScreenGui") then
    local old = TargetParent:FindFirstChild(UI_NAME)
    if old then old:Destroy() end
end

--// State & Configuration
local State = {
    Theme = "DarkGlass", -- DarkGlass, LightGlass, PureBW
    ReducedMotion = false,
    CurrentTab = "Dashboard",
    Minimized = false,
    Maximized = false,
    ToggleKey = Enum.KeyCode.RightControl,
    History = {},
    Notifications = {},
    Notes = "Catatan development & testing AkioHub...",
    FPSHistory = {},
    -- Auto Farm High Altitude Platform State
    AutoFarmEnabled = false,
    PlatformEnabled = true,
    PlatformSize = 40,
    PlatformTransparency = 0.65,
    PlatformColorName = "PureWhite",
    TargetAltitude = nil,
    FarmElapsed = 0,
    FloatingPanelVisible = false
}

local PlatformColors = {
    PureWhite = {label = "Pure White", color = Color3.fromRGB(248, 248, 252)},
    SilverMist = {label = "Silver Mist", color = Color3.fromRGB(185, 185, 196)},
    ObsidianGlass = {label = "Obsidian Glass", color = Color3.fromRGB(32, 32, 38)}
}

--// Theme Palettes (iOS Monochrome Glass)
local Themes = {
    DarkGlass = {
        BgMain = Color3.fromRGB(18, 18, 22),
        BgPanel = Color3.fromRGB(28, 28, 34),
        BgCard = Color3.fromRGB(36, 36, 44),
        TextPrimary = Color3.fromRGB(250, 250, 252),
        TextSecondary = Color3.fromRGB(165, 165, 175),
        Stroke = Color3.fromRGB(255, 255, 255),
        StrokeTrans = 0.85,
        MainTrans = 0.16,
        CardTrans = 0.25,
        BadgeBg = Color3.fromRGB(255, 255, 255),
        BadgeText = Color3.fromRGB(15, 15, 18)
    },
    LightGlass = {
        BgMain = Color3.fromRGB(242, 242, 247),
        BgPanel = Color3.fromRGB(255, 255, 255),
        BgCard = Color3.fromRGB(232, 232, 238),
        TextPrimary = Color3.fromRGB(20, 20, 24),
        TextSecondary = Color3.fromRGB(100, 100, 112),
        Stroke = Color3.fromRGB(0, 0, 0),
        StrokeTrans = 0.88,
        MainTrans = 0.14,
        CardTrans = 0.20,
        BadgeBg = Color3.fromRGB(20, 20, 24),
        BadgeText = Color3.fromRGB(250, 250, 252)
    },
    PureBW = {
        BgMain = Color3.fromRGB(10, 10, 10),
        BgPanel = Color3.fromRGB(18, 18, 18),
        BgCard = Color3.fromRGB(26, 26, 26),
        TextPrimary = Color3.fromRGB(255, 255, 255),
        TextSecondary = Color3.fromRGB(170, 170, 170),
        Stroke = Color3.fromRGB(255, 255, 255),
        StrokeTrans = 0.78,
        MainTrans = 0.10,
        CardTrans = 0.15,
        BadgeBg = Color3.fromRGB(255, 255, 255),
        BadgeText = Color3.fromRGB(0, 0, 0)
    }
}

--// Utility Functions
local function Create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

local function Tween(obj, props, duration, style, dir)
    if State.ReducedMotion then
        for k, v in pairs(props) do
            obj[k] = v
        end
        return
    end
    local info = TweenInfo.new(
        duration or 0.28,
        style or Enum.EasingStyle.Quint,
        dir or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function CopyClipboard(text)
    if setclipboard then
        setclipboard(tostring(text))
        return true
    elseif toclipboard then
        toclipboard(tostring(text))
        return true
    end
    return false
end

local function FormatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function AddHistory(action)
    table.insert(State.History, 1, {
        time = os.date("%H:%M:%S"),
        action = action
    })
    if #State.History > 40 then
        table.remove(State.History)
    end
end

--// Fetch Experience Name Safely
local ExperienceName = "Loading Experience..."
task.spawn(function()
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if ok and info and info.Name then
        ExperienceName = info.Name
    else
        ExperienceName = "Place #" .. tostring(game.PlaceId)
    end
end)

--// Root ScreenGui
local ScreenGui = TargetParent:IsA("ScreenGui") and TargetParent or Create("ScreenGui", {
    Name = UI_NAME,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    Parent = TargetParent
})

--// Theme Registry for Live Switching
local ThemeBindings = {}
local function BindTheme(obj, prop, key)
    table.insert(ThemeBindings, {obj = obj, prop = prop, key = key})
    obj[prop] = Themes[State.Theme][key]
end

local function ApplyTheme(themeName)
    State.Theme = themeName
    local t = Themes[themeName]
    for _, b in ipairs(ThemeBindings) do
        if b.obj and b.obj.Parent then
            Tween(b.obj, {[b.prop] = t[b.key]}, 0.25)
        end
    end
end

--// Toast Notification System
local ToastHolder = Create("Frame", {
    Name = "ToastHolder",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -20, 0, 20),
    Size = UDim2.new(0, 300, 0, 400),
    BackgroundTransparency = 1,
    ZIndex = 120,
    Parent = ScreenGui
}, {
    Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 8)
    })
})

local function Notify(title, message, nType)
    table.insert(State.Notifications, 1, {
        title = title,
        message = message,
        type = nType or "System",
        time = os.date("%H:%M:%S")
    })
    if #State.Notifications > 50 then
        table.remove(State.Notifications)
    end

    local t = Themes[State.Theme]
    local toast = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundColor3 = t.BgPanel,
        BackgroundTransparency = 0.12,
        ClipsDescendants = true,
        ZIndex = 121,
        Parent = ToastHolder
    }, {
        Create("UICorner", {CornerRadius = UDim.new(0, 14)}),
        Create("UIStroke", {
            Color = t.Stroke,
            Transparency = t.StrokeTrans,
            Thickness = 1
        }),
        Create("TextLabel", {
            Position = UDim2.new(0, 14, 0, 10),
            Size = UDim2.new(1, -28, 0, 18),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Text = title,
            TextColor3 = t.TextPrimary,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 122
        }),
        Create("TextLabel", {
            Position = UDim2.new(0, 14, 0, 29),
            Size = UDim2.new(1, -28, 0, 24),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = message,
            TextColor3 = t.TextSecondary,
            TextSize = 11,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 122
        })
    })

    toast.Position = UDim2.new(1, 320, 0, 0)
    Tween(toast, {Position = UDim2.new(0, 0, 0, 0)}, 0.35, Enum.EasingStyle.Back)

    task.delay(3.5, function()
        if toast and toast.Parent then
            local out = Tween(toast, {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0)}, 0.25)
            if out then out.Completed:Wait() end
            toast:Destroy()
        end
    end)
end

--// High Altitude Platform Engine
local PlatformPart = nil
local PlatformSelection = nil

local function DestroyPlatform()
    if PlatformSelection then
        PlatformSelection:Destroy()
        PlatformSelection = nil
    end
    if PlatformPart then
        PlatformPart:Destroy()
        PlatformPart = nil
    end
end

local function EnsurePlatform()
    if not State.PlatformEnabled then
        DestroyPlatform()
        return nil
    end

    if not PlatformPart or not PlatformPart.Parent then
        PlatformPart = Create("Part", {
            Name = "AkioHub_HighAltitudePlatform",
            Anchored = true,
            CanCollide = true,
            CanQuery = false,
            CanTouch = false,
            Material = Enum.Material.SmoothPlastic,
            Size = Vector3.new(State.PlatformSize, 1.5, State.PlatformSize),
            Transparency = State.PlatformTransparency,
            Color = PlatformColors[State.PlatformColorName].color,
            TopSurface = Enum.SurfaceType.Smooth,
            BottomSurface = Enum.SurfaceType.Smooth,
            Parent = workspace
        })

        PlatformSelection = Create("SelectionBox", {
            Name = "AkioPlatformBorder",
            Adornee = PlatformPart,
            Color3 = Color3.fromRGB(245, 245, 250),
            LineThickness = 0.04,
            SurfaceTransparency = 0.85,
            Parent = PlatformPart
        })
    else
        PlatformPart.Size = Vector3.new(State.PlatformSize, 1.5, State.PlatformSize)
        PlatformPart.Transparency = State.PlatformTransparency
        PlatformPart.Color = PlatformColors[State.PlatformColorName].color
    end

    return PlatformPart
end

local function ComputeHighestElevatedY(originXZ)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignoreList = {}
    if LocalPlayer.Character then
        table.insert(ignoreList, LocalPlayer.Character)
    end
    if PlatformPart then
        table.insert(ignoreList, PlatformPart)
    end
    params.FilterDescendantsInstances = ignoreList
    params.IgnoreWater = false

    local rayOrigin = Vector3.new(originXZ.X, 1200, originXZ.Z)
    local result = workspace:Raycast(rayOrigin, Vector3.new(0, -1600, 0), params)

    local baseHighestY = result and result.Position.Y or (LocalPlayer.Character and LocalPlayer.Character:GetPivot().Position.Y or 50)
    return math.clamp(baseHighestY + 28, 35, 1150)
end

local function PositionCharacterAtAltitude(targetY)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local currentXZ = Vector2.new(root.Position.X, root.Position.Z)
    local plat = EnsurePlatform()
    if plat then
        plat.CFrame = CFrame.new(currentXZ.X, targetY - 1.25, currentXZ.Y)
    end

    local desiredPos = Vector3.new(currentXZ.X, targetY + 2.5, currentXZ.Y)
    local distY = math.abs(root.Position.Y - desiredPos.Y)
    if distY > 1.5 or not State.PlatformEnabled then
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = CFrame.new(desiredPos, desiredPos + root.CFrame.LookVector)
    end
end

local StopAutoFarm

--// Animated Loading Screen (iOS Boot Splash)
local Splash = Create("Frame", {
    Name = "SplashScreen",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(10, 10, 12),
    BackgroundTransparency = 0.15,
    ZIndex = 200,
    Parent = ScreenGui
})

local SplashCard = Create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 260, 0, 170),
    BackgroundColor3 = Color3.fromRGB(22, 22, 26),
    BackgroundTransparency = 0.1,
    ZIndex = 201,
    Parent = Splash
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 24)}),
    Create("UIStroke", {Color = Color3.new(1, 1, 1), Transparency = 0.82, Thickness = 1}),
    Create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 24),
        Size = UDim2.new(0, 48, 0, 48),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 202
    }, {
        Create("UICorner", {CornerRadius = UDim.new(0, 14)}),
        Create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBlack,
            Text = "Λ",
            TextColor3 = Color3.fromRGB(12, 12, 14),
            TextSize = 26,
            ZIndex = 203
        })
    }),
    Create("TextLabel", {
        Position = UDim2.new(0, 0, 0, 82),
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "AkioHub",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 18,
        ZIndex = 202
    }),
    Create("TextLabel", {
        Position = UDim2.new(0, 0, 0, 104),
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = "Ultimate Roblox Companion • v1.2.0",
        TextColor3 = Color3.fromRGB(160, 160, 170),
        TextSize = 11,
        ZIndex = 202
    })
})

local ProgressTrack = Create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 136),
    Size = UDim2.new(0, 180, 0, 4),
    BackgroundColor3 = Color3.fromRGB(50, 50, 58),
    ZIndex = 202,
    Parent = SplashCard
}, {
    Create("UICorner", {CornerRadius = UDim.new(1, 0)})
})

local ProgressFill = Create("Frame", {
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    ZIndex = 203,
    Parent = ProgressTrack
}, {
    Create("UICorner", {CornerRadius = UDim.new(1, 0)})
})

--// Responsive Sizing Calculation
local Viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled or Viewport.X < 760
local DefaultWidth = IsMobile and math.clamp(Viewport.X - 24, 340, 620) or 880
local DefaultHeight = IsMobile and math.clamp(Viewport.Y - 60, 420, 640) or 550

--// Main Floating Window
local MainWindow = Create("Frame", {
    Name = "MainWindow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, DefaultWidth, 0, DefaultHeight),
    ClipsDescendants = true,
    Visible = false,
    Parent = ScreenGui
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 22)})
})
BindTheme(MainWindow, "BackgroundColor3", "BgMain")
BindTheme(MainWindow, "BackgroundTransparency", "MainTrans")

local MainStroke = Create("UIStroke", {
    Thickness = 1.2,
    Parent = MainWindow
})
BindTheme(MainStroke, "Color", "Stroke")
BindTheme(MainStroke, "Transparency", "StrokeTrans")

--// Top Titlebar (Draggable + Window Controls)
local TopBar = Create("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 52),
    BackgroundTransparency = 1,
    Parent = MainWindow
})

local BrandGroup = Create("Frame", {
    Position = UDim2.new(0, 16, 0.5, -16),
    Size = UDim2.new(0, 270, 0, 32),
    BackgroundTransparency = 1,
    Parent = TopBar
})

local LogoBadge = Create("Frame", {
    Size = UDim2.new(0, 32, 0, 32),
    Parent = BrandGroup
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
    Create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack,
        Text = "Λ",
        TextSize = 17,
        Name = "Glyph"
    })
})
BindTheme(LogoBadge, "BackgroundColor3", "BadgeBg")
BindTheme(LogoBadge.Glyph, "TextColor3", "BadgeText")

local BrandTitle = Create("TextLabel", {
    Position = UDim2.new(0, 42, 0, 0),
    Size = UDim2.new(0, 190, 0, 18),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "AkioHub",
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = BrandGroup
})
BindTheme(BrandTitle, "TextColor3", "TextPrimary")

local BrandSub = Create("TextLabel", {
    Position = UDim2.new(0, 42, 0, 17),
    Size = UDim2.new(0, 220, 0, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Ultimate Roblox Companion • v1.2.0",
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = BrandGroup
})
BindTheme(BrandSub, "TextColor3", "TextSecondary")

local ControlsFrame = Create("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -16, 0.5, 0),
    Size = UDim2.new(0, 108, 0, 28),
    BackgroundTransparency = 1,
    Parent = TopBar
}, {
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8)
    })
})

local function MakeWinBtn(symbol, bg, callback)
    local btn = Create("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        BackgroundColor3 = bg,
        BackgroundTransparency = 0.15,
        Font = Enum.Font.GothamBold,
        Text = symbol,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 13,
        AutoButtonColor = false,
        Parent = ControlsFrame
    }, {
        Create("UICorner", {CornerRadius = UDim.new(1, 0)})
    })
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local FloatingPill = Create("TextButton", {
    Name = "AkioFloatingPill",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 14),
    Size = UDim2.new(0, 154, 0, 36),
    BackgroundColor3 = Color3.fromRGB(20, 20, 24),
    BackgroundTransparency = 0.15,
    Font = Enum.Font.GothamBold,
    Text = "Λ  AkioHub",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 13,
    Visible = false,
    ZIndex = 90,
    Parent = ScreenGui
}, {
    Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
    Create("UIStroke", {Color = Color3.new(1, 1, 1), Transparency = 0.8, Thickness = 1})
})

MakeWinBtn("−", Color3.fromRGB(70, 70, 80), function()
    State.Minimized = true
    MainWindow.Visible = false
    FloatingPill.Visible = true
    Notify("AkioHub Minimized", "Klik pill di atas atau tekan RightCtrl untuk membuka.")
end)

MakeWinBtn("□", Color3.fromRGB(70, 70, 80), function()
    State.Maximized = not State.Maximized
    if State.Maximized then
        Tween(MainWindow, {
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0.95, 0, 0.92, 0)
        }, 0.3)
    else
        Tween(MainWindow, {
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, DefaultWidth, 0, DefaultHeight)
        }, 0.3)
    end
end)

MakeWinBtn("×", Color3.fromRGB(190, 55, 55), function()
    MainWindow.Visible = false
    FloatingPill.Visible = true
    Notify("AkioHub Hidden", "Interface disembunyikan. Klik pill untuk buka kembali.")
end)

FloatingPill.MouseButton1Click:Connect(function()
    MainWindow.Visible = true
    FloatingPill.Visible = false
    State.Minimized = false
end)

--// Helper for Draggable Frames
local function MakeDraggable(frame, handle, lockWhenMaximized)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            if lockWhenMaximized and State.Maximized then return end
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

MakeDraggable(MainWindow, TopBar, true)

--// Divider Line
local TopDivider = Create("Frame", {
    Position = UDim2.new(0, 16, 0, 52),
    Size = UDim2.new(1, -32, 0, 1),
    BorderSizePixel = 0,
    Parent = MainWindow
})
BindTheme(TopDivider, "BackgroundColor3", "Stroke")
BindTheme(TopDivider, "BackgroundTransparency", "StrokeTrans")

--// Navigation & Content Area Layout
local NavList = {
    {id = "Dashboard", icon = "⌂", label = "Dashboard"},
    {id = "AutoFarm", icon = "▲", label = "Auto Farm"},
    {id = "Profile", icon = "◉", label = "Profile"},
    {id = "Avatar", icon = "◈", label = "Avatar"},
    {id = "Servers", icon = "⊞", label = "Servers"},
    {id = "Players", icon = "❖", label = "Players"},
    {id = "Performance", icon = "⚡", label = "Performance"},
    {id = "Session", icon = "◷", label = "Session"},
    {id = "Statistics", icon = "▤", label = "Statistics"},
    {id = "Utilities", icon = "⌘", label = "Utilities"},
    {id = "Notifications", icon = "🔔", label = "Alerts"},
    {id = "Settings", icon = "⚙", label = "Settings"},
    {id = "About", icon = "ⓘ", label = "About"}
}

local Sidebar = Create("ScrollingFrame", {
    Name = "Sidebar",
    Position = IsMobile and UDim2.new(0, 12, 1, -56) or UDim2.new(0, 14, 0, 62),
    Size = IsMobile and UDim2.new(1, -24, 0, 44) or UDim2.new(0, 185, 1, -76),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = IsMobile and Enum.AutomaticSize.X or Enum.AutomaticSize.Y,
    ScrollBarThickness = 0,
    ScrollingDirection = IsMobile and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
    Parent = MainWindow
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 16)}),
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6)
    }),
    Create("UIListLayout", {
        FillDirection = IsMobile and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4)
    })
})
BindTheme(Sidebar, "BackgroundColor3", "BgPanel")
BindTheme(Sidebar, "BackgroundTransparency", "CardTrans")

local SidebarStroke = Create("UIStroke", {Thickness = 1, Parent = Sidebar})
BindTheme(SidebarStroke, "Color", "Stroke")
BindTheme(SidebarStroke, "Transparency", "StrokeTrans")

local ContentArea = Create("Frame", {
    Name = "ContentArea",
    Position = IsMobile and UDim2.new(0, 12, 0, 62) or UDim2.new(0, 210, 0, 62),
    Size = IsMobile and UDim2.new(1, -24, 1, -126) or UDim2.new(1, -224, 1, -76),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    Parent = MainWindow
})

--// UI Component Builders
local Pages = {}
local NavButtons = {}

local function CreatePage(id)
    local page = Create("ScrollingFrame", {
        Name = id .. "_Page",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 0.6,
        Visible = (id == "Dashboard"),
        Parent = ContentArea
    }, {
        Create("UIPadding", {
            PaddingRight = UDim.new(0, 6),
            PaddingBottom = UDim.new(0, 16)
        }),
        Create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10)
        })
    })
    Pages[id] = page
    return page
end

local function CreateSectionTitle(parent, title, subtitle)
    local holder = Create("Frame", {
        Size = UDim2.new(1, 0, 0, subtitle and 38 or 24),
        BackgroundTransparency = 1,
        Parent = parent
    })
    local lbl = Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = title,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = holder
    })
    BindTheme(lbl, "TextColor3", "TextPrimary")

    if subtitle then
        local sub = Create("TextLabel", {
            Position = UDim2.new(0, 0, 0, 20),
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Text = subtitle,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = holder
        })
        BindTheme(sub, "TextColor3", "TextSecondary")
    end
    return holder
end

local function CreateCard(parent, height)
    local card = Create("Frame", {
        Size = UDim2.new(1, 0, 0, height or 80),
        AutomaticSize = height == nil and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
        Parent = parent
    }, {
        Create("UICorner", {CornerRadius = UDim.new(0, 16)}),
        Create("UIPadding", {
            PaddingTop = UDim.new(0, 12),
            PaddingBottom = UDim.new(0, 12),
            PaddingLeft = UDim.new(0, 14),
            PaddingRight = UDim.new(0, 14)
        })
    })
    BindTheme(card, "BackgroundColor3", "BgCard")
    BindTheme(card, "BackgroundTransparency", "CardTrans")

    local st = Create("UIStroke", {Thickness = 1, Parent = card})
    BindTheme(st, "Color", "Stroke")
    BindTheme(st, "Transparency", "StrokeTrans")
    return card
end

local function CreateActionButton(parent, text, callback)
    local btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        Font = Enum.Font.GothamSemibold,
        Text = text,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = parent
    }, {
        Create("UICorner", {CornerRadius = UDim.new(0, 11)})
    })
    BindTheme(btn, "BackgroundColor3", "BadgeBg")
    BindTheme(btn, "TextColor3", "BadgeText")

    btn.MouseButton1Click:Connect(function()
        AddHistory("Clicked: " .. text)
        Tween(btn, {BackgroundTransparency = 0.3}, 0.08)
        task.delay(0.1, function()
            if btn and btn.Parent then
                Tween(btn, {BackgroundTransparency = 0}, 0.15)
            end
        end)
        callback()
    end)
    return btn
end

local function CreateInfoRow(parent, labelText, initialValue)
    local row = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        Parent = parent
    })
    local k = Create("TextLabel", {
        Size = UDim2.new(0.45, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = labelText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row
    })
    BindTheme(k, "TextColor3", "TextSecondary")

    local v = Create("TextLabel", {
        Position = UDim2.new(0.45, 0, 0, 0),
        Size = UDim2.new(0.55, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        Text = tostring(initialValue),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row
    })
    BindTheme(v, "TextColor3", "TextPrimary")
    return v
end

--// Switch Tab Function
local function SwitchTab(tabId)
    State.CurrentTab = tabId
    AddHistory("Navigated to " .. tabId)
    for id, page in pairs(Pages) do
        page.Visible = (id == tabId)
    end
    for id, btn in pairs(NavButtons) do
        local active = (id == tabId)
        local t = Themes[State.Theme]
        Tween(btn, {
            BackgroundTransparency = active and 0.1 or 1
        }, 0.2)
        btn.TextColor3 = active and t.BadgeText or t.TextPrimary
    end
end

for _, item in ipairs(NavList) do
    local btn = Create("TextButton", {
        Name = item.id .. "_Nav",
        Size = IsMobile and UDim2.new(0, 96, 1, 0) or UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = (item.id == "Dashboard") and 0.1 or 1,
        Font = Enum.Font.GothamSemibold,
        Text = "  " .. item.icon .. "  " .. item.label,
        TextSize = 12,
        TextXAlignment = IsMobile and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        Parent = Sidebar
    }, {
        Create("UICorner", {CornerRadius = UDim.new(0, 11)})
    })
    BindTheme(btn, "BackgroundColor3", "BadgeBg")
    btn.TextColor3 = (item.id == "Dashboard") and Themes[State.Theme].BadgeText or Themes[State.Theme].TextPrimary

    btn.MouseButton1Click:Connect(function()
        SwitchTab(item.id)
    end)
    NavButtons[item.id] = btn
end

-- ========================================================================
-- 1. DASHBOARD PAGE (Full v1.0.0)
-- ========================================================================
local DashPage = CreatePage("Dashboard")
CreateSectionTitle(DashPage, "Welcome back, " .. LocalPlayer.DisplayName, "Live telemetry & workspace overview")

local HeroCard = CreateCard(DashPage, 88)
Create("ImageLabel", {
    Size = UDim2.new(0, 62, 0, 62),
    BackgroundColor3 = Color3.fromRGB(45, 45, 52),
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150",
    Parent = HeroCard
}, {
    Create("UICorner", {CornerRadius = UDim.new(1, 0)})
})

local HeroName = Create("TextLabel", {
    Position = UDim2.new(0, 76, 0, 4),
    Size = UDim2.new(1, -180, 0, 22),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")",
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = HeroCard
})
BindTheme(HeroName, "TextColor3", "TextPrimary")

local HeroMeta = Create("TextLabel", {
    Position = UDim2.new(0, 76, 0, 27),
    Size = UDim2.new(1, -180, 0, 18),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "UserID: " .. LocalPlayer.UserId .. " • Account Age: " .. LocalPlayer.AccountAge .. " days",
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = HeroCard
})
BindTheme(HeroMeta, "TextColor3", "TextSecondary")

local HeroLinkBtn = Create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, 0, 0.5, 0),
    Size = UDim2.new(0, 105, 0, 32),
    Font = Enum.Font.GothamSemibold,
    Text = "Copy Profile",
    TextSize = 11,
    Parent = HeroCard
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 10)})
})
BindTheme(HeroLinkBtn, "BackgroundColor3", "BadgeBg")
BindTheme(HeroLinkBtn, "TextColor3", "BadgeText")
HeroLinkBtn.MouseButton1Click:Connect(function()
    local url = "https://www.roblox.com/users/" .. LocalPlayer.UserId .. "/profile"
    if CopyClipboard(url) then
        Notify("Profile Link Copied", url)
    end
end)

local MetricsCard = CreateCard(DashPage)
Create("UIListLayout", {Padding = UDim.new(0, 4), Parent = MetricsCard})
local DashExpName = CreateInfoRow(MetricsCard, "Experience", ExperienceName)
CreateInfoRow(MetricsCard, "Place ID", game.PlaceId)
CreateInfoRow(MetricsCard, "Server Job ID", game.JobId ~= "" and game.JobId or "Studio / Local")
CreateInfoRow(MetricsCard, "Server Region", "Unavailable via Client API")
local DashPlayers = CreateInfoRow(MetricsCard, "Players", #Players:GetPlayers() .. " / " .. Players.MaxPlayers)
local DashSession = CreateInfoRow(MetricsCard, "Session Duration", "00:00:00")
local DashFPS = CreateInfoRow(MetricsCard, "Frame Rate (FPS)", "60 FPS")
local DashPing = CreateInfoRow(MetricsCard, "Network Ping", "Measuring...")
local DashMem = CreateInfoRow(MetricsCard, "Client Memory", "Measuring...")
CreateInfoRow(MetricsCard, "Platform / Input", IsMobile and "Mobile / Touch" or "Desktop / Keyboard")
local DashClock = CreateInfoRow(MetricsCard, "Local Time", os.date("%H:%M:%S"))

local QuickCard = CreateCard(DashPage)
Create("UIListLayout", {Padding = UDim.new(0, 8), Parent = QuickCard})
local QuickTitle = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "Quick Actions",
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = QuickCard
})
BindTheme(QuickTitle, "TextColor3", "TextPrimary")

CreateActionButton(QuickCard, "Copy Server Job ID", function()
    CopyClipboard(game.JobId)
    Notify("Copied", "Server Job ID disalin ke clipboard.")
end)

CreateActionButton(QuickCard, "Rejoin Current Server", function()
    Notify("Rejoining...", "Menghubungkan ulang ke server saat ini.")
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end)

-- ========================================================================
-- 2. AUTO FARM — HIGH ALTITUDE PLATFORM PAGE
-- ========================================================================
local FarmPage = CreatePage("AutoFarm")
CreateSectionTitle(FarmPage, "Auto Farm — High Altitude Platform", "Elevated testing vantage & persistent standing platform")

local FarmStatusCard = CreateCard(FarmPage)
Create("UIListLayout", {Padding = UDim.new(0, 5), Parent = FarmStatusCard})
local FarmStatusVal = CreateInfoRow(FarmStatusCard, "Farming Status", "Idle")
local FarmHeightVal = CreateInfoRow(FarmStatusCard, "Current Altitude (Y)", "0.0 studs")
local FarmPlatStateVal = CreateInfoRow(FarmStatusCard, "Platform State", "Enabled (Standby)")
local FarmTimerVal = CreateInfoRow(FarmStatusCard, "Farm Session Timer", "00:00:00")

local FarmControlsCard = CreateCard(FarmPage)
Create("UIListLayout", {Padding = UDim.new(0, 8), Parent = FarmControlsCard})

local ToggleFarmBtn = CreateActionButton(FarmControlsCard, "Auto Farm: OFF (Tap to Start)", function()
    State.AutoFarmEnabled = not State.AutoFarmEnabled
    if State.AutoFarmEnabled then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local xz = root and Vector2.new(root.Position.X, root.Position.Z) or Vector2.new(0, 0)
        State.TargetAltitude = ComputeHighestElevatedY(xz)
        PositionCharacterAtAltitude(State.TargetAltitude)
        Notify("Auto Farm Active", string.format("Diposisikan di ketinggian %.1f studs.", State.TargetAltitude))
    else
        Notify("Auto Farm Paused", "Auto Farm dijeda; platform tetap tersedia jika aktif.")
    end
end)

local TogglePlatBtn = CreateActionButton(FarmControlsCard, "Platform Surface: ENABLED", function()
    State.PlatformEnabled = not State.PlatformEnabled
    if State.PlatformEnabled then
        EnsurePlatform()
        Notify("Platform Enabled", "Standing platform transparan diaktifkan.")
    else
        DestroyPlatform()
        Notify("Platform Disabled", "Standing platform dihapus dari workspace.")
    end
end)

CreateActionButton(FarmControlsCard, "Floating Control Panel: SHOW / HIDE", function()
    State.FloatingPanelVisible = not State.FloatingPanelVisible
    Notify("Floating Panel", State.FloatingPanelVisible and "Floating control panel ditampilkan." or "Floating control panel disembunyikan.")
end)

StopAutoFarm = function()
    State.AutoFarmEnabled = false
    State.TargetAltitude = nil
    State.FarmElapsed = 0
    DestroyPlatform()
    Notify("Auto Farm Stopped", "Status direset ke Idle & platform dibersihkan.")
end

CreateActionButton(FarmControlsCard, "Stop & Reset Auto Farm", StopAutoFarm)

local FarmConfigCard = CreateCard(FarmPage)
Create("UIListLayout", {Padding = UDim.new(0, 8), Parent = FarmConfigCard})

local ConfigHeader = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "Platform Configuration",
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = FarmConfigCard
})
BindTheme(ConfigHeader, "TextColor3", "TextPrimary")

local SizeRow = CreateInfoRow(FarmConfigCard, "Platform Size", State.PlatformSize .. " x " .. State.PlatformSize .. " studs")
CreateActionButton(FarmConfigCard, "Cycle Size (24 / 40 / 64 studs)", function()
    if State.PlatformSize == 24 then
        State.PlatformSize = 40
    elseif State.PlatformSize == 40 then
        State.PlatformSize = 64
    else
        State.PlatformSize = 24
    end
    SizeRow.Text = State.PlatformSize .. " x " .. State.PlatformSize .. " studs"
    if PlatformPart then
        Tween(PlatformPart, {Size = Vector3.new(State.PlatformSize, 1.5, State.PlatformSize)}, 0.25)
    end
    Notify("Platform Size", "Ukuran platform diubah ke " .. State.PlatformSize .. " studs.")
end)

local TransRow = CreateInfoRow(FarmConfigCard, "Transparency", string.format("%.2f", State.PlatformTransparency))
CreateActionButton(FarmConfigCard, "Cycle Transparency (0.40 / 0.65 / 0.85)", function()
    if math.abs(State.PlatformTransparency - 0.40) < 0.05 then
        State.PlatformTransparency = 0.65
    elseif math.abs(State.PlatformTransparency - 0.65) < 0.05 then
        State.PlatformTransparency = 0.85
    else
        State.PlatformTransparency = 0.40
    end
    TransRow.Text = string.format("%.2f", State.PlatformTransparency)
    if PlatformPart then
        Tween(PlatformPart, {Transparency = State.PlatformTransparency}, 0.25)
    end
    Notify("Platform Transparency", "Transparansi diubah ke " .. TransRow.Text)
end)

local ColorRow = CreateInfoRow(FarmConfigCard, "Platform Color", PlatformColors[State.PlatformColorName].label)
CreateActionButton(FarmConfigCard, "Cycle Color (White / Silver / Obsidian)", function()
    if State.PlatformColorName == "PureWhite" then
        State.PlatformColorName = "SilverMist"
    elseif State.PlatformColorName == "SilverMist" then
        State.PlatformColorName = "ObsidianGlass"
    else
        State.PlatformColorName = "PureWhite"
    end
    ColorRow.Text = PlatformColors[State.PlatformColorName].label
    if PlatformPart then
        Tween(PlatformPart, {Color = PlatformColors[State.PlatformColorName].color}, 0.25)
    end
    Notify("Platform Color", "Warna platform: " .. ColorRow.Text)
end)

--// Floating Control Panel (Draggable iOS Glass Mini-Widget)
local FloatPanel = Create("Frame", {
    Name = "AutoFarmFloatingPanel",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -24, 0.5, 0),
    Size = UDim2.new(0, 210, 0, 128),
    Visible = false,
    ZIndex = 85,
    Parent = ScreenGui
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 18)}),
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12)
    })
})
BindTheme(FloatPanel, "BackgroundColor3", "BgPanel")
BindTheme(FloatPanel, "BackgroundTransparency", "MainTrans")

local FloatStroke = Create("UIStroke", {Thickness = 1, Parent = FloatPanel})
BindTheme(FloatStroke, "Color", "Stroke")
BindTheme(FloatStroke, "Transparency", "StrokeTrans")

local FloatHeader = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "▲ Auto Farm Control",
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 86,
    Parent = FloatPanel
})
BindTheme(FloatHeader, "TextColor3", "TextPrimary")
MakeDraggable(FloatPanel, FloatHeader, false)

local FloatStatusLbl = Create("TextLabel", {
    Position = UDim2.new(0, 0, 0, 20),
    Size = UDim2.new(1, 0, 0, 16),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Status: Idle • Alt: 0.0",
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 86,
    Parent = FloatPanel
})
BindTheme(FloatStatusLbl, "TextColor3", "TextSecondary")

local FloatToggleBtn = Create("TextButton", {
    Position = UDim2.new(0, 0, 0, 44),
    Size = UDim2.new(1, 0, 0, 30),
    Font = Enum.Font.GothamSemibold,
    Text = "Toggle Auto Farm",
    TextSize = 11,
    ZIndex = 86,
    Parent = FloatPanel
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 9)})
})
BindTheme(FloatToggleBtn, "BackgroundColor3", "BadgeBg")
BindTheme(FloatToggleBtn, "TextColor3", "BadgeText")
FloatToggleBtn.MouseButton1Click:Connect(function()
    State.AutoFarmEnabled = not State.AutoFarmEnabled
    if State.AutoFarmEnabled then
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local xz = root and Vector2.new(root.Position.X, root.Position.Z) or Vector2.new(0, 0)
        State.TargetAltitude = ComputeHighestElevatedY(xz)
        PositionCharacterAtAltitude(State.TargetAltitude)
        Notify("Auto Farm Active", "Diaktifkan via Floating Panel.")
    else
        Notify("Auto Farm Paused", "Dijeda via Floating Panel.")
    end
end)

local FloatPlatBtn = Create("TextButton", {
    Position = UDim2.new(0, 0, 0, 80),
    Size = UDim2.new(0.48, 0, 0, 28),
    Font = Enum.Font.GothamSemibold,
    Text = "Platform",
    TextSize = 10,
    ZIndex = 86,
    Parent = FloatPanel
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 9)})
})
BindTheme(FloatPlatBtn, "BackgroundColor3", "BgCard")
BindTheme(FloatPlatBtn, "TextColor3", "TextPrimary")
FloatPlatBtn.MouseButton1Click:Connect(function()
    State.PlatformEnabled = not State.PlatformEnabled
    if State.PlatformEnabled then EnsurePlatform() else DestroyPlatform() end
end)

local FloatStopBtn = Create("TextButton", {
    Position = UDim2.new(0.52, 0, 0, 80),
    Size = UDim2.new(0.48, 0, 0, 28),
    BackgroundColor3 = Color3.fromRGB(185, 55, 55),
    Font = Enum.Font.GothamSemibold,
    Text = "Stop / Reset",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 10,
    ZIndex = 86,
    Parent = FloatPanel
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 9)})
})
FloatStopBtn.MouseButton1Click:Connect(function()
    StopAutoFarm()
end)

-- ========================================================================
-- 3. PROFILE CENTER (Full v1.0.0)
-- ========================================================================
local ProfilePage = CreatePage("Profile")
CreateSectionTitle(ProfilePage, "Profile Center", "Inspect Roblox player profiles & account metadata")

local ProfSearchCard = CreateCard(ProfilePage)
Create("UIListLayout", {Padding = UDim.new(0, 8), Parent = ProfSearchCard})

local ProfInput = Create("TextBox", {
    Size = UDim2.new(1, 0, 0, 34),
    PlaceholderText = "Cari username Roblox (contoh: Roblox)...",
    Text = "",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    ClearTextOnFocus = false,
    Parent = ProfSearchCard
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
    Create("UIPadding", {PaddingLeft = UDim.new(0, 10)})
})
BindTheme(ProfInput, "BackgroundColor3", "BgPanel")
BindTheme(ProfInput, "TextColor3", "TextPrimary")

local ProfDetailsCard = CreateCard(ProfilePage)
Create("UIListLayout", {Padding = UDim.new(0, 6), Parent = ProfDetailsCard})
local ProfThumb = Create("ImageLabel", {
    Size = UDim2.new(0, 72, 0, 72),
    BackgroundColor3 = Color3.fromRGB(40, 40, 48),
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150",
    Parent = ProfDetailsCard
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 16)})
})
local ProfDisp = CreateInfoRow(ProfDetailsCard, "Display Name", LocalPlayer.DisplayName)
local ProfUser = CreateInfoRow(ProfDetailsCard, "Username", "@" .. LocalPlayer.Name)
local ProfId = CreateInfoRow(ProfDetailsCard, "User ID", LocalPlayer.UserId)
local ProfLink = CreateInfoRow(ProfDetailsCard, "Profile URL", "roblox.com/users/" .. LocalPlayer.UserId)
local ProfInServer = CreateInfoRow(ProfDetailsCard, "Server Presence", "In Current Server")

CreateActionButton(ProfSearchCard, "Lookup Username", function()
    local target = ProfInput.Text:gsub("%s+", "")
    if target == "" then
        Notify("Input Kosong", "Masukkan username Roblox terlebih dahulu.")
        return
    end
    task.spawn(function()
        local ok, userId = pcall(function()
            return Players:GetUserIdFromNameAsync(target)
        end)
        if ok and userId then
            local nameOk, realName = pcall(function()
                return Players:GetNameFromUserIdAsync(userId)
            end)
            ProfThumb.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150"
            ProfDisp.Text = nameOk and realName or target
            ProfUser.Text = "@" .. (nameOk and realName or target)
            ProfId.Text = tostring(userId)
            ProfLink.Text = "roblox.com/users/" .. userId
            ProfInServer.Text = Players:GetPlayerByUserId(userId) and "In Current Server" or "External / Offline"
            Notify("Profile Found", "Menampilkan data untuk @" .. (nameOk and realName or target))
        else
            Notify("Not Found", "Username '" .. target .. "' tidak ditemukan.")
        end
    end)
end)

CreateActionButton(ProfDetailsCard, "Copy Looked-Up User ID", function()
    CopyClipboard(ProfId.Text)
    Notify("Copied", "User ID " .. ProfId.Text .. " disalin.")
end)

-- ========================================================================
-- 4. AVATAR EXPLORER (Full v1.0.0)
-- ========================================================================
local AvatarPage = CreatePage("Avatar")
CreateSectionTitle(AvatarPage, "Avatar Explorer", "Inspect equipped accessories, clothing & body colors")

local AvatarCard = CreateCard(AvatarPage)
Create("UIListLayout", {Padding = UDim.new(0, 6), Parent = AvatarCard})

Create("ImageLabel", {
    Size = UDim2.new(0, 110, 0, 110),
    BackgroundColor3 = Color3.fromRGB(38, 38, 46),
    Image = "rbxthumb://type=Avatar&id=" .. LocalPlayer.UserId .. "&w=150&h=150",
    Parent = AvatarCard
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 16)})
})

local AvatarItemsList = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Memuat daftar aksesoris karakter...",
    TextSize = 12,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = AvatarCard
})
BindTheme(AvatarItemsList, "TextColor3", "TextSecondary")

local function RefreshAvatarData()
    local char = LocalPlayer.Character
    if not char then
        AvatarItemsList.Text = "Karakter belum dimuat (Unavailable)."
        return
    end
    local lines = {}
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Accessory") then
            table.insert(lines, "• [Accessory] " .. item.Name)
        elseif item:IsA("Shirt") then
            table.insert(lines, "• [Shirt] ID: " .. tostring(item.ShirtTemplate))
        elseif item:IsA("Pants") then
            table.insert(lines, "• [Pants] ID: " .. tostring(item.PantsTemplate))
        end
    end
    AvatarItemsList.Text = #lines > 0 and table.concat(lines, "\n") or "Tidak ada aksesoris/pakaian terpasang."
end

CreateActionButton(AvatarCard, "Refresh Equipped Outfit", function()
    RefreshAvatarData()
    Notify("Avatar Refreshed", "Daftar aksesoris & pakaian diperbarui.")
end)
task.spawn(RefreshAvatarData)

-- ========================================================================
-- 5. SERVER EXPLORER (Full v1.0.0)
-- ========================================================================
local ServerPage = CreatePage("Servers")
CreateSectionTitle(ServerPage, "Server Explorer", "Public server instance telemetry & quick hop")

local ServerCard = CreateCard(ServerPage)
Create("UIListLayout", {Padding = UDim.new(0, 6), Parent = ServerCard})
CreateInfoRow(ServerCard, "Current Place ID", game.PlaceId)
CreateInfoRow(ServerCard, "Instance Job ID", game.JobId ~= "" and game.JobId or "Local Studio")
local SrvPopRow = CreateInfoRow(ServerCard, "Occupancy", #Players:GetPlayers() .. " / " .. Players.MaxPlayers)
CreateInfoRow(ServerCard, "Public Server Browser", "HTTP API Restricted on Client")

local ServerNote = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Catatan: Roblox memblokir akses langsung ke endpoint games.roblox.com dari client script standar tanpa proxy eksternal. Kamu tetap bisa melakukan Official Server Hop melalui TeleportService.",
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = ServerCard
})
BindTheme(ServerNote, "TextColor3", "TextSecondary")

CreateActionButton(ServerCard, "Official Server Hop (Random Public Server)", function()
    Notify("Server Hop", "Mencari instance publik baru...")
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)

-- ========================================================================
-- 6. PLAYER DIRECTORY (Full v1.0.0 with Search Box)
-- ========================================================================
local PlayersPage = CreatePage("Players")
CreateSectionTitle(PlayersPage, "Player Directory", "Active players in current experience")

local PlayerSearchBox = Create("TextBox", {
    Size = UDim2.new(1, 0, 0, 34),
    PlaceholderText = "Filter pemain di server ini...",
    Text = "",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    ClearTextOnFocus = false,
    Parent = PlayersPage
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
    Create("UIPadding", {PaddingLeft = UDim.new(0, 12)})
})
BindTheme(PlayerSearchBox, "BackgroundColor3", "BgCard")
BindTheme(PlayerSearchBox, "TextColor3", "TextPrimary")

local PlayerListHolder = Create("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    Parent = PlayersPage
}, {
    Create("UIListLayout", {Padding = UDim.new(0, 6)})
})

local function RebuildPlayerList()
    for _, ch in ipairs(PlayerListHolder:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end
    local query = PlayerSearchBox.Text:lower()
    for _, plr in ipairs(Players:GetPlayers()) do
        if query == "" or plr.Name:lower():find(query, 1, true) or plr.DisplayName:lower():find(query, 1, true) then
            local pCard = CreateCard(PlayerListHolder, 56)
            Create("ImageLabel", {
                Size = UDim2.new(0, 32, 0, 32),
                BackgroundColor3 = Color3.fromRGB(45, 45, 52),
                Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=100&h=100",
                Parent = pCard
            }, {
                Create("UICorner", {CornerRadius = UDim.new(1, 0)})
            })

            local pName = Create("TextLabel", {
                Position = UDim2.new(0, 42, 0, 0),
                Size = UDim2.new(1, -135, 0, 16),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                Text = plr.DisplayName .. " (@" .. plr.Name .. ")",
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = pCard
            })
            BindTheme(pName, "TextColor3", "TextPrimary")

            local pSub = Create("TextLabel", {
                Position = UDim2.new(0, 42, 0, 17),
                Size = UDim2.new(1, -135, 0, 14),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                Text = "ID: " .. plr.UserId .. " • Age: " .. plr.AccountAge .. "d",
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = pCard
            })
            BindTheme(pSub, "TextColor3", "TextSecondary")

            local copyBtn = Create("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.new(0, 74, 0, 26),
                Font = Enum.Font.GothamSemibold,
                Text = "Copy ID",
                TextSize = 10,
                Parent = pCard
            }, {
                Create("UICorner", {CornerRadius = UDim.new(0, 8)})
            })
            BindTheme(copyBtn, "BackgroundColor3", "BadgeBg")
            BindTheme(copyBtn, "TextColor3", "BadgeText")
            copyBtn.MouseButton1Click:Connect(function()
                CopyClipboard(plr.UserId)
                Notify("Copied", "UserId " .. plr.Name .. " disalin.")
            end)
        end
    end
end

PlayerSearchBox:GetPropertyChangedSignal("Text"):Connect(RebuildPlayerList)
Players.PlayerAdded:Connect(RebuildPlayerList)
Players.PlayerRemoving:Connect(RebuildPlayerList)
RebuildPlayerList()

-- ========================================================================
-- 7. PERFORMANCE CENTER (Full v1.0.0 with 30-Bar Live FPS Graph)
-- ========================================================================
local PerfPage = CreatePage("Performance")
CreateSectionTitle(PerfPage, "Performance Center", "Real-time FPS telemetry, frame-time & memory")

local GraphCard = CreateCard(PerfPage, 130)
local GraphTitle = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "Live FPS History (Last 30 Samples)",
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = GraphCard
})
BindTheme(GraphTitle, "TextColor3", "TextPrimary")

local GraphBarsHolder = Create("Frame", {
    Position = UDim2.new(0, 0, 0, 26),
    Size = UDim2.new(1, 0, 0, 78),
    BackgroundTransparency = 1,
    Parent = GraphCard
}, {
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 3)
    })
})

local GraphBars = {}
for i = 1, 30 do
    local bar = Create("Frame", {
        Size = UDim2.new(1/30, -3, 0.5, 0),
        BorderSizePixel = 0,
        Parent = GraphBarsHolder
    }, {
        Create("UICorner", {CornerRadius = UDim.new(0, 3)})
    })
    BindTheme(bar, "BackgroundColor3", "BadgeBg")
    table.insert(GraphBars, bar)
end

local PerfStatsCard = CreateCard(PerfPage)
Create("UIListLayout", {Padding = UDim.new(0, 4), Parent = PerfStatsCard})
local PerfFPSRow = CreateInfoRow(PerfStatsCard, "Current FPS", "60")
local PerfFrameRow = CreateInfoRow(PerfStatsCard, "Frame Time (ms)", "16.6 ms")
local PerfMemRow = CreateInfoRow(PerfStatsCard, "Total Memory (MB)", "Measuring...")
local PerfPingRow = CreateInfoRow(PerfStatsCard, "Network Ping (ms)", "Measuring...")

CreateActionButton(PerfStatsCard, "Optimize Graphics (Low Quality Mode)", function()
    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    Notify("Performance Preset", "Rendering Quality diatur ke Level 01.")
end)

-- ========================================================================
-- 8. SESSION TRACKER (Full v1.0.0 with Reset Timer)
-- ========================================================================
local SessionPage = CreatePage("Session")
CreateSectionTitle(SessionPage, "Session Tracker", "Active playtest duration & developer notes")

local SessionCard = CreateCard(SessionPage)
Create("UIListLayout", {Padding = UDim.new(0, 6), Parent = SessionCard})
local SessStartRow = CreateInfoRow(SessionCard, "Session Started", StartTimeStr)
local SessDurRow = CreateInfoRow(SessionCard, "Active Duration", "00:00:00")
CreateInfoRow(SessionCard, "Tracked Experience", ExperienceName)

local NotesBox = Create("TextBox", {
    Size = UDim2.new(1, 0, 0, 90),
    Text = State.Notes,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextWrapped = true,
    MultiLine = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ClearTextOnFocus = false,
    Parent = SessionCard
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
    Create("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})
})
BindTheme(NotesBox, "BackgroundColor3", "BgPanel")
BindTheme(NotesBox, "TextColor3", "TextPrimary")

CreateActionButton(SessionCard, "Reset Session Timer", function()
    StartTick = tick()
    StartTimeStr = os.date("%H:%M:%S")
    SessStartRow.Text = StartTimeStr
    Notify("Session Reset", "Timer sesi diatur ulang ke 00:00:00.")
end)

-- ========================================================================
-- 9. STATISTICS & HISTORY (Full v1.0.0)
-- ========================================================================
local StatsPage = CreatePage("Statistics")
CreateSectionTitle(StatsPage, "Statistics & Activity Log", "Session metrics & recent UI interactions")

local StatsCard = CreateCard(StatsPage)
Create("UIListLayout", {Padding = UDim.new(0, 5), Parent = StatsCard})
local StatNotifCount = CreateInfoRow(StatsCard, "Notifications Logged", "0")
local StatHistCount = CreateInfoRow(StatsCard, "Actions Recorded", "0")
local StatPlayerCount = CreateInfoRow(StatsCard, "Server Player Count", tostring(#Players:GetPlayers()))

local HistoryLogLabel = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Belum ada aktivitas tercatat.",
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = StatsCard
})
BindTheme(HistoryLogLabel, "TextColor3", "TextSecondary")

-- ========================================================================
-- 10. UTILITIES CENTER (Full v1.0.0: Stopwatch + Calculator)
-- ========================================================================
local UtilPage = CreatePage("Utilities")
CreateSectionTitle(UtilPage, "Utility Center", "Developer tools, stopwatch & quick math")

local SwCard = CreateCard(UtilPage)
Create("UIListLayout", {Padding = UDim.new(0, 6), Parent = SwCard})
local SwRunning = false
local SwElapsed = 0
local SwDisplay = CreateInfoRow(SwCard, "Stopwatch", "00:00.00")

CreateActionButton(SwCard, "Start / Pause Stopwatch", function()
    SwRunning = not SwRunning
end)
CreateActionButton(SwCard, "Reset Stopwatch", function()
    SwRunning = false
    SwElapsed = 0
    SwDisplay.Text = "00:00.00"
end)

local CalcCard = CreateCard(UtilPage)
Create("UIListLayout", {Padding = UDim.new(0, 6), Parent = CalcCard})
local CalcInput = Create("TextBox", {
    Size = UDim2.new(1, 0, 0, 34),
    PlaceholderText = "Ekspresi matematika (contoh: 128 * 4 + 16)",
    Text = "",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    ClearTextOnFocus = false,
    Parent = CalcCard
}, {
    Create("UICorner", {CornerRadius = UDim.new(0, 10)}),
    Create("UIPadding", {PaddingLeft = UDim.new(0, 10)})
})
BindTheme(CalcInput, "BackgroundColor3", "BgPanel")
BindTheme(CalcInput, "TextColor3", "TextPrimary")

local CalcResult = CreateInfoRow(CalcCard, "Result", "—")
CreateActionButton(CalcCard, "Calculate", function()
    local expr = CalcInput.Text
    if expr:match("^[%d%+%-%*/%%%.%(%)%s%^]+$") then
        local fn = loadstring("return " .. expr)
        if fn then
            local ok, res = pcall(fn)
            if ok then
                CalcResult.Text = tostring(res)
                return
            end
        end
    end
    CalcResult.Text = "Invalid Expression"
end)

-- ========================================================================
-- 11. NOTIFICATION CENTER (Full v1.0.0 with Clear Button)
-- ========================================================================
local NotifPage = CreatePage("Notifications")
CreateSectionTitle(NotifPage, "Notification Center", "History of system & UI alerts")

local NotifCard = CreateCard(NotifPage)
Create("UIListLayout", {Padding = UDim.new(0, 6), Parent = NotifCard})
local NotifListText = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Belum ada riwayat notifikasi.",
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = NotifCard
})
BindTheme(NotifListText, "TextColor3", "TextSecondary")

CreateActionButton(NotifCard, "Clear Notification History", function()
    State.Notifications = {}
    NotifListText.Text = "Riwayat notifikasi dibersihkan."
end)

-- ========================================================================
-- 12. SETTINGS & CUSTOMIZATION (Full v1.0.0 with Reduced Motion)
-- ========================================================================
local SettingsPage = CreatePage("Settings")
CreateSectionTitle(SettingsPage, "Customization & Settings", "iOS Glassmorphism themes & motion preferences")

local ThemeCard = CreateCard(SettingsPage)
Create("UIListLayout", {Padding = UDim.new(0, 6), Parent = ThemeCard})

CreateActionButton(ThemeCard, "Theme: iOS Dark Glass (Default)", function()
    ApplyTheme("DarkGlass")
    Notify("Theme Applied", "Switched to iOS Dark Glass.")
end)

CreateActionButton(ThemeCard, "Theme: iOS Light Frosted Glass", function()
    ApplyTheme("LightGlass")
    Notify("Theme Applied", "Switched to iOS Light Glass.")
end)

CreateActionButton(ThemeCard, "Theme: Pure Monochrome B&W", function()
    ApplyTheme("PureBW")
    Notify("Theme Applied", "Switched to Pure Black & White.")
end)

CreateActionButton(ThemeCard, "Toggle Reduced Motion", function()
    State.ReducedMotion = not State.ReducedMotion
    Notify("Accessibility", "Reduced Motion: " .. tostring(State.ReducedMotion))
end)

-- ========================================================================
-- 13. ABOUT AKIOHUB (Full v1.0.0)
-- ========================================================================
local AboutPage = CreatePage("About")
CreateSectionTitle(AboutPage, "About AkioHub", "Architecture & developer information")

local AboutCard = CreateCard(AboutPage)
Create("UIListLayout", {Padding = UDim.new(0, 6), Parent = AboutCard})
CreateInfoRow(AboutCard, "Application", "AkioHub")
CreateInfoRow(AboutCard, "Tagline", "Ultimate Roblox Companion")
CreateInfoRow(AboutCard, "Version", "1.2.0 (Full Merged)")
CreateInfoRow(AboutCard, "Developer", "Akio")
CreateInfoRow(AboutCard, "Design Language", "iOS Black & White Glassmorphism")

local AboutDesc = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "AkioHub dirancang sebagai companion interface modular berkinerja tinggi dengan estetika minimalis khas iOS, menggabungkan telemetri klien real-time, inspeksi profil & avatar resmi, utilitas pengembangan, dan High Altitude Platform dalam satu file Luau.",
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = AboutCard
})
BindTheme(AboutDesc, "TextColor3", "TextSecondary")

--// Keybind Toggle (RightControl)
UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == State.ToggleKey then
        MainWindow.Visible = not MainWindow.Visible
        FloatingPill.Visible = not MainWindow.Visible
    end
end)

--// Real-Time Telemetry, Stopwatch, Graph & Auto Farm Loop
local FrameCount = 0
local LastFpsUpdate = tick()

RunService.RenderStepped:Connect(function(dt)
    FrameCount += 1

    -- Stopwatch Update
    if SwRunning then
        SwElapsed += dt
        local mins = math.floor(SwElapsed / 60)
        local secs = SwElapsed % 60
        SwDisplay.Text = string.format("%02d:%05.2f", mins, secs)
    end

    -- Auto Farm High Altitude Platform Execution
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local currentY = root and root.Position.Y or 0

    if State.AutoFarmEnabled then
        State.FarmElapsed += dt
        if not State.TargetAltitude and root then
            State.TargetAltitude = ComputeHighestElevatedY(Vector2.new(root.Position.X, root.Position.Z))
        end
        if State.TargetAltitude then
            PositionCharacterAtAltitude(State.TargetAltitude)
        end
    elseif State.PlatformEnabled and PlatformPart and root then
        PlatformPart.CFrame = CFrame.new(root.Position.X, PlatformPart.Position.Y, root.Position.Z)
    end

    -- Update Auto Farm UI Indicators
    ToggleFarmBtn.Text = State.AutoFarmEnabled and "Auto Farm: ACTIVE (Tap to Pause)" or "Auto Farm: OFF (Tap to Start)"
    TogglePlatBtn.Text = State.PlatformEnabled and "Platform Surface: ENABLED" or "Platform Surface: DISABLED"
    FloatPanel.Visible = State.FloatingPanelVisible

    FarmStatusVal.Text = State.AutoFarmEnabled and "Active (High Altitude)" or "Idle"
    FarmHeightVal.Text = string.format("%.1f studs", currentY)
    FarmPlatStateVal.Text = State.PlatformEnabled and (PlatformPart and "Active Beneath Character" or "Ready") or "Disabled"
    FarmTimerVal.Text = FormatTime(State.FarmElapsed)
    FloatStatusLbl.Text = string.format("%s • Alt: %.1f • %s", State.AutoFarmEnabled and "Active" or "Idle", currentY, FormatTime(State.FarmElapsed))

    local now = tick()
    if now - LastFpsUpdate >= 0.5 then
        local fps = math.clamp(math.floor(FrameCount / (now - LastFpsUpdate) + 0.5), 1, 240)
        local frameMs = string.format("%.1f ms", (1 / math.max(fps, 1)) * 1000)
        FrameCount = 0
        LastFpsUpdate = now

        -- Update FPS Graph History
        table.insert(State.FPSHistory, fps)
        if #State.FPSHistory > 30 then
            table.remove(State.FPSHistory, 1)
        end
        for i, bar in ipairs(GraphBars) do
            local val = State.FPSHistory[i] or 60
            local ratio = math.clamp(val / 60, 0.08, 1)
            Tween(bar, {Size = UDim2.new(1/30, -3, ratio, 0)}, 0.2)
        end

        local memMb = string.format("%.1f MB", Stats:GetTotalMemoryUsageMb())
        local pingVal = "N/A"
        pcall(function()
            pingVal = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms"
        end)

        local durStr = FormatTime(now - StartTick)
        DashExpName.Text = ExperienceName
        DashPlayers.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
        DashSession.Text = durStr
        DashFPS.Text = fps .. " FPS"
        DashPing.Text = pingVal
        DashMem.Text = memMb
        DashClock.Text = os.date("%H:%M:%S")

        PerfFPSRow.Text = tostring(fps) .. " FPS"
        PerfFrameRow.Text = frameMs
        PerfMemRow.Text = memMb
        PerfPingRow.Text = pingVal

        SessDurRow.Text = durStr
        SrvPopRow.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
        StatNotifCount.Text = tostring(#State.Notifications)
        StatHistCount.Text = tostring(#State.History)
        StatPlayerCount.Text = tostring(#Players:GetPlayers())

        if #State.History > 0 then
            local hLines = {}
            for i = 1, math.min(12, #State.History) do
                local item = State.History[i]
                table.insert(hLines, "[" .. item.time .. "] " .. item.action)
            end
            HistoryLogLabel.Text = table.concat(hLines, "\n")
        end

        if #State.Notifications > 0 then
            local nLines = {}
            for i = 1, math.min(12, #State.Notifications) do
                local n = State.Notifications[i]
                table.insert(nLines, "[" .. n.time .. "] " .. n.title .. " — " .. n.message)
            end
            NotifListText.Text = table.concat(nLines, "\n")
        end
    end
end)

--// Boot Sequence Execution
task.spawn(function()
    Tween(ProgressFill, {Size = UDim2.new(1, 0, 1, 0)}, 0.85, Enum.EasingStyle.Quart)
    task.wait(0.95)
    Tween(Splash, {BackgroundTransparency = 1}, 0.3)
    Tween(SplashCard, {BackgroundTransparency = 1}, 0.25)
    task.wait(0.3)
    Splash:Destroy()

    MainWindow.Visible = true
    MainWindow.Size = UDim2.new(0, DefaultWidth * 0.92, 0, DefaultHeight * 0.92)
    Tween(MainWindow, {Size = UDim2.new(0, DefaultWidth, 0, DefaultHeight)}, 0.35, Enum.EasingStyle.Back)
    Notify("AkioHub v1.2.0 Ready", "Semua modul v1.0.0 + Auto Farm High Altitude siap!")
end)
