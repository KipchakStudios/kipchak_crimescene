Actions = {}

local Perms = { allowed = false, removeOthers = false, clear = false }

local function refreshPerms()
    local result = lib.callback.await('kipchak_crimescene:getAccess', false)
    if type(result) == 'table' then
        Perms = result
    end
    return Perms
end

function Actions.CanManage(id)
    local obj = id and Store[id]
    if not obj or not Perms.allowed then return false end
    return obj.ownerTag == Perms.tag or Perms.removeOthers == true
end

function Actions.CanNote(id)
    local obj = id and Store[id]
    return obj ~= nil and obj.kind == 'marker' and Config.Markers.Notes.Enabled and Actions.CanManage(id)
end

function Actions.Remove(id)
    if not id or not Store[id] then return end
    local ok, reason = lib.callback.await('kipchak_crimescene:remove', false, id)
    if ok then
        Util.Notify(L('removed'), 'success')
    else
        Util.Notify(L('err_' .. tostring(reason)), 'error')
    end
end

function Actions.EditNote(id)
    local obj = id and Store[id]
    if not obj or obj.kind ~= 'marker' or not Config.Markers.Notes.Enabled then return end
    local input = lib.inputDialog(L('note_title'), {
        { type = 'input', label = L('note_label'), default = obj.note, max = Config.Markers.Notes.MaxLength }
    })
    if not input then return end
    local ok, reason = lib.callback.await('kipchak_crimescene:setNote', false, id, input[1] or '')
    if ok then
        Util.Notify(L('note_saved'), 'success')
    else
        Util.Notify(L('err_' .. tostring(reason)), 'error')
    end
end

function Actions.Info(id)
    local obj = id and Store[id]
    if not obj then return end
    local lines = {}
    if obj.kind == 'marker' then
        lines[#lines + 1] = L('info_marker', obj.number)
    end
    lines[#lines + 1] = L('info_notify', obj.ownerName or '?', obj.timeText or '')
    if obj.note then
        lines[#lines + 1] = L('info_note', obj.note)
    end
    Util.Notify(table.concat(lines, '  \n'), 'inform')
end

local function askNote()
    if not (Config.Markers.Notes.Enabled and Config.Markers.Notes.AskOnPlace) then return end
    local input = lib.inputDialog(L('note_title'), {
        { type = 'input', label = L('note_label'), max = Config.Markers.Notes.MaxLength }
    })
    return input and input[1] or nil
end

local function startMarkers()
    local nextNumber = lib.callback.await('kipchak_crimescene:nextNumber', false) or 1
    local markers = Config.Markers
    Placement.Run({
        model = function() return MarkerModel(nextNumber) end,
        onFrame = function(pos, _, _, top)
            Util.DrawText3D(vector3(pos.x, pos.y, top + 0.15), tostring(nextNumber), markers.TextScale, markers.TextColor)
        end,
        onConfirm = function(pos, heading)
            local ok, _, extra = Placement.Submit({
                kind = 'marker',
                model = MarkerModel(nextNumber),
                coords = pos,
                heading = heading,
                note = askNote()
            })
            if not ok then return not extra end
            nextNumber = extra + 1
            return Config.Placement.ChainPlacement
        end
    })
end

local function startProp(prop)
    Placement.Run({
        model = prop.model,
        onConfirm = function(pos, heading)
            local ok, _, fatal = Placement.Submit({
                kind = 'prop',
                model = prop.model,
                coords = pos,
                heading = heading
            })
            if not ok then return not fatal end
            return Config.Placement.ChainPlacement
        end
    })
end

local function findAimed(ped)
    local hit, coords, _, entity = Util.CameraRaycast(Config.Placement.RayDistance, 17, ped)
    if not hit then return end
    local id = EntityIds[entity]
    if not id then
        local bestDist = 1.25
        for oid in pairs(Spawned) do
            local obj = Store[oid]
            if obj then
                local dist = #(obj.coords - coords)
                if dist < bestDist then
                    id, bestDist = oid, dist
                end
            end
        end
    end
    local obj = id and Store[id]
    if not obj or #(obj.coords - GetEntityCoords(ped)) > Config.Permissions.InteractDistance then return end
    return id
end

local function removeMode()
    if Placement.Busy then return end
    Placement.Busy = true

    local keys = Config.Placement.KeyLabels
    local controls = Config.Placement.Controls
    local color = Config.Placement.InvalidColor
    local lines = {
        Util.HelpLine(keys.Confirm, L('help_remove')),
        Util.HelpLine(keys.Cancel, L('help_exit'))
    }
    if Config.Markers.Notes.Enabled then
        lines[#lines + 1] = Util.HelpLine(keys.EditNote, L('help_note'))
    end
    Util.ShowHelp(lines)

    local highlighted
    while true do
        Util.DisableControls()
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then break end

        local id = findAimed(ped)
        local entity = id and Spawned[id]
        if highlighted ~= entity then
            if highlighted and DoesEntityExist(highlighted) then
                SetEntityDrawOutline(highlighted, false)
            end
            highlighted = entity
            if entity then
                SetEntityDrawOutline(entity, true)
            end
        end

        if entity then
            local obj = Store[id]
            SetEntityDrawOutlineColor(color[1], color[2], color[3], 255)
            DrawMarker(0, obj.coords.x, obj.coords.y, (obj.top or obj.coords.z + 0.5) + 0.35, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.18, 0.18, 0.18, color[1], color[2], color[3], 200, true, true, 2, false, nil, nil, false)
        end

        if Util.Pressed(controls.Cancel) then
            break
        elseif id and Util.Pressed(controls.Confirm) then
            Actions.Remove(id)
        elseif id and Config.Markers.Notes.Enabled and Util.Pressed(controls.EditNote) and Store[id].kind == 'marker' then
            Actions.EditNote(id)
        end

        Wait(0)
    end

    if highlighted and DoesEntityExist(highlighted) then
        SetEntityDrawOutline(highlighted, false)
    end
    lib.hideTextUI()
    Placement.Busy = false
end

local function clearOwn()
    local answer = lib.alertDialog({
        header = L('clear_confirm_header'),
        content = L('clear_confirm_own'),
        centered = true,
        cancel = true
    })
    if answer ~= 'confirm' then return end
    local ok, result = lib.callback.await('kipchak_crimescene:clear', false, 'own')
    if ok then
        Util.Notify(L('cleared', result), 'success')
    else
        Util.Notify(L('err_' .. tostring(result)), 'error')
    end
end

local function clearRadius()
    local input = lib.inputDialog(L('menu_clear_radius'), {
        { type = 'number', label = L('radius_label'), default = Config.Scene.Radius, min = 1, max = Config.Permissions.MaxClearRadius, required = true }
    })
    if not input or not input[1] then return end
    local ok, result = lib.callback.await('kipchak_crimescene:clear', false, 'radius', input[1])
    if ok then
        Util.Notify(L('cleared', result), 'success')
    else
        Util.Notify(L('err_' .. tostring(result)), 'error')
    end
end

local function async(fn, ...)
    local args = { ... }
    return function()
        CreateThread(function() fn(table.unpack(args)) end)
    end
end

local function openMenu()
    if Placement.Busy then return end
    refreshPerms()
    if not Perms.allowed then
        Util.Notify(L('err_no_permission'), 'error')
        return
    end
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        Util.Notify(L('err_in_vehicle'), 'error')
        return
    end

    local options = {}

    if Config.Menu.Marker and Config.Markers.Enabled then
        options[#options + 1] = { title = L('menu_marker'), description = L('menu_marker_desc'), icon = 'location-dot', onSelect = async(startMarkers) }
    end

    if Config.Menu.Tape and Config.Tape.Enabled then
        local styles = Tape.StyleKeys()
        if #styles > 1 then
            local styleOptions = {}
            for _, key in ipairs(styles) do
                styleOptions[#styleOptions + 1] = { title = Config.Tape.Styles[key].label, icon = 'ribbon', onSelect = async(Tape.Start, key) }
            end
            lib.registerContext({ id = 'kipchak_crimescene_tape', title = L('menu_tape_style'), menu = 'kipchak_crimescene_main', options = styleOptions })
            options[#options + 1] = { title = L('menu_tape'), description = L('menu_tape_desc'), icon = 'ribbon', menu = 'kipchak_crimescene_tape' }
        elseif #styles == 1 then
            options[#options + 1] = { title = L('menu_tape'), description = L('menu_tape_desc'), icon = 'ribbon', onSelect = async(Tape.Start, styles[1]) }
        end
    end

    if Config.Menu.Props and #Config.Props > 0 then
        local propOptions = {}
        for _, prop in ipairs(Config.Props) do
            propOptions[#propOptions + 1] = { title = prop.label, icon = prop.icon, onSelect = async(startProp, prop) }
        end
        lib.registerContext({ id = 'kipchak_crimescene_props', title = L('menu_props'), menu = 'kipchak_crimescene_main', options = propOptions })
        options[#options + 1] = { title = L('menu_props'), description = L('menu_props_desc'), icon = 'road-barrier', menu = 'kipchak_crimescene_props' }
    end

    if Config.Menu.Remove then
        options[#options + 1] = { title = L('menu_remove'), description = L('menu_remove_desc'), icon = 'trash', onSelect = async(removeMode) }
    end

    if Config.Menu.Clear then
        if Perms.clear then
            lib.registerContext({
                id = 'kipchak_crimescene_clear',
                title = L('menu_clear'),
                menu = 'kipchak_crimescene_main',
                options = {
                    { title = L('menu_clear_own'), description = L('menu_clear_own_desc'), icon = 'user', onSelect = async(clearOwn) },
                    { title = L('menu_clear_radius'), description = L('menu_clear_radius_desc'), icon = 'circle-dot', onSelect = async(clearRadius) }
                }
            })
            options[#options + 1] = { title = L('menu_clear'), description = L('menu_clear_desc'), icon = 'broom', menu = 'kipchak_crimescene_clear' }
        else
            options[#options + 1] = { title = L('menu_clear'), description = L('menu_clear_own_desc'), icon = 'broom', onSelect = async(clearOwn) }
        end
    end

    if #options == 0 then
        Util.Notify(L('err_disabled'), 'error')
        return
    end

    lib.registerContext({ id = 'kipchak_crimescene_main', title = L('menu_title'), options = options })
    lib.showContext('kipchak_crimescene_main')
end

if Config.Commands.Menu.Enabled then
    RegisterCommand(Config.Commands.Menu.Name, async(openMenu), false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Menu.Name, L('cmd_menu_desc'))
end

if Config.Commands.ClearScene.Enabled then
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.ClearScene.Name, L('cmd_clear_desc'), {
        { name = 'radius', help = L('cmd_clear_arg') }
    })
end

if Config.Keybind.Enabled then
    lib.addKeybind({
        name = 'kipchak_crimescene_menu',
        description = L('keybind_desc'),
        defaultKey = Config.Keybind.Key,
        onPressed = async(openMenu)
    })
end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end
    while true do
        refreshPerms()
        Wait(30000)
    end
end)
