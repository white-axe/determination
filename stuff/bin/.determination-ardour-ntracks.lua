#!/bin/ardour8-lua
-- Determination - Deterministic rendering environment for white-axe's music
-- Copyright (C) 2024 Liu Hao <whiteaxe@tuta.io>
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

session = load_session(
  os.getenv("DETERMINATION_ARDOUR_PROJECT"),
  os.getenv("DETERMINATION_ARDOUR_SESSION")
)
assert(session)

print(#session:get_tracks():table())

close_session()
quit()
