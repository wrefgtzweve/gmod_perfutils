# :computer: gmod_perfutils
Various scripts I've made over the years to find performance bottle necks in garrysmod.

## Installation
Either clone/download the repository and put it in your `addons/` folder or run the individual files, the files are designed to be able to be ran by themselves and have superadmin checks.

## Usage
| File | Commands | Description |
| --- | --- | --- |
| `sh_hookperf.lua` | `red_sv_hookperf` `red_cl_hookperf` | This script will log the time taken to run each hook over the span of the amount of time give, defaults to 10 seconds. This can be useful to find laggy hooks without having to use something as heavy as FProfiler as that can cause significiant lag while active, thus being hard to use on servers. |
| `sh_hookorder.lua` | `red_sv_hookorder` `red_cl_hookorder` | This script will print out the order in which hooks are called. This can be useful to determine if a hook is returning early and preventing other hooks from being called. Also shows the time taken to run each hook. |
| `sh_netperf.lua` | `red_sv_netperf_start` `red_cl_netperf_start` `red_sv_netperf_stop` `red_cl_netperf_stop` | This script will detour all net receivers log the amount of bytes received and the time taken to process the message. This can be useful to reduce networking load on both server and client. |
| `sh_indexcounter.lua` | `red_sv_indexcounter` `red_cl_indexcounter` | This script will count the amount of __index metamethod calls on entities. The more the worse, entity indexing is significiantly slower than using the entity table directly (ent:GetTable()). |
| `sh_net_logger.lua` | `red_(sv/cl)_netlogger_start` `red_(sv/cl)_netlogger_stop`  `red_(sv/cl)_netlogger_ignore` | Starts the netlogger, all incomming net.* functions will be printed to console in order as they're being read. Spammy net messages can be ignored using `red_(sv/cl)_netlogger_ignore netmsgname` |
| `sv_net_dumper.lua` | `red_sv_netdump` | This script will find all `net.Receive` function origins and dump their files to the data folder. This can be useful for locating badly performing hooks and exploits. |
| `sh_sentperf.lua` | `red_sv_sentperf` `red_cl_sentperf` | This script will log the time taken to run each method on all scripted entities over the span of the amount of time given, defaults to 10 seconds. This can be useful to find laggy methods without having to use something as heavy as FProfiler as that can cause significant lag while active, thus being hard to use on servers. |

## Extra tools
Tools i often use and can recommend for performance profiling.

| Tool  | Description |
| ------------- | ------------- |
| [FProfiler](https://github.com/FPtje/FProfiler)  | A tool that can be used to profile lua code. It can be used to find performance bottlenecks in your code after you've determined them being an issue with +showbudget or +showvprof.  |
| concmd `+showbudget` | Shows the budget panel in the top right corner of the screen. This shows how long each frame is taking to render, super useful as the first step in finding performance issues. This isn't limited to lua either which is a big bonus.  |
| concmd `+showvprof` | Shows the vprof panel, has detailed information about costs. |
| convar `phys_speeds 1` | Shows the amount of time it took per tick to execute see [here](https://github.com/ValveSoftware/source-sdk-2013/blob/0d8dceea4310fde5706b3ce1c70609d72a38efdf/mp/src/game/server/physics.cpp#L1697) for the source. |
