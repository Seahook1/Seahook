local HttpService = game:GetService("HttpService")
local CurrentPlaceId = game.PlaceId

local Registry = {
    [18687417158] = { 
        Name = "The Forsaken", 
        Url = "https://raw.githubusercontent.com/Seahook1/Seahook/refs/heads/main/Hooksaken.luau" 
    },
    [6839171747] = { 
        Name = "DOORS", 
        Url = "https://raw.githubusercontent.com/Seahook1/Seahook/refs/heads/main/doors.luau" 
    },
}

local function executeScript(gameData)
    print(string.format("[Loader]: Initializing %s (ID: %d)...", gameData.Name, CurrentPlaceId))

    local targetUrl = gameData.Url .. "?cache=" .. tick()

    local success, response = pcall(function()
        return game:HttpGet(targetUrl)
    end)

    if not success or not response then
        warn(string.format("[Loader Error]: Failed to download payload for %s.", gameData.Name))
        return
    end

    local loadSuccess, loadError = pcall(function()
        local compiledFn, compileError = loadstring(response)
        if not compiledFn then
            error(compileError)
        end
        return compiledFn()
    end)

    if loadSuccess then
        print(string.format("[Loader Success]: %s executed cleanly.", gameData.Name))
    else
        warn(string.format("[Loader Error]: Execution faulted in %s -> %s", gameData.Name, tostring(loadError)))
    end
end

local function dispatch()
    local matchedGame = Registry[CurrentPlaceId]

    if matchedGame then
        task.spawn(function()
            executeScript(matchedGame)
        end)
    else
        warn(string.format("[Loader]: Unregistered Place ID detected: %d. No script loaded.", CurrentPlaceId))
    end
end

dispatch()
