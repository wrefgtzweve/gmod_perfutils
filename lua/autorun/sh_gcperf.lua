local hookC = Color( 58, 150, 221 )
local darkGray = Color( 100, 100, 100 )
local softWhite = Color( 205, 205, 205 )
local hookIDC = Color( 19, 161, 14 )
local memC = Color( 231, 72, 86 )
local countC = Color( 52, 64, 235 )

local colWhite   = Color( 255, 255, 255 )
local colGray    = Color( 160, 160, 160 )
local colCyan    = Color( 100, 220, 255 )
local colYellow  = Color( 255, 220, 80  )
local colGreen   = Color( 100, 220, 120 )
local colHeader  = Color( 220, 180, 255 )
local tab = "\t"

local colors = { hookIDC, hookC, memC, countC, softWhite, darkGray }
local function printer( ... )
    local order = {}
    for i, txt in pairs( { ... } ) do
        table.insert( order, colors[i] )
        table.insert( order, tostring( txt ) .. " " )
    end

    table.insert( order, "\n" )

    MsgC( unpack( order ) )
end

-- support for srlion's hook library priorities
local function GetInternalHooks()
    if hook.Author ~= "Srlion" then return end
    local i = 0

    while true do
        i = i + 1

        local name, value = debug.getupvalue( hook.Call, i )
        if not name then break end

        if name == "events" then
            return value
        end
    end
end

local cmd = SERVER and "red_sv_gcperf" or "red_cl_gcperf"
concommand.Add( cmd, function( ply, _, args )
    if SERVER and IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint( "No permission." )
    end

    if GC_PERF_RUNNING then
        MsgC( softWhite, "Garbage profiler is already running.\n" )
        return
    end

    if HOOK_PERF_RUNNING or SENT_PERF_RUNNING then
        MsgC( softWhite, "Another profiler is running, stop it first.\n" )
        return
    end

    local time = tonumber( args[1] ) or 10

    GC_PERF_RUNNING = true
    GC_PERF_HOOKS = GC_PERF_HOOKS or {}
    GC_PERF_GM = GC_PERF_GM or {}
    GC_PERF_ENT_METHODS = GC_PERF_ENT_METHODS or {}
    GC_PERF_ENT_TABLES = GC_PERF_ENT_TABLES or {}

    local lagTbl = {}

    local internalHooks = GetInternalHooks()

    for hookName, hookTable in pairs( hook.GetTable() ) do
        for hookEvent, hookFunc in pairs( hookTable ) do
            local priority

            if internalHooks and internalHooks[hookName] and internalHooks[hookName][hookEvent] then
                priority = internalHooks[hookName][hookEvent].priority
            end

            GC_PERF_HOOKS[hookName] = GC_PERF_HOOKS[hookName] or {}
            GC_PERF_HOOKS[hookName][hookEvent] = { func = hookFunc, priority = priority }

            local originalFunc = hookFunc
            local originInfo = debug.getinfo( originalFunc, "S" )
            local hookFuncOrigin = originInfo.short_src
            local hookFuncLastDefined = originInfo.lastlinedefined

            local function wrapper( ... )
                local memBefore = collectgarbage( "count" )
                local a, b, c, d, e, f = originalFunc( ... )
                local memAfter = collectgarbage( "count" )

                local delta = memAfter - memBefore
                if delta > 0 then
                    local info = lagTbl[hookEvent]
                    if not info then
                        info = { count = 0, mem = 0, hook = hookName, origin = hookFuncOrigin, lastDefined = hookFuncLastDefined, isGM = false }
                        lagTbl[hookEvent] = info
                    end
                    info.count = info.count + 1
                    info.mem = info.mem + delta
                end

                return a, b, c, d, e, f
            end

            hook.Add( hookName, hookEvent, wrapper, priority )
        end
    end

    local GM = GAMEMODE or GM
    for methodName, func in pairs( GM ) do
        if isfunction( func ) then
            GC_PERF_GM[methodName] = GC_PERF_GM[methodName] or func
            local original = GC_PERF_GM[methodName]
            local originInfo = debug.getinfo( original, "S" )

            local function detour( ... )
                local memBefore = collectgarbage( "count" )
                local a, b, c, d, e, f = original( ... )
                local memAfter = collectgarbage( "count" )

                local delta = memAfter - memBefore
                if delta > 0 then
                    local info = lagTbl[methodName]
                    if not info then
                        info = { count = 0, mem = 0, hook = methodName, origin = originInfo.short_src, lastDefined = originInfo.lastlinedefined, isGM = true }
                        lagTbl[methodName] = info
                    end
                    info.count = info.count + 1
                    info.mem = info.mem + delta
                end

                return a, b, c, d, e, f
            end

            GM[methodName] = detour
        end
    end

    local function wrapFunction( tbl, varName, original, className )
        local originInfo = debug.getinfo( original, "S" )
        local entOrigin = originInfo.short_src
        local linedefined = originInfo.linedefined
        local perfID = entOrigin .. ":" .. tostring( linedefined )

        local function wrapper( ... )
            local memBefore = collectgarbage( "count" )
            local a, b, c, d, e, f = original( ... )
            local memAfter = collectgarbage( "count" )

            local delta = memAfter - memBefore
            if delta > 0 then
                local info = lagTbl[perfID]
                if not info then
                    info = { count = 0, mem = 0, class = className, varName = varName, origin = entOrigin, linedefined = linedefined, isSent = true }
                    lagTbl[perfID] = info
                end
                info.count = info.count + 1
                info.mem = info.mem + delta
            end

            return a, b, c, d, e, f
        end

        tbl[varName] = wrapper
    end

    for _, ent in ipairs( ents.GetAll() ) do
        if not ent:IsScripted() then continue end

        GC_PERF_ENT_METHODS[ent] = GC_PERF_ENT_METHODS[ent] or {}
        local entTable = ent:GetTable()
        for varName, var in pairs( entTable ) do
            if not isfunction( var ) then continue end
            GC_PERF_ENT_METHODS[ent][varName] = var
            wrapFunction( entTable, varName, var, ent:GetClass() )
        end
    end

    for className, entry in pairs( scripted_ents.GetList() ) do
        local entTable = entry.t
        if not entTable then continue end

        GC_PERF_ENT_TABLES[entTable] = GC_PERF_ENT_TABLES[entTable] or {}
        for varName, var in pairs( entTable ) do
            if not isfunction( var ) then continue end
            GC_PERF_ENT_TABLES[entTable][varName] = var
            wrapFunction( entTable, varName, var, className )
        end
    end

    timer.Simple( time, function()
        -- restore
        local allHooks = hook.GetTable()
        for hookName, hookTable in pairs( allHooks ) do
            for hookEvent in pairs( hookTable ) do
                local orig = GC_PERF_HOOKS[hookName] and GC_PERF_HOOKS[hookName][hookEvent]
                if not orig then continue end

                hook.Remove( hookName, hookEvent )
                hook.Add( hookName, hookEvent, orig.func, orig.priority )
            end
        end

        for methodName, func in pairs( GC_PERF_GM ) do
            if not GM[methodName] then
                continue
            end

            GM[methodName] = func
        end

        GC_PERF_HOOKS = nil

        for ent, methods in pairs( GC_PERF_ENT_METHODS ) do
            if not IsValid( ent ) then continue end
            for methodName, originalFunc in pairs( methods ) do
                if isfunction( originalFunc ) then
                    ent[methodName] = originalFunc
                end
            end
        end

        for entTable, methods in pairs( GC_PERF_ENT_TABLES ) do
            for methodName, originalFunc in pairs( methods ) do
                if isfunction( originalFunc ) then
                    entTable[methodName] = originalFunc
                end
            end
        end

        GC_PERF_ENT_METHODS = nil
        GC_PERF_ENT_TABLES = nil
        GC_PERF_RUNNING = nil

        if CLIENT then
            chat.AddText( "Garbage profiler finished." )
        end

        -- sort
        local sortedHooks, sortedSents = {}, {}
        for k, v in pairs( lagTbl ) do
            if v.isSent then
                table.insert( sortedSents, v )
            else
                table.insert( sortedHooks, { k, v } )
            end
        end

        table.sort( sortedHooks, function( a, b )
            return a[2].mem > b[2].mem
        end )

        table.sort( sortedSents, function( a, b )
            return a.mem > b.mem
        end )

        MsgC( softWhite, "Garbage generating hooks:\n" )
        printer( "Name", "Hook", "Mem (KB)", "Count", "Origin", "Line defined" )
        for i = 1, 100 do
            local v = sortedHooks[i]
            if not v then break end

            printer( ( v[2].isGM and "GM:" or "" ) .. tostring( v[1] ), v[2].hook, math.Round( v[2].mem, 3 ), v[2].count, v[2].origin, v[2].lastDefined )
        end

        -- Add garbage up per hookname
        MsgC( softWhite, "\nGarbage summed by hook name:\n" )
        printer( "Name", "Hook", "Mem (KB)", "Count", "Origin", "Line defined" )
        local summed = {}
        for _, v in pairs( lagTbl ) do
            if v.isSent then continue end

            local info = summed[v.hook]
            if not info then
                info = { count = 0, mem = 0, hook = v.hook, origin = v.origin, lastDefined = v.lastDefined }
                summed[v.hook] = info
            end
            info.count = info.count + v.count
            info.mem = info.mem + v.mem
        end

        local sortedSummed = {}
        for k, v in pairs( summed ) do
            table.insert( sortedSummed, { k, v } )
        end
        table.sort( sortedSummed, function( a, b )
            return a[2].mem > b[2].mem
        end )

        -- only print top 100
        for i = 1, 100 do
            local v = sortedSummed[i]
            if not v then break end

            MsgC( hookC, tostring( v[1] ), darkGray, " - ", memC, math.Round( v[2].mem, 3 ) .. " KB", darkGray, " - ", countC, v[2].count .. " calls", "\n" )
        end

        MsgC( softWhite, "\nGarbage generating sent methods:\n" )
        MsgC( colHeader, "Class", tab, "Method", tab, "Mem (KB)", tab, "Count", tab, "Origin", "\n" )
        for i = 1, 100 do
            local sort = sortedSents[i]
            if sort then
                MsgC(
                    colCyan,   sort.class,
                    colGray,   tab,
                    colWhite,  sort.varName,
                    colGray,   tab,
                    colGreen,  tostring( math.Round( sort.mem, 3 ) ),
                    colGray,   tab,
                    colYellow, tostring( sort.count ),
                    colGray,   tab .. sort.origin .. ":" .. sort.linedefined,
                    colWhite,  "\n"
                )
            end
        end

        local totalCount, totalMem = 0, 0
        for _, v in pairs( lagTbl ) do
            if not v.isSent then continue end
            totalCount = totalCount + v.count
            totalMem = totalMem + v.mem
        end

        MsgC( colHeader, "Total", colGray, tab, colGreen, tostring( math.Round( totalMem, 3 ) ), colGray, tab, colYellow, tostring( totalCount ), colWhite, "\n" )

        MsgC( darkGray, "Note: only calls with a positive net KB diff of collectgarbage(\"count\") are counted, zero and negative calls (GC collected) are ignored.\n" )
    end )
end )
