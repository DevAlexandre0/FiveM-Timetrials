ESX = exports["es_extended"]:getSharedObject()
-- Local parameters
local START_PROMPT_DISTANCE = 5.0              -- distance to prompt to start race
local DRAW_TEXT_DISTANCE = 100.0                -- distance to start rendering the race name text
local DRAW_SCORES_DISTANCE = 25.0               -- Distance to start rendering the race scores
local DRAW_SCORES_COUNT_MAX = 15                -- Maximum number of scores to draw above race title
local CHECKPOINT_Z_OFFSET = -5.00               -- checkpoint offset in z-axis
local RACING_HUD_COLOR = {255, 255, 255, 255}    -- color for racing HUD above map
local pedplayer = GetPlayerPed(-1)

--- FOR LAP ---
local Rollinglap = 0
local Rolling = 0
local Flylap = 0
local Fly = 0
--- FOR Endurances ---
local minutes = 125
local seconds  = 0

-- State variables
local raceState = {
    cP = 1,
    index = 0 ,
    scores = nil,
    startTime = 0,
    blip = nil,
    checkpoint = nil,
    lap = 1,
}

-- Array of colors to display scores, top to bottom and scores out of range will be white
local raceScoreColors = {
    {214, 175, 54, 255},
    {167, 167, 173, 255},
    {167, 112, 68, 255}
}

-- Create preRace thread
Citizen.CreateThread(function()
    preRace()
end)

-- Function that runs when a race is NOT active
function preRace()
    -- Initialize race state
    raceState.cP = 1
    raceState.index = 0 
    raceState.startTime = 0
    raceState.blip = nil
    raceState.checkpoint = nil
    raceState.lap = 1
    
    -- While player is not racing
    while raceState.index == 0 do
        -- Update every frame
        Citizen.Wait(0)

        -- Get player
        local player = GetPlayerPed(-1)

        -- Loop through all races
        for index, race in pairs(races) do
            if race.isEnabled then
                -- Draw map marker
                DrawMarker(0, race.start.x, race.start.y, race.start.z - 1, 0, 0, 0, 0, 0, 0, 3.0001, 3.0001, 1.5001, 255, 165, 0,165, 0, 0, 0,0)
                
                -- Check distance from map marker and draw text if close enough
                if GetDistanceBetweenCoords( race.start.x, race.start.y, race.start.z, GetEntityCoords(player)) < DRAW_TEXT_DISTANCE then
                    -- Draw race name
                    Draw3DText(race.start.x, race.start.y, race.start.z-0.600, race.title, RACING_HUD_COLOR, 4, 0.3, 0.3)
                end

                -- When close enough, draw scores
                if GetDistanceBetweenCoords( race.start.x, race.start.y, race.start.z, GetEntityCoords(player)) < DRAW_SCORES_DISTANCE then
                    -- If we've received updated scores, display them
                    if raceState.scores ~= nil then
                        -- Get scores for this race and sort them
                        raceScores = raceState.scores[race.title]
                        if raceScores ~= nil then
                            local sortedScores = {}
                            for k, v in pairs(raceScores) do
                                table.insert(sortedScores, { key = k, value = v })
                            end
                            table.sort(sortedScores, function(a,b) return a.value.time < b.value.time end)

                            -- Create new list with scores to draw
                            local count = 0
                            drawScores = {}
                            for k, v in pairs(sortedScores) do
                                if count < DRAW_SCORES_COUNT_MAX then
                                    count = count + 1
                                    table.insert(drawScores, v.value)
                                end
                            end

                            -- Initialize offset
                            local zOffset = 0
                            if (#drawScores > #raceScoreColors) then
                                zOffset = 0.450*(#raceScoreColors) + 0.300*(#drawScores - #raceScoreColors - 1)
                            else
                                zOffset = 0.450*(#drawScores - 1)
                            end

                            -- Print scores above title
                            for k, score in pairs(drawScores) do
                                -- Draw score text with color coding
                                if (k > #raceScoreColors) then
                                    -- Draw score in white, decrement offset
                                    Draw3DText(race.start.x, race.start.y, race.start.z+zOffset, string.format("%s %.2fmin (%s)", score.car, (score.time*(0.001/60)), score.player), {255,255,255,255}, 4, 0.13, 0.13)
                                    zOffset = zOffset - 0.300
                                else
                                    -- Draw score with color and larger text, decrement offset
                                    Draw3DText(race.start.x, race.start.y, race.start.z+zOffset, string.format("%s %.2fmin (%s)", score.car, (score.time*(0.001/60)), score.player), raceScoreColors[k], 4, 0.22, 0.22)
                                    zOffset = zOffset - 0.450
                                end
                            end
                        end
                    end
                end
                
                -- When close enough, prompt player
                if GetDistanceBetweenCoords( race.start.x, race.start.y, race.start.z, GetEntityCoords(player)) < START_PROMPT_DISTANCE then
                    helpMessage("Press ~INPUT_CONTEXT~ to Race!")
                    if IsControlJustReleased(1, 51) and GetVehiclePedIsIn(player, false) ~= 0  then
                        -- Set race index, clear scores and trigger event to start the race
                        raceState.index = index
                        raceState.scores = nil
                        TriggerEvent("raceCountdown")
                        break
                    elseif IsControlJustReleased(1, 51) and GetVehiclePedIsIn(player, false) == 0 then
                        exports['mythic_notify']:SendAlert('error', 'You should enter vehicle RACE!')
                    end
                end
            end
        end
        --------ENDU------
        for index, endurance in pairs(endurances) do
            if endurance.isEnabled then
                -- Draw map marker
                DrawMarker(0, endurance.start.x, endurance.start.y, endurance.start.z - 1, 0, 0, 0, 0, 0, 0, 3.0001, 3.0001, 1.5001, 255, 165, 0,165, 0, 0, 0,0)
                
                -- Check distance from map marker and draw text if close enough
                if GetDistanceBetweenCoords( endurance.start.x, endurance.start.y, endurance.start.z, GetEntityCoords(player)) < DRAW_TEXT_DISTANCE then
                    -- Draw race name
                    Draw3DText(endurance.start.x, endurance.start.y, endurance.start.z-0.600, endurance.title, RACING_HUD_COLOR, 4, 0.3, 0.3)
                end

                -- When close enough, draw scores
                if GetDistanceBetweenCoords( endurance.start.x, endurance.start.y, endurance.start.z, GetEntityCoords(player)) < DRAW_SCORES_DISTANCE then
                    -- If we've received updated scores, display them
                    if raceState.scores ~= nil then
                        -- Get scores for this race and sort them
                        raceScores = raceState.scores[endurance.title]
                        if raceScores ~= nil then
                            local sortedScores = {}
                            for k, v in pairs(raceScores) do
                                table.insert(sortedScores, { key = k, value = v })
                            end
                            table.sort(sortedScores, function(a,b) return a.value.lap < b.value.lap end)

                            -- Create new list with scores to draw
                            local count = 0
                            drawScores = {}
                            for k, v in pairs(sortedScores) do
                                if count < DRAW_SCORES_COUNT_MAX then
                                    count = count + 1
                                    table.insert(drawScores, v.value)
                                end
                            end

                            -- Initialize offset
                            local zOffset = 0
                            if (#drawScores > #raceScoreColors) then
                                zOffset = 0.450*(#raceScoreColors) + 0.300*(#drawScores - #raceScoreColors - 1)
                            else
                                zOffset = 0.450*(#drawScores - 1)
                            end

                            -- Print scores above title
                            for k, score in pairs(drawScores) do
                                -- Draw score text with color coding
                                if (k > #raceScoreColors) then
                                    -- Draw score in white, decrement offset
                                    Draw3DText(endurance.start.x, endurance.start.y, endurance.start.z+zOffset, string.format("%s %ilap (%s)", score.car, (score.lap), score.player), {255,255,255,255}, 4, 0.13, 0.13)
                                    zOffset = zOffset - 0.300
                                else
                                    -- Draw score with color and larger text, decrement offset
                                    Draw3DText(endurance.start.x, endurance.start.y, endurance.start.z+zOffset, string.format("%s %ilap (%s)", score.car, (score.lap), score.player), raceScoreColors[k], 4, 0.22, 0.22)
                                    zOffset = zOffset - 0.450
                                end
                            end
                        end
                    end
                end
                
                -- When close enough, prompt player
                if GetDistanceBetweenCoords( endurance.start.x, endurance.start.y, endurance.start.z, GetEntityCoords(player)) < START_PROMPT_DISTANCE then
                    helpMessage("Press ~INPUT_CONTEXT~ to Race!")
                    if IsControlJustReleased(1, 51) and GetVehiclePedIsIn(player, false) ~= 0 then
                        -- Set race index, clear scores and trigger event to start the race
                        raceState.index = index
                        raceState.scores = nil
                        TriggerEvent("enduranceCountdown")
                        break
                    elseif IsControlJustReleased(1, 51) and GetVehiclePedIsIn(player, false) == 0 then
                        exports['mythic_notify']:SendAlert('error', 'You should enter vehicle RACE!')
                    end
                end
            end
        end
    end
end


-- Receive race scores from server and print
RegisterNetEvent("raceReceiveScores")
AddEventHandler("raceReceiveScores", function(scores)
    -- Save scores to state
    raceState.scores = scores
end)

RegisterNetEvent('showCountdown')
AddEventHandler('showCountdown', function()
    Citizen.CreateThread(function()
        -- Countdown timer
        local time = 0
        function setcountdown(x) time = GetGameTimer() + x*1000 end
        function getcountdown() return math.floor((time-GetGameTimer())/1000) end
        
        -- Count down to race start
        setcountdown(6)
        while getcountdown() > 0 do
            -- Update HUD
            Citizen.Wait(1)
            --FreezeEntityPosition(GetVehiclePedIsUsing(GetPlayerPed(-1)), true)
            DrawHudText(getcountdown(), {255,255,255,255},0.5,0.4,4.0,4.0)
            --FreezeEntityPosition(GetVehiclePedIsUsing(GetPlayerPed(-1)), false)
        end   
    end)
end)

-- Countdown race start with controls disabled
RegisterNetEvent("raceCountdown")
AddEventHandler("raceCountdown", function()
    -- Get race from index
    local race = races[raceState.index]
    
    -- Teleport player to start and set heading
    teleportToCoord(race.start.x, race.start.y, race.start.z + 4.0, race.start.heading)
    
    Citizen.CreateThread(function()
        -- Countdown timer
        local time = 0
        function setcountdown(x) time = GetGameTimer() + x*1000 end
        function getcountdown() return math.floor((time-GetGameTimer())/1000) end
        
        -- Count down to race start
        setcountdown(6)
        while getcountdown() > 0 do
            -- Update HUD
            Citizen.Wait(1)
            FreezeEntityPosition(GetVehiclePedIsUsing(GetPlayerPed(-1)), true)
            DrawHudText(getcountdown(), {255,255,255,255},0.5,0.4,4.0,4.0)
            FreezeEntityPosition(GetVehiclePedIsUsing(GetPlayerPed(-1)), false)
            -- Disable acceleration/reverse until race starts
            --DisableControlAction(2, 71, true)
            --DisableControlAction(2, 72, true)
        end
        
        -- Enable acceleration/reverse once race starts
        --EnableControlAction(2, 71, true)
        --EnableControlAction(2, 72, true)
        
        -- Start race
        TriggerEvent("raceRaceActive")
    end)
end)

-- Main race function
RegisterNetEvent("raceRaceActive")
AddEventHandler("raceRaceActive", function()
    -- Get race from index
    local race = races[raceState.index]
    
    -- Start a new timer
    raceState.startTime = GetGameTimer()
    Citizen.CreateThread(function()
        -- Create first checkpoint
        checkpoint = CreateCheckpoint(race.checkpoints[raceState.cP].type, race.checkpoints[raceState.cP].x,  race.checkpoints[raceState.cP].y,  race.checkpoints[raceState.cP].z + CHECKPOINT_Z_OFFSET, race.checkpoints[raceState.cP].x,race.checkpoints[raceState.cP].y, race.checkpoints[raceState.cP].z, race.checkpointRadius, 204, 204, 1, math.ceil(255*race.checkpointTransparency), 0)
        raceState.blip = AddBlipForCoord(race.checkpoints[raceState.cP].x, race.checkpoints[raceState.cP].y, race.checkpoints[raceState.cP].z)
        
        -- Set waypoints if enabled
        if race.showWaypoints == true then
            SetNewWaypoint(race.checkpoints[raceState.cP+1].x, race.checkpoints[raceState.cP+1].y)
        end
        
        -- While player is racing, do stuff
        while raceState.index ~= 0 do 
            Citizen.Wait(1)
            
            
            -- Stop race when L is pressed, clear and reset everything
            if IsControlJustReleased(0, 182) and GetLastInputMethod(0) then
                -- Delete checkpoint and raceState.blip
                DeleteCheckpoint(checkpoint)
                RemoveBlip(raceState.blip)
                
                -- Set new waypoint and teleport to the same spot 
                SetNewWaypoint(race.start.x, race.start.y)
                teleportToCoord(race.start.x, race.start.y, race.start.z + 4.0, race.start.heading)
                
                -- Clear racing index and break
                raceState.index = 0
                break
            end

            -- Draw checkpoint and time HUD above minimap
            local checkpointDist = math.floor(GetDistanceBetweenCoords(race.checkpoints[raceState.cP].x,  race.checkpoints[raceState.cP].y,  race.checkpoints[raceState.cP].z, GetEntityCoords(GetPlayerPed(-1))))
            if race.laps > 1 and race.FlylapandRolling == true then
            DrawHudText(string.format("Fly Lap: %i / %i", Fly, Flylap), RACING_HUD_COLOR, 0.015, 0.600, 0.5, 0.5)
            DrawHudText(string.format("Rolling Lap: %i / %i", Rolling, Rollinglap), RACING_HUD_COLOR, 0.015, 0.635, 0.5, 0.5)
            end
            DrawHudText(string.format("Lap: %i / %i", raceState.lap, race.laps), RACING_HUD_COLOR, 0.015, 0.675, 0.5, 0.5)
            DrawHudText(("%.3fs"):format((GetGameTimer() - raceState.startTime)/1000), RACING_HUD_COLOR, 0.015, 0.705, 0.7, 0.7)
            DrawHudText(string.format("Checkpoint %i / %i (%d m)", raceState.cP, #race.checkpoints, checkpointDist), RACING_HUD_COLOR, 0.015, 0.745, 0.5, 0.5)

            -- Check distance from checkpoint
            if GetDistanceBetweenCoords(race.checkpoints[raceState.cP].x,  race.checkpoints[raceState.cP].y,  race.checkpoints[raceState.cP].z, GetEntityCoords(GetPlayerPed(-1))) < race.checkpointRadius then
                -- Delete checkpoint and map raceState.blip, 
                DeleteCheckpoint(checkpoint)
                RemoveBlip(raceState.blip)
                
                -- Play checkpoint sound
                PlaySoundFrontend(-1, "RACE_PLACED", "HUD_AWARDS")
                
                -- Check if at finish line
                if raceState.cP == #(race.checkpoints) and raceState.lap == race.laps then
                    -- Save time and play sound for finish line
                    
                    local finishTime = (GetGameTimer() - raceState.startTime)
                    PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds")
                    
                    -- Get vehicle name and create score
                    local aheadVehHash = GetEntityModel(GetVehiclePedIsUsing(GetPlayerPed(-1)))
                    local aheadVehNameText = GetLabelText(GetDisplayNameFromVehicleModel(aheadVehHash))
                    local score = {}
                    score.player = GetPlayerName(PlayerId())
                    score.time = finishTime
                    score.car = aheadVehNameText
                    minutes = finishTime * (0.001/60)
                    
                    -- Send server event with score and message, move this to server eventually
                    -- **Backup
                    --message = string.format("Player " .. GetPlayerName(PlayerId()) .. " finished " .. race.title .. " using " .. aheadVehNameText .. " in " .. (finishTime / 1000) .. "  s")
                    --TriggerServerEvent('racePlayerFinished', GetPlayerName(PlayerId()), message, race.title, score)

                    message = string.format("Player " .. GetPlayerName(PlayerId()) .. " finished " .. race.title .. " using " .. aheadVehNameText .. " in " .. (minutes) .. " minutes " .. finishTime .. " milisec")
                    TriggerServerEvent('racePlayerFinished', GetPlayerName(PlayerId()), message, race.title, score)


                    TriggerServerEvent('Reward',pedplayer)
                    
                    -- Clear racing index and break
                    raceState.index = 0
                    break
                -- Check if lap is finish if not race more lap
                elseif raceState.cP == #(race.checkpoints) and raceState.lap < race.laps then
                    raceState.cP = 0
                    if race.laps > 1 then
                        if race.FlylapandRolling == true then
                            if Fly < Flylap then
                                Fly = Fly + 1
                            elseif Fly == Flylap and Rolling < Rollinglap then
                                Rolling = Rolling +1
                            elseif Fly == Flylap and Rolling == Rollinglap then
                                raceState.lap = raceState.lap + 1
                            end
                        else
                            raceState.lap = raceState.lap + 1
                        end
                    end
                end

                -- Increment checkpoint counter and create next checkpoint
                raceState.cP = math.ceil(raceState.cP+1)
                if race.checkpoints[raceState.cP].type == 5 then
                    -- Create normal checkpoint
                    checkpoint = CreateCheckpoint(race.checkpoints[raceState.cP].type, race.checkpoints[raceState.cP].x,  race.checkpoints[raceState.cP].y,  race.checkpoints[raceState.cP].z + CHECKPOINT_Z_OFFSET, race.checkpoints[raceState.cP].x, race.checkpoints[raceState.cP].y, race.checkpoints[raceState.cP].z, race.checkpointRadius, 204, 204, 1, math.ceil(255*race.checkpointTransparency), 0)
                    raceState.blip = AddBlipForCoord(race.checkpoints[raceState.cP].x, race.checkpoints[raceState.cP].y, race.checkpoints[raceState.cP].z)
                    SetNewWaypoint(race.checkpoints[raceState.cP+1].x, race.checkpoints[raceState.cP+1].y)
                elseif race.checkpoints[raceState.cP].type == 9 then
                    -- Create finish line
                    checkpoint = CreateCheckpoint(race.checkpoints[raceState.cP].type, race.checkpoints[raceState.cP].x,  race.checkpoints[raceState.cP].y,  race.checkpoints[raceState.cP].z + 4.0, race.checkpoints[raceState.cP].x, race.checkpoints[raceState.cP].y, race.checkpoints[raceState.cP].z, race.checkpointRadius, 204, 204, 1, math.ceil(255*race.checkpointTransparency), 0)
                    raceState.blip = AddBlipForCoord(race.checkpoints[raceState.cP].x, race.checkpoints[raceState.cP].y, race.checkpoints[raceState.cP].z)
                    SetNewWaypoint(race.checkpoints[raceState.cP].x, race.checkpoints[raceState.cP].y)
                end
            end
        end
                
        -- Reset race
        preRace()
    end)
end)

RegisterNetEvent("enduranceCountdown")
AddEventHandler("enduranceCountdown", function()
    -- Get race from index
    local endurance = endurances[raceState.index]

    
    -- Teleport player to start and set heading
    teleportToCoord(endurance.start.x, endurance.start.y, endurance.start.z + 4.0, endurance.start.heading)
    
    Citizen.CreateThread(function()
        -- Countdown timer
        local time = 0
        function setcountdown(x) time = GetGameTimer() + x*1000 end
        function getcountdown() return math.floor((time-GetGameTimer())/1000) end
        
        -- Count down to race start
        setcountdown(6)
        while getcountdown() > 0 do
            -- Update HUD
            Citizen.Wait(1)
            FreezeEntityPosition(GetVehiclePedIsUsing(GetPlayerPed(-1)), true)
            DrawHudText(getcountdown(), {255,255,255,255},0.5,0.4,4.0,4.0)
            FreezeEntityPosition(GetVehiclePedIsUsing(GetPlayerPed(-1)), false)
            -- Disable acceleration/reverse until race starts
            --DisableControlAction(2, 71, true)
            --DisableControlAction(2, 72, true)
        end
        
        -- Enable acceleration/reverse once race starts
        --EnableControlAction(2, 71, true)
        --EnableControlAction(2, 72, true)
        
        -- Start race
        TriggerEvent("enduranceRaceActive")
    end)
end)

RegisterNetEvent("enduranceRaceActive")
AddEventHandler("enduranceRaceActive", function()
    -- Get race from index
    local endurance = endurances[raceState.index]
    local min = minutes
    local sec = seconds
    
    -- Start a new timer
    raceState.startTime = GetGameTimer()
    Citizen.CreateThread(function()
        -- Create first checkpoint
        checkpoint = CreateCheckpoint(endurance.checkpoints[raceState.cP].type, endurance.checkpoints[raceState.cP].x,  endurance.checkpoints[raceState.cP].y,  endurance.checkpoints[raceState.cP].z + CHECKPOINT_Z_OFFSET, endurance.checkpoints[raceState.cP].x,endurance.checkpoints[raceState.cP].y, endurance.checkpoints[raceState.cP].z, endurance.checkpointRadius, 204, 204, 1, math.ceil(255*endurance.checkpointTransparency), 0)
        raceState.blip = AddBlipForCoord(endurance.checkpoints[raceState.cP].x, endurance.checkpoints[raceState.cP].y, endurance.checkpoints[raceState.cP].z)
        -- Set waypoints if enabled
        if endurance.showWaypoints == true then
            SetNewWaypoint(endurance.checkpoints[raceState.cP+1].x, endurance.checkpoints[raceState.cP+1].y)
        end

        CreateThread(function()
            while (min > 0 or sec > 0) and raceState.index ~= 0 do
                Citizen.Wait(1000)
                if sec == 0 then
                    if min > 0 then
                        min = min - 1
                        sec = 59
                    end
                else
                    sec = sec - 1
                end
            end
        end)
        
        
        
        -- While player is racing, do stuff
        while raceState.index ~= 0 do 
            Citizen.Wait(1)
            
            -- Stop race when L is pressed, clear and reset everything
            if IsControlJustReleased(0, 182) and GetLastInputMethod(0) then
                -- Delete checkpoint and raceState.blip
                DeleteCheckpoint(checkpoint)
                RemoveBlip(raceState.blip)
                
                -- Set new waypoint and teleport to the same spot 
                SetNewWaypoint(endurance.start.x, endurance.start.y)
                teleportToCoord(endurance.start.x, endurance.start.y, endurance.start.z + 4.0, endurance.start.heading)
                
                -- Clear racing index and break
                raceState.index = 0
                break
            end

            -- Draw checkpoint and time HUD above minimap
            local checkpointDist = math.floor(GetDistanceBetweenCoords(endurance.checkpoints[raceState.cP].x,  endurance.checkpoints[raceState.cP].y,  endurance.checkpoints[raceState.cP].z, GetEntityCoords(GetPlayerPed(-1))))
            DrawHudText(string.format("Lap: %i", raceState.lap), RACING_HUD_COLOR, 0.015, 0.595, 0.5, 0.5)
            DrawHudText(string.format("%02d:%02d", min, sec), RACING_HUD_COLOR, 0.015, 0.625, 0.7, 0.7)
            DrawHudText(string.format("Checkpoint %i / %i (%d m)", raceState.cP, #endurance.checkpoints, checkpointDist), RACING_HUD_COLOR, 0.015, 0.675, 0.5, 0.5)

            -- Check if finish
            if min == 0 and sec == 0 then
                -- Save time and play sound for finish line
                
                local finishTime = (GetGameTimer() - raceState.startTime)
                PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds")

                
                -- Get vehicle name and create score
                local aheadVehHash = GetEntityModel(GetVehiclePedIsUsing(GetPlayerPed(-1)))
                local aheadVehNameText = GetLabelText(GetDisplayNameFromVehicleModel(aheadVehHash))
                local score = {}
                score.player = GetPlayerName(PlayerId())
                score.lap = raceState.lap
                score.car = aheadVehNameText
                -- Send server event with score and message, move this to server eventually
                message = string.format("Player " .. GetPlayerName(PlayerId()) .. " finished " .. endurance.title .. " using " .. aheadVehNameText .. " in " .. (raceState.lap) .. " laps and" .. raceState.cP .. " checkpoints")
                TriggerServerEvent('Finishedtext', GetPlayerName(PlayerId()), message)


                --TriggerServerEvent('Reward',pedplayer)
                DeleteCheckpoint(checkpoint)
                RemoveBlip(raceState.blip)
                -- Clear racing index and break
                raceState.index = 0
                min = minutes
                sec = seconds

            end
            -- Check distance from checkpoint
            if GetDistanceBetweenCoords(endurance.checkpoints[raceState.cP].x,  endurance.checkpoints[raceState.cP].y,  endurance.checkpoints[raceState.cP].z, GetEntityCoords(GetPlayerPed(-1))) < endurance.checkpointRadius then
                -- Delete checkpoint and map raceState.blip, 
                DeleteCheckpoint(checkpoint)
                RemoveBlip(raceState.blip)
                
                -- Play checkpoint sound
                PlaySoundFrontend(-1, "RACE_PLACED", "HUD_AWARDS")
                
                -- Check if lap is finish if not race more lap
                if raceState.cP == #(endurance.checkpoints) and (min > 0 or sec > 0) then
                    raceState.cP = 0
                    raceState.lap = raceState.lap + 1
                end

                -- Increment checkpoint counter and create next checkpoint
                raceState.cP = math.ceil(raceState.cP+1)
                if endurance.checkpoints[raceState.cP].type == 5 then
                    -- Create normal checkpoint
                    checkpoint = CreateCheckpoint(endurance.checkpoints[raceState.cP].type, endurance.checkpoints[raceState.cP].x,  endurance.checkpoints[raceState.cP].y,  endurance.checkpoints[raceState.cP].z + CHECKPOINT_Z_OFFSET, endurance.checkpoints[raceState.cP].x, endurance.checkpoints[raceState.cP].y, endurance.checkpoints[raceState.cP].z, endurance.checkpointRadius, 204, 204, 1, math.ceil(255*endurance.checkpointTransparency), 0)
                    raceState.blip = AddBlipForCoord(endurance.checkpoints[raceState.cP].x, endurance.checkpoints[raceState.cP].y, endurance.checkpoints[raceState.cP].z)
                    SetNewWaypoint(endurance.checkpoints[raceState.cP+1].x, endurance.checkpoints[raceState.cP+1].y)
                elseif endurance.checkpoints[raceState.cP].type == 9 then
                    -- Create finish line
                    checkpoint = CreateCheckpoint(endurance.checkpoints[raceState.cP].type, endurance.checkpoints[raceState.cP].x,  endurance.checkpoints[raceState.cP].y,  endurance.checkpoints[raceState.cP].z + 4.0, endurance.checkpoints[raceState.cP].x, endurance.checkpoints[raceState.cP].y, endurance.checkpoints[raceState.cP].z, endurance.checkpointRadius, 204, 204, 1, math.ceil(255*endurance.checkpointTransparency), 0)
                    raceState.blip = AddBlipForCoord(endurance.checkpoints[raceState.cP].x, endurance.checkpoints[raceState.cP].y, endurance.checkpoints[raceState.cP].z)
                    SetNewWaypoint(endurance.checkpoints[raceState.cP].x, endurance.checkpoints[raceState.cP].y)
                end
            end
        end
                
        -- Reset race
        preRace()
    end)
end)

-- Create map blips for all enabled tracks
Citizen.CreateThread(function()
    for _, race in pairs(races) do
        if race.isEnabled then
            race.blip = AddBlipForCoord(race.start.x, race.start.y, race.start.z)
            SetBlipSprite(race.blip, race.mapBlipId)
            SetBlipDisplay(race.blip, 4)
            SetBlipScale(race.blip, 1.0)
            SetBlipColour(race.blip, race.mapBlipColor)
            SetBlipAsShortRange(race.blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(race.title)
            EndTextCommandSetBlipName(race.blip)
        end
    end
    for _, endurance in pairs(endurances) do
        if endurance.isEnabled then
            endurance.blip = AddBlipForCoord(endurance.start.x, endurance.start.y, endurance.start.z)
            SetBlipSprite(endurance.blip, endurance.mapBlipId)
            SetBlipDisplay(endurance.blip, 4)
            SetBlipScale(endurance.blip, 1.0)
            SetBlipColour(endurance.blip, endurance.mapBlipColor)
            SetBlipAsShortRange(endurance.blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(endurance.title)
            EndTextCommandSetBlipName(endurance.blip)
        end
    end
end)

-- Utility function to teleport to coordinates
function teleportToCoord(x, y, z, heading)
    Citizen.Wait(1)
    local player = GetPlayerPed(-1)
    if IsPedInAnyVehicle(player, true) then
        SetEntityCoords(GetVehiclePedIsUsing(player), x, y, z)
        Citizen.Wait(100)
        SetEntityHeading(GetVehiclePedIsUsing(player), heading)
    else
        SetEntityCoords(player, x, y, z)
        Citizen.Wait(100)
        SetEntityHeading(player, heading)
    end
end

-- Utility function to display help message
function helpMessage(text, duration)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, duration or 5000)
end

-- Utility function to display 3D text
function Draw3DText(x,y,z,textInput,colour,fontId,scaleX,scaleY)
    local px,py,pz=table.unpack(GetGameplayCamCoords())
    local dist = GetDistanceBetweenCoords(px,py,pz, x,y,z, 1)
    local scale = (1/dist)*20
    local fov = (1/GetGameplayCamFov())*100
    local scale = scale*fov

    SetTextScale(scaleX*scale, scaleY*scale)
    SetTextFont(fontId)
    SetTextProportional(1)
    local colourr,colourg,colourb,coloura = table.unpack(colour)
    SetTextColour(colourr,colourg,colourb, coloura)
    SetTextDropshadow(2, 1, 1, 1, 255)
    SetTextEdge(3, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(textInput)
    SetDrawOrigin(x,y,z+2, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

-- Utility function to display HUD text
function DrawHudText(text,colour,coordsx,coordsy,scalex,scaley)
    SetTextFont(4)
    SetTextProportional(7)
    SetTextScale(scalex, scaley)
    local colourr,colourg,colourb,coloura = table.unpack(colour)
    SetTextColour(colourr,colourg,colourb, coloura)
    SetTextDropshadow(0, 0, 0, 0, coloura)
    SetTextEdge(1, 0, 0, 0, coloura)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(coordsx,coordsy)
end