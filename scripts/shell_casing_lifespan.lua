#version 2



function init()
	script_active = true
	shape = FindShape("")
	min_dist = math.random(15,55)
	life_timer = 0 
	max_life = math.random(10,45)

end

function tick(dt) 
	if(script_active) then 
		if(IsHandleValid(shape)) then 
			local shape_pos = GetShapeWorldTransform(shape).pos
			local player_pos = GetPlayerPos()
			if((life_timer > max_life and  VecLength(VecSub(player_pos,shape_pos))>min_dist) or life_timer > max_life *2 ) then 
				Delete(shape)
				script_active = false
			else
				life_timer = life_timer + dt
			end
		else 
			script_active = false
		end
	end

end


-- ============================================================
-- MP callback wrappers (added for Teardown v2 multiplayer)
-- Routes legacy SP top-level callbacks (init/tick/update/draw)
-- through the client.* table so the mod runs in MP context.
-- Phase 2/3 will migrate server-only mutations to server.* via
-- ServerCall. See MIGRATION_NOTES.md.
-- ============================================================
if client then
    if init   then function client.init()     init()     end end
    if tick   then function client.tick(dt)   tick(dt)   end end
    if update then function client.update(dt) update(dt) end end
    if draw   then function client.draw()     draw()     end end
end


-- ============================================================
-- Phase 2: server.* wrappers
-- AVF was written as a single-context SP mod. Routing the same
-- legacy callbacks to server.* in addition to client.* lets the
-- host's server-side Lua state execute world-mutating calls
-- (Shoot, MakeHole, Explosion, SetProperty, SetBodyTransform,
-- Spawn, Delete, Paint) that are SERVER ONLY in v2.
--
-- LIMITATIONS — read MIGRATION_NOTES.md:
--  * Resource loaders (LoadSound, LoadSprite) called from init()
--    run in BOTH contexts. Server context has no renderer; calls
--    return invalid handles. Audio/visual will only work for the
--    client copy. Acceptable for testing on solo-host.
--  * tick/update run twice on the host (once per context). This
--    is wasteful and may cause state divergence in long sessions.
--  * Pure rendering calls (DrawSprite, UI.*) inside tick will be
--    no-ops in server context but should not crash.
--  * draw() is NOT mapped to server.* — server has no draw hook.
-- ============================================================
if server then
    if init   then function server.init()     init()     end end
    if tick   then function server.tick(dt)   tick(dt)   end end
    if update then function server.update(dt) update(dt) end end
end
