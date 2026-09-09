local sspdo = loadstring(game:HttpGet("https://raw.githubusercontent.com/ruki3i/Creations/refs/heads/main/source/DockManager.luau"))()
local LuaUEngine = loadstring(game:HttpGet("https://raw.githubusercontent.com/ruki3i/Creations/refs/heads/main/source/LuaUEngine.luau"))()

local ScriptViewer = {}
local window
local editor
local currentScript

-- Decompile using lua.expert API
local function decompileWithAPI(scriptInstance)
    if not scriptInstance or not scriptInstance:IsA("LuaSourceContainer") then
        return nil, "Invalid script instance"
    end
    
    -- Get the bytecode
    local bytecode = scriptInstance:GetBytecode()
    if not bytecode or #bytecode == 0 then
        return nil, "No bytecode found"
    end
    
    -- Encode to base64
    local function base64Encode(data)
        local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
        local result = {}
        for i = 1, #data, 3 do
            local bytes = { string.byte(data, i, i+2) }
            local b1, b2, b3 = bytes[1] or 0, bytes[2] or 0, bytes[3] or 0
            local n = (b1 * 0x10000) + (b2 * 0x100) + b3
            for j = 1, 4 do
                local charIndex = math.floor(n / 0x100000) % 64
                table.insert(result, b64chars:sub(charIndex+1, charIndex+1))
                n = n * 64
            end
        end
        local padding = ({ '', '==', '=' })[(#data % 3) + 1]
        return table.concat(result):sub(1, -#padding-1) .. padding
    end
    
    local encoded = base64Encode(bytecode)
    
    -- Make request to lua.expert API
    local requestData = {
        Url = "https://api.lua.expert/decompile",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = game:GetService("HttpService"):JSONEncode({ script = encoded })
    }
    
    local response = syn and syn.request(requestData) or request(requestData)
    
    if response and response.StatusCode == 200 then
        return response.Body, nil
    else
        return nil, "API request failed: " .. (response and response.StatusCode or "unknown error")
    end
end

function ScriptViewer.Init()
    window = sspdo.new("Script Viewer", 650, 450)
    ScriptViewer.Window = window

    local contentPane = window.GuiElems.Content

    local actionBar = Instance.new("Frame")
    actionBar.Name = "ActionBar"
    actionBar.Size = UDim2.new(1, 0, 0, 24)
    actionBar.BackgroundColor3 = Color3.fromRGB(52, 52, 52)
    actionBar.BorderSizePixel = 0
    actionBar.Parent = contentPane

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Horizontal
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 0)
    listLayout.Parent = actionBar

    local function createButton(name, text, order)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.LayoutOrder = order
        btn.Size = UDim2.new(0.2, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.BorderSizePixel = 0
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.Text = text
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 14
        btn.AutoButtonColor = false
        btn.Parent = actionBar
        return btn
    end

    local btnCopy = createButton("CopyBtn", "Copy to Clipboard", 1)
    local btnSave = createButton("SaveBtn", "Save to File", 2)
    local btnExec = createButton("ExecuteBtn", "Execute", 3)
    local btnClear = createButton("ClearBtn", "Clear", 4)
    local btnDecompile = createButton("DecompileBtn", "Decompile", 5)

    local editorContainer = Instance.new("Frame")
    editorContainer.Name = "EditorContainer"
    editorContainer.Position = UDim2.new(0, 0, 0, 24)
    editorContainer.Size = UDim2.new(1, 0, 1, -24)
    editorContainer.BackgroundTransparency = 1 
    editorContainer.Parent = contentPane

    editor = LuaUEngine.new(editorContainer)
    editor.ScrollBarTrackTransparency = 1
    editor.ScrollBarStrokeTransparency = 1
    
    editor.Font = Enum.Font.Code
    editor.StrokeThickness = 1.35
    editor.StrokeColor3 = Color3.fromRGB(0, 0, 0)
    editor.StrokeTransparency = 0.75
    
    editor:ImportTheme("https://raw.githubusercontent.com/ruki3i/Creations/refs/heads/main/source/LuaUTheme.luau")

    btnCopy.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(editor.Text)
        end
    end)

    btnSave.MouseButton1Click:Connect(function()
        if writefile then
            local filename = "ScriptViewer_" .. os.time() .. ".txt"
            if currentScript and currentScript.Name then
                filename = currentScript.Name .. "_" .. os.time() .. ".txt"
            end
            writefile(filename, editor.Text)
        end
    end)

    btnExec.MouseButton1Click:Connect(function()
        pcall(function()
            loadstring(editor.Text)()
        end)
    end)

    btnClear.MouseButton1Click:Connect(function()
        editor.Text = ""
    end)

    btnDecompile.MouseButton1Click:Connect(function()
        if currentScript then
            local success, result = decompileWithAPI(currentScript)
            if success then
                editor.Text = "-- Decompiled with lua.expert\n" .. result
            else
                editor.Text = "-- Decompilation failed: " .. result
            end
        else
            editor.Text = "-- No script loaded to decompile"
        end
    end)
end

function ScriptViewer.ViewScript(scriptInstance, customSource)
    if not window then
        ScriptViewer.Init()
    end

    currentScript = scriptInstance
    local name = scriptInstance and scriptInstance.Name or "Script"
    window:SetTitle("Script Viewer - " .. name)

    if customSource then
        editor.Text = customSource
    else
        -- Try lua.expert API first
        local success, result = decompileWithAPI(scriptInstance)
        if success and result then
            editor.Text = "-- Decompiled with lua.expert\n" .. result
        else
            -- Fallback to local decompile
            if decompile and typeof(scriptInstance) == "Instance" and scriptInstance:IsA("LuaSourceContainer") then
                local ok, localResult = pcall(decompile, scriptInstance)
                if ok and localResult then
                    editor.Text = localResult
                else
                    editor.Text = "-- Could not decompile script\n-- Error: " .. (result or "Unknown error")
                end
            else
                editor.Text = "-- Invalid script or not a LuaSourceContainer"
            end
        end
    end

    window:Show()
end

-- Function to view the local player's animate script
function ScriptViewer.ViewAnimateScript()
    local player = game.Players.LocalPlayer
    if not player then
        return "No local player found"
    end
    
    local character = player.Character
    if not character then
        return "No character found"
    end
    
    local animateScript = character:FindFirstChild("Animate")
    if not animateScript then
        return "No Animate script found in character"
    end
    
    ScriptViewer.ViewScript(animateScript)
end

return ScriptViewer
