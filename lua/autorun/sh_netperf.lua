local perfTable = {}
local bitTable = {}
local totalStartTime = 0
local running = false

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

        bitTable[strName] = ( bitTable[strName] or 0 ) + len
        local start = SysTime()

        net_Incoming( len, client )

        local endtime = SysTime()
        perfTable[strName] = ( perfTable[strName] or 0 ) + ( endtime - start )

        net.ReadHeader = net_ReadHeader
    end
end

concommand.Add( SERVER and "red_sv_netperf_start" or "red_cl_netperf_start", function( ply )
    if SERVER and IsValid( ply ) then return end

    print( "Netperf started" )
    running = true
    totalStartTime = SysTime()
    applyWrap()
end )

concommand.Add( SERVER and "red_sv_netperf_stop" or "red_cl_netperf_stop", function( ply )
    if SERVER and IsValid( ply ) then return end

    if not running then
        print( "Netperf isn't running." )
        return
    end

    running = false
    print( "Netperf results:\n" )
    print( "Sorted by time:\n" )

    local perfstr = ""
    for k, v in SortedPairsByValue( perfTable, true ) do
        perfstr = perfstr .. k .. " - " .. v .. "s - " .. bitTable[k] .. " bits\n"
    end

    print( perfstr )
    print( "Sorted by bits:\n" )

    local bitstr = ""
    for k, v in SortedPairsByValue( bitTable, true ) do
        bitstr = bitstr .. k .. " - " .. v .. " bits - " .. perfTable[k] .. "s\n"
    end

    print( bitstr )
    print( "Time ran: " .. ( SysTime() - totalStartTime ) .. "s" )

    net.Incoming = netperf_net_Incoming
end )
