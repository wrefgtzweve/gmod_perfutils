local blue = Color( 58, 150, 221 )
local darkGray = Color( 100, 100, 100 )
local softWhite = Color( 205, 205, 205 )
local lineNumGreen = Color( 19, 161, 14 )
local softRed = Color( 231, 72, 86 )
local pink = Color( 235, 52, 137 )

local hookRanNum = 0

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

local function GetHookPriority( internalHooks, hookName, hookID )
    if not internalHooks then return end

    local event = internalHooks[hookName]
    if not event then return end

    local hookInfo = event[hookID]
    if not hookInfo then return end

    return hookInfo.priority
end

local function wrapHooks( hookTable, hookName, hookCount )
    hookRanNum = 0
    local internalHooks = GetInternalHooks()

    for hookID, originalFunc in pairs( hookTable ) do
        local originInfo = debug.getinfo( originalFunc, "S" )
        local hookFuncOrigin = originInfo.short_src
        local hookFuncLastDefined = originInfo.lastlinedefined
        local priority = GetHookPriority( internalHooks, hookName, hookID )

        local wrappedHook = function( ... )
            hookRanNum = hookRanNum + 1

            if hookRanNum == 1 then
                print( ... )
            end

            local startTime = SysTime()
            local a, b, c, d, e, f = originalFunc( ... )
            local timeTook = SysTime() - startTime
            local fancyTime = math.Round( timeTook * 1000, 6 )

            MsgC( lineNumGreen, hookRanNum, darkGray, ": ", blue, hookID, softWhite, " ", softRed, fancyTime, "ms ", softWhite, hookFuncOrigin, ":", hookFuncLastDefined, "\n" )

            if a ~= nil then
                MsgC( pink, "Hook returned a value, printing it to console.\n" )
                for k, v in pairs( { a, b, c, d, e, f } ) do
                    if v == "" then v = "!Empty string!" end
                    print( k, v )
                end
            end

            if hookCount == hookRanNum then
                MsgC( pink, "Done!\n" )
            end

            hook.Add( hookName, hookID, originalFunc, priority )
            return a, b, c, d, e, f
        end
        hook.Add( hookName, hookID, wrappedHook, priority )
    end
end

concommand.Add( SERVER and "red_sv_hookorder" or "red_cl_hookorder", function( ply, _, _, str )
    if IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint( "No permission." )
    end

    local hookTable = hook.GetTable()
    local hooks = hookTable[str]

    if not hooks then
        return MsgC( pink, "No hooks with given hook name.\n" )
    end

    local hookCount = table.Count( hooks )

    MsgC( pink, "Wrapping " .. hookCount .. " hooks...\n" )
    wrapHooks( hooks, str, hookCount )
    MsgC( pink, "Waiting for hook: ", blue, str, pink, " to run...\n" )
end )
