local blue = Color( 58, 150, 221 )
local darkGray = Color( 100, 100, 100 )
local softWhite = Color( 205, 205, 205 )
local lineNumGreen = Color( 19, 161, 14 )
local softRed = Color( 231, 72, 86 )
local pink = Color( 235, 52, 137 )

local hookRanNum = 0

local function wrapHooks( hookTable, hookName, hookCount )
    hookRanNum = 0
    for hookID, originalFunc in pairs( hookTable ) do
        local originInfo = debug.getinfo( originalFunc, "S" )
        local hookFuncOrigin = originInfo.short_src
        local hookFuncLastDefined = originInfo.lastlinedefined

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

            hook.Add( hookName, hookID, originalFunc )
            return a, b, c, d, e, f
        end
        hook.Add( hookName, hookID, wrappedHook )
    end
end

concommand.Add( SERVER and "red_sv_hookorder" or "red_cl_hookorder", function( ply, _, _, str )
    if IsValid( ply ) and not ply:IsSuperAdmin() then
        return MsgC( pink, "No permission.\n" )
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
