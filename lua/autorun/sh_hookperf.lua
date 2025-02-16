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
        return MsgC( pink, "No permission.\n" )
    end

    local time = tonumber( args[1] ) or 10

    local lagTbl = {}
    HOOK_PERF_ORIGINALS = HOOK_PERF_ORIGINALS or {}

    for hookName, hookTable in pairs( hook.GetTable() ) do
        for hookEvent, hookFunc in pairs( hookTable ) do
            HOOK_PERF_ORIGINALS[hookName] = HOOK_PERF_ORIGINALS[hookName] or {}
            HOOK_PERF_ORIGINALS[hookName][hookEvent] = hookFunc

            local hookFunc = hookFunc
            local originInfo = debug.getinfo( hookFunc, "S" )
            local hookFuncOrigin = originInfo.short_src
            local hookFuncLastDefined = originInfo.lastlinedefined

            local function wrapper( ... )
                local info = lagTbl[hookEvent]
                if not info then
                    info = { count = 0, time = 0, hook = hookName, origin = hookFuncOrigin, lastDefined = hookFuncLastDefined }
                    lagTbl[hookEvent] = info
                end
                info.count = info.count + 1

                local sysTime = SysTime()
                local a, b, c, d, e, f = hookFunc( ... )
                lagTbl[hookEvent].time = lagTbl[hookEvent].time + SysTime() - sysTime

                return a, b, c, d, e, f
            end

            hook.Add( hookName, hookEvent, wrapper )
        end
    end

    timer.Simple( time, function()
        -- restore
        for hookName, hookTable in ipairs( hook.GetTable() ) do
            for hookEvent in pairs( hookTable ) do
                hook.Remove( hookName, hookEvent )
                hook.Add( hookName, hookEvent, HOOK_PERF_ORIGINALS[hookName][hookEvent] )
            end
        end

        -- sort
        local sorted = {}
        for k, v in pairs( lagTbl ) do
            table.insert( sorted, { k, v } )
        end

        table.sort( sorted, function( a, b )
            return a[2].time > b[2].time
        end )

        MsgC( softWhite, "Laggy hooks:\n" )
        printer( "Hook name", "Hook", "Time", "Count", "Origin", "Line defined" )
        for i = 1, 100 do
            local v = sorted[i]
            if not v then break end

            printer( v[1], v[2].hook, v[2].time, v[2].count, v[2].origin, v[2].lastDefined )
        end

        HOOK_PERF_ORIGINALS = nil
    end )
end )
