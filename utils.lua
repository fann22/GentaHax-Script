-- utils.lua
local utils = {}

-- extend string:split
do
    local smt = getmetatable("")
    local old_index = smt.__index

    smt.__index = function(str, key)
        if key == "split" then
            return function(self, sep)
                local result = {}

                if sep == nil then
                    for part in self:gmatch("%S+") do
                        table.insert(result, part)
                    end
                    return result
                end

                if sep == "" then
                    for i = 1, #self do
                        table.insert(result, self:sub(i, i))
                    end
                    return result
                end

                local start = 1
                while true do
                    local i, j = self:find(sep, start, true)
                    if not i then break end
                    table.insert(result, self:sub(start, i - 1))
                    start = j + 1
                end
                table.insert(result, self:sub(start))

                return result
            end
        end
        if key == "getEmbedData" then
            return function(self, data)
                return self:match("embed_data|"..data.."|(%d+)") or ""
            end
        end
        if type(old_index) == "table" then
            return old_index[key]
        elseif type(old_index) == "function" then
            return old_index(str, key)
        end
    end
end

-- extend number
do
    local nmt = debug.getmetatable(0) or {}
    local old_index = nmt.__index

    nmt.__index = function(num, key)
        if key == "isSeed" then
            return function(self)
                -- misalnya definisi seed = ganjil
                return self % 2 ~= 0
            end
        end

        if type(old_index) == "table" then
            return old_index[key]
        elseif type(old_index) == "function" then
            return old_index(num, key)
        end
    end

    debug.setmetatable(0, nmt)
end

-- runDelayed
function utils.runDelayed(fn, delay, ...)
    local args = {...}
    local label = "executor_" .. tostring(math.random(1000000, 9999999))
    local startTime = getCurrentTimeInternal()

    AddHook("OnRender", label, function()
        if getCurrentTimeInternal() >= startTime + delay then
            local ok, err = pcall(fn, table.unpack(args))
            if not ok then
                logToConsole("runDelayed error: " .. tostring(err))
            end
            RemoveHook(label)
        end
    end)
end

function utils.player()
    local data = getLocal()

    local x, y = data.pos.x, data.pos.y

    data.intX = x // 32
    data.intY = y // 32
    data.floatX = x
    data.floatY = y
    data.pos = nil

    function data:getItem(id)
        for _, item in pairs(getInventory()) do
            if item.id == id then
                return item.amount
            end
        end
        return 0
    end
    function data:getItems()
        return getInventory()
    end

    return data
end

return utils
