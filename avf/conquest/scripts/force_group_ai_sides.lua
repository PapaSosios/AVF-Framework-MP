



vehicleParts = {
	ai_elements = {
		side = 1,


	},
}

function init()
	vehicle = nil
	vehicles = FindVehicles("cfg") 
	for i = 1,#vehicles do 
		local value = GetTagValue(sceneVehicle, "cfg")
		if(value == "vehicle") then
			vehicle.id = sceneVehicle
	end


end

function init_ai_elements()
	if(vehicleParts.ai_elements ~= nil) then 
		for key,val in pairs(vehicleParts.ai_elements) do 
			if(type(val)== 'table') then
				for subKey,subVal in pairs(val) do
					SetTag(vehicle.id,"avf_ai".."_"..key.."_"..subKey,subVal)
				end
			elseif(key =="side") then 
				SetTag(vehicle.id,"avf_ai",val)
			else
				SetTag(vehicle.id,"avf_ai"..key,val)
			end
			
			
		end
	end


end