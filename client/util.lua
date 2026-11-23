Util = {}

local modelInfo = {}

function Util.Notify(message, kind)
    lib.notify({ title = L('title'), description = message, type = kind or 'inform' })
end

function Util.LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return end
    local ok = pcall(lib.requestModel, hash, 5000)
    if not ok then return end
    return hash
end

function Util.ModelInfo(hash)
    local info = modelInfo[hash]
    if info then return info end
    local min, max = GetModelDimensions(hash)
    info = { base = -min.z, height = max.z - min.z }
    if info.height > 0.0 then
        modelInfo[hash] = info
    end
    return info
end

local function rotationToDirection(rot)
    local x, z = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(x))
    return vector3(-math.sin(z) * c, math.cos(z) * c, math.sin(x))
end

function Util.CameraRaycast(distance, flags, ignore)
    local origin = GetGameplayCamCoord()
    local target = origin + rotationToDirection(GetGameplayCamRot(2)) * distance
    local handle = StartExpensiveSynchronousShapeTestLosProbe(origin.x, origin.y, origin.z, target.x, target.y, target.z, flags, ignore, 4)
    local _, hit, coords, normal, entity = GetShapeTestResult(handle)
    return hit == 1 or hit == true, coords, normal, entity, origin, target
end

local glyphMap = {
    ['\196\159'] = 'g',
    ['\196\158'] = 'G',
    ['\197\159'] = 's',
    ['\197\158'] = 'S',
    ['\196\176'] = 'I'
}

local sanitizeCache = {}
local sanitizeCount = 0

local function sanitizeText(text)
    if Config.Sanitize3DText == false or type(text) ~= 'string' then return text end
    local cached = sanitizeCache[text]
    if cached then return cached end
    local result = text:gsub('[\196\197][\128-\191]', glyphMap)
    if sanitizeCount >= 256 then
        sanitizeCache = {}
        sanitizeCount = 0
    end
    sanitizeCache[text] = result
    sanitizeCount = sanitizeCount + 1
    return result
end

function Util.DrawText3D(coords, text, scale, color, offsetY)
    text = sanitizeText(text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextColour(color[1], color[2], color[3], color[4] or 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, offsetY or 0.0)
    ClearDrawOrigin()
end

function Util.HelpLine(label, text)
    return ('**[%s]** %s'):format(label, text)
end

function Util.ShowHelp(lines)
    lib.showTextUI(table.concat(lines, '  \n'), { position = Config.Placement.TextUIPosition })
end

function Util.Pressed(list)
    for i = 1, #list do
        if IsDisabledControlJustPressed(0, list[i]) then return true end
    end
    return false
end

function Util.Held(list)
    for i = 1, #list do
        if IsDisabledControlPressed(0, list[i]) then return true end
    end
    return false
end

local blocked = { 14, 15, 16, 17, 24, 25, 37, 44, 38, 47, 74, 140, 141, 142, 143, 257, 263, 264, 191, 194 }

for name, list in pairs(Config.Placement.Controls) do
    if name ~= 'Fine' then
        for _, control in ipairs(list) do
            blocked[#blocked + 1] = control
        end
    end
end

function Util.DisableControls()
    for i = 1, #blocked do
        DisableControlAction(0, blocked[i], true)
    end
end
