local cmd = SERVER and "red_sv_hookperf" or "red_cl_hookperf"
concommand.Add( cmd, function( ply )
    if SERVER and IsValid( ply ) then return end

    local lagTbl = {}
    HOOK_PERF_ORIGINALS = HOOK_PERF_ORIGINALS or {}

    for hookName, hookTable in pairs( hook.GetTable() ) do
        for hookEvent, hookFunc in pairs( hookTable ) do
            HOOK_PERF_ORIGINALS[hookName] = HOOK_PERF_ORIGINALS[hookName] or {}
            HOOK_PERF_ORIGINALS[hookName][hookEvent] = hookFunc

            local hookFunc = hookFunc
            local function wrapper( ... )
                local info = lagTbl[hookEvent]
                if not info then
                    info = { count = 0, time = 0, hook = hookName }
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

    timer.Simple( 10, function()
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

        print( "Laggy hooks:" )
        for i = 1, 100 do
            local v = sorted[i]
            if not v then break end

            print( v[1], v[2].hook, v[2].time, v[2].count )
        end

        HOOK_PERF_ORIGINALS = nil
    end )
end )