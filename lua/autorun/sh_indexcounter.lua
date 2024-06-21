local meta = FindMetaTable( "Entity" )

ENT_INDEX = ENT_INDEX or meta.__index

local cmd = SERVER and "red_sv_indexcounter" or "red_cl_indexcounter"
concommand.Add( cmd, function( ply )
    if SERVER and IsValid( ply ) then return end

    local origins = {}

    function meta.__index( tbl, key )

        local info = debug.getinfo( 2 )
        local name = info.short_src .. ":" .. info.linedefined
        origins[name] = origins[name] and origins[name] + 1 or 1

        return ENT_INDEX( tbl, key )
    end

    timer.Simple( 10, function()
        meta.__index = ENT_INDEX

        local indexed = {}
        for origin, count in pairs( origins ) do
            table.insert( indexed, { origin = origin, count = count } )
        end

        table.sort( indexed, function( a, b ) return a.count > b.count end )

        for _, data in ipairs( indexed ) do
            print( data.count, data.origin )
        end

        if CLIENT then
            chat.AddText( Color( 255, 0, 0 ), "Entity index profiling complete. See console for results." )
        end
        print( "Entity index profiling complete. See console for results." )
    end )
end )
