local blacklist = {
    "G4S=",
    "V=",
    "QQ=",
    "QQ.=",
    "BEJE=",
    "Q.Q ",
    "R=",
    "C$N ",
    "PAN?=",
    "V=",
    "RM3=",
    "B'J=",
    "K=",
    "G@S ",
    "P=",
    "1WL=",
    "PLY?=",
    "BJ.=",
    "N=",
    "BJ1=",
    "H=",
    "C5N=",
    "X=",
    "G4S-",
    "RME=",
    "BOS=",
    "GA$=",
    "BJ=",
    "LME=",
    "FREEWL=",
    "FREEDL=",
    "FREEBGL=",
    "FREEDQ=",
    "K3S="
}

function remove_backtick(str)
    return str:gsub("`.", "")
end

function check(str)
    if str:find("[MSG]_>> `c>>") and str:find("=") then
        return true
    end

    if not str or not str:find("`6<```") and not str:find("```6>``") then
        return false
    end

    str = remove_backtick(str)
    for _, b in ipairs(blacklist) do
        if str:find(b, 1, true) then -- true = plain search (faster)
            return true
        end
    end
    return false
end

AddHook("OnVarlist", "HOOK", function(var, _)
    collectgarbage("collect")
    if var[0] == "OnTalkBubble" then
        return check(var[2])
    elseif var[0] == "OnConsoleMessage" then
        return check(var[1])
    end
    return false
end)