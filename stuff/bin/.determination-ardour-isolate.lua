#!/bin/ardour8-lua
-- Determination - Deterministic rendering environment for white-axe's music
-- Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

backend = AudioEngine:set_backend("None (Dummy)", "ardour", "")
assert(AudioEngine:current_backend_name() == "Dummy")
backend:set_buffer_size(1024)
assert(backend:buffer_size() == 1024)

session = load_session(
  os.getenv("DETERMINATION_ARDOUR_PROJECT"),
  os.getenv("DETERMINATION_ARDOUR_SESSION")
)
assert(session)

i = math.tointeger(os.getenv("DETERMINATION_ARDOUR_TRACK"))

-- Make sure disabling a track in a group doesn't also disable the other tracks
-- in the group
for group in session:route_groups():iter() do
  group:set_route_active(false)
end

for j, track in ipairs(session:get_tracks():table()) do
  if j ~= i then
    -- Disable every track except for track i
    track:set_active(false, nil)
    -- Disable all the plugins in every track except for track i as well,
    -- otherwise Ardour will still load the plugins, and even doing that can
    -- cause exported audio to change!
    k = 0
    while true do
      processor = track:nth_processor(k)
      if processor:isnil() then
        break
      elseif processor:to_plugininsert():isnil() then
        k = k + 1
      else
        assert(track:remove_processor(processor, nil, true) == 0)
      end
    end
  end
end

assert(
  session:save_state(
    "~exporttmp-" .. os.getenv("DETERMINATION_ARDOUR_SESSION"),
    false, -- pending
    false, -- switch_to_snapshot
    false, -- template_only
    true,  -- for_archive
    false  -- only_used_assets
  ) == 0
)

close_session()
quit()
