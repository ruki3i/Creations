local TweenService = game:GetService("TweenService")

local GlowUI = {}
GlowUI.__index = GlowUI

local DEFAULT_CONFIG = {
    Image = "rbxassetid://105164730203338",
    SliceCenter = Rect.new(48, 48, 80, 80),
    Padding = 30,
    Color = Color3.fromRGB(255, 255, 255),
    Transparency = 0,
    Style = "Bottom",
    ZIndex = -1
}

function GlowUI.new(targetFrame, config)
    config = config or {}
    local self = setmetatable({}, GlowUI)
    
    self.Target = targetFrame
    self.Padding = config.Padding or DEFAULT_CONFIG.Padding
    self.Color = config.Color or DEFAULT_CONFIG.Color
    self.Transparency = config.Transparency or DEFAULT_CONFIG.Transparency
    self.Image = config.Image or DEFAULT_CONFIG.Image
    self.SliceCenter = config.SliceCenter or DEFAULT_CONFIG.SliceCenter
    self.Style = config.Style or DEFAULT_CONFIG.Style
    
    self.ZIndex = config.ZIndex or (targetFrame.ZIndex - 1)
    if self.ZIndex < 0 and not targetFrame.Parent:IsA("ScreenGui") then
        self.ZIndex = 0 
    end
    
    self.Instances = {}
    self.Connections = {}
    self.PulseTween = nil
    
    self:_build()
    
    return self
end

function GlowUI:_build()
    if self.Style == "Full" then
        local glow = Instance.new("ImageLabel")
        glow.Name = "GlowFull"
        glow.BackgroundTransparency = 1
        glow.Image = self.Image
        glow.ScaleType = Enum.ScaleType.Slice
        glow.SliceCenter = self.SliceCenter
        glow.ImageColor3 = self.Color
        glow.ImageTransparency = self.Transparency
        glow.ZIndex = self.ZIndex
        glow.AnchorPoint = Vector2.new(0.5, 0.5)
        glow.Position = UDim2.new(0.5, 0, 0.5, 0)
        glow.Size = UDim2.new(1, self.Padding * 2, 1, self.Padding * 2)
        glow.Parent = self.Target
        
        table.insert(self.Instances, glow)
        self.MainGlow = glow
        
    elseif self.Style == "Bottom" then
        local clip = Instance.new("Frame")
        clip.Name = "GlowClip"
        clip.BackgroundTransparency = 1
        clip.ClipsDescendants = true
        clip.ZIndex = self.ZIndex
        clip.AnchorPoint = Vector2.new(0.5, 0)
        clip.Position = UDim2.new(0.5, 0, 1, 0) 
        clip.Size = UDim2.new(1, self.Padding * 2, 0, self.Padding)
        clip.Parent = self.Target
        
        local glow = Instance.new("ImageLabel")
        glow.Name = "GlowBottom"
        glow.BackgroundTransparency = 1
        glow.Image = self.Image
        glow.ScaleType = Enum.ScaleType.Slice
        glow.SliceCenter = self.SliceCenter
        glow.ImageColor3 = self.Color
        glow.ImageTransparency = self.Transparency
        glow.ZIndex = self.ZIndex
        glow.AnchorPoint = Vector2.new(0.5, 1)
        glow.Position = UDim2.new(0.5, 0, 1, 0)
        glow.Parent = clip
        
        table.insert(self.Instances, clip)
        table.insert(self.Instances, glow)
        self.MainGlow = glow
        
        local function updateSize()
            local absY = self.Target.AbsoluteSize.Y
            glow.Size = UDim2.new(1, 0, 0, absY + (self.Padding * 2))
        end
        
        local conn = self.Target:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSize)
        table.insert(self.Connections, conn)
        updateSize()
    end
end

function GlowUI:Update(newConfig)
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local goals = {}
    
    if newConfig.Color then
        self.Color = newConfig.Color
        goals.ImageColor3 = self.Color
    end
    if newConfig.Transparency then
        self.Transparency = newConfig.Transparency
        goals.ImageTransparency = self.Transparency
    end
    
    if self.MainGlow then
        TweenService:Create(self.MainGlow, tweenInfo, goals):Play()
    end
end

function GlowUI:Pulse(speed, minTrans, maxTrans)
    speed = speed or 2
    minTrans = minTrans or 0.1
    maxTrans = maxTrans or 0.8
    
    if self.MainGlow then
        self.MainGlow.ImageTransparency = maxTrans
        local tweenInfo = TweenInfo.new(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        self.PulseTween = TweenService:Create(self.MainGlow, tweenInfo, {ImageTransparency = minTrans})
        self.PulseTween:Play()
    end
end

function GlowUI:StopPulse()
    if self.PulseTween then
        self.PulseTween:Cancel()
        self.PulseTween = nil
    end
    if self.MainGlow then
        TweenService:Create(self.MainGlow, TweenInfo.new(0.3), {ImageTransparency = self.Transparency}):Play()
    end
end

function GlowUI:Destroy()
    self:StopPulse()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    for _, inst in ipairs(self.Instances) do
        inst:Destroy()
    end
    self.Instances = {}
    self.Connections = {}
end

return GlowUI
