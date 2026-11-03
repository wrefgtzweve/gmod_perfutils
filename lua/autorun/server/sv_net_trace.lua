local window = 3 -- Seconds of messages to track
local maxPrint = 200 -- Max amount of messages to print
local kickWords = { "reliable", "overflow", "channel" }
local tracking = false
local trackers = {}
local currentName

net._Start = net._Start or net.Start
net._Send = net._Send or net.Send
net._Broadcast = net._Broadcast or net.Broadcast

if nettrace_installed then
    nettrace_installed = false
    net.Start = net._Start
    net.Send = net._Send
    net.Broadcast = net._Broadcast
end

-- Fifo for tracking net messages per player within a time window
local function push( ply, name, size )
    if not IsValid( ply ) then return end

    local userid = ply:UserID()
    local tracker = trackers[userid]
    if not tracker then
        tracker = { first = 1, last = 0, entries = {} }
        trackers[userid] = tracker
    end

    local now = CurTime()
    local last = tracker.last + 1
    tracker.last = last
    tracker.entries[last] = { name = name, size = size, time = now }

    while tracker.first <= last and now - tracker.entries[tracker.first].time > window do
        tracker.entries[tracker.first] = nil
        tracker.first = tracker.first + 1
    end
end

local function pushTargets( target, name, size )
    if IsValid( target ) then
        push( target, name, size )
    elseif istable( target ) then
        for _, ply in ipairs( target ) do
            push( ply, name, size )
        end
    elseif target and target.GetPlayers then
        for _, ply in ipairs( target:GetPlayers() ) do
            push( ply, name, size )
        end
    end
end

local function applyWrap()
    function net.Start( name, ... )
        currentName = name
        return net._Start( name, ... )
    end

    function net.Send( target, ... )
        local size = net.BytesWritten() or 0
        local name = currentName
        local a, b, c = net._Send( target, ... )
        pushTargets( target, name, size )
        currentName = nil
        return a, b, c
    end

    function net.Broadcast( ... )
        local size = net.BytesWritten() or 0
        local name = currentName
        net._Broadcast( ... )
        for _, ply in ipairs( player.GetAll() ) do
            push( ply, name, size )
        end
        currentName = nil
    end

    nettrace_installed = true
end

local function unwrap()
    net.Start = net._Start
    net.Send = net._Send
    net.Broadcast = net._Broadcast
    nettrace_installed = false
    tracking = false
    trackers = {}
    currentName = nil
end

gameevent.Listen( "player_disconnect" )
hook.Add( "player_disconnect", "red_nettrace_disconnect", function( data )
    if not tracking then return end

    local tracker = trackers[data.userid]
    trackers[data.userid] = nil
    if not tracker then return end

    local reason = data.reason or ""
    local lower = string.lower( reason )
    local matched = false
    for _, word in ipairs( kickWords ) do
        if string.find( lower, word, 1, true ) then
            matched = true
            break
        end
    end
    if not matched then return end

    local now = CurTime()
    print( string.format( "[NETTRACE] %s (%s) disconnected (%s), net messages sent to them in the last %ds (newest first):", data.name, data.networkid, reason, window ) )

    local total = 0
    local shown = 0
    if tracker then
        for i = tracker.last, tracker.first, -1 do
            local entry = tracker.entries[i]
            local age = now - entry.time
            if age > window then break end

            total = total + 1
            if shown < maxPrint then
                shown = shown + 1
                print( string.format( "    %6.2fs ago  %-40s %8d bytes", age, entry.name or "?", entry.size ) )
            end
        end
    end

    if total == 0 then
        print( "    (none)" )
    elseif shown < total then
        print( string.format( "    ... and %d more", total - shown ) )
    end
end )

concommand.Add( "red_sv_nettrace_start", function( ply )
    if IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint( "No permission." )
    end

    if tracking then
        print( "Nettrace is already running." )
        return
    end

    trackers = {}
    applyWrap()
    tracking = true
    print( "Nettrace started, players kicked for overflowing the reliable channel will print the net messages they were sent in the last " .. window .. "s." )
end )

concommand.Add( "red_sv_nettrace_stop", function( ply )
    if IsValid( ply ) and not ply:IsSuperAdmin() then
        return ply:ChatPrint( "No permission." )
    end

    if not tracking then
        print( "Nettrace isn't running." )
        return
    end

    unwrap()
    print( "Nettrace stopped." )
end )
