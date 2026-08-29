local stellarwidgets = {}
if getgenv()._stellarwidgets then
	pcall(function() getgenv()._stellarwidgets:Cleanup() end)
end
getgenv()._stellarwidgets = stellarwidgets
stellarwidgets.AllWidgets = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local guiHolder = pcall(function() return CoreGui.Name end) and CoreGui or LocalPlayer:WaitForChild("PlayerGui")

stellarwidgets.Theme = {
	Background = Color3.fromRGB(35, 35, 40),
	TopBar = Color3.fromRGB(45, 45, 55),
	Outline = Color3.fromRGB(55, 55, 70),
	Button = Color3.fromRGB(65, 65, 80),
	ButtonHover = Color3.fromRGB(85, 85, 105),
	ButtonPress = Color3.fromRGB(35, 35, 50),
	Text = Color3.fromRGB(240, 240, 255),
	ResizeHandle = Color3.fromRGB(70, 70, 90),
	PinActive = Color3.fromRGB(100, 170, 255)
}

local visibleWidgets = {}
local displayOrderStart = 20
local tweens = {}
local isA = game.IsA

function stellarwidgets:Cleanup()
	for _, widget in ipairs(self.AllWidgets) do
		if widget.Gui then widget.Gui:Destroy() end
	end
	for _, tween in ipairs(tweens) do
		tween:Cancel()
	end
	table.clear(tweens)
	table.clear(self.AllWidgets)
	table.clear(visibleWidgets)
end

function stellarwidgets.SetTheme(baseColor)
	local h, s, v = baseColor:ToHSV()
	local function shift(dv, ds) return Color3.fromHSV(h, math.clamp(s + (ds or 0), 0, 1), math.clamp(v + (dv or 0), 0, 1)) end
	local t = stellarwidgets.Theme
	t.Background = baseColor
	t.TopBar = shift(0.05, 0.1)
	t.Outline = shift(0.1, 0.15)
	t.Button = shift(0.12, 0.1)
	t.ButtonHover = shift(0.2, 0.1)
	t.ButtonPress = shift(-0.05, 0.2)
	t.ResizeHandle = shift(0.15, 0.1)
	t.PinActive = shift(0.3, 0.4)

	for _, widget in ipairs(stellarwidgets.AllWidgets) do
		widget.GuiElems.Content.BackgroundColor3 = t.Background
		widget.GuiElems.Line.BackgroundColor3 = t.Outline
		widget.GuiElems.TopBar.BackgroundColor3 = t.TopBar
		widget.GuiElems.Title.TextColor3 = t.Text
		widget.GuiElems.Close.TextColor3 = t.Text
		widget.GuiElems.Fold.TextColor3 = t.Text
		widget.GuiElems.Pin.TextColor3 = t.Text
		for _, ctrl in ipairs(widget.GuiElems.ResizeControls:GetChildren()) do
			if ctrl:IsA("GuiObject") then
				ctrl.BackgroundColor3 = t.ResizeHandle
			end
		end
	end
end

local function create(data)
	local insts = {}
	for _, v in pairs(data) do insts[v[1]] = Instance.new(v[2]) end
	for _, v in pairs(data) do
		for prop, val in pairs(v[3]) do
			if type(val) == "table" then
				insts[v[1]][prop] = insts[val[1]]
			else
				insts[v[1]][prop] = val
			end
		end
	end
	return insts[1]
end

local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = setmetatable({}, Signal)
	self.Connections = {}
	return self
end

function Signal:Connect(func)
	local con = {
		Signal = self,
		Func = func,
		Disconnect = function(c)
			local pos = table.find(c.Signal.Connections, c)
			if pos then table.remove(c.Signal.Connections, pos) end
		end
	}
	self.Connections[#self.Connections + 1] = con
	return con
end

function Signal:Fire(...)
	for _, v in next, self.Connections do
		xpcall(coroutine.wrap(v.Func), function(e) warn(e .. "\n" .. debug.traceback()) end, ...)
	end
end

local function checkMouseInGui(gui)
	if gui == nil then return false end
	local mouseLoc = UserInputService:GetMouseLocation()
	local guiPosition = gui.AbsolutePosition
	local guiSize = gui.AbsoluteSize	
	return mouseLoc.X >= guiPosition.X and mouseLoc.X < guiPosition.X + guiSize.X and mouseLoc.Y >= guiPosition.Y and mouseLoc.Y < guiPosition.Y + guiSize.Y
end

local function buttonAnim(button, data)
	local holding = false
	local disabled = false
	local mode = data and data.Mode or 1
	local control = {}

	if mode == 2 then
		local lerpTo = data.LerpTo or Color3.new(0, 0, 0)
		local delta = data.LerpDelta or 0.2
		control.StartColor = data.StartColor or button.BackgroundColor3
		control.PressColor = data.PressColor or control.StartColor:lerp(lerpTo, delta)
		control.HoverColor = data.HoverColor or control.StartColor:lerp(control.PressColor, 0.6)
		control.OutlineColor = data.OutlineColor
	end

	button.InputBegan:Connect(function(input)
		if disabled then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement and not holding then
			if mode == 1 then
				button.BackgroundTransparency = 0.5
			elseif mode == 2 then
				button.BackgroundColor3 = control.HoverColor
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = true
			if mode == 1 then
				button.BackgroundTransparency = 0
			elseif mode == 2 then
				button.BackgroundColor3 = control.PressColor
				if control.OutlineColor then button.BorderColor3 = control.PressColor end
			end
		end
	end)

	button.InputEnded:Connect(function(input)
		if disabled then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement and not holding then
			if mode == 1 then
				button.BackgroundTransparency = 1
			elseif mode == 2 then
				button.BackgroundColor3 = control.StartColor
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
			if mode == 1 then
				button.BackgroundTransparency = checkMouseInGui(button) and 0.5 or 1
			elseif mode == 2 then
				button.BackgroundColor3 = checkMouseInGui(button) and control.HoverColor or control.StartColor
				if control.OutlineColor then button.BorderColor3 = control.OutlineColor end
			end
		end
	end)

	control.Disable = function()
		disabled = true
		holding = false
		if mode == 1 then button.BackgroundTransparency = 1 elseif mode == 2 then button.BackgroundColor3 = control.StartColor end
	end

	control.Enable = function()
		disabled = false
	end

	return control
end

local function stopTweens()
	for i = 1, #tweens do
		tweens[i]:Cancel()
	end
	tweens = {}
end

local function updateWidgetOrders()
	local count = 0
	for i = #visibleWidgets, 1, -1 do
		if not visibleWidgets[i].Pinned then
			visibleWidgets[i].Gui.DisplayOrder = displayOrderStart + count
			count = count + 1
		else
			visibleWidgets[i].Gui.DisplayOrder = displayOrderStart + 1000 + count
			count = count + 1
		end
	end
end

local function moveToTop(widget)
	local found = table.find(visibleWidgets, widget)
	if found then
		table.remove(visibleWidgets, found)
		table.insert(visibleWidgets, 1, widget)
		updateWidgetOrders()
	end
end

local function focusInput(self, obj)
	if isA(obj, "GuiButton") or isA(obj, "TextBox") then
		obj.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				moveToTop(self)
			end
		end)
	end
end

local function resizeHook(self, resizer, dir)
	local guiMain = self.GuiElems.Main
	resizer.InputBegan:Connect(function(input)
		if not self.Dragging and not self.Resizing and self.Resizable and not self.Folded then
			local isV = dir:find("[NS]") and true
			local signX = dir:find("W") and -1 or (dir:find("E") and 1 or 0)
			local signY = dir:find("N") and -1 or (dir:find("S") and 1 or 0)
			
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				resizer.BackgroundTransparency = 0.5
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				moveToTop(self)
				local releaseEvent, mouseEvent
				self.Resizing = resizer
				resizer.BackgroundTransparency = 1
				local startInputX = input.Position.X
				local startInputY = input.Position.Y
				local startSizeX = self.SizeX
				local startSizeY = self.SizeY
				local startPosX = guiMain.Position.X.Offset
				local startPosY = guiMain.Position.Y.Offset
				
				releaseEvent = UserInputService.InputEnded:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then
						releaseEvent:Disconnect()
						mouseEvent:Disconnect()
						self.Resizing = false
						resizer.BackgroundTransparency = 1
					end
				end)
				
				mouseEvent = UserInputService.InputChanged:Connect(function(inp)
					if self.Resizable and inp.UserInputType == Enum.UserInputType.MouseMovement then
						self:StopTweens()
						local deltaX = inp.Position.X - startInputX
						local deltaY = inp.Position.Y - startInputY
						local newSizeX = startSizeX + (deltaX * signX)
						local newSizeY = startSizeY + (deltaY * signY)
						local newPosX = startPosX + (signX == -1 and deltaX or 0)
						local newPosY = startPosY + (signY == -1 and deltaY or 0)
						
						if newSizeX < self.MinX then 
							newPosX = newPosX - (self.MinX - newSizeX) * (signX == -1 and 1 or 0)
							newSizeX = self.MinX 
						end
						if newSizeY < self.MinY then 
							newPosY = newPosY - (self.MinY - newSizeY) * (signY == -1 and 1 or 0)
							newSizeY = self.MinY 
						end
						
						self.SizeX = newSizeX
						self.SizeY = newSizeY
						guiMain.Position = UDim2.new(0, newPosX, 0, newPosY)
						guiMain.Size = UDim2.new(0, newSizeX, 0, newSizeY)
					end
				end)
			end
		end
	end)
	resizer.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and self.Resizing ~= resizer then
			resizer.BackgroundTransparency = 1
		end
	end)
end

local funcs = {}
local widgetMt = {__index = funcs}

local function createGui(self)
	local theme = stellarwidgets.Theme
	local gui = create({
		{1, "ScreenGui", {Name="Widget", ZIndexBehavior=Enum.ZIndexBehavior.Sibling}},
		{2, "Frame", {Active=true, BackgroundTransparency=1, BorderSizePixel=0, Name="Main", Parent={1}, Position=UDim2.new(0, self.PosX, 0, self.PosY), Size=UDim2.new(0, self.SizeX, 0, self.SizeY), ClipsDescendants=false}},
		{3, "Frame", {BackgroundColor3=theme.Background, BorderSizePixel=0, Name="Content", Parent={2}, Position=UDim2.new(0, 0, 0, 24), Size=UDim2.new(1, 0, 1, -24), ClipsDescendants=true}},
		{4, "Frame", {BackgroundColor3=theme.Outline, BorderSizePixel=0, Name="Line", Parent={3}, Size=UDim2.new(1, 0, 0, 1)}},
		{5, "Frame", {BackgroundColor3=theme.TopBar, BorderSizePixel=0, Name="TopBar", Parent={2}, Size=UDim2.new(1, 0, 0, 24)}},
		{6, "TextLabel", {BackgroundTransparency=1, Font=3, Name="Title", Parent={5}, Position=UDim2.new(0, 8, 0, 0), Size=UDim2.new(1, -16, 0, 24), Text="Widget", TextColor3=theme.Text, TextSize=14, TextXAlignment=0}},
		{7, "TextButton", {AutoButtonColor=false, BackgroundColor3=Color3.fromRGB(0,0,0), BackgroundTransparency=1, BorderSizePixel=0, Font=3, Name="Close", Parent={5}, Position=UDim2.new(1, -22, 0, 4), Size=UDim2.new(0, 16, 0, 16), Text="", TextColor3=theme.Text, TextSize=14}},
		{8, "ImageLabel", {BackgroundTransparency=1, Image="rbxassetid://5054663650", Parent={7}, Position=UDim2.new(0, 3, 0, 3), Size=UDim2.new(0, 10, 0, 10)}},
		{9, "UICorner", {CornerRadius=UDim.new(0, 4), Parent={7}}},
		{10, "TextButton", {AutoButtonColor=false, BackgroundColor3=Color3.fromRGB(0,0,0), BackgroundTransparency=1, BorderSizePixel=0, Font=3, Name="Fold", Parent={5}, Position=UDim2.new(1, -42, 0, 4), Size=UDim2.new(0, 16, 0, 16), Text="", TextColor3=theme.Text, TextSize=14}},
		{11, "ImageLabel", {BackgroundTransparency=1, Image="rbxassetid://5034768003", Parent={10}, Position=UDim2.new(0, 3, 0, 3), Size=UDim2.new(0, 10, 0, 10)}},
		{12, "UICorner", {CornerRadius=UDim.new(0, 4), Parent={10}}},
		{13, "TextButton", {AutoButtonColor=false, BackgroundColor3=Color3.fromRGB(0,0,0), BackgroundTransparency=1, BorderSizePixel=0, Font=3, Name="Pin", Parent={5}, Position=UDim2.new(1, -62, 0, 4), Size=UDim2.new(0, 16, 0, 16), Text="", TextColor3=theme.Text, TextSize=14}},
		{14, "ImageLabel", {BackgroundTransparency=1, Image="rbxassetid://6031094670", Parent={13}, Position=UDim2.new(0, 2, 0, 2), Size=UDim2.new(0, 12, 0, 12)}},
		{15, "UICorner", {CornerRadius=UDim.new(0, 4), Parent={13}}},
		{16, "ImageLabel", {BackgroundTransparency=1, BorderSizePixel=0, Image="rbxassetid://1427967925", Name="Outlines", Parent={2}, Position=UDim2.new(0, -5, 0, -5), ScaleType=1, Size=UDim2.new(1, 10, 1, 10), SliceCenter=Rect.new(6, 6, 25, 25), TileSize=UDim2.new(0, 20, 0, 20)}},
		{17, "Frame", {BackgroundTransparency=1, Name="ResizeControls", Parent={2}, Position=UDim2.new(0, -5, 0, -5), Size=UDim2.new(1, 10, 1, 10)}},
		{18, "TextButton", {AutoButtonColor=false, BackgroundColor3=theme.ResizeHandle, BackgroundTransparency=1, BorderSizePixel=0, Name="North", Parent={17}, Position=UDim2.new(0, 5, 0, 0), Size=UDim2.new(1, -10, 0, 5), Text=""}},
		{19, "TextButton", {AutoButtonColor=false, BackgroundColor3=theme.ResizeHandle, BackgroundTransparency=1, BorderSizePixel=0, Name="South", Parent={17}, Position=UDim2.new(0, 5, 1, -5), Size=UDim2.new(1, -10, 0, 5), Text=""}},
		{20, "TextButton", {AutoButtonColor=false, BackgroundColor3=theme.ResizeHandle, BackgroundTransparency=1, BorderSizePixel=0, Name="NorthEast", Parent={17}, Position=UDim2.new(1, -5, 0, 0), Size=UDim2.new(0, 5, 0, 5), Text=""}},
		{21, "TextButton", {AutoButtonColor=false, BackgroundColor3=theme.ResizeHandle, BackgroundTransparency=1, BorderSizePixel=0, Name="East", Parent={17}, Position=UDim2.new(1, -5, 0, 5), Size=UDim2.new(0, 5, 1, -10), Text=""}},
		{22, "TextButton", {AutoButtonColor=false, BackgroundColor3=theme.ResizeHandle, BackgroundTransparency=1, BorderSizePixel=0, Name="West", Parent={17}, Position=UDim2.new(0, 0, 0, 5), Size=UDim2.new(0, 5, 1, -10), Text=""}},
		{23, "TextButton", {AutoButtonColor=false, BackgroundColor3=theme.ResizeHandle, BackgroundTransparency=1, BorderSizePixel=0, Name="SouthEast", Parent={17}, Position=UDim2.new(1, -5, 1, -5), Size=UDim2.new(0, 5, 0, 5), Text=""}},
		{24, "TextButton", {AutoButtonColor=false, BackgroundColor3=theme.ResizeHandle, BackgroundTransparency=1, BorderSizePixel=0, Name="NorthWest", Parent={17}, Size=UDim2.new(0, 5, 0, 5), Text=""}},
		{25, "TextButton", {AutoButtonColor=false, BackgroundColor3=theme.ResizeHandle, BackgroundTransparency=1, BorderSizePixel=0, Name="SouthWest", Parent={17}, Position=UDim2.new(0, 0, 1, -5), Size=UDim2.new(0, 5, 0, 5), Text=""}},
		{26, "UICorner", {CornerRadius=UDim.new(0, 6), Parent={2}}},
		{27, "UICorner", {CornerRadius=UDim.new(0, 6), Parent={3}}},
		{28, "UICorner", {CornerRadius=UDim.new(0, 6), Parent={5}}}
	})
	
	local guiMain = gui.Main
	local guiTopBar = guiMain.TopBar
	local guiResizeControls = guiMain.ResizeControls
	
	self.GuiElems.Main = guiMain
	self.GuiElems.TopBar = guiTopBar
	self.GuiElems.Content = guiMain.Content
	self.GuiElems.Line = guiMain.Content.Line
	self.GuiElems.Outlines = guiMain.Outlines
	self.GuiElems.Title = guiTopBar.Title
	self.GuiElems.Close = guiTopBar.Close
	self.GuiElems.Fold = guiTopBar.Fold
	self.GuiElems.Pin = guiTopBar.Pin
	self.GuiElems.ResizeControls = guiResizeControls
	self.ContentPane = guiMain.Content
	
	guiTopBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and self.Draggable then
			moveToTop(self)
			local releaseEvent, mouseEvent
			local startInputX = input.Position.X
			local startInputY = input.Position.Y
			local initX = guiMain.Position.X.Offset
			local initY = guiMain.Position.Y.Offset
			self.Dragging = true
			
			releaseEvent = UserInputService.InputEnded:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseButton1 then
					releaseEvent:Disconnect()
					mouseEvent:Disconnect()
					self.Dragging = false
				end
			end)
			
			mouseEvent = UserInputService.InputChanged:Connect(function(inp)
				if inp.UserInputType == Enum.UserInputType.MouseMovement and self.Draggable and not self.Closed then
					local deltaX = inp.Position.X - startInputX
					local deltaY = inp.Position.Y - startInputY
					local posX = initX + deltaX
					local posY = initY + deltaY
					
					local maxBounds = guiHolder.AbsoluteSize
					local snap = 20
					
					if posX < snap then posX = 0
					elseif posX + guiMain.Size.X.Offset > maxBounds.X - snap then posX = maxBounds.X - guiMain.Size.X.Offset end
					
					if posY < snap then posY = 0
					elseif posY + guiMain.Size.Y.Offset > maxBounds.Y - snap then posY = maxBounds.Y - guiMain.Size.Y.Offset end
					
					guiMain.Position = UDim2.new(0, posX, 0, posY)
					self.PosX = posX
					self.PosY = posY
				end
			end)
		end
	end)
	
	guiTopBar.Close.MouseButton1Click:Connect(function()
		if not self.Closed then self:Close() end
	end)
	guiTopBar.Fold.MouseButton1Click:Connect(function()
		if not self.Closed then self:SetFolded() end
	end)
	guiTopBar.Pin.MouseButton1Click:Connect(function()
		if not self.Closed then self:SetPinned() end
	end)
	
	guiMain.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not self.Closed then
			moveToTop(self)
		end
	end)
	
	resizeHook(self, guiResizeControls.North, "N")
	resizeHook(self, guiResizeControls.NorthEast, "NE")
	resizeHook(self, guiResizeControls.East, "E")
	resizeHook(self, guiResizeControls.SouthEast, "SE")
	resizeHook(self, guiResizeControls.South, "S")
	resizeHook(self, guiResizeControls.SouthWest, "SW")
	resizeHook(self, guiResizeControls.West, "W")
	resizeHook(self, guiResizeControls.NorthWest, "NW")
	
	gui.DescendantAdded:Connect(function(obj) focusInput(self, obj) end)
	for _, desc in ipairs(gui:GetDescendants()) do
		focusInput(self, desc)
	end
	
	self.FoldAnim = buttonAnim(guiTopBar.Fold)
	self.CloseAnim = buttonAnim(guiTopBar.Close)
	self.PinAnim = buttonAnim(guiTopBar.Pin)
	
	return gui
end

function funcs:SetFolded(set)
	local oldVal = self.Folded
	local newVal = (set == nil) and not self.Folded or set
	self.Folded = newVal
	
	local resizeControls = self.GuiElems.ResizeControls
	for _, ctrl in ipairs(resizeControls:GetChildren()) do
		if ctrl:IsA("GuiObject") then
			ctrl.Visible = not newVal
		end
	end
	
	self:StopTweens()
	self.GuiElems.Main:TweenSize(UDim2.new(0, self.SizeX, 0, newVal and 24 or self.SizeY), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.3, true)
	self.GuiElems.Fold.ImageLabel.Image = newVal and "rbxassetid://5060023708" or "rbxassetid://5034768003"
	
	if oldVal ~= newVal then
		if newVal then self.OnFold:Fire() else self.OnUnfold:Fire() end
	end
end

function funcs:SetPinned(set)
	local oldVal = self.Pinned
	local newVal = (set == nil) and not self.Pinned or set
	self.Pinned = newVal
	
	self.GuiElems.Pin.ImageLabel.ImageColor3 = newVal and stellarwidgets.Theme.PinActive or Color3.new(1,1,1)
	
	local ti = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if newVal then
		self:DoTween(self.GuiElems.Content, ti, {BackgroundTransparency = 0.4})
		self:DoTween(self.GuiElems.TopBar, ti, {BackgroundTransparency = 0.2})
		self:DoTween(self.GuiElems.Outlines, ti, {ImageTransparency = 0.5})
	else
		self:DoTween(self.GuiElems.Content, ti, {BackgroundTransparency = 0})
		self:DoTween(self.GuiElems.TopBar, ti, {BackgroundTransparency = 0})
		self:DoTween(self.GuiElems.Outlines, ti, {ImageTransparency = 0})
	end
	
	updateWidgetOrders()
	if oldVal ~= newVal then
		if newVal then self.OnPin:Fire() else self.OnUnpin:Fire() end
	end
end

function funcs:Resize(sizeX, sizeY)
	self.SizeX = sizeX or self.SizeX
	self.SizeY = sizeY or self.SizeY
	self.GuiElems.Main.Size = UDim2.new(0, self.SizeX, 0, self.SizeY)
end

function funcs:SetTitle(title)
	self.GuiElems.Title.Text = title
end

function funcs:Add(obj, name)
	if type(obj) == "table" and obj.Gui and obj.Gui:IsA("GuiObject") then
		obj.Gui.Parent = self.ContentPane
	else
		obj.Parent = self.ContentPane
	end
	if name then self.Elements[name] = obj end
end

function funcs:GetElement(name)
	return self.Elements[name]
end

function funcs:Close()
	self.Closed = true
	local pos = table.find(visibleWidgets, self)
	if pos then table.remove(visibleWidgets, pos) end
	
	self.FoldAnim.Disable()
	self.CloseAnim.Disable()
	self.PinAnim.Disable()
	self.OnClose:Fire()
	
	self:StopTweens()
	local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tiFade = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	self:DoTween(self.GuiElems.Main, ti, {Size = UDim2.new(0, self.SizeX, 0, 24)})
	
	task.spawn(function()
		task.wait(0.2)
		if self.Closed then
			self:DoTween(self.GuiElems.Title, tiFade, {TextTransparency = 1})
			self:DoTween(self.GuiElems.Fold.ImageLabel, tiFade, {ImageTransparency = 1})
			self:DoTween(self.GuiElems.Close.ImageLabel, tiFade, {ImageTransparency = 1})
			self:DoTween(self.GuiElems.Pin.ImageLabel, tiFade, {ImageTransparency = 1})
			self:DoTween(self.GuiElems.TopBar, tiFade, {BackgroundTransparency = 1})
			self:DoTween(self.GuiElems.Outlines, tiFade, {ImageTransparency = 1})
			task.wait(0.15)
			if self.Closed then
				self.Gui.Parent = nil
				updateWidgetOrders()
			end
		end
	end)
end

function funcs:Show()
	if not self.Closed then
		self:SetFolded(false)
		return
	end
	self.Closed = false
	
	self.GuiElems.Title.TextTransparency = 0
	self.GuiElems.Fold.ImageLabel.ImageTransparency = 0
	self.GuiElems.Close.ImageLabel.ImageTransparency = 0
	self.GuiElems.Pin.ImageLabel.ImageTransparency = 0
	self.GuiElems.TopBar.BackgroundTransparency = self.Pinned and 0.2 or 0
	self.GuiElems.Outlines.ImageTransparency = self.Pinned and 0.5 or 0
	self.GuiElems.Fold.ImageLabel.Image = "rbxassetid://5034768003"
	
	self.FoldAnim.Enable()
	self.CloseAnim.Enable()
	self.PinAnim.Enable()
	
	if not table.find(visibleWidgets, self) then
		table.insert(visibleWidgets, 1, self)
	end
	
	self.Gui.Parent = guiHolder
	self.GuiElems.Main.Size = UDim2.new(0, self.SizeX, 0, 24)
	
	self:StopTweens()
	local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	self:DoTween(self.GuiElems.Main, ti, {Size = UDim2.new(0, self.SizeX, 0, self.SizeY)})
	
	updateWidgetOrders()
	self.OnOpen:Fire()
end

function funcs:DoTween(...)
	local tween = TweenService:Create(...)
	self.Tweens[#self.Tweens + 1] = tween
	tween:Play()
end

function funcs:StopTweens()
	for i, v in pairs(self.Tweens) do
		v:Cancel()
	end
	self.Tweens = {}
end

function stellarwidgets.new(title, sizeX, sizeY, posX, posY)
	local obj = setmetatable({
		Folded = false,
		Dragging = false,
		Resizing = false,
		Pinned = false,
		Draggable = true,
		Resizable = true,
		Closed = true,
		SizeX = sizeX or 250,
		SizeY = sizeY or 200,
		MinX = 150,
		MinY = 100,
		PosX = posX or (guiHolder.AbsoluteSize.X / 2 - (sizeX or 250) / 2),
		PosY = posY or (guiHolder.AbsoluteSize.Y / 2 - (sizeY or 200) / 2),
		GuiElems = {},
		Tweens = {},
		Elements = {},
		OnOpen = Signal.new(),
		OnClose = Signal.new(),
		OnFold = Signal.new(),
		OnUnfold = Signal.new(),
		OnPin = Signal.new(),
		OnUnpin = Signal.new()
	}, widgetMt)
	
	obj.Gui = createGui(obj)
	table.insert(stellarwidgets.AllWidgets, obj)
	if title then obj:SetTitle(title) end
	return obj
end

return stellarwidgets
