

--[[

	File that manages conquest mode behaviours, activies, point scoring, etc. 


	Thsi can be custmized to make very specific game modes or used as is for a simple conquest game. 

	examples can include respawning assets with points lost for respawns or capture pont ticks. 


	teams:
		1: bluefor
		2: opfor
		3: inde

]]


phonetic_alphabet = {
[1] = "Alpha",
[2] = "Bravo",
[3] = "Charlie",
[4] = "Delta",
[5] = "Echo",
[6] = "Foxtrot",
[7] = "Golf",
[8] = "Hotel",
[9] = "India",
[10] = "Juliett",
[11] = "Kilo",
[12] = "Lima",
[13] = "Mike",
[14] = "November",
[15] = "Oscar",
[16] = "Papa",
[17] = "Quebec",
[18] = "Romeo",
[19] = "Sierra",
[20] = "Tango",
[21] = "Uniform",
[22] = "Victor",
[23] = "Whiskey",
[24] = "X-ray",
[25] = "Yankee",
[26] = "Zulu",
}


side_names = {
	[1] = "blufor",
	[2] = "opfor",
	[3] = "inde"


}

side_colours = {
	[1] = {0,0,1},
	[2] = {1,0,0},
	[3] = {0,1,0}


}

capture_point_states = {}
default_capture_point_state = {
						active = true,
						id = 0,
						name = "DEFAULT",
						captured = false,
						capture_side = 0,
						capture_percentage = 0,
}

total_capture_points = 0

team_scores = {0,0,0}
-- team_scores = {0,0,0}

score_to_win = 9000

player_team = 1


score_tick = 1000
score_count = 0


score_increment = 1


min_held_percentage = .20

capture_points = nil 


manager_active = false

function init()
	--get current AVF entities
	-- update_capture_point_list()	
	local existng_conquest_manager = GetBool("level.avf_conquest.game_manager_enabled")
	if(not existng_conquest_manager) then 
		SetBool("level.avf_conquest.game_manager_enabled", true)
		manager_active = true
	end

end


--[[

CAPTURE POINT VALUES: 


	SetTag(capture_point,"active","true")   true/false
	SetTag(capture_point,"captured","false") true/false
	SetTag(capture_point,"capture_side",0) 0,1,2,3 
	SetTag(capture_point,"capture_percentage",0) 0-1
	SetTag(capture_point,"capture_zone_value",capture_zone_value) number 



]]

function tick(dt)   
	if(manager_active) then 
		-- DebugWatch("startng tick",#capture_point_states)
		update_capture_point_list()	
		-- document_capture_points( )
		-- DebugWatch("ending  tick",#capture_point_states)

		score_count = score_count + dt
		if(score_count>score_increment) then
			calculate_scores()
			score_count=0

		end 
	end
end

-- add newly found capture point to list of known points, give it a name. 
function add_capture_point(capture_point_handle)	
	capture_point_states[#capture_point_states+1] = deepcopy(default_capture_point_state)
	local current_index = #capture_point_states
	SetTag(capture_point_handle,"avf_conquest_id",current_index)  
	
	local capture_point_name = phonetic_alphabet[current_index]
	if( GetTagValue(capture_point_handle,"avf_conquest_point_name")~= nil) then 
		SetTag(capture_point_handle,"avf_conquest_point_name",capture_point_name)
		capture_point_name = GetTagValue(capture_point_handle,"avf_conquest_point_name")
	end  
	capture_point_states[current_index].id = capture_point_handle  
	capture_point_states[current_index].name = capture_point_name

	SetTag(capture_point_handle,"avf_conquest_point_registered",true)  

end

function update_capture_point_details(capture_point_handle)	
	local current_index = tonumber(GetTagValue(capture_point_handle,"avf_conquest_id"))
	DebugWatch("test point: "..current_index, capture_point_states[current_index].name)
	capture_point_states[current_index].captured = GetTagValue(capture_point_handle,"captured")
	capture_point_states[current_index].capture_side = GetTagValue(capture_point_handle,"capture_side")
	capture_point_states[current_index].capture_percentage = GetTagValue(capture_point_handle,"capture_percentage")

end


-- update list of capture points every few seconds, if capture point not known then add to list. 
function update_capture_point_list()	
	capture_points = FindTriggers("avf_conquest_point",true)
	for i = 1,#capture_points do 
		-- team_scores[i] = GetTagValue(capture_points[i],"capture_percentage")
		if(GetTagValue(capture_points[i],"avf_conquest_point_registered")=="") then 
			add_capture_point(capture_points[i])	
		else
			update_capture_point_details(capture_points[i])
		end
	end

end


function document_capture_points( )
	for i =1, #capture_point_states do
		format_capture_info(capture_point_states[i])
		-- DebugWatch("Capture Point: "..capture_points[capture_points[i]Status",team_scores[i])
	end
end



--[[
	a capture point has 3 states - uncaptured / neutral 
	[SIDE] capturing 
	[SIDE] captured
	this may extend to Contested but not currently 


]]
function format_capture_info(capture_point)
		local capture_point_name = capture_point.name
		local side_string = ""
		local side_colour = {1,1,1}
		local state_string = "Uncaptured"
		local cap_side = tonumber(capture_point.capture_side)
		local capture_percentage = tonumber(capture_point.capture_percentage)
		if(cap_side~= 0 ) then 
			side_string = side_names[cap_side]
			side_colour = side_colours[cap_side]
			if(capture_percentage>min_held_percentage) then
				state_string = "Captured"
			else
				state_string = "Capturing"
			end
		end 
		local capture_string = 'Capture Point '..capture_point_name.." | "..side_string.." "..state_string..": "..math.floor(capture_percentage*100).."%"
		-- DebugWatch('Capture Point '..capture_point_name..": ",side_string.." "..state_string.." "..math.floor(capture_percentage*100).."%")
		-- DebugWatch('Capture Point '..capture_point_states[i].name.." capture_percentage",math.floor(capture_percentage*100).."%")
		return capture_string,side_colour 
end

function calculate_scores()
	for i =1, #capture_point_states do
		local cap_side = tonumber(capture_point_states[i].capture_side)
		local capture_percentage = tonumber(capture_point_states[i].capture_percentage)*100
		if(cap_side>0 and capture_percentage>min_held_percentage) then 
			team_scores[cap_side] = team_scores[cap_side] + score_increment
		end
	end
	for i = 1,3 do
		DebugWatch("team "..i.." score",team_scores[i])
	end

end

function draw(dt)
	if(manager_active) then 
		show_capture_values(dt)
	end
end


function show_capture_values(dt)
	local capture_string = ""
	local side_colour = {1,1,1}
	local text_size = UiHeight()*0.02
	local text_buffer= text_size + (text_size * 0.5)
	UiTranslate(UiWidth()*0.025, UiHeight()*.5)
	UiPush()
		for i =1, #capture_point_states do
			capture_string, side_colour  = format_capture_info(capture_point_states[i])
			-- DebugWatch("Capture Point: "..capture_points[capture_points[i]Status",team_scores[i])
			
			UiAlign("left middle")
			UiFont("bold.ttf", text_size)
			UiColor(side_colour[1],side_colour[2],side_colour[3])
			UiText(capture_string)
			UiTranslate(0, text_buffer)
		end

		
	UiPop()
end





function clamp(val, lower, upper)
    if lower > upper then lower, upper = upper, lower end -- swap if boundaries supplied the wrong way
    return math.max(lower, math.min(upper, val))
end




function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end