-- depends: https://forum.minetest.net/viewtopic.php?f=9&t=23158 / biomeinfo
nextgen_music = {players = {}, playing = {}, handles = {}, songs = {}, id_playing = {}, song_time_left = {}, time_next = {}, modpath = minetest.get_modpath("nextgen_music")}
if not nextgen_music.modpath then
        error("nextgen_music mod folder has to be named 'nextgen_music'!")
end

local storage = minetest.get_mod_storage()

-- Optional V6 Support
local have_biomeinfo = minetest.get_modpath("biomeinfo") ~= nil
local is_v6 = minetest.get_mapgen_setting("mg_name") == "v6"
if is_v6 and not have_biomeinfo then
	minetest.log("warning", "The nextgen_music mod also needs biomeinfo to support v6 mapgens.")
end

-- Configuration option
local start_enabled = minetest.settings:get_bool("nextgen_music_enabled", true)

local sfile, sfileerr=io.open(nextgen_music.modpath.."/songs.txt")
if not sfile then error("Error opening songs.txt: "..sfileerr) end
for linent in sfile:lines() do
        local line = string.match(linent, "^%s*(.-)%s*$")
        if line~="" and string.sub(line,1,1)~="#" then
                local name, timeMinsStr, timeSecsStr = string.match(line, "^(%S+)%s+(%d+):([%d%.]+)$")
                local timeMins, timeSecs = tonumber(timeMinsStr), tonumber(timeSecsStr)
                if name and timeMins and timeSecs then
                        nextgen_music.songs[#nextgen_music.songs+1]={name=name, length=timeMins*60+timeSecs, lengthhr=timeMinsStr..":"..timeSecsStr}
                else
                        minetest.log("warning", "[nextgen_music] Misformatted song entry in songs.txt: "..line)
                end
        end
end
sfile:close()

if #nextgen_music.songs==0 then
        print("[nextgen_music]no songs registered, not doing anything")
        return
end

minetest.register_on_joinplayer(function(player)
	local pname = player:get_player_name()
	if (storage:get(pname) and storage:get(pname) == "1") or start_enabled then  -- enabled
		nextgen_music.players[pname] = {
			last_ippos = {x=0,y=0,z=0},
			enable = true }
	else  -- not enabled
		nextgen_music.players[pname] = {
			last_ippos = {x=0,y=0,z=0},
			enable = false }
	end
	nextgen_music.time_next[pname] = 10
	nextgen_music.playing[pname] = nil
	nextgen_music.id_playing[pname] = nil
	nextgen_music.song_time_left[pname] = nil
end)

minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	if nextgen_music.players[pname] then
		nextgen_music.players[pname] = nil
	end
end)

local timer = 0

minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 0.5 then
		return
	end
	timer = 0

	for _, player in ipairs(minetest.get_connected_players()) do
		local pname = player:get_player_name()
		local ippos = vector.round(player:get_pos())  -- integer position
		local bpos = vector.new(ippos)  -- surface position at which to calculate biome
		while bpos.y > 0 and minetest.get_node(bpos).name == "air" do
			bpos.y = bpos.y - 1
		end

		local heat, humidity, name
		if is_v6 then
			if have_biomeinfo then  -- v6 support available
				name = biomeinfo.get_v6_biome(bpos)
			else  -- v6 support missing
				name = "unknown"
			end
		else
			local bdata = minetest.get_biome_data(bpos)
			name = minetest.get_biome_name(bdata.biome)
		end

                if nextgen_music.playing[pname] then
                        if nextgen_music.song_time_left[pname]<=0 then
                                nextgen_music.stop_song(pname)
                                nextgen_music.time_next[pname]=10
                        else
                                nextgen_music.song_time_left[pname]=nextgen_music.song_time_left[pname]-dtime
                        end
                elseif nextgen_music.time_next[pname] then
                        if nextgen_music.time_next[pname]<=0 then
                                nextgen_music.play_song(name, pname)
                        else
                                nextgen_music.time_next[pname]=nextgen_music.time_next[pname]-dtime
                        end
		end

                if not vector.equals(ippos, nextgen_music.players[pname].last_ippos) then
	                nextgen_music.players[pname].last_ippos = vector.new(ippos)  -- update last player position
		end
	end
end)

nextgen_music.play_song=function(id, pname)
        local song=nextgen_music.songs[id]
        if not song then return end
        if nextgen_music.playing[pname] then
                nextgen_music.stop_song(pname)
        else
		local handle = minetest.sound_play(song.name, {to_player=pname, gain=1})
                if handle then
                	nextgen_music.handles[pname]=handle
                end
        end
        nextgen_music.playing[pname]=id
end

nextgen_music.stop_song=function(pname)
        minetest.sound_stop(nextgen_music.handles[pname])
        nextgen_music.playing[pname]=nil
        nextgen_music.handles[pname]=nil
end

