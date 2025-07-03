local debug_getinfo = debug.getinfo

local toWrap = {
    "Vector",
    "Angle",
    "Color",
}

local cmd = SERVER and "red_sv_garbage" or "red_cl_garbage"
concommand.Add( cmd, function( ply, _, args )
    if SERVER and IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint( "No permission." )
    end

    local time = tonumber( args[1] ) or 10
    local origins = {}

    for _, globName in ipairs( toWrap ) do
        local originalFunc = _G["__" .. globName .. "_og"] or _G[globName]
        _G["__" .. globName .. "_og"] = originalFunc

        local function detour( ... )
            local info = debug_getinfo( 2 )
            local name = info.short_src .. ":" .. info.linedefined
            origins[name] = origins[name] and origins[name] + 1 or 1

            return originalFunc( ... )
        end

        _G[globName] = detour
    end

    local startTime = SysTime()
    timer.Simple( time, function()
        print( "Garbage creation profiling complete. Time taken: " .. ( SysTime() - startTime ) .. " seconds." )

        for _, globName in ipairs( toWrap ) do
            _G[globName] = _G["__" .. globName .. "_og"]
            _G["__" .. globName .. "_og"] = nil
        end

        local indexed = {}
        for origin, count in pairs( origins ) do
            table.insert( indexed, { origin = origin, count = count } )
        end

        table.sort( indexed, function( a, b ) return a.count > b.count end )

        local max = 100
        local max_count = indexed[1].count

        for _, data in ipairs( indexed ) do
            max = max - 1
            if max < 0 then break end

            MsgC( Color( 255, 255 - ( data.count / max_count * 255 ), 0 ), data.count, color_white, " | ", data.origin, "\n" )
        end

        if CLIENT then
            chat.AddText( Color( 255, 0, 0 ), "Garbage creation profiling complete. See console for results." )
        end
        print( "Garbage creation profiling complete. See console for results." )
    end )
end )
