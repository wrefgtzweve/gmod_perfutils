local cmd = SERVER and "red_sv_sentperf" or "red_cl_sentperf"
concommand.Add( cmd, function( ply, _, args )
    if SERVER and IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint( "No permission." )
    end

    if SENT_PERF_RUNNING then
        MsgC( softWhite, "Sent performance profiler is already running.\n" )
        return
    end

    SENT_PERF_RUNNING = true
    ENT_METHODS_ORIGINALS = ENT_METHODS_ORIGINALS or {}

    local lagTbl = {}

    for _, ent in ipairs( ents.GetAll() ) do
        if not ent:IsScripted() then continue end

        ENT_METHODS_ORIGINALS[ent] = ENT_METHODS_ORIGINALS[ent] or {}
        local entTable = ent:GetTable()
        for varName, var in pairs( entTable ) do
            if not isfunction( var ) then continue end
            ENT_METHODS_ORIGINALS[ent][varName] = var

            local original = ENT_METHODS_ORIGINALS[ent][varName]
            local originInfo = debug.getinfo( original, "S" )
            local perfID = ent:GetClass() .. ":" .. varName
            local entOrigin = originInfo.short_src
            local entLastDefined = originInfo.lastlinedefined

            local function wrapper( ... )
                local sysTime = SysTime()
                local a, b, c, d, e, f = original( ... )
                local elapsed = SysTime() - sysTime

                local info = lagTbl[perfID]
                if not info then
                    info = { class = ent:GetClass(), varName = varName, count = 0, time = 0, origin = entOrigin, lastDefined = entLastDefined }
                    lagTbl[perfID] = info
                end

                info.count = info.count + 1
                info.time = info.time + elapsed

                return a, b, c, d, e, f
            end

            ent[varName] = wrapper
        end
    end

    local time = tonumber( args[1] ) or 10
    local startTime = SysTime()
    timer.Simple( time, function()
        if CLIENT then
            chat.AddText( "Sent performance profiler finished." )
        end

        for ent, methods in pairs( ENT_METHODS_ORIGINALS ) do
            if not IsValid( ent ) then continue end
            for methodName, originalFunc in pairs( methods ) do
                if isfunction( originalFunc ) then
                    ent[methodName] = originalFunc
                end
            end
        end

        local sorted = {}
        for _, info in pairs( lagTbl ) do
            table.insert( sorted, info )
        end

        table.sort( sorted, function( a, b )
            return a.time > b.time
        end )

        local endTime = SysTime()
        local runTime = math.Round( endTime - startTime, 2 )
        print( "Sent profiler ran for " .. runTime .. " seconds." )
        print( "Class\tCount\tTime (seconds)\tOrigin\tLast Defined" )
        for i = 1, 100 do
            local sort = sorted[i]
            if sort then
                print( sort.class, sort.varName, sort.count, sort.time, sort.origin .. ":" .. sort.lastDefined )
            end
        end

        SENT_PERF_RUNNING = nil
        ENT_METHODS_ORIGINALS = nil
    end )
end )
