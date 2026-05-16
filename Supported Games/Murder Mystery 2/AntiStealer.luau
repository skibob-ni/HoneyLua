--[[
usage:
    local AntiStealer = loadstring(game:HttpGet("https://raw.githubusercontent.com/ThatSick/HoneyLua/refs/heads/main/Supported%20Games/Murder%20Mystery%202/AntiStealer.luau"))()
    local scan = AntiStealer.RunStartupTradeTamperScan()

    return scan.detected, scan.reason

return examples:
    false clean
    true RequestSent:executor_closure_on_trade_remote

This script only scans and reports. It will not kick or block trades.
]]

local Tamper = {Version = "2026.05.13.1"}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local watched = {
    "GetRequest",
    "RequestSent",
    "StartTrade",
    "UpdateTrade",
    "AcceptTrade",
    "CompleteTrade",
    "OfferItem",
    "RemoveOffer",
    "EndTrade"
}

local badHashes = {
    ["1af8219d01069a76dc696efe48db9c1746b00d757b590a4b4463c33f4248fd9e16d913827493b6f1f566cfd9e47471ad"] = true,
    ["d1c5a56a5941a358f4923c3e545aa8871d525329032a5da02a23fac1eed61a0621d9a3d5bd5258ecc967cb90fb21cd28"] = true
}

local highRisk = {
    StartTrade = true,
    UpdateTrade = true,
    AcceptTrade = true,
    CompleteTrade = true,
    OfferItem = true,
    RemoveOffer = true,
    EndTrade = true
}

local baselinePaths = {
    "ReplicatedStorage.UpdateData",
    "ReplicatedStorage.ChatMessage",
    "ReplicatedStorage.Remotes.Gameplay.RoundStart",
    "ReplicatedStorage.Remotes.Inventory.Equip",
    "ReplicatedStorage.TrapSystem.TrapNotification"
}

local envMarkers = {
    executed = {"boolean", "true", "executed_global_marker", "high"}
}

local function inspect(connection)
    local info = {
        line = nil,
        source = "",
        hash = nil,
        isExecutorClosure = false,
        constants = {}
    }

    local fn
    pcall(function() fn = connection.Function end)

    if typeof(fn) == "function" then
        pcall(function() info.line = debug.info(fn, "l") end)
        pcall(function() info.source = tostring(debug.info(fn, "s") or "") end)
        pcall(function() info.hash = getfunctionhash and getfunctionhash(fn) or nil end)
        pcall(function() info.isExecutorClosure = isexecutorclosure and isexecutorclosure(fn) or false end)

        local getter = type(debug) == "table" and debug.getconstants or nil
        local gotConstants, values = false, nil

        if type(getter) == "function" then
            gotConstants, values = pcall(getter, fn)
        end

        if gotConstants and type(values) == "table" then
            for i = 1, math.min(#values, 12) do
                local value = values[i]
                local valueKind = typeof(value)
                info.constants[#info.constants + 1] = (value == nil or valueKind == "string" or valueKind == "number" or valueKind == "boolean")
                    and tostring(value)
                    or valueKind
            end
        end
    end

    if type(info.hash) == "string" and info.hash ~= "" then
        info.signature = "hash:" .. info.hash
    else
        info.signature = table.concat({
            tostring(info.source or ""),
            tostring(info.line or ""),
            table.concat(info.constants or {}, "\31")
        }, "\30")
    end

    return info
end

local function normalizeTrustedSignatures(options)
    local trusted = {}
    if type(options) ~= "table" or type(options.trustedSignatures) ~= "table" then
        return trusted
    end

    for key, value in pairs(options.trustedSignatures) do
        if type(key) == "string" and value == true then
            trusted[key] = true
        elseif type(value) == "string" and value ~= "" then
            trusted[value] = true
        end
    end

    return trusted
end

local function scanRemote(remote, baseline)
    local ok, list = pcall(getconnections, remote.OnClientEvent)
    if not ok or type(list) ~= "table" then
        return {
            name = remote.Name,
            ok = false,
            error = "getconnections failed",
            total = 0,
            executorCount = 0,
            suspicious = {}
        }
    end

    local result = {
        name = remote.Name,
        ok = true,
        total = #list,
        executorCount = 0,
        suspicious = {}
    }

    for _, connection in ipairs(list) do
        local info = inspect(connection)

        if info.isExecutorClosure then
            result.executorCount += 1

            local reason
            if type(baseline) == "table" and baseline[info.signature] == true then
                reason = nil
            elseif badHashes[info.hash] then
                reason = "known_bad_hash"
            elseif highRisk[tostring(remote.Name)] then
                local markerA = string.char(76, 117, 114, 97, 112, 104, 32, 83, 99, 114, 105, 112, 116, 58)
                local markerB = string.char(40, 105, 110, 116, 101, 114, 110, 97, 108, 41)
                local hasA = false
                local hasB = false

                for _, value in ipairs(info.constants or {}) do
                    value = tostring(value)
                    hasA = hasA or value == markerA
                    hasB = hasB or value == markerB
                end

                if hasA and hasB then
                    reason = "wrapped_trade_signature"
                end
            end

            if not reason and (type(baseline) ~= "table" or baseline[info.signature] ~= true) then
                reason = "executor_closure_on_trade_remote"
            end

            if reason then
                result.suspicious[#result.suspicious + 1] = {
                    reason = reason,
                    confidence = (reason == "executor_closure_on_trade_remote" and not highRisk[tostring(remote.Name)]) and "medium" or "high",
                    hash = info.hash,
                    line = info.line,
                    source = info.source
                }
            end
        end
    end

    return result
end

local function scanEnv()
    local globals = getgenv()
    local hits = {}

    if type(globals) ~= "table" then
        return {
            ok = false,
            error = "global environment unavailable",
            suspicious = hits
        }
    end

    for key, rule in pairs(envMarkers) do
        local value = rawget(globals, key)
        local actualType = typeof(value)

        if value ~= nil and actualType == rule[1] and tostring(value) == rule[2] then
            hits[#hits + 1] = {
                key = key,
                reason = rule[3],
                confidence = rule[4],
                valueType = actualType,
                value = tostring(value)
            }
        end
    end

    return {
        ok = true,
        suspicious = hits
    }
end

local function runScan(options)
    local envScan = scanEnv()
    local ok = type(getconnections) == "function" and type(isexecutorclosure) == "function"
    local skipReason
    local results = {}
    local flagged = {}

    if not ok then
        local missing = {}
        if type(getconnections) ~= "function" then missing[#missing + 1] = "getconnections" end
        if type(isexecutorclosure) ~= "function" then missing[#missing + 1] = "isexecutorclosure" end
        skipReason = "missing " .. table.concat(missing, ", ")
    end

    if ok then
        local baseline = normalizeTrustedSignatures(options)

        for _, path in ipairs(baselinePaths) do
            local remote = game

            for part in string.gmatch(path, "[^%.]+") do
                if remote == game then
                    local gotService, service = pcall(game.GetService, game, part)
                    remote = gotService and service or remote:FindFirstChild(part)
                else
                    remote = remote and remote:FindFirstChild(part)
                end
            end

            local list
            if remote and remote:IsA("RemoteEvent") then
                local gotConnections
                gotConnections, list = pcall(getconnections, remote.OnClientEvent)
                if not gotConnections or type(list) ~= "table" then
                    list = nil
                end
            end

            for _, connection in ipairs(list or {}) do
                local info = inspect(connection)

                if info.isExecutorClosure and info.signature ~= "" then
                    baseline[info.signature] = true
                end
            end
        end

        local trade = ReplicatedStorage:FindFirstChild("Trade")

        if trade then
            for _, name in ipairs(watched) do
                local remote = trade:FindFirstChild(name)

                if remote and remote:IsA("RemoteEvent") then
                    local result = scanRemote(remote, baseline)
                    results[#results + 1] = result

                    if #(result.suspicious or {}) > 0 then
                        flagged[#flagged + 1] = result
                    end
                end
            end
        end
    end

    local detected = #(envScan.suspicious or {}) > 0 or #flagged > 0
    local scan = {
        version = Tamper.Version,
        detected = detected,
        confidence = detected and "high" or "none",
        reason = detected and nil or "clean",
        envScan = envScan,
        originalScan = {
            ok = ok,
            skipped = not ok,
            reason = skipReason
        },
        flagged = flagged,
        results = results
    }

    if detected then
        if #(envScan.suspicious or {}) > 0 then
            scan.reason = "startup_runtime_marker"
        else
            local firstRemote = flagged[1]
            local firstHit = firstRemote and firstRemote.suspicious and firstRemote.suspicious[1]
            scan.reason = firstRemote
                and (tostring(firstRemote.name or "trade_remote") .. ":" .. tostring(firstHit and firstHit.reason or "trade_listener"))
                or "startup_trade_tamper"
        end
    end

    getgenv().HoneyMM2RemoteAntiStealerLastScan = scan

    return scan
end

Tamper.RunStartupTradeTamperScan = runScan
Tamper.RunRuntimeTradeTamperScan = runScan

return Tamper
