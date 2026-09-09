local sspdo = loadstring(game:HttpGet("https://raw.githubusercontent.com/ruki3i/Creations/refs/heads/main/source/DockManager.luau"))()
local LuaUEngine = loadstring(game:HttpGet("https://raw.githubusercontent.com/ruki3i/Creations/refs/heads/main/source/LuaUEngine.luau"))()

local ScriptViewer = {}
local window
local editor
local currentScript

local function base64Encode(data)
    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local result = {}
    local padding = 0
    
    for i = 1, #data, 3 do
        local bytes = { string.byte(data, i, i+2) }
        local b1, b2, b3 = bytes[1] or 0, bytes[2] or 0, bytes[3] or 0
        
        if i + 1 > #data then
            padding = 2
        elseif i + 2 > #data then
            padding = 1
        end
        
        local n = (b1 * 0x10000) + (b2 * 0x100) + b3
        
        for j = 1, 4 do
            local charIndex = math.floor(n / 0x100000) % 64
            table.insert(result, b64chars:sub(charIndex+1, charIndex+1))
            n = n * 64
        end
    end
    
    local resultStr = table.concat(result)
    if padding == 1 then
        resultStr = resultStr:sub(1, -2) .. "="
    elseif padding == 2 then
        resultStr = resultStr:sub(1, -3) .. "=="
    end
    
    return resultStr
end

local function getBytecodeSafe(scriptInstance)
    if not scriptInstance then
        return nil
    end
    
    local success, bytecode = pcall(getscriptbytecode, scriptInstance)
    if success and type(bytecode) == "string" and #bytecode > 0 then
        return bytecode
    end
    
    if scriptInstance.GetBytecode then
        success, bytecode = pcall(scriptInstance.GetBytecode, scriptInstance)
        if success and type(bytecode) == "string" and #bytecode > 0 then
            return bytecode
        end
    end
    
    if scriptInstance.Bytecode then
        return scriptInstance.Bytecode
    end
    
    return nil
end

local function decompileWithAPI(scriptInstance)
    if not scriptInstance then
        return nil, "No script instance provided"
    end
    
    if not scriptInstance:IsA("LuaSourceContainer") then
        return nil, "Script is not a LuaSourceContainer"
    end
    
    local bytecode = getBytecodeSafe(scriptInstance)
    if not bytecode or #bytecode == 0 then
        return nil, "No bytecode found in script"
    end
    
    local encoded = base64Encode(bytecode)
    if not encoded or #encoded == 0 then
        return nil, "Failed to encode bytecode to base64"
    end
    
    local httpService = game:GetService("HttpService")
    local requestBody = httpService:JSONEncode({ script = encoded })
    
    local response = nil
    local requestFunctions = {
        function() 
            return syn and syn.request({
                Url = "https://api.lua.expert/decompile",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = requestBody
            })
        end,
        function()
            return request({
                Url = "https://api.lua.expert/decompile",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = requestBody
            })
        end,
        function()
            return httpService:PostAsync("https://api.lua.expert/decompile", requestBody, Enum.HttpContentType.ApplicationJson)
        end
    }
    
    for _, reqFunc in ipairs(requestFunctions) do
        local success, result = pcall(reqFunc)
        if success and result then
            response = result
            break
        end
    end
    
    if not response then
        return nil, "All request methods failed"
    end
    
    if typeof(response) == "string" then
        return response, nil
    elseif typeof(response) == "table" and response.Body then
        if response.StatusCode == 200 then
            return response.Body, nil
        else
            return nil, "API returned status " .. (response.StatusCode or "unknown")
        end
    else
        return nil, "Unexpected response format"
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
        if not currentScript then
            editor.Text = "No script loaded to decompile"
            return
        end
        
        editor.Text = "Decompiling using lua.expert API...\nPlease wait..."
        
        task.spawn(function()
            local success, result = decompileWithAPI(currentScript)
            if success then
                editor.Text = "Decompiled with lua.expert\nhttps://lua.expert/\n" .. result
            else
                editor.Text = "Decompilation failed: " .. (result or "Unknown error") .. "\n\nTrying local decompile as fallback..."
                
                if decompile and typeof(currentScript) == "Instance" and currentScript:IsA("LuaSourceContainer") then
                    local ok, localResult = pcall(decompile, currentScript)
                    if ok and localResult and #localResult > 0 then
                        editor.Text = "Local decompile fallback result:\n" .. localResult
                    else
                        editor.Text = editor.Text .. "\n\nLocal decompile also failed"
                    end
                end
            end
        end)
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
        editor.Text = "Loading script...\nAttempting decompile with lua.expert API..."
        
        task.spawn(function()
            local success, result = decompileWithAPI(scriptInstance)
            if success and result then
                editor.Text = "Decompiled with lua.expert\nhttps://lua.expert/\n" .. result
            else
                local fallbackMsg = "API decompile failed: " .. (result or "Unknown error") .. "\n\n"
                
                if decompile and typeof(scriptInstance) == "Instance" and scriptInstance:IsA("LuaSourceContainer") then
                    local ok, localResult = pcall(decompile, scriptInstance)
                    if ok and localResult and #localResult > 0 then
                        editor.Text = fallbackMsg .. "Local decompile result:\n" .. localResult
                    else
                        editor.Text = fallbackMsg .. "Local decompile also failed\nScript may be obfuscated or protected"
                    end
                else
                    editor.Text = fallbackMsg .. "No decompile function available"
                end
            end
        end)
    end

    window:Show()
end

function ScriptViewer.ViewAnimateScript()
    local player = game.Players.LocalPlayer
    if not player then
        warn("No local player found")
        return
    end
    
    local character = player.Character
    if not character then
        character = player.CharacterAdded:Wait()
    end
    
    local animateScript = character:FindFirstChild("Animate")
    if not animateScript then
        animateScript = game:GetService("StarterCharacterScripts"):FindFirstChild("Animate")
        if not animateScript then
            warn("No Animate script found")
            return
        end
    end
    
    ScriptViewer.ViewScript(animateScript)
end

return ScriptViewer
