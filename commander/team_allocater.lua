--[[



		Allows setting of AVF vehicles to teams

		Teams are : bluefor | opfor | indfor 





]]


AVF_PLAYER_COMMANDER = {
	current_side = 1,
	sides = {
		[1] = "BLUFOR",
		[2] = "OPFOR",
		[3] = "INDFOR",
	},


	current_target = nil,
	last_target = nil,
	target_lock_time = 0,
	target_lock_max = 1.25,
	accepted_colour = Vec(0,1,0),
	unmatched_colour = Vec(1,0,0)

}
CURRENT_AI_TRACK = 0


function team_allocator_init()
	RegisterTool("avf_ai_commander_team_allocator", "AVF Command", "MOD/vox/commander_radio.vox",5)
	SetBool("game.tool.avf_ai_commander_team_allocator.enabled", true)
end

function team_allocator_tick()
	team_allocator_weapon()
end

function team_allocator_weapon()
	if GetString("game.player.tool") == "avf_ai_commander_team_allocator" then
		--Tool is selected. Tool logic goes here.
		local current_target_side = AVF_PLAYER_COMMANDER['sides'][AVF_PLAYER_COMMANDER['current_side']]
		if  not InputDown("lmb") and InputPressed("rmb") then
			AVF_PLAYER_COMMANDER['current_side'] = (AVF_PLAYER_COMMANDER['current_side']%#AVF_PLAYER_COMMANDER['sides'])+1
		end
		if GetBool("game.player.canusetool") and InputDown("lmb") then 
			local t = GetPlayerCameraTransform()
			local hit, dist, normal, shape  = QueryRaycast(t.pos, TransformToParentVec(t,Vec(0, 0, -1)), 100)
			if hit then
				local tracked_body = GetShapeBody(shape)
				tracked_body,mass = get_largest_body(tracked_body)
				if(IsBodyDynamic(tracked_body) and not HasTag(tracked_body,"avf_ai_commander_set")) then 
					if(tracked_body ==AVF_PLAYER_COMMANDER.current_target) then 
						AVF_PLAYER_COMMANDER.target_lock_time =  AVF_PLAYER_COMMANDER.target_lock_time + GetTimeStep()
						local track_percentage =  clamp(AVF_PLAYER_COMMANDER.target_lock_time  / AVF_PLAYER_COMMANDER.target_lock_max,0,1)
						CURRENT_AI_TRACK = track_percentage
						if AVF_PLAYER_COMMANDER.target_lock_time  < AVF_PLAYER_COMMANDER.target_lock_max  then
							--Draw white outline at 50% transparency

							local track_colour = VecLerp(AVF_PLAYER_COMMANDER.unmatched_colour,AVF_PLAYER_COMMANDER.accepted_colour,track_percentage)
							DrawBodyOutline(
								tracked_body,track_colour[1],track_colour[2],track_colour[3] ,0.5)
						else
							--Draw green outline, fully opaque
							DrawBodyOutline(tracked_body, 0, 1, 0, 1)
							DrawBodyHighlight(tracked_body, 1)
							local vehicle = GetBodyVehicle(tracked_body)
							if(vehicle and not HasTag(vehicle,"avf_ai")) then 
								if (HasTag(vehicle,"avf_initialized")) then 
									SetTag(vehicle,"new_avf_ai")
								end
								SetTag(vehicle,"avf_ai",AVF_PLAYER_COMMANDER['current_side'])

							elseif(not HasTag(tracked_body,"avf_ai")) then 
								SetTag(tracked_body,"avf_ai",AVF_PLAYER_COMMANDER['current_side'])
								
							end
							SetTag(tracked_body,"avf_ai_commander_set")
						end
					else
						AVF_PLAYER_COMMANDER.current_target = tracked_body
					end
				else
					AVF_PLAYER_COMMANDER.target_lock_time=0
				end
			else

				AVF_PLAYER_COMMANDER.target_lock_time=0
			end		
		elseif(AVF_PLAYER_COMMANDER.target_lock_time>0) then 
			AVF_PLAYER_COMMANDER.target_lock_time=0
		end

		local b = GetToolBody()
		if b ~= 0 then
			local shapes = GetBodyShapes(b)
			local used_tool_pos = GetShapeLocalTransform(shapes[4])
			local unused_tool_pos = TransformCopy(used_tool_pos)
			unused_tool_pos.pos = Vec(-400,-400,-400)
			SetShapeLocalTransform(shapes[1], unused_tool_pos)
			SetShapeLocalTransform(shapes[2], unused_tool_pos)
			SetShapeLocalTransform(shapes[3], unused_tool_pos)
			if(current_target_side == "BLUFOR") then 
				SetShapeLocalTransform(shapes[1], used_tool_pos)
			elseif(current_target_side == "OPFOR") then 
				SetShapeLocalTransform(shapes[2], used_tool_pos)
			else
				SetShapeLocalTransform(shapes[3], used_tool_pos)
			end
			SetShapeLocalTransform(shapes[4], used_tool_pos)
		end

	end

end



function draw_allocator_bar()
	UiPush()
		UiFont("bold.ttf", 20)
		UiTranslate(UiCenter(), UiHeight()-40)
		UiTranslate(-100, 30)
		local track_percentage =  clamp(AVF_PLAYER_COMMANDER.target_lock_time  / AVF_PLAYER_COMMANDER.target_lock_max,0,1)
		progressBar(200,60,track_percentage)
		UiColor(1,1,1)
		UiTranslate(100, -12)
		UiAlign("center middle")
		UiText("TEAM ASSIGNMENT	")
	UiPop()

end

function team_allocator_draw()
	if GetString("game.player.tool") == "avf_ai_commander_team_allocator" and GetBool("game.player.canusetool") then
		if GetBool("game.player.canusetool") and InputDown("lmb") then 
			draw_allocator_bar()
		end
		UiPush()
			UiAlign("top left")
			local w = 250
			local h = 1*22 + 30
			UiTranslate(UiWidth()-w-20, UiHeight()-h-20 - 50) -- because I don't know how big the official vehicle UI will be
			UiColor(0,0,0,0.5)
			UiImageBox("ui/common/box-solid-6.png", 250, h, 6, 6)
			UiTranslate(125, 32)
			UiColor(1,1,1)
			UiTranslate(-60, 0)
				
			local key = "lmb - "
			local func = "(hold), assign team"
			UiFont("bold.ttf", 22)
			UiAlign("right")
			UiText(key)
			UiTranslate(10, 0)
			UiFont("regular.ttf", 22)
			UiAlign("left")
			UiText(func)
			UiTranslate(-10, 22)
		UiPop()
		UiPush()
			UiAlign("top left")
			local w = 250
			local h = 1*22 + 30
			UiTranslate(UiWidth()-w-20, UiHeight()-h-20 - 20) -- because I don't know how big the official vehicle UI will be
			UiColor(0,0,0,0.5)
			UiImageBox("ui/common/box-solid-6.png", 250, h, 6, 6)
			UiTranslate(125, 32)
			UiColor(1,1,1)
			UiTranslate(-60, 0)
				
			local key = "rmb - "
			local func = "Change target team"
			UiFont("bold.ttf", 22)
			UiAlign("right")
			UiText(key)
			UiTranslate(10, 0)
			UiFont("regular.ttf", 22)
			UiAlign("left")
			UiText(func)
			UiTranslate(-10, 22)
		UiPop()
	end

end


