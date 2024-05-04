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
  "~exporttmp-" .. os.getenv("DETERMINATION_ARDOUR_SESSION")
)
assert(session)

i = math.tointeger(os.getenv("DETERMINATION_ARDOUR_TRACK"))
i_str = i < 10
  and "00" .. tostring(i)
  or i < 100
  and "0" .. tostring(i)
  or tostring(i)

export_dir = os.getenv("DETERMINATION_ARDOUR_EXPORT_DIR")
export = session:simple_export()
export:set_name(os.getenv("DETERMINATION_ARDOUR_TRACK_PREFIX") .. i_str)
assert(export:set_preset("aa832fd9-91df-4bad-a7ea-d40fba4e3c5a"))
if export_dir then
  export:set_folder(export_dir)
end
assert(export:run_export())

close_session()
quit()
