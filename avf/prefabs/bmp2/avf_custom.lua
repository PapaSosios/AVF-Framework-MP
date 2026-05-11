#include "check_avf.lua"



function init()
	local sceneVehicle = FindVehicle("cfg")
		local value = GetTagValue(sceneVehicle, "cfg")
		if(value == "vehicle") then
			vehicle.id = sceneVehicle

			local status,retVal = pcall(initVehicle)
			if status then 
				-- utils.printStr("no errors")
			else
				DebugPrint(retVal)
			end
			-- initVehicle()
		end

		SetTag(sceneVehicle,"AVF_Custom","unset")

		check_AVF:init(sceneVehicle)


end


function initVehicle()
	if unexpected_condition then error() end
	vehicle.body = GetVehicleBody(vehicle.id)
	vehicle.transform =  GetBodyTransform(vehicle.body)
	vehicle.shapes = GetBodyShapes(vehicle.body)
	local totalShapes = ""
	for i=1,#vehicle.shapes do
		local value = GetTagValue(vehicle.shapes[i], "component")
		if(value~= "")then
			if(value=="chassis") then
				for key,val in pairs(vehicleParts.chassis) do 
					if(HasTag(vehicle.shapes[i],key)) then
						addItems(vehicle.shapes[i],val)
					end
				end
			end
			totalShapes = totalShapes..value.." "
			local test = GetShapeJoints(vehicle.shapes[i])
				for j=1,#test do 
					local val2 = GetTagValue(test[j], "component")
					if(val2~= "")then

						
						totalShapes = totalShapes..val2.." "

						if(val2=="turretJoint")then

							totalShapes = totalShapes..traverseTurret(test[j], vehicle.shapes[i])

						elseif val2=="gunJoint" then
							

							totalShapes = totalShapes..addGun(test[j], vehicle.shapes[i])

						end
					end
				end
		end	
	end
end

function traverseTurret(turretJoint,attatchedShape)
	local outString = ""
	local turret = GetJointOtherShape(turretJoint, attatchedShape)
	local joints = GetShapeJoints(turret)

	for j=1,#joints do 
		if(joints[j]~=turretJoint)then
			local val2 = GetTagValue(joints[j], "component")

			-- DebugPrint("turret shapes:"..val2)
			if(val2=="turretJoint")then

				totalShapes = totalShapes..traverseTurret(joints[j], turret)

			elseif val2=="gunJoint" then
				outString = outString..addGun(joints[j], turret)
			end
		end
	end
	for key,val in pairs(vehicleParts.turrets) do 
		if(HasTag(turret,val)) then
			addItems(turret,key)
		end
	end
	return outString
end

function addGun(gunJoint,attatchedShape)
	local gun = GetJointOtherShape(gunJoint, attatchedShape)
	for key,val in pairs(vehicleParts.guns) do 
		
		if(HasTag(gun,key)) then
			-- DebugPrint(key)
			addItems(gun,val)
		end
	end
	local val3 = GetTagValue(gun, "component")
	return val3
end
-- @magazine1_tracer
function addItems(shape,values)
	for key,val in pairs(values) do 
			if(type(val)== 'table') then
				SetTag(shape, "@"..key)
				for subKey,subVal in pairs(val) do 
					if(type(subVal)== 'table') then
						for subKey2,subVal2 in pairs(subVal) do 
							-- DebugPrint( "@"..string.sub(key,1,-2)..subKey.."_"..subKey2.."="..subVal2)
							if key == "magazines" then
								
								SetTag(shape, "@"..string.sub(key,1,-2)..subKey.."_"..subKey2, subVal2)
							else
								SetTag(shape, "@"..key..subKey..subKey2, subVal2)
							end

						end
					else
						if key == "magazines" then
							SetTag(shape, "@"..string.sub(key,1,-2).."_"..subKey, subVal)
						else
							SetTag(shape, "@"..key..subKey, subVal)
						end
					end
				end
			else
				SetTag(shape, "@"..key,val)
			end		
	end
end

-- function tick(dt)
-- 	check_AVF:tick()

-- end


function draw(dt)
	if(check_AVF.enabled) then 
		check_AVF:draw()
	end

end

-- end
utils = {
	contains = function(set,key)
		return set[key] ~= nil
		-- body
	end,
	}


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
