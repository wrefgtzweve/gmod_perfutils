concommand.Add( SERVER and "red_sv_netdump" or "red_cl_netdump", function( ply )
    if IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint("No permission.")
    end

    local folder = SERVER and "netdump_sv" or "netdump_cl"

    if file.Exists( folder, "DATA" ) then
        for _, fil in ipairs( file.Find( "netdump/*", "DATA" ) ) do
            file.Delete( folder .. "/" .. fil )
        end
        file.Delete( folder )
    end
    file.CreateDir( folder )

    for name, func in pairs( net.Receivers ) do
        local info = debug.getinfo( func, "S" )
        local source = info.short_src
        local lineDefined = info.linedefined - 5
        local lineEnd = info.lastlinedefined + 5

        local found = false
        local path = "GAME"

        if file.Exists( source, "GAME" ) then
            found = true
            path = "GAME"
        elseif file.Exists( source, "LUA" ) then
            found = true
            path = "LUA"
        else
            print( "[NETDUMP] Unknown source:", name, " - ", source )
        end

        if found then
            file.AsyncRead( source, path, function( _, _, status, data )
                if status ~= FSASYNC_OK then
                    print( "[NETDUMP] Failed to read file:", name, " - ", source )
                    return
                end

                local lines = string.Explode( "\n", data )
                local dump = "--" .. name .. " " .. source .. ":" .. lineDefined .. "-" .. lineEnd .. "\n"

                for lineNum, line in ipairs( lines ) do
                    if lineNum < lineDefined then continue end
                    if lineNum > lineEnd then break end
                    dump = dump .. line .. "\n"
                end

                file.Write( folder .. "/" .. name .. ".txt", dump )
                print( "[NETDUMP] Dumped:", name, " - ", source )
            end )
        end
    end
end )
