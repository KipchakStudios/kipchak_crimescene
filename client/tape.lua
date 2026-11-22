Tape = {}

local cfg = Config.Tape
local TXD_NAME = 'kipchak_crimescene_tape'
local segments, nearSegments = {}, {}
local builtVersion = -1
local poleHeight

do
    local txd = CreateRuntimeTxd(TXD_NAME)
    local created = {}
    for _, style in pairs(cfg.Styles) do
        if not created[style.texture] then
            created[style.texture] = true
            CreateRuntimeTextureFromImage(txd, style.texture, ('textures/%s.png'):format(style.texture))
        end
    end
end

local function tapeHeight()
    if type(cfg.Height) == 'number' then return cfg.Height end
    if poleHeight then return poleHeight end
    local info = Util.ModelInfo(joaat(cfg.PoleModel))
    if info.height > 0.0 then
        poleHeight = math.max(info.height - 0.04, cfg.Thickness)
        return poleHeight
    end
    return 0.7
end

local function poly(x1, y1, z1, x2, y2, z2, x3, y3, z3, r, g, b, a, tex, u1, v1, u2, v2, u3, v3)
    DrawSpritePoly(x1, y1, z1, x2, y2, z2, x3, y3, z3, r, g, b, a, TXD_NAME, tex, u1, v1, 1.0, u2, v2, 1.0, u3, v3, 1.0)
end

function Tape.DrawSegment(a, b, styleKey, alpha, tint)
    local style = cfg.Styles[styleKey] or cfg.Styles[cfg.DefaultStyle]
    if not style then return end

    local cam = GetFinalRenderedCamCoord()
    if (cam.x - a.x) * (a.y - b.y) + (cam.y - a.y) * (b.x - a.x) > 0 then
        a, b = b, a
    end

    local dir = b - a
    local len = #dir
    if len < 0.05 then return end

    local color = tint or style.color
    local r, g, bl = color[1], color[2], color[3]
    local al = alpha or style.alpha or 255
    local tex = style.texture
    local h = tapeHeight()
    local t = cfg.Thickness
    local tile = t * cfg.TextureRatio
    local steps = math.ceil(len / tile)

    for i = 0, steps - 1 do
        local d0 = i * tile
        local d1 = math.min(d0 + tile, len)
        local s = a + dir * (d0 / len)
        local e = a + dir * (d1 / len)
        local u = (d1 - d0) / tile
        local sTop, sBot = s.z + h, s.z + h - t
        local eTop, eBot = e.z + h, e.z + h - t
        poly(s.x, s.y, sTop, e.x, e.y, eTop, e.x, e.y, eBot, r, g, bl, al, tex, 0.0, 0.0, u, 0.0, u, 1.0)
        poly(s.x, s.y, sTop, e.x, e.y, eBot, s.x, s.y, sBot, r, g, bl, al, tex, 0.0, 0.0, u, 1.0, 0.0, 1.0)
        poly(s.x, s.y, sTop, e.x, e.y, eBot, e.x, e.y, eTop, r, g, bl, al, tex, 0.0, 0.0, u, 1.0, u, 0.0)
        poly(s.x, s.y, sTop, s.x, s.y, sBot, e.x, e.y, eBot, r, g, bl, al, tex, 0.0, 0.0, 0.0, 1.0, u, 1.0)
    end
end

local function rebuild()
    local list = {}
    for _, obj in pairs(Store) do
        if obj.kind == 'pole' and obj.link then
            local other = Store[obj.link]
            if other then
                list[#list + 1] = { a = other.coords, b = obj.coords, style = obj.style, half = #(other.coords - obj.coords) * 0.5 }
            end
        end
    end
    segments = list
    builtVersion = StoreVersion
end

CreateThread(function()
    while true do
        if builtVersion ~= StoreVersion then rebuild() end
        local pos = GetEntityCoords(PlayerPedId())
        local list = {}
        for _, seg in ipairs(segments) do
            if #(pos - (seg.a + seg.b) * 0.5) <= cfg.DrawDistance + seg.half then
                list[#list + 1] = seg
            end
        end
        nearSegments = list
        Wait(500)
    end
end)

CreateThread(function()
    while true do
        if #nearSegments == 0 or not cfg.Enabled then
            Wait(500)
        else
            for _, seg in ipairs(nearSegments) do
                Tape.DrawSegment(seg.a, seg.b, seg.style)
            end
            Wait(0)
        end
    end
end)

function Tape.StyleKeys()
    local keys = {}
    for key in pairs(cfg.Styles) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(x, y)
        if x == cfg.DefaultStyle then return true end
        if y == cfg.DefaultStyle then return false end
        return x < y
    end)
    return keys
end

function Tape.Start(styleKey)
    local first, last
    local count = 0
    local keys = Config.Placement.KeyLabels

    Placement.Run({
        model = cfg.PoleModel,
        help = {
            Util.HelpLine(keys.TapeFinish, L('help_finish')),
            Util.HelpLine(keys.TapeClose, L('help_close'))
        },
        validate = function(pos)
            if not last then return true end
            local dist = #(pos - last.coords)
            return dist <= cfg.MaxSegment and dist >= 0.3
        end,
        onFrame = function(pos, _, valid)
            if last then
                Tape.DrawSegment(last.coords, pos, last.style, cfg.PreviewAlpha, not valid and Config.Placement.InvalidColor or nil)
            end
        end,
        onConfirm = function(pos, heading)
            local ok, result, fatal = Placement.Submit({
                kind = 'pole',
                model = cfg.PoleModel,
                coords = pos,
                heading = heading,
                style = styleKey,
                link = last and last.id
            })
            if not ok then return not fatal and result ~= 'invalid' end
            local style = last and last.style or styleKey
            last = { id = result, coords = pos, style = style }
            if not first then first = last end
            count = count + 1
            return true
        end,
        actions = {
            {
                controls = Config.Placement.Controls.TapeFinish,
                run = function() return true end
            },
            {
                controls = Config.Placement.Controls.TapeClose,
                run = function()
                    if count < 3 then
                        Util.Notify(L('err_tape_short'), 'error')
                        return false
                    end
                    local ok, reason = lib.callback.await('kipchak_crimescene:closeTape', false, first.id, last.id)
                    if not ok then
                        Util.Notify(L('err_' .. tostring(reason)), 'error')
                        return false
                    end
                    Util.Notify(L('tape_closed'), 'success')
                    return true
                end
            }
        }
    })
end
