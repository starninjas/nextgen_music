-- depends: https://forum.minetest.net/viewtopic.php?f=9&t=23158 / biomeinfo
display_biome = {}
local storage = minetest.get_mod_storage()

-- Optional V6 Support
local have_biomeinfo = minetest.get_modpath("biomeinfo") ~= nil
local is_v6 = minetest.get_mapgen_setting("mg_name") == "v6"
if is_v6 and not have_biomeinfo then
	minetest.log("warning", "The display_biome mod also needs biomeinfo to support v6 mapgens.")
end

-- Configuration option
local start_enabled = minetest.settings:get_bool("display_biome_enabled", false)


minetest.register_on_joinplayer(function(player)
	local pname = player:get_player_name()
	if (storage:get(pname) and storage:get(pname) == "1") or start_enabled then  -- enabled
		display_biome[pname] = {
			last_ippos = {x=0,y=0,z=0},
			enable = true }
	else  -- not enabled
		display_biome[pname] = {
			last_ippos = {x=0,y=0,z=0},
			enable = false }
	end
end)

minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	if display_biome[pname] then
		display_biome[pname] = nil
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
   		if not vector.equals(ippos, display_biome[pname].last_ippos) then  -- position changed
				-- simple search for ground elevation
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
				local rc = name
        if not vector.equals(ippos, display_biome[pname].last_ippos) then
					display_biome[pname].last_ippos = vector.new(ippos)  -- update last player position
				end
			end
		end
	end
end)
