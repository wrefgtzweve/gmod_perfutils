local perfTable = {}
local bitTable = {}
local countTable = {}
local umsgTable = {}
local umsgCountTable = {}
local dtvarTable = {}
local dtvarCountTable = {}
local dtvarBitTable = {}
local totalStartTime = 0
local running = false

local function estimateNetVarBits( value )
    local valueType = type( value )
    if valueType == "boolean" then return 1 end
    if valueType == "number" then return 32 end
    if valueType == "string" then return #value * 8 end
    if isvector( value ) or isangle( value ) then return 96 end
    if valueType == "userdata" then return 32 end
    return 0
end

local function applyWrap()
    netperf_net_Incoming = netperf_net_Incoming or net.Incoming
    local net_Incoming = netperf_net_Incoming

    netperf_usermessage_IncomingMessage = netperf_usermessage_IncomingMessage or usermessage.IncomingMessage
    local um_IncomingMessage = netperf_usermessage_IncomingMessage

    usermessage.IncomingMessage = function( name, msg )
        if not running then return um_IncomingMessage( name, msg ) end
        local start = SysTime()
        um_IncomingMessage( name, msg )
        local elapsed = SysTime() - start
        umsgTable[name] = ( umsgTable[name] or 0 ) + elapsed
        umsgCountTable[name] = ( umsgCountTable[name] or 0 ) + 1
    end

    if DTVar_ReceiveProxyGL then
        netperf_DTVar_ReceiveProxyGL = netperf_DTVar_ReceiveProxyGL or DTVar_ReceiveProxyGL
        local dtvar_ReceiveProxyGL = netperf_DTVar_ReceiveProxyGL

        function DTVar_ReceiveProxyGL( ent, varType, index, newValue )
            if not running then return dtvar_ReceiveProxyGL( ent, varType, index, newValue ) end
            local start = SysTime()
            dtvar_ReceiveProxyGL( ent, varType, index, newValue )
            local elapsed = SysTime() - start
            local class = IsValid( ent ) and ent ~= NULL and ent:GetClass() or "NULL"
            local key = class .. " " .. tostring( varType ) .. "[" .. tostring( index ) .. "]"
            dtvarTable[key] = ( dtvarTable[key] or 0 ) + elapsed
            dtvarCountTable[key] = ( dtvarCountTable[key] or 0 ) + 1
            dtvarBitTable[key] = ( dtvarBitTable[key] or 0 ) + estimateNetVarBits( newValue )
        end
    end

    function net.Incoming( len, client )
        local headerNum = net.ReadHeader()
        local strName = util.NetworkIDToString( headerNum )

        net_ReadHeader = net_ReadHeader or net.ReadHeader
        net.ReadHeader = function()
            return headerNum
        end

        bitTable[strName] = ( bitTable[strName] or 0 ) + len
        countTable[strName] = ( countTable[strName] or 0 ) + 1
        local start = SysTime()

        net_Incoming( len, client )

        local endtime = SysTime()
        perfTable[strName] = ( perfTable[strName] or 0 ) + ( endtime - start )

        net.ReadHeader = net_ReadHeader
    end
end

local nw2Table = {}
local nw2BitTable = {}
hook.Add( "EntityNetworkedVarChanged", "NetPerf", function( _ent, name, _oldval, newval )
    if not running then return end

    nw2Table[name] = ( nw2Table[name] or 0 ) + 1
    nw2BitTable[name] = ( nw2BitTable[name] or 0 ) + estimateNetVarBits( newval )
end )

concommand.Add( SERVER and "red_sv_netperf_start" or "red_cl_netperf_start", function( ply )
    if SERVER and IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint( "No permission." )
    end

    totalStartTime = SysTime()
    table.Empty( perfTable )
    table.Empty( bitTable )
    table.Empty( countTable )
    table.Empty( umsgTable )
    table.Empty( umsgCountTable )
    table.Empty( dtvarTable )
    table.Empty( dtvarCountTable )
    table.Empty( dtvarBitTable )
    table.Empty( nw2Table )
    table.Empty( nw2BitTable )

    applyWrap()
    running = true
    print( "Netperf started" )
end )

concommand.Add( SERVER and "red_sv_netperf_stop" or "red_cl_netperf_stop", function( ply )
    if SERVER and IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint( "No permission." )
    end

    if not running then
        print( "Netperf isn't running." )
        return
    end

    running = false

    local colWhite   = Color( 255, 255, 255 )
    local colCyan    = Color( 100, 220, 255 )
    local colYellow  = Color( 255, 220, 80  )
    local colGreen   = Color( 100, 220, 120 )
    local colHeader  = Color( 220, 180, 255 )

    local function printTable( headers, rows, rowColors, rightAlign )
        local widths = {}
        for i = 1, #headers do widths[i] = #headers[i] end
        for _, row in ipairs( rows ) do
            for i = 1, #headers do
                widths[i] = math.max( widths[i], #row[i] )
            end
        end

        local function emit( cells, colors )
            for i = 1, #cells do
                local text = cells[i]
                if i < #cells then
                    local pad = string.rep( " ", math.max( widths[i] - #text, 0 ) )
                    text = rightAlign[i] and ( pad .. text ) or ( text .. pad )
                    text = text .. "  "
                end
                MsgC( colors[i], text )
            end
            MsgC( colWhite, "\n" )
        end

        local headerColors = {}
        for i = 1, #headers do headerColors[i] = colHeader end

        emit( headers, headerColors )
        for _, row in ipairs( rows ) do
            emit( row, rowColors )
        end
    end

    MsgC( colYellow, "Netperf ran for " .. math.Round( SysTime() - totalStartTime, 2 ) .. " seconds.\n" )

    if next( perfTable ) then
        MsgC( colHeader, "Netmessages sorted by time:\n" )
        local rows = {}
        for k, v in SortedPairsByValue( perfTable, true ) do
            rows[#rows + 1] = { k, tostring( math.Round( v, 6 ) ), tostring( bitTable[k] ), tostring( countTable[k] or 0 ) }
        end
        printTable( { "Name", "Time (s)", "Bits", "Count" }, rows,
            { colCyan, colGreen, colYellow, colWhite }, { false, true, true, true } )

        MsgC( colHeader, "\nNetmessages sorted by bits:\n" )
        rows = {}
        for k, v in SortedPairsByValue( bitTable, true ) do
            rows[#rows + 1] = { k, tostring( v ), tostring( math.Round( perfTable[k], 6 ) ), tostring( countTable[k] or 0 ) }
        end
        printTable( { "Name", "Bits", "Time (s)", "Count" }, rows,
            { colCyan, colYellow, colGreen, colWhite }, { false, true, true, true } )

        local totalCount, totalTime = 0, 0
        for name, time in pairs( perfTable ) do
            totalCount = totalCount + ( countTable[name] or 0 )
            totalTime = totalTime + time
        end

        local totalBitCount = 0
        for _, bits in pairs( bitTable ) do
            totalBitCount = totalBitCount + bits
        end

        MsgC( colHeader, "\nTotal netmessages: ", colWhite, tostring( totalCount ), colHeader, ", total time: ", colGreen, tostring( math.Round( totalTime, 6 ) ) .. "s", colHeader, ", total bits: ", colYellow, tostring( totalBitCount ), colWhite, "\n\n" )
    end

    if next( nw2Table ) then
        MsgC( colHeader, "NW2 sorted by count:\n" )
        local rows = {}
        for k, v in SortedPairsByValue( nw2Table, true ) do
            rows[#rows + 1] = { k, tostring( v ), "~" .. tostring( nw2BitTable[k] or 0 ) }
        end
        printTable( { "Name", "Count", "~ Bits" }, rows,
            { colCyan, colWhite, colYellow }, { false, true, true } )

        local totalNw2Count, totalNw2Bits = 0, 0
        for name, count in pairs( nw2Table ) do
            totalNw2Count = totalNw2Count + count
            totalNw2Bits = totalNw2Bits + ( nw2BitTable[name] or 0 )
        end

        MsgC( colHeader, "\nTotal NW2 changes: ", colWhite, tostring( totalNw2Count ), colHeader, ", total ~bits: ", colYellow, "~" .. tostring( totalNw2Bits ), colWhite, "\n\n" )
    end

    if next( dtvarTable ) then
        MsgC( colHeader, "DTVars sorted by count:\n" )
        local rows = {}
        for k, v in SortedPairsByValue( dtvarCountTable, true ) do
            rows[#rows + 1] = { k, tostring( v ), "~" .. tostring( dtvarBitTable[k] or 0 ), tostring( math.Round( dtvarTable[k] or 0, 6 ) ) }
        end
        printTable( { "Class / Type / Index", "Count", "~ Bits", "Time (s)" }, rows,
            { colCyan, colWhite, colYellow, colGreen }, { false, true, true, true } )

        local totalDtvarCount, totalDtvarTime, totalDtvarBits = 0, 0, 0
        for name, time in pairs( dtvarTable ) do
            totalDtvarCount = totalDtvarCount + ( dtvarCountTable[name] or 0 )
            totalDtvarTime = totalDtvarTime + time
            totalDtvarBits = totalDtvarBits + ( dtvarBitTable[name] or 0 )
        end

        MsgC( colHeader, "\nTotal DTVars: ", colWhite, tostring( totalDtvarCount ), colHeader, ", total time: ", colGreen, tostring( math.Round( totalDtvarTime, 6 ) ) .. "s", colHeader, ", total ~bits: ", colYellow, "~" .. tostring( totalDtvarBits ), colWhite, "\n\n" )
    end

    if next( umsgTable ) then
        MsgC( colHeader, "Usermessages sorted by time:\n" )
        local rows = {}
        for k, v in SortedPairsByValue( umsgTable, true ) do
            rows[#rows + 1] = { k, tostring( math.Round( v, 6 ) ), tostring( umsgCountTable[k] or 0 ) }
        end
        printTable( { "Name", "Time (s)", "Count" }, rows,
            { colCyan, colGreen, colWhite }, { false, true, true } )

        local totalUmsgCount, totalUmsgTime = 0, 0
        for name, time in pairs( umsgTable ) do
            totalUmsgCount = totalUmsgCount + ( umsgCountTable[name] or 0 )
            totalUmsgTime = totalUmsgTime + time
        end

        MsgC( colHeader, "\nTotal usermessages: ", colWhite, tostring( totalUmsgCount ), colHeader, ", total time: ", colGreen, tostring( math.Round( totalUmsgTime, 6 ) ) .. "s", colWhite, "\n" )
    end

    net.Incoming = netperf_net_Incoming
    net.ReadHeader = net_ReadHeader
    usermessage.IncomingMessage = netperf_usermessage_IncomingMessage
    if netperf_DTVar_ReceiveProxyGL then
        DTVar_ReceiveProxyGL = netperf_DTVar_ReceiveProxyGL
    end
end )
