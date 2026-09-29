Marker = {}

local active = nil

local function hexToRgb(hex)
    hex = tostring(hex or '#6fd8cd'):gsub('#', '')

    return tonumber(hex:sub(1, 2), 16) or 111,
           tonumber(hex:sub(3, 4), 16) or 216,
           tonumber(hex:sub(5, 6), 16) or 205
end

local function groundAt(coords)
    local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)
    return found and z or (coords.z - 1.0)
end

local function spaced(text)
    local out = {}

    for index = 1, #text do
        out[#out + 1] = text:sub(index, index)
    end

    return table.concat(out, ' ')
end

local function formatDistance(metres)
    if metres >= 1000.0 then return ('%.1fKM'):format(metres / 1000.0) end
    return ('%dM'):format(math.floor(metres))
end

local function alphaFor(distance)
    local waypoint = Config.Waypoint

    if distance > waypoint.DrawDistance then return 0.0 end

    local fadingIn = waypoint.DrawDistance - waypoint.FadeInOver
    if distance > fadingIn then
        return (waypoint.DrawDistance - distance) / waypoint.FadeInOver
    end

    return 1.0
end

local function scaleFor(distance)
    local waypoint = Config.Waypoint
    local along = math.min(math.max(distance / waypoint.DrawDistance, 0.0), 1.0)

    return waypoint.ScaleNear + (waypoint.ScaleFar - waypoint.ScaleNear) * along
end

local function text(value, font, scale, x, y, red, green, blue, alpha)
    SetTextFont(font)
    SetTextScale(scale, scale)
    SetTextColour(red, green, blue, alpha)
    SetTextCentre(true)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentSubstringPlayerName(value)
    DrawText(x, y)
end

local function render(marker, distance, alpha)
    local waypoint = Config.Waypoint
    local red, green, blue = hexToRgb(waypoint.Colour)

    local shade = math.floor(255 * alpha)
    if shade < 4 then return end

    local target = marker.coords
    local ground = marker.ground
    local top = ground + waypoint.Height

    DrawMarker(1, target.x, target.y, ground - 0.95,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        1.4, 1.4, 0.3,
        red, green, blue, math.floor(shade * 0.45),
        false, false, 2, false, nil, nil, false)

    if waypoint.Beam then
        DrawLine(target.x, target.y, top - 0.4, target.x, target.y, ground,
            red, green, blue, math.floor(shade * 0.6))
    end

    if not waypoint.Label then return end

    local onScreen, x, y = World3dToScreen2d(target.x, target.y, top)
    if not onScreen then return end

    local scale = scaleFor(distance)

    text(formatDistance(distance), 7, scale * 1.5, x, y, 255, 255, 255, shade)

    local ruleY = y + (scale * 0.072)
    DrawRect(x, ruleY, scale * 0.20, 0.0018, red, green, blue, math.floor(shade * 0.8))

    text(spaced(marker.label), 4, scale * 0.62, x, ruleY + 0.008,
        255, 255, 255, math.floor(shade * 0.95))
end

---@param coords vector3
---@param label string|nil
function Marker.set(coords, label)
    Marker.clear()
    if not coords or not Config.Waypoint.Enabled then return end

    active = {
        coords = coords,
        label = (label or 'Objective'):upper(),
        ground = groundAt(coords),
    }

    CreateThread(function()
        while active do
            local marker = active
            local distance = #(GetEntityCoords(PlayerPedId()) - marker.coords)
            local alpha = alphaFor(distance)

            if alpha <= 0.0 then
                Wait(500)
            else
                render(marker, distance, alpha)
                Wait(0)
            end
        end
    end)
end

function Marker.clear()
    active = nil
end

---@return boolean
function Marker.isActive() return active ~= nil end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Marker.clear()
end)
