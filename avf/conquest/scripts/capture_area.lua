#version 2
--[[


	capture_area script 



		outline of script: 

			Gets list of active assets 

			Computes distance of assets to location 

			as assets move into area, tick moves towards that assets side. 


			As tick moves, colour changes to / from neutral to assets colour. 

			When tick hits max, area remains under that side, unless tick doesn't hit min value. 



	Code story: 


		As a zone:

			I tick until the max value 

			dependent on what side entitites have the largest presence in my area

			biased based on the quantity of those entities within my area


			if no max value reached, nor any entity present, then i tick until i reach neutral 


				netal s 


		As an entity entering a region alone: 

		1: 
			
			When i enter a neutral area
			
			the counter ticks towards my side

			until it hits max


		2:
			When I enter a hostile area

			the counter ticks their hold downwards

			until it hits neutral 

		3: 

			When I enter friendly territory 

			the counter remains constant



		As an entity entering a region with entities within: 

		1: 
			
			When i enter an area with a larger quantity of friendly assets

			the ticker will be biased towards our side. 


		2:
			When I enter a region with more hostile entities 

			The ticker will be biased towards their side. 

		3: 

			When I consider bias to a side


			I consider the bias to be the product of the majority - perhaps ease out cubic. 

		4: 
			if i enter a zone controlled by other entities not in control of zone

			zone ticks down to neutral 

			zone then handled as per regular rules. 



--------------------------------------------------------------------------------------------------------


	
	Assumptions:
		Assets could range from vehicles to people. Larger AVf handlers will only consider if a region is registered as "active" and its side. 


		Some assets may have a higher or lower capability to hold a region. This will be an advanced feature. 

		Assets with high capture capability will be measured as a float value above the regular 1 asset 1 score, likewise for assets with lower capture capability. 


		NO AVF COMPATIBLE ASSET IS LABELLED AS MORE THAN ONE SIDE, UNLESS YOU HAVE SOME INSANE LOGIC FOR THINGS THAT WILL COUNT AS LESS OF AN ASSEST, 
		This means that vehicles are labelled once, bodies once, shapes once, unless you do so.

			If you complain of a thing being counted twice then i shall be dissapointed. 




]]


capture_zone_value = 1

capture_zone_range = 35

base_smoke = 0.3

--side represents which side holds the point. 
-- capture point is the same but more firm due to drunk me coding in the past 
capture_point_side =0 
side =0 
-- how held is the point by the current side (this is min tick not max tick)
capture_percentage = 0

min_capture_percentage = 0.2


capture_total = 0 

capture_total_max = 75

-- the total tick value of the point as it stands. 
tick_total = 0

-- how much of this tick is applied as a base rate 1-1 of a tick. 
tick_rate =1 

-- -- the min tick to be captured
-- tick_min = 25

-- -- the max value to be captured
-- tick_max = 60


-- time since last update to perform a tick, in ms, best to keep higher as this does a full scan of assets and therefore each node will doe. 
tick_update = 0.750

-- the counter until the next update 
tick_update_counter = 0 



team_capture_score = {0,0,0}

blufor_hold = 0
opfor_hold = 0
inde_hold = 0


function init()
	--get current AVF entities


	capture_point = FindTrigger("avf_conquest_point")
	capture_point_sprite = LoadSprite("gfx/ring.png")


	SetTag(capture_point,"active","true")
	SetTag(capture_point,"captured","false")
	SetTag(capture_point,"capture_side",0)
	SetTag(capture_point,"capture_percentage",0)
	SetTag(capture_point,"capture_zone_value",capture_zone_value) 

	triggerWidth = capture_zone_range
	triggerDepth = capture_zone_range

	spriteColorR = .5
	spriteColorB = .5
	spriteColorG = .5
	spriteColorAlpha = 2

	-- capture_total_max = tick_max




end

function tick(dt)   

		draw_capture_region(dt)
		--[[

			for all elements of one side closer than max 
				incremeent tick total to max of +/- tick_max. 
		]]
		capture_region_tick(dt)


		-- DebugWatch("Capture Point: "..capture_point.." Status",team_capture_score)

end

function draw_capture_region(dt)
		local trigger_pos = GetTriggerTransform(capture_point)

		trigger_pos.rot = QuatLookAt(Vec(0,0,0),Vec(0,1,0))
		DrawSprite(capture_point_sprite,trigger_pos , triggerWidth, triggerDepth, spriteColorR + team_capture_score[2], spriteColorG + team_capture_score[3], spriteColorB + team_capture_score[1], spriteColorAlpha, true, false)


		deploy_smoke(trigger_pos.pos)
end

function capture_region_tick(dt)
	tick_update_counter = tick_update_counter + dt
	if (tick_update_counter > tick_update) then 
		tick_update_counter = tick_update_counter % tick_update
		measure_entities()

		record_global_state(dt)
	end
end


function deploy_smoke(pos)

	life = 5+5*math.random()

	smoke_dir =  VecAdd(rndVec(0.9),GetWindVelocity(pos))
	smoke_dir =  VecAdd(Vec(0, 2, 0),smoke_dir )


	ParticleReset()
	ParticleColor(base_smoke + team_capture_score[2], base_smoke + team_capture_score[3] , base_smoke + team_capture_score[1], base_smoke , base_smoke , base_smoke )
	ParticleGravity(1)
	ParticleDrag(0.2)
	ParticleRadius(0.1, 0.7)
	ParticleEmissive(2, 0)
	ParticleAlpha(1.0, 0.0)
	ParticleCollide(0, 1)
	SpawnParticle(pos, smoke_dir, life)



end


--[[


		Process:
			- call measure_entities tick to calculate present entities
			- Call measure_tick tick to calculate the tick strength of an entity, add strength to tick total. 
			- apply tick to zone - decide if adversarial tick, to strengthen tick, or reduce zone strength 
			- final consideration 


	---------------------------------------------------------------



	Calculates all assets in an area that would need to be considered by the capture region, and turns them into a score based on their class

	currently only works for vehicles, code needed to work out bodies that may be different from typical AVF assets.  

	please make sure you label the correct entities with the tags, as this will check shapes and it'll be a nightmare, especially for complicated stuff!!
]]
function measure_entities()
	local avf_vehicles, avf_bodies, avf_shapes  = get_avf_entities() 
	-- DebugWatch("avf vehicles: ", tablelength(avf_vehicles))
	-- DebugWatch("avf bodies: ", tablelength(avf_bodies))
	-- DebugWatch("avf shapes: ", tablelength(avf_shapes))
	local blufor_score, opfor_score, inde_score = 0, 0, 0
	blufor_score, opfor_score, inde_score = measure_entity_set(avf_vehicles, blufor_score, opfor_score, inde_score,"vehicle" )
	blufor_score, opfor_score, inde_score = measure_entity_set(avf_bodies, blufor_score, opfor_score, inde_score, "body",avf_vehicles)
	blufor_score, opfor_score, inde_score = measure_entity_set(avf_shapes, blufor_score, opfor_score, inde_score, "shape",avf_vehicles,avf_bodies )
	-- DebugPrint("time: "..GetTimeStep().." blufor: "..blufor_score)
	blufor_score,opfor_score,inde_score = apply_tick(blufor_score,opfor_score,inde_score)


end


--[[

	take a group of entities, such as vehicles or bodies or shapes, and perform the appropriate calculations

]]
function measure_entity_set(entity_set, blufor_score, opfor_score, inde_score, entity_type,ready_vehicles,ready_bodies )
	ready_vehicles = ready_vehicles or nil 
	ready_bodies = ready_bodies or nil 
	local entity_side = -1
	local entity_score = 0
	local scores = { 
					[1] = blufor_score,
					[2] = opfor_score,
					[3] = inde_score,
				} 
	for i=1,#entity_set do
		entity_score = 0
	--	DebugPrint("entity type "..GetEntityType(entity_set[i]).. " entity set: "..entity_type )

		--[[

			NEEDS DEBUG 

			NEEDS TO WORK OUT IF OBJECT HAS BEEN COUNTED ABOVE, AND IF SO THEN TO NOTE ACT, IF NO VEHICLE OR BODY EXISTS THEN CONTINUE AS NORMAL. 



			update: 20220923 : it has been decided that if you be a dumb shit and make everything have a side then it's on you. 
				~This is not lazy coding.

		]]
		if(entity_in_range(entity_set[i])) then 
			if(HasTag(entity_set[i],"avf_side") and not (HasTag(entity_set[i],"avf_dead") or HasTag(entity_set[i],"avf_vehicle_disabled"))) then 
				if(entity_type == "vehicle" ) then 
						measure_entity_score(entity_set[i], scores)  
				elseif(entity_type == "body") then  
					if(not HasTag(GetBodyVehicle(entity_set[i],"avf_side"))) then 
						-- DebugPrint("body "..tostring(entity_set[i]))
						measure_entity_score(entity_set[i], scores)
					end
				elseif(entity_type == "shape") then 
					if(not HasTag(GetShapeBody(entity_set[i]),"avf_side") and not HasTag(GetBodyVehicle(GetShapeBody(entity_set[i]),"avf_side"))) then 
						measure_entity_score(entity_set[i], scores)
					end
				end
			end
		end
	end
	return scores[1], scores[2], scores[3]
end

function measure_entity_score(entity, scores)
		entity_side =  tonumber(GetTagValue(entity,"avf_side"))
		if(entity_side~=nil and entity_side>0 and entity_side<4) then 
			entity_score = measure_entity_tick(entity,0)
			scores[entity_side] = scores[entity_side] + entity_score 
		end
	return scores

end

--[[

	Calculates individual asset tick value

	Modify this if you create special vehicles like resource vehicles, scout units, or light units.

	This will allow you to make some vehicles have more or less influence on the capture

]]
function measure_entity_tick(asset, modifiers)
	local asset_value = 0
	local asset_tag_value = tonumber(GetTagValue(asset,"avf_asset_value"))
	if(asset_tag~=nil) then 
		asset_value = 1 * asset_tag_value
	else
		asset_value = 1
	end
	return asset_value
end

function entity_in_range(entity)
	local entity_pos = get_entity_pos(entity)
	if(VecLength(VecSub(entity_pos, GetTriggerTransform(capture_point).pos))<= capture_zone_range*.5) then 
--		DebugPrint("entity of type "..GetEntityType(entity).." in range! Distance: "..VecLength(VecSub(entity_pos, GetTriggerTransform(capture_point).pos)))	
		return true
	else
		return false
	end
end


--[[

	Calculates what assets will make the region tick for their side based on measured scores on assumed asset capability.


	check if side is occupied, if the current side is ticked over then site hold drops. 


		if site not owned then get all holds and if one is stronger tehn add to that, otherwise remains held or doesn't drop. 


]]


function calculate_tick(blufor_score, opfor_score, inde_score)
	scores = {blufor_score, opfor_score, inde_score}
	-- DebugWatch("blufor tick",blufor_score)
	-- DebugWatch("opfor tick",opfor_score)
	-- DebugWatch("inde tick",inde_score)
	local max_tick = 0
	local tick_side = 0
	local negative_tick = 0
	for i =1,3 do 
		if(scores[i] ~= 0) then 
			if(capture_point_side> 0) then 
				if(i == capture_point_side) then 
					max_tick = scores[i]
					tick_side = i
				else
					negative_tick = negative_tick + scores[i] 
				end

			else
				if(check_max_tick(scores[i],max_tick))then 
					max_tick = scores[i]
					tick_side = i
				else
					negative_tick = negative_tick + scores[i]
				end
			end
		end
	end
	if(tick_side == 0 and get_capture_percentage()<min_capture_percentage) then 
		negative_tick = 1
	end
	return tick_side,max_tick,negative_tick


end

--[[

	Calculates what assets will make the region tick for their side based on measured scores on assumed asset capability.


	checks tick above neg, then adds to side, if no side then adds to that. 

		otherwise deducts from main

]]

function apply_tick(blufor_score, opfor_score, inde_score) 
	local flag_changed = false
	local tick_side, tick_quantity, negative_tick = calculate_tick(blufor_score, opfor_score, inde_score)
	local tick_value =  tick_quantity - negative_tick
	if tick_value > 0 then 
		if(capture_point_side  == 0) then 
			capture_point_side = tick_side
			capture_total = tick_value
			flag_changed = true
		else
			if(capture_point_side  == tick_side) then 
				capture_total = math.min(capture_total + tick_value,capture_total_max)
			else 
				capture_total = capture_total - tick_value
				if(capture_total) <= 0 then 
					capture_point_side = 0
					capture_total = 0
					flag_changed = true
				end
			end
		end
	else
		capture_total = capture_total + tick_value
		if(capture_total) <= 0 then 
			capture_point_side = 0
			capture_total = 0
			flag_changed = true
		end		
	end
	set_controlling_side(capture_point_side,capture_total,flag_changed )

end


--[[ 

	set values for controlling side from 0-1 then map that to the smoke controls to inform terriory hold

]]
function set_controlling_side(side,capture_total,flag_changed )
	if(capture_point_side ~= 0) then 
				team_capture_score[capture_point_side] =  get_capture_percentage()
	elseif(flag_changed) then 
		for i=1,3 do 
				team_capture_score[i] = 0
		end
	end
end



--[[

	Increments the tick value and updates global record.

]]

function record_global_state() 
	local capture_state = "false"
	if(capture_point_side~=0) then
		if(get_capture_percentage()>=min_capture_percentage) then 
			capture_state = "true"
		end
	end
	SetTag(capture_point,"captured",capture_state)
	SetTag(capture_point,"capture_side",capture_point_side)
	SetTag(capture_point,"capture_percentage",get_capture_percentage())

end

function check_max_tick(side,max_tick)
	if(side>max_tick) then 
		return true
	else
		return false
	end

end



function get_capture_percentage()
	return capture_total / capture_total_max

end




function get_avf_entities()
	-- vehicles
	local  avf_vehicles = FindVehicles("avf_side",true)
	-- bodies
	local  avf_bodies = FindBodies("avf_side",true)
	-- shapes
	local  avf_shapes = FindShapes("avf_side",true)
	return  avf_vehicles, avf_bodies, avf_shapes 
end


function get_entity_pos(entity)
	local entity_type = GetEntityType(entity)
	local entity_pos = nil
	if(entity_type == "vehicle") then 
		entity_pos = VecCopy(GetVehicleTransform(entity).pos)
	elseif(entity_type == "body") then
		entity_pos = VecCopy(GetBodyTransform(entity).pos)
	elseif(entity_type == "shape") then
		entity_pos = VecCopy(GetShapeWorldTransform(entity).pos)
	end
	return entity_pos
end

function getDistanceToPlayer()
	local playerPos = GetPlayerPos()
	return VecLength(VecSub(playerPos,  GetTriggerTransform(stockpiles[1]).pos))
end

function get_2D_distance(p1,p2)
	local point1 = VecCopy(p1)
	local point2 = VecCopy(p2)
	point1[2] =0
	point2[2] =0
	local distance = VecLength(VecSub(point1, point2))
	return distance
end


--Return a random vector of desired length
function rndVec(length)
	local v = VecNormalize(Vec(math.random(-100,100), math.random(-100,100), math.random(-100,100)))
	return VecScale(v, length)	
end


function rnd(mi, ma)
	return math.random(1000)/1000*(ma-mi) + mi
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function setContains(set, key)
    return set[key] ~= nil
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
