local hookC = Color( 58, 150, 221 )
local darkGray = Color( 100, 100, 100 )
local softWhite = Color( 205, 205, 205 )
local hookIDC = Color( 19, 161, 14 )
local timeC = Color( 231, 72, 86 )
local countC = Color( 52, 64, 235 )

local colors = { hookIDC, hookC, timeC, countC, softWhite, darkGray }
local function printer( ... )
    local order = {}
    for i, txt in pairs( { ... } ) do
        table.insert( order, colors[i] )
        table.insert( order, tostring( txt ) .. " " )
    end

    table.insert( order, "\n" )

    MsgC( unpack( order ) )
end

local cmd = SERVER and "red_sv_hookperf" or "red_cl_hookperf"
concommand.Add( cmd, function( ply, _, args )
    if SERVER and IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint( "No permission." )
    end

    local time = tonumber( args[1] ) or 10

    if HOOK_PERF_RUNNING then
        MsgC( softWhite, "Hook performance profiler is already running.\n" )
        return
    end

    local lagTbl = {}
    HOOK_PERF_ORIGINALS = HOOK_PERF_ORIGINALS or {}
    HOOK_PERF_RUNNING = true

    for hookName, hookTable in pairs( hook.GetTable() ) do
        for hookEvent, hookFunc in pairs( hookTable ) do
            HOOK_PERF_ORIGINALS[hookName] = HOOK_PERF_ORIGINALS[hookName] or {}
            HOOK_PERF_ORIGINALS[hookName][hookEvent] = HOOK_PERF_ORIGINALS[hookName][hookEvent] or hookFunc

            local originalFunc = HOOK_PERF_ORIGINALS[hookName][hookEvent]
            local originInfo = debug.getinfo( originalFunc, "S" )
            local hookFuncOrigin = originInfo.short_src
            local hookFuncLastDefined = originInfo.lastlinedefined

            local function wrapper( ... )
                local info = lagTbl[hookEvent]
                if not info then
                    info = { count = 0, time = 0, hook = hookName, origin = hookFuncOrigin, lastDefined = hookFuncLastDefined, isGM = false }
                    lagTbl[hookEvent] = info
                end
                info.count = info.count + 1

                local sysTime = SysTime()
                local a, b, c, d, e, f = originalFunc( ... )
                lagTbl[hookEvent].time = lagTbl[hookEvent].time + SysTime() - sysTime

                return a, b, c, d, e, f
            end

            hook.Add( hookName, hookEvent, wrapper )
        end
    end

    local GM = GAMEMODE or GM
    GM_ORIGINALS = GM_ORIGINALS or {}
    for methodName, func in pairs( GM ) do
        if isfunction( func ) then
            GM_ORIGINALS[methodName] = GM_ORIGINALS[methodName] or func
            local original = GM_ORIGINALS[methodName]
            local originInfo = debug.getinfo( original, "S" )

            local function detour( ... )
                local startTime = SysTime()
                local a, b, c, d, e, f = original( ... )

                local info = lagTbl[methodName]
                if not info then
                    info = { count = 0, time = 0, hook = methodName, origin = originInfo.short_src, lastDefined = originInfo.lastlinedefined, isGM = true }
                    lagTbl[methodName] = info
                end

                lagTbl[methodName].time = lagTbl[methodName].time + SysTime() - startTime
                return a, b, c, d, e, f
            end

            GM[methodName] = detour
        end
    end

    timer.Simple( time, function()
        -- restore
        local allHooks = hook.GetTable()
        for hookName, hookTable in pairs( allHooks ) do
            for hookEvent in pairs( hookTable ) do
                if not allHooks[hookName] or not allHooks[hookName][hookEvent] then
                    continue
                end

                hook.Remove( hookName, hookEvent )
                hook.Add( hookName, hookEvent, HOOK_PERF_ORIGINALS[hookName][hookEvent] )
            end
        end

        for methodName, func in pairs( GM_ORIGINALS ) do
            if not GM[methodName] then
                continue
            end

            GM[methodName] = func
        end

        HOOK_PERF_ORIGINALS = nil
        HOOK_PERF_RUNNING = nil

        -- sort
        local sorted = {}
        for k, v in pairs( lagTbl ) do
            table.insert( sorted, { k, v } )
        end

        table.sort( sorted, function( a, b )
            return a[2].time > b[2].time
        end )

        MsgC( softWhite, "Laggy hooks:\n" )
        printer( "Name", "Hook", "Time", "Count", "Origin", "Line defined" )
        for i = 1, 100 do
            local v = sorted[i]
            if not v then break end

            printer( ( v[2].isGM and "GM:" or "" ) .. tostring( v[1] ), v[2].hook, v[2].time, v[2].count, v[2].origin, v[2].lastDefined )
        end


        -- Add hook performance up per hookname
        MsgC( softWhite, "\nLaggy hooks summed by hook name:\n" )
        printer( "Name", "Hook", "Time", "Count", "Origin", "Line defined" )
        local summed = {}
        for _, v in pairs( lagTbl ) do
            local info = summed[v.hook]
            if not info then
                info = { count = 0, time = 0, hook = v.hook, origin = v.origin, lastDefined = v.lastDefined, isGM = v.isGM }
                summed[v.hook] = info
            end
            info.count = info.count + v.count
            info.time = info.time + v.time
        end

        local sortedSummed = {}
        for k, v in pairs( summed ) do
            table.insert( sortedSummed, { k, v } )
        end
        table.sort( sortedSummed, function( a, b )
            return a[2].time > b[2].time
        end )

        -- only print top 100
        for i = 1, 100 do
            local v = sortedSummed[i]
            if not v then break end

            MsgC( hookC, tostring( v[1] ), darkGray, " - ", timeC, math.Round( v[2].time, 6 ) .. "s", darkGray, " - ", countC, v[2].count .. " calls", "\n" )
        end
    end )
end )
