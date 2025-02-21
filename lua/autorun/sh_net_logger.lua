local running = false

local netReaders = {
    "ReadAngle",
    "ReadBit",
    "ReadBool",
    "ReadColor",
    "ReadData",
    "ReadDouble",
    "ReadEntity",
    "ReadFloat",
    "ReadInt",
    "ReadMatrix",
    "ReadNormal",
    "ReadPlayer",
    "ReadString",
    "ReadType",
    "ReadUInt",
    "ReadUInt64",
    "ReadVector"
}

local ignoreNets = { wire_overlay_data = true }
net._ReadTable = net._ReadTable or net.ReadTable

local white = Color( 255, 255, 255 )
local startColor = Color( 0, 255, 0 )
local endColor = Color( 255, 0, 0 )
local blueColor = Color( 166, 190, 255 )
local realmColor = CLIENT and Color( 255, 200, 0 ) or Color( 0, 200, 255 )

local function wrapNetRead()
    function net.ReadTable()
        print( "NET: START net.ReadTable" )
        local tbl = net._ReadTable()
        print( "NET: END net.ReadTable" )
        return tbl
    end

    for _, reader in ipairs( netReaders ) do
        local oldFunc = net[reader]
        net["_" .. reader] = net["_" .. reader] or oldFunc
        net[reader] = function( ... )
            local args = { ... }
            local res = oldFunc( ... )
            if #args ~= 0 then
                local argStr = ""
                for i, arg in ipairs( args ) do
                    argStr = argStr .. tostring( arg )
                    if i ~= #args then
                        argStr = argStr .. ", "
                    end
                end

                MsgC( "    net." .. reader, "(", argStr, ")", white, ": ", blueColor, tostring( res ), "\n" )
            else
                MsgC( "    net." .. reader, white, ": ", blueColor, tostring( res ), "\n" )
            end
            return res
        end
    end
end

local function unwrapNetRead()
    for _, reader in ipairs( netReaders ) do
        net[reader] = net["_" .. reader]
        net["_" .. reader] = nil
    end

    net.ReadTable = net._ReadTable
end

local function applyWrap()
    netperf_net_Incoming = netperf_net_Incoming or net.Incoming
    local net_Incoming = netperf_net_Incoming

    function net.Incoming( len, client )
        local headerNum = net.ReadHeader()
        local strName = util.NetworkIDToString( headerNum )

        net_ReadHeader = net.ReadHeader
        net.ReadHeader = function()
            return headerNum
        end

        if not ignoreNets[strName] then
            MsgC( startColor, "NET START: ", realmColor, strName, blueColor, " (" .. len .. " bytes)", "\n" )
            wrapNetRead()
        end

        local sysTime = SysTime()
        ProtectedCall( net_Incoming, len, client )
        local took = SysTime() - sysTime

        if not ignoreNets[strName] then
            MsgC( endColor, "NET END: ", realmColor, strName, blueColor, " (" .. string.format( "%.4f", took * 1000 ) .. "ms)", "\n\n" )
            unwrapNetRead()
        end

        net.ReadHeader = net_ReadHeader
    end
end

concommand.Add( SERVER and "red_sv_netlogger_start" or "red_cl_netlogger_start", function( ply )
    if SERVER and IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint("No permission.")
    end

    applyWrap()
    running = true
    print( "Netlogger started" )
end )

concommand.Add( SERVER and "red_sv_netlogger_stop" or "red_cl_netlogger_stop", function( ply )
    if SERVER and IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint("No permission.")
    end

    if not running then
        print( "Netlogger isn't running." )
        return
    end

    running = false
    net.Incoming = netperf_net_Incoming
end )

concommand.Add( SERVER and "red_sv_netlogger_ignore" or "red_cl_netlogger_ignore", function( ply, _, args )
    if SERVER and IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint("No permission.")
    end

    if not running then
        print( "Netlogger isn't running." )
        return
    end

    local name = args[1]
    if not name then
        print( "No name specified." )
        return
    end

    ignoreNets[name] = true
    print( "Ignoring net message: " .. name )
end )