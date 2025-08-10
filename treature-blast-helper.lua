-- Table to store found treasures
local treasures = {}
-- Total treasures counter
local total = 0
-- Lock state for rendering
local lock = true

-- Scans the world for treasures or specific tile counts
function scan(cliff)
    local total = 0

    -- Loop through all tiles in the world
    for x = 0, 99 do
        for y = 0, 53 do
            local tile = checkTile(x, y)
            local fg = tile.fg

            if not cliff then
                -- Collect all treasures with foreground ID 7628
                if fg == 7628 then
                    table.insert(treasures, { x = x, y = y })
                end
            else
                -- Count tiles with foreground ID 7620
                if fg == 7620 then
                    total = total + 1
                end
            end
        end
    end

    -- If in cliff mode, return true if enough tiles exist
    if cliff then
        return total >= 1000
    end
end

-- Returns true if two numbers are within a certain tolerance
local function isClose(a, b, tolerance)
    return math.abs(a - b) <= tolerance
end

-- Clamps value v between a and b
local function clamp(v, a, b)
    return math.max(a, math.min(b, v))
end

-- Converts RGBA values to ABGR hex
local function rgba_to_hex_abgr(r, g, b, a)
    return a * 16777216 + b * 65536 + g * 256 + r
end

-- Rendering function
function render()
    -- If locked or no treasures, skip rendering
    if lock or #treasures == 0 then
        collectgarbage("collect")
        return
    end

    -- Get local player data
    local p_local = getLocal()
    if p_local == nil then
        lock = true
        treasures = {}
        return
    end

    -- Distance thresholds (in tiles)
    local close_threshold = 5
    local far_threshold   = 25

    -- Line thickness for normal and highlighted treasures
    local normal_thickness = 2.0
    local highlight_thickness = 5.0

    -- Player's screen position
    local p_screen = worldToScreen(p_local.pos.x + 9, p_local.pos.y - 20)

    -- Player's tile position
    local px_tile = math.floor(p_local.pos.x) // 32
    local py_tile = math.floor(p_local.pos.y) // 32

    -- Step 1: Calculate distances from player to each treasure
    local distances = {}
    local minDist, maxDist = math.huge, 0
    for i, pos in ipairs(treasures) do
        local dx = pos.x - px_tile
        local dy = pos.y - py_tile
        local dist = math.sqrt(dx * dx + dy * dy)
        distances[i] = dist
        if dist < minDist then minDist = dist end
        if dist > maxDist then maxDist = dist end
    end

    -- Avoid division by zero
    local range = maxDist - minDist
    if range <= 0 then range = 1 end

    -- Find nearest treasure index
    local nearestIndex = 1
    for i = 1, #distances do
        if distances[i] < distances[nearestIndex] then
            nearestIndex = i
        end
    end

    -- Step 2: Render each treasure
    for i, pos in ipairs(treasures) do
        local dist = distances[i]

        -- Normalize distance (0 = nearest, 1 = farthest)
        local t = clamp((dist - minDist) / range, 0, 1)

        -- Color interpolation (green → red)
        local r = math.floor(255 * t)
        local g = math.floor(255 * (1 - t))
        local b = 0
        local a = 255
        local color = rgba_to_hex_abgr(r, g, b, a)

        -- Screen positions for treasure rectangle
        local s_screen = worldToScreen(pos.x * 32, pos.y * 32 + 1)
        local e_screen = worldToScreen(pos.x * 32 + 32, pos.y * 32 + 32)

        -- Highlight the nearest treasure with a thicker line
        if i == nearestIndex then
            ImGui.BG:AddRect(s_screen, e_screen, color, 0.0, 0.8)
            ImGui.BG:AddLine(p_screen, s_screen, color, highlight_thickness)
        else
            ImGui.BG:AddRect(s_screen, e_screen, color, 0.0, 0.8)
            ImGui.BG:AddLine(p_screen, s_screen, color, normal_thickness)
        end
    end

    collectgarbage("collect")
end

-- Generates a random string with given length
function random(length)
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = {}
    math.randomseed(os.time() + math.random(1000)) -- Seed RNG
    for i = 1, length do
        local rand = math.random(1, #charset)
        table.insert(result, charset:sub(rand, rand))
    end
    return table.concat(result)
end

-- Hook to render treasures
AddHook("OnRender", "RENDER_VEND_FINDER", render)

-- Hook for text packet events
AddHook("OnTextPacket", "TEXT_PACKET", function(_, pkt)
    collectgarbage("collect")
    if pkt == "action|quit_to_exit" then
        lock = true
        treasures = {}
    end
    if pkt == "action|input\n|text|/s" then
        lock = false
        treasures = {}
        scan()
        total = #treasures
        logToConsole("`9 >>> Found " .. #treasures .. " Hidden Treasures <<<")
        return true
    end
end)

-- Hook for game update packet events
AddHook("OnGameUpdatePacket", "kontol", function(raw)
    collectgarbage("collect")
    if raw.type == 3 and raw.value == 18 then
        for i = #treasures, 1, -1 do
            local pos = treasures[i]
            if raw.punchx == pos.x and raw.punchy == pos.y then
                table.remove(treasures, i)
                local after = #treasures
                if after ~= 0 then
                    logToConsole(string.format("`9 >>> %d Hidden Treasures remains (was %d) <<<", after, total))
                else
                    logToConsole("`9 >> All Hidden Treasures have been collected <<")
                end
            end
        end
    end
end)

-- Hook for dialog and console events
AddHook("OnVarlist", "varlist", function(v, netid)
    collectgarbage("collect")

    -- Intercept Treasure Blast dialog
    if v[0] == "OnDialogRequest" and v[1]:find("Treasure Blast") and v[1]:find("new world!") and netid == -1 then
        local var = {}
        var[0] = "OnDialogRequest"
        var[1] = [[set_default_color|`o
add_label_with_icon|big|`wTreasure Blast``|left|7588|
add_textbox|This item creates a new world.|left|
add_textbox|This name is randomly generated by lua|left|
add_text_input|worldname|World Name:|]] .. random(8) .. [[|24|
embed_data|itemID|7588
end_dialog|terraformer_reply|Cancel|`5Create!``|]]
        sendVariant(var, -1)
        return true
    end

    -- Auto-scan treasures when entering a world with enough tiles
    if v[0] == "OnConsoleMessage" then
        if v[1]:find("World") and v[1]:find("entered.  There are") then
            if scan(true) then
                lock = false
                treasures = {}
                scan()
                total = #treasures
                logToConsole("`9 >>> Found " .. #treasures .. " Hidden Treasures <<<")
            end
        end
    end
end)
