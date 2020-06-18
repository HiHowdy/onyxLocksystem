ESX = nil

local vehicles = {}
local searchedVehicles = {}
local pickedVehicled = {}
local hasCheckedOwnedVehs = false
local lockDisable = false

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    end
end)

function givePlayerKeys(plate)
    local vehPlate = plate
    table.insert(vehicles, vehPlate)
end

function hasToggledLock()
    lockDisable = true
    Wait(100)
    lockDisable = false
end

function playLockAnim(vehicle)
    local dict = "anim@mp_player_intmenu@key_fob@"
    RequestAnimDict(dict)

    local veh = vehicle

    while not HasAnimDictLoaded do
        Citizen.Wait(0)
    end

    if not IsPedInAnyVehicle(GetPlayerPed(-1), true) then
        TaskPlayAnim(PlayerPedId(), dict, "fob_click_fp", 8.0, 8.0, -1, 48, 1, false, false, false)
    end
end

function toggleLock(vehicle)
    local veh = vehicle

    local plate = GetVehicleNumberPlateText(veh)
    local lockStatus = GetVehicleDoorLockStatus(veh)
    if hasKeys(plate) and not lockDisable then
        print('lock status: ' .. lockStatus)
        if lockStatus == 1 then
            SetVehicleDoorsLocked(veh, 2)
            SetVehicleDoorsLockedForAllPlayers(veh, true)
            exports['mythic_notify']:DoHudText('inform', 'Vehicle Locked')
            playLockAnim()
            hasToggledLock()
        elseif lockStatus == 2 then
            SetVehicleDoorsLocked(veh, 1)
            SetVehicleDoorsLockedForAllPlayers(veh, false)
            exports['mythic_notify']:DoHudText('inform', 'Vehicle Unlocked')
            playLockAnim(veh)
            hasToggledLock()
        else
            SetVehicleDoorsLocked(veh, 2)
            SetVehicleDoorsLockedForAllPlayers(veh, true)
            exports['mythic_notify']:DoHudText('inform', 'Vehicle Locked')
            playLockAnim()
            hasToggledLock()
        end
        if not IsPedInAnyVehicle(GetPlayerPed(-1), true) then
            Wait(500)
            local flickers = 0
            while flickers < 2 do
                SetVehicleLights(veh, 2)
                Wait(170)
                SetVehicleLights(veh, 0)
                flickers = flickers + 1
                Wait(170)
            end
        end
    end
end

RegisterNetEvent('onyx:pickDoor')
AddEventHandler('onyx:pickDoor', function()
    -- TODO: Lockpicking vehicle doors to gain access
end)

-- Locking vehicles
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local pos = GetEntityCoords(GetPlayerPed(-1))
        if IsControlJustReleased(0, 303) then
            if IsPedInAnyVehicle(GetPlayerPed(-1), false) then
                local veh = GetVehiclePedIsIn(GetPlayerPed(-1), false)
                toggleLock(veh)
            else
                local veh = GetClosestVehicle(pos.x, pos.y, pos.z, 3.0, 0, 70)
                if DoesEntityExist(veh) then
                    toggleLock(veh)
                end
            end
        end

        -- TODO: Unable to gain access to vehicles without a lockpick or keys
        -- local enteringVeh = GetVehiclePedIsTryingToEnter(GetPlayerPed(-1))
        -- local enteringPlate = GetVehicleNumberPlateText(enteringVeh)

        -- if not hasKeys(entertingPlate) then
        --     SetVehicleDoorsLocked(enteringVeh, 2)
        -- end
    end
end)

local isSearching = false
local isHotwiring = false

-- Has entered vehicle without keys
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local ped = GetPlayerPed(-1)
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped)
            local driver = GetPedInVehicleSeat(veh, -1)
            local plate = GetVehicleNumberPlateText(veh)
            if driver == ped then
                if not hasKeys(plate) and not isHotwiring and not isSearching then
                    local pos = GetEntityCoords(ped)
                    if hasBeenSearched(plate) then
                        DrawText3Ds(pos.x, pos.y, pos.z + 0.2, 'Press ~y~[H] ~w~to hotwire')
                    else
                        DrawText3Ds(pos.x, pos.y, pos.z + 0.2, 'Press ~y~[H] ~w~to hotwire or ~g~[G] ~w~to search')
                    end
                    SetVehicleEngineOn(veh, false, true, true)
                    -- Searching
                    if IsControlJustReleased(0, 47) and not isSearching and not hasBeenSearched(plate) then -- G
                        if hasBeenSearched(plate) then
                            isSearching = true
                            exports['progressBars']:startUI(5000, "Searching Vehicle")
                            Citizen.Wait(5000)
                            isSearching = false
                            exports['mythic_notify']:DoHudText('error', 'You search the vehicle and find nothing')
                        else
                            local rnd = math.random(1, 8)
                            if rnd == 4 then
                                isSearching = true
                                exports['progressBars']:startUI(6000, "Searching Vehicle")
                                Citizen.Wait(6000)
                                isSearching = false
                                exports['mythic_notify']:DoHudText('inform', "You found the keys for plate [" .. plate .. ']')
                                table.insert(vehicles, plate)
                                TriggerServerEvent('onyx:updateSearchedVehTable', plate)
                                table.insert(searchedVehicles, plate)
                            else
                                isSearching = true
                                exports['progressBars']:startUI(6000, "Searching Vehicle")
                                Citizen.Wait(6000)
                                isSearching = false
                                exports['mythic_notify']:DoHudText('error', 'You search the vehicle and find nothing')

                                -- Update veh table so other players cant search the same vehicle
                                TriggerServerEvent('onyx:updateSearchedVehTable', plate)
                                table.insert(searchedVehicles, plate)
                            end
                        end
                    end
                    -- Hotwiring
                    if IsControlJustReleased(0, 74) and not isHotwiring then -- E
                        TriggerServerEvent('onyx:reqHotwiring', plate)
                    end
                else
                    SetVehicleEngineOn(veh, true, true, false)
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if isHotwiring then
            DisableControlAction(0, 75, true)  -- Disable exit vehicle
            DisableControlAction(0, 74, true)  -- Lights
        end
    end
end)

RegisterNetEvent('onyx:updatePlates')
AddEventHandler('onyx:updatePlates', function(plate)
    table.insert(vehicles, plate)
end)

RegisterNetEvent('onyx:beginHotwire')
AddEventHandler('onyx:beginHotwire', function(plate)
    local veh = GetVehiclePedIsIn(GetPlayerPed(-1), false)
    RequestAnimDict("veh@std@ds@base")

    while not HasAnimDictLoaded("veh@std@ds@base") do
        Citizen.Wait(100)
	end
    local time = 12500 -- in ms

    local vehPlate = plate
    isHotwiring = true

    SetVehicleEngineOn(veh, false, true, true)
    SetVehicleLights(veh, 0)
    
    if Config.HotwireAlarmEnabled then
        local alarmChance = math.random(1, Config.HotwireAlarmChance)

        if alarmChance == 1 then
            SetVehicleAlarm(veh, true)
            StartVehicleAlarm(veh)
        end
    end

    exports['progressBars']:startUI(time, "Hotwiring [Stage 1]")
    TaskPlayAnim(PlayerPedId(), "veh@std@ds@base", "hotwire", 8.0, 8.0, -1, 1, 0.3, true, true, true)
    Citizen.Wait(time)
    Wait(1000)
    exports['progressBars']:startUI(time, "Hotwiring [Stage 2]")
    TaskPlayAnim(PlayerPedId(), "veh@std@ds@base", "hotwire", 8.0, 8.0, -1, 1, 0.6, true, true, true)
    Citizen.Wait(time)
    Wait(1000)
    exports['progressBars']:startUI(time, "Hotwiring [Stage 3]")
    TaskPlayAnim(PlayerPedId(), "veh@std@ds@base", "hotwire", 8.0, 8.0, -1, 1, 0.4, true, true, true)
    Citizen.Wait(time)
    Wait(1000)
    table.insert(vehicles, vehPlate)
    StopAnimTask(PlayerPedId(), 'veh@std@ds@base', 'hotwire', 1.0)
    isHotwiring = false
    SetVehicleEngineOn(veh, true, true, false)
end)

local isRobbing = false
local canRob = false
local prevPed = false
local prevCar = false

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local foundEnt, aimingEnt = GetEntityPlayerIsFreeAimingAt(PlayerId())
        local entPos = GetEntityCoords(aimingEnt)
        local pos = GetEntityCoords(GetPlayerPed(-1))
        local dist = GetDistanceBetweenCoords(pos.x, pos.y, pos.z, entPos.x, entPos.y, entPos.z, true)

        if foundEnt and prevPed ~= aimingEnt and IsPedInAnyVehicle(aimingEnt, false) and IsPedArmed(PlayerPedId(), 7) and dist < 20.0 and not IsPedInAnyVehicle(PlayerPedId()) then
            if not IsPedAPlayer(aimingEnt) then
                prevPed = aimingEnt
                Wait(math.random(300, 700))
                local dict = "random@mugging3"
                RequestAnimDict(dict)
                while not HasAnimDictLoaded(dict) do
                    Citizen.Wait(0)
                end
                local rand = math.random(1, 10)

                if rand > 4 then
                    prevCar = GetVehiclePedIsIn(aimingEnt, false)
                    TaskLeaveVehicle(aimingEnt, prevCar)
                    SetVehicleEngineOn(prevCar, false, false, false)
                    while IsPedInAnyVehicle(aimingEnt, false) do
                        Citizen.Wait(0)
                    end
                    SetBlockingOfNonTemporaryEvents(aimingEnt, true)
                    ClearPedTasksImmediately(aimingEnt)
                    TaskPlayAnim(aimingEnt, dict, "handsup_standing_base", 8.0, -8.0, 0.01, 49, 0, 0, 0, 0)
                    ResetPedLastVehicle(aimingEnt)
                    TaskWanderInArea(aimingEnt, 0, 0, 0, 20, 100, 100)
                    canRob = true
                    beginRobTimer(aimingEnt)
                end
            end
        end
    end
end)

local canTakeKeys = true

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if canRob and not IsEntityDead(prevPed) and IsPlayerFreeAiming(PlayerId()) then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local entPos = GetEntityCoords(prevPed)
            if GetDistanceBetweenCoords(pos.x, pos.y, pos.z, entPos.x, entPos.y, entPos.z, false) < 3.5 then
                DrawText3Ds(entPos.x, entPos.y, entPos.z, 'Press ~y~[E]~w~ to rob')
                if IsControlJustReleased(0, 38) then
                    local rand = math.random(1, 10)
                    if rand == 1 then
                        Wait(400)
                        exports['mythic_notify']:DoHudText('inform', 'They do not hand over the keys')
                    else
                        local plate = GetVehicleNumberPlateText(prevCar)
                        exports['progressBars']:startUI(3600, "Taking Keys")
                        Wait(3600)
                        givePlayerKeys(plate)
                        exports['mythic_notify']:DoHudText('inform', 'You rob the keys')
                    end
                    SetBlockingOfNonTemporaryEvents(prevPed, false)
                    canRob = false
                end
            end
        end
    end
end)

-- if GetDistanceBetweenCoords(pos.x, pos.y, pos.z, entPos.x, entPos.y, entPos.z, false) < 4.5 and canRob then
--     if not IsEntityDead(aimingEnt) then
--         DrawText3Ds(entPos.x, entPos.y, entPos.z, 'Press ~y~[E]~w~ to rob')
--         print('message should pop up')
--         if IsControlJustReleased(0, 38) then
--             local plate = GetVehicleNumberPlateText(prevCar)
--             exports['progressBars']:startUI(3500, "Taking Keys")
--             Wait(3600)
--             givePlayerKeys(plate)
--             exports['mythic_notify']:DoHudText('inform', 'You rob the keys')
--             canRob = false
--         end
--     end

RegisterCommand('weapon', function(source, args)
    GiveWeaponToPed(GetPlayerPed(-1), "WEAPON_PISTOL", 1000, false, false)
end)

function beginRobTimer(entity)
    local timer = 18

    while canRob do
        timer = timer - 1
        if timer == 0 then
            canRob = false
            SetBlockingOfNonTemporaryEvents(entity, false)
        end
        Wait(1000)
    end
end

function isNpc(ped)
    if IsPedAPlayer(ped) then
        return false
    else
        return true
    end
end


RegisterNetEvent('onyx:returnSearchedVehTable')
AddEventHandler('onyx:returnSearchedVehTable', function(plate)
    local vehPlate = plate
    table.insert(searchedVehicles, vehPlate)
end)

function hasBeenSearched(plate)
    local vehPlate = plate
    for k, v in ipairs(searchedVehicles) do
        if v == vehPlate then
            return true
        end
    end
    return false
end

function hasKeys(plate)
    local vehPlate = plate
    for k, v in ipairs(vehicles) do
        if v == vehPlate or v == vehPlate .. ' ' then
            return true
        end
    end
    return false
end

function DrawText3Ds(x, y, z, text)
	local onScreen,_x,_y=World3dToScreen2d(x,y,z)
	local factor = #text / 460
	local px,py,pz=table.unpack(GetGameplayCamCoords())
	
	SetTextScale(0.3, 0.3)
	SetTextFont(6)
	SetTextProportional(1)
	SetTextColour(255, 255, 255, 160)
	SetTextEntry("STRING")
	SetTextCentre(1)
	AddTextComponentString(text)
	DrawText(_x,_y)
	DrawRect(_x,_y + 0.0115, 0.02 + factor, 0.027, 28, 28, 28, 95)
end