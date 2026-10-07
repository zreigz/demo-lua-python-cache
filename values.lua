-- Dynamic helm values (lua phase).
-- Delete this file during the python migration so a stale luaFile pointer fails loudly.
values["engine"] = "lua"
values["message"] = "rendered-by-lua"
values["replicaCount"] = 2
