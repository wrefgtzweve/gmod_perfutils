local entMeta = FindMetaTable( "Entity" )
local plyMeta = FindMetaTable( "Player" )
local wepMeta = FindMetaTable( "Weapon" )

ENT_INDEX = ENT_INDEX or entMeta.__index
PLAYER_INDEX = PLAYER_INDEX or plyMeta.__index
WEAPON_INDEX = WEAPON_INDEX or wepMeta.__index

local toWrap = {
    [entMeta] = ENT_INDEX,
    [plyMeta] = PLAYER_INDEX,
    [wepMeta] = WEAPON_INDEX
}

local cmd = SERVER and "red_sv_indexcounter" or "red_cl_indexcounter"
concommand.Add( cmd, function( ply, _, args )
    if SERVER and IsValid( ply ) then return end
    local time = tonumber( args[1] ) or 10

    local origins = {}

    for meta, original in pairs( toWrap ) do
        meta.__index = function( tbl, key )
            local info = debug.getinfo( 2 )
            local name = info.short_src .. ":" .. info.linedefined
            origins[name] = origins[name] and origins[name] + 1 or 1

            return original( tbl, key )
        end
    end

    timer.Simple( time, function()
        entMeta.__index = ENT_INDEX
        plyMeta.__index = PLAYER_INDEX
        wepMeta.__index = WEAPON_INDEX

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
            chat.AddText( Color( 255, 0, 0 ), "Entity index profiling complete. See console for results." )
        end
        print( "Entity index profiling complete. See console for results." )
    end )
end )
