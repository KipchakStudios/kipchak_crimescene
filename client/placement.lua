Placement = { Busy = false }

local cfg = Config.Placement
local minNormalZ = math.cos(math.rad(cfg.MaxSlope))

local function createGhost(hash, pos)
    local ghost = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetEntityInvincible(ghost, true)
    SetEntityAlpha(ghost, cfg.GhostAlpha, false)
    SetEntityDrawOutline(ghost, true)
    return ghost
end

local function removeGhost(ghost)
    if ghost and DoesEntityExist(ghost) then
        SetEntityDrawOutline(ghost, false)
        DeleteEntity(ghost)
    end
end

local function spotValid(hit, pos, normal, origin, playerPos)
    if not hit then return false end
    if normal.z < minNormalZ then return false end
    if #(pos - playerPos) > cfg.MaxDistance then return false end
    if TestProbeAgainstWater(origin.x, origin.y, origin.z, pos.x, pos.y, pos.z) then return false end
    return true
end

function Placement.HelpLines(extra)
    local keys = cfg.KeyLabels
    local lines = {
        Util.HelpLine(keys.Confirm, L('help_confirm')),
        Util.HelpLine(keys.Cancel, L('help_cancel')),
        Util.HelpLine(keys.Rotate, L('help_rotate')),
        Util.HelpLine(keys.Fine, L('help_fine'))
    }
    for _, line in ipairs(extra or {}) do
        lines[#lines + 1] = line
    end
    return lines
end

function Placement.Submit(data)
    local ok, result, extra = lib.callback.await('kipchak_crimescene:place', false, data)
    if ok then return true, result, extra end
    Util.Notify(L('err_' .. tostring(result)), 'error')
    return false, result, extra
end

function Placement.Run(opts)
    if Placement.Busy then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        Util.Notify(L('err_in_vehicle'), 'error')
        return
    end

    local function wantedModel()
        if type(opts.model) == 'function' then return opts.model() end
        return opts.model
    end

    local currentModel = wantedModel()
    local hash = Util.LoadModel(currentModel, opts.fallback)
    if not hash then
        Util.Notify(L('err_model_load'), 'error')
        return
    end

    Placement.Busy = true
    local info = Util.ModelInfo(hash)
    local ghost = createGhost(hash, GetEntityCoords(ped))
    local heading = GetEntityHeading(ped)
    local lastInvalidNotice = 0
    Util.ShowHelp(Placement.HelpLines(opts.help))

    while Placement.Busy do
        Util.DisableControls()
        ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then break end

        local desired = wantedModel()
        if desired ~= currentModel then
            local newHash = Util.LoadModel(desired, opts.fallback)
            if newHash then
                removeGhost(ghost)
                hash, currentModel = newHash, desired
                info = Util.ModelInfo(hash)
                ghost = createGhost(hash, GetEntityCoords(ped))
            end
        end

        local hit, pos, normal, _, origin, target = Util.CameraRaycast(cfg.RayDistance, 17, ped)
        if not hit then pos = target end
        local valid = spotValid(hit, pos, normal, origin, GetEntityCoords(ped))
        if valid and opts.validate then
            valid = opts.validate(pos) == true
        end

        local speed = cfg.RotateSpeed * GetFrameTime()
        local step = cfg.WheelStep
        if Util.Held(cfg.Controls.Fine) then
            speed = speed * cfg.FineMultiplier
            step = step * cfg.FineMultiplier
        end
        if Util.Held(cfg.Controls.RotateLeft) then heading = heading + speed end
        if Util.Held(cfg.Controls.RotateRight) then heading = heading - speed end
        if Util.Pressed(cfg.Controls.WheelLeft) then heading = heading + step end
        if Util.Pressed(cfg.Controls.WheelRight) then heading = heading - step end
        heading = heading % 360.0

        SetEntityCoordsNoOffset(ghost, pos.x, pos.y, pos.z + info.base, false, false, false)
        SetEntityHeading(ghost, heading)

        local color = valid and cfg.ValidColor or cfg.InvalidColor
        SetEntityAlpha(ghost, valid and cfg.GhostAlpha or cfg.InvalidAlpha, false)
        SetEntityDrawOutlineColor(color[1], color[2], color[3], 255)
        DrawMarker(25, pos.x, pos.y, pos.z + 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.7, 0.7, 0.7, color[1], color[2], color[3], 150, false, false, 2, false, nil, nil, false)

        if opts.onFrame then
            opts.onFrame(pos, heading, valid, pos.z + info.height)
        end

        local stop = false
        if Util.Pressed(cfg.Controls.Confirm) then
            if valid then
                stop = not opts.onConfirm(pos, heading)
            elseif GetGameTimer() - lastInvalidNotice > 1500 then
                lastInvalidNotice = GetGameTimer()
                Util.Notify(L('err_invalid_spot'), 'error')
            end
        elseif Util.Pressed(cfg.Controls.Cancel) then
            stop = true
        elseif opts.actions then
            for _, action in ipairs(opts.actions) do
                if Util.Pressed(action.controls) then
                    stop = action.run(pos, heading, valid) == true
                    break
                end
            end
        end

        if stop then break end
        Wait(0)
    end

    removeGhost(ghost)
    lib.hideTextUI()
    Placement.Busy = false
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Placement.Busy then
        lib.hideTextUI()
    end
end)
