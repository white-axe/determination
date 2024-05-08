#!/bin/ardour8-lua
-- Determination - Deterministic rendering environment for music and art
-- Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, version 3.

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

for j, track in ipairs(session:get_tracks():table()) do
  if j ~= i then
    track:remove_processor(track:the_instrument(), nil, true)
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
