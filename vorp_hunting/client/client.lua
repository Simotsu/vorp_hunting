---@diagnostic disable: undefined-global
local peltz = {}
local prompts = GetRandomIntInRange(0, 0xffffff)
local playerJob
local openButcher
local pressed = false
local entities = {}
local lastUsageTime = 0
local cooldownTime = Config.BaitCooldownTimer  

RegisterNetEvent("vorp:SelectedCharacter") -- NPC loads after selecting character
AddEventHandler("vorp:SelectedCharacter", function(charid)
    if Config.butcherfunction then
        StartButchers()
    end
end)

RegisterNetEvent('simotsu_hunting:findJob')
AddEventHandler('simotsu_hunting:findJob', function(job)
    playerJob = job
end)

RegisterNetEvent('simotsu_hunting:finalizeReward')
AddEventHandler('simotsu_hunting:finalizeReward', function(entity, horse)
    -- Remove Animal/Pelt
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
        Citizen.InvokeNative(0x5E94EA09E7207C16, entity) --Delete_2 Entity
    end

    -- Remove pelt from horse
    if horse and DoesEntityExist(horse.horse) then
        Citizen.InvokeNative(0x627F7F3A0C4C51FF, horse.horse, horse.pelt)
    end
end)

RegisterNetEvent("simotsu_hunting:unlock", function()
    pressed = false
end)

function StartButchers() -- Loading Butchers Function
    for i, v in ipairs(Config.Butchers) do
        if v.butcherped then
            local hashModel = joaat(v.npcmodel)
            if IsModelValid(hashModel) then
                RequestModel(hashModel, false)
                while not HasModelLoaded(hashModel) do
                    Wait(100)
                end
            else
                return print(v.npcmodel .. " is not valid") -- Concatenations
            end
            -- Spawn Ped
            local npc = CreatePed(hashModel, v.coords.x, v.coords.y, v.coords.z, v.heading, false, true, true, true)
            repeat Wait(0) until DoesEntityExist(npc)
            Citizen.InvokeNative(0x283978A15512B2FE, npc, true) -- SetRandomOutfitVariation
            SetEntityNoCollisionEntity(PlayerPedId(), npc, false)
            SetEntityCanBeDamaged(npc, false)
            SetEntityInvincible(npc, true)
            Wait(1000)
            FreezeEntityPosition(npc, true)            -- NPC can't escape
            SetBlockingOfNonTemporaryEvents(npc, true) -- NPC can't be scared
            Config.Butchers[i].NpcHandle = npc
        end
        if v.showblip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, v.coords) -- Blip Creation
            SetBlipSprite(blip, v.blip, true)                                           -- Blip Texture
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, v.butchername)               -- Name of Blip
            Config.Butchers[i].BlipHandle = blip
        end
    end
end

local function awardQuality(quality, entity, horse, cb)
    local skinFound = nil
    for k, v in pairs(Config.Animals) do
        if (quality == v.perfect) or (quality == v.good) or (quality == v.poor) then
            skinFound = k
            break -- no need to keep looping through the config; micro-optimizations ftw!
        end
    end

    if skinFound then
        TriggerServerEvent("simotsu_hunting:giveReward", "pelt", {
            model = skinFound,
            quality = quality,
            entity = entity,
            horse = horse
        }, false)
        cb()
    end
end

local function SellAnimal()                                               -- Selling animal function
    local horse = Citizen.InvokeNative(0x4C8B59171957BCF7, PlayerPedId()) -- _GET_LAST_MOUNT
    local alreadysoldanimal = false
    -- Logic for if a horse is detected

    if horse and DoesEntityExist(horse) and NetworkGetEntityOwner(horse) == PlayerId() then
        -- Check if the horse is holding anything
        if Citizen.InvokeNative(0xA911EE21EDF69DAF, horse) then              -- IS_PED_CARRYING_SOMETHING
            local holding2 = Citizen.InvokeNative(0xD806CD2A4F2C2996, horse) -- _GET_FIRST_ENTITY_PED_IS_CARRYING           
            print(Citizen.InvokeNative(0x31FEF6A20F00B963, holding2))
            local model2 = GetEntityModel(holding2)

            local quality2 = Citizen.InvokeNative(0x31FEF6A20F00B963, holding2) --_GET_CARRIABLE_FROM_ENTITY
            if Config.Animals[model2] then                                      -- Fallback for paying for non pelts'
                alreadysoldanimal = true
                local netid = NetworkGetNetworkIdFromEntity(holding2)
                TriggerServerEvent("simotsu_hunting:giveReward", "carcass",
                    { model = model2, entity = holding2, netid = netid }, false)
            elseif (quality2 ~= false and quality2 ~= nil) then --Award pelt if pelt is on horse
                awardQuality(quality2, holding2, nil, function()
                    alreadysoldanimal = true
                end)
            end
        end

        if Citizen.InvokeNative(0x0CEEB6F4780B1F2F, horse, 0) then -- _GET_PELT_FROM_HORSE
            for x = #peltz, 1, -1 do
                local y = peltz[x]
                if not y.sold then
                    y.sold = true
                    local q = Citizen.InvokeNative(0x0CEEB6F4780B1F2F, horse, x - 1)
                    awardQuality(q, nil, { horse = horse, pelt = q }, function()
                        alreadysoldanimal = true
                    end)
                end
                table.remove(peltz, x)
            end
        end
    end

    local holding = Citizen.InvokeNative(0xD806CD2A4F2C2996, PlayerPedId()) -- ISPEDHOLDING
    if holding and alreadysoldanimal == false then                          -- Checking if you are holding an animal
        local quality = Citizen.InvokeNative(0x31FEF6A20F00B963, holding)   -- _GET_CARRIABLE_FROM_ENTITY

        local model = GetEntityModel(holding)

        if holding then
            local entityNetworkId = NetworkGetNetworkIdFromEntity(holding)
            SetNetworkIdExistsOnAllMachines(entityNetworkId, true)
            local entityId = NetworkGetEntityFromNetworkId(entityNetworkId)

            if not NetworkHasControlOfEntity(entityId) then
                NetworkRequestControlOfEntity(entityId)
                NetworkRequestControlOfNetworkId(entityNetworkId)
            end
        end

        if Config.Animals[model] then -- Paying for animals
            alreadysoldanimal = true
            local netid = NetworkGetNetworkIdFromEntity(holding)
            return TriggerServerEvent("simotsu_hunting:giveReward", "carcass",
                { model = model, entity = holding, netid = netid }, false)
        else -- Paying for skins
            awardQuality(quality, holding, nil, function()
                alreadysoldanimal = true
            end)
        end
    end

    if (alreadysoldanimal == false) then
        if holding == false then
            TriggerEvent("vorp:TipRight", Config.Language.NotHoldingAnimal, 4000)
        else
            TriggerEvent("vorp:TipRight", Config.Language.NotInTheButcher, 4000)
        end
    end

    SetTimeout(5000, function()
        pressed = false
    end)
end

function Keys(table)
    local num = 0
    for k, v in pairs(table) do
        num = num + 1
    end
    return num
end

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for key, value in ipairs(Config.Butchers) do
        if value.NpcHandle then
            DeleteEntity(value.NpcHandle)
        end
        if value.BlipHandle then
            RemoveBlip(value.BlipHandle)
        end
    end
end)

Citizen.CreateThread(function()
    Citizen.Wait(5000)
    local str = Config.Language.press
    openButcher = PromptRegisterBegin()
    PromptSetControlAction(openButcher, Config.keys["G"])
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(openButcher, str)
    PromptSetEnabled(openButcher, 1)
    PromptSetVisible(openButcher, 1)
    PromptSetStandardMode(openButcher, 1)
    PromptSetHoldMode(openButcher, 1)
    PromptSetGroup(openButcher, prompts)
    Citizen.InvokeNative(0xC5F428EE08FA7F2C, openButcher, true)
    PromptRegisterEnd(openButcher)
end)

Citizen.CreateThread(function()
    if Config.DevMode then
        StartButchers()
    end
    Citizen.InvokeNative(0x39363DFD04E91496, PlayerId(), true) -- enable mery kil
    while true do
        Wait(2)
        local player = PlayerPedId()
        local horse = Citizen.InvokeNative(0x4C8B59171957BCF7, player)
        if horse ~= nil then
            local playerCoords = GetEntityCoords(player)
            local horsecoords = GetEntityCoords(horse)
            local holding = Citizen.InvokeNative(0xD806CD2A4F2C2996, player)
            local quality = Citizen.InvokeNative(0x31FEF6A20F00B963, holding)
            local dist = GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, horsecoords.x,
                horsecoords.y, horsecoords.z, false)

            if 2 > dist then
                local model = GetEntityModel(holding)
                if holding ~= false and Config.Animals[model] == nil then
                    local maxpelts = 3 -- cant bemore than this
                    if maxpelts > Keys(peltz) then
                        local label = CreateVarString(10, 'LITERAL_STRING', Config.Language.stow)
                        PromptSetActiveGroupThisFrame(prompts, label)
                        if Citizen.InvokeNative(0xC92AC953F0A982AE, openButcher) then
                            TaskPlaceCarriedEntityOnMount(player, holding, horse, 1)
                            table.insert(peltz, {
                                holding = holding,
                                quality = quality
                            })

                            Wait(500)
                        end
                    end
                end
            end
        end
    end
end)

--  Check for Animals being skinned/plucked/stored
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2)
        local size = GetNumberOfEvents(0)
        if size > 0 then
            for index = 0, size - 1 do
                local event = GetEventAtIndex(0, index)
                if event == 1376140891 then
                    local view = exports[GetCurrentResourceName()]:DataViewNativeGetEventData(0, index, 3)
                    local pedGathered = view['2']
                    local ped = view['0']
                    local model = GetEntityModel(pedGathered)

                    -- Bool to let you know if animation/longpress was enacted.
                    local bool_unk = view['4']

                    -- Ensure the player who enacted the event is the one who gets the rewards
                    local player = PlayerPedId()
                    local playergate = player == ped

                    if model and playergate == true then
                        --  print('Animal Gathered: ' .. model) --remove this if you want
                    end

                    if model and Config.SkinnableAnimals[model] ~= nil and playergate == true and bool_unk == 1 then
                        TriggerServerEvent("simotsu_hunting:giveReward", "skinned", { model = model }, true)
                        --VORPcore.NotifyAvanced(Config.SkinnableAnimals[model].action.." "..Config.SkinnableAnimals[model].name ,Config.SkinnableAnimals[model].type, Config.SkinnableAnimals[model].texture , "COLOR_PURE_WHITE", 4000)
                    end
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    if Config.butcherfunction then
        while true do
            local sleep = 1000
            for i, v in ipairs(Config.Butchers) do
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - v.coords)

                if distance <= v.radius then -- Checking distance between player and butcher
                    sleep = 0
                    local label = CreateVarString(10, 'LITERAL_STRING', Config.Language.sell)
                    PromptSetActiveGroupThisFrame(prompts, label)

                    if Citizen.InvokeNative(0xC92AC953F0A982AE, openButcher) then
                        if not pressed then
                            pressed = true
                            if Config.joblocked then
                                TriggerServerEvent("simotsu_hunting:getJob") --TODO calbacks
                                while playerJob == nil do
                                    Wait(0)
                                end
                                if playerJob == v.butcherjob then
                                    SellAnimal()
                                else
                                    TriggerEvent("vorp:TipRight", Config.Language.notabutcher .. " : " .. v.butcherjob,
                                        4000)
                                end
                            else
                                SellAnimal()
                            end
                        end
                    end
                end
            end

            Citizen.Wait(sleep)
        end
    end
end)


-----  useful to get hash from animals or pelts  ------------
if Config.DevMode then
    RegisterCommand('animal', function(source, args, rawCommand)
        local ped = PlayerPedId()
        local holding = Citizen.InvokeNative(0xD806CD2A4F2C2996, ped)
        local quality = Citizen.InvokeNative(0x31FEF6A20F00B963, holding)
        local model = GetEntityModel(holding)
        local type = GetPedType(holding)
        local hash = joaat(holding)

        print('holding', holding)
        print('quality', quality)
        print('model', model)
        print('type', type)
        print('hash', hash)
    end, false)
    --

    ----------- spawn an animal to make tests ------------------

    RegisterCommand("hunt", function(source, args, rawCommand)
        local animal = args[1]
        local freeze = args[2]
        local player = PlayerPedId()
        local playerCoords = GetEntityCoords(player)

        if animal == nil then
            animal = 'a_c_goat_01'
        end

        if freeze == nil then
            freeze = '2000'
        end

        freeze = tonumber(freeze)


        RequestModel(animal)
        while not HasModelLoaded(animal) do
            Wait(10)
        end

        animal = CreatePed(animal, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, animal, 1, 0)
        Wait(freeze)
        FreezeEntityPosition(animal, true)
    end, false)
    --
end

RegisterNetEvent('applyPredatorBaitEffect')
AddEventHandler('applyPredatorBaitEffect', function(provisionType)
    
    local currentTime = GetGameTimer()

    if currentTime - lastUsageTime < cooldownTime then
        local remainingTime = math.ceil((lastUsageTime + cooldownTime - currentTime) / 1000)  -- Convert to seconds
        local message = ("Please wait %d seconds until performing this action again"):format(remainingTime)
        TriggerEvent("chat:addMessage", {color = {255, 0, 0}, args = {"System", message}})
        return
    end

    lastUsageTime = currentTime
    
    -- Add visual effects or other actions to represent the effect of using the bait
    -- For example, you could play a sound, display a particle effect, or show a notification
    if provisionType == "PREDATOR_BAIT" then
        TriggerEvent("chat:addMessage", {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "You have applied the predator bait.\n Hide quietly while the animal approaches..."}
        })
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, PlayerPedId(), 1, 2, GetHashKey("KIT_EMOTE_TAUNT_BOOHOO_1"), 0, 0, 0, 0, 0)
        name = GetRandomAnimalName(provisionType)
        print(name)
        local playerPed = PlayerPedId()
        local pos, playerHeading = GetEntityCoords(playerPed), GetEntityHeading(playerPed)
        local coords = vector3(pos.x, pos.y, pos.z) -- Example coordinates (replace with desired coordinates)
        local coords2 = vector3(pos.x, pos.y, pos.z) -- where Animal spawns
        Wait(5000)
        SpawnPedWithNavigation(name, coords2, coords, playerHeading, function(ped)
            -- Callback function executed when the ped is spawned
            print("Ped spawned:", ped)
            if ped then
           -- TriggerServerEvent("simotsu_hunting:removeBait", 'consumable_predator_bait')
            end
        end)

    elseif provisionType == "POTENT_PREDATOR_BAIT" then
        TriggerEvent("chat:addMessage", {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "You have applied the  potent predator bait.\n Hide quietly while it approaches..."}
        })
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, PlayerPedId(), 1, 2, GetHashKey("KIT_EMOTE_TAUNT_BOOHOO_1"), 0, 0, 0, 0, 0)
        name = GetRandomAnimalName(provisionType)
        print(name)
        local playerPed = PlayerPedId()
        local pos, playerHeading = GetEntityCoords(playerPed), GetEntityHeading(playerPed)
        local coords = vector3(pos.x, pos.y, pos.z) -- Example coordinates (replace with desired coordinates)
        local coords2 = vector3(pos.x, pos.y, pos.z) -- where Animal spawns
        Wait(5000)
        SpawnPedWithNavigation(name, coords2, coords, playerHeading, function(ped)
            -- Callback function executed when the ped is spawned
            print("Ped spawned:", ped)
            if ped then
            --TriggerServerEvent("simotsu_hunting:removeBait", 'consumable_potent_predator_bait')
            end
        end)
    elseif provisionType == "POTENT_HERBIVORE_BAIT" then
        TriggerEvent("chat:addMessage", {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "You have applied the potent herbivore bait."}
        })
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, PlayerPedId(), 1, 2, GetHashKey("KIT_EMOTE_TAUNT_BOOHOO_1"), 0, 0, 0, 0, 0)
        name = GetRandomAnimalName(provisionType)
        print(name)
        local playerPed = PlayerPedId()
        local pos, playerHeading = GetEntityCoords(playerPed), GetEntityHeading(playerPed)
        local coords = vector3(pos.x, pos.y, pos.z) -- Example coordinates (replace with desired coordinates)
        local coords2 = vector3(pos.x, pos.y, pos.z) -- where Animal spawns

       
        Wait(5000)
        SpawnPedWithNavigation(name, coords2, coords, playerHeading, function(ped)
            -- Callback function executed when the ped is spawned
            print("Ped spawned:", ped)
            if ped then
              --  TriggerServerEvent("simotsu_hunting:removeBait", 'consumable_potent_herbivore_bait')
            end
        end)
    elseif provisionType == "HERBIVORE_BAIT" then
        TriggerEvent("chat:addMessage", {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "You have applied the herbivore bait."}
        })
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, PlayerPedId(), 1, 2, GetHashKey("KIT_EMOTE_TAUNT_BOOHOO_1"), 0, 0, 0, 0, 0)
        name = GetRandomAnimalName(provisionType)
        print(name)
        local playerPed = PlayerPedId()
        local pos, playerHeading = GetEntityCoords(playerPed), GetEntityHeading(playerPed)
        local coords = vector3(pos.x, pos.y, pos.z) -- Example coordinates (replace with desired coordinates)
        local coords2 = vector3(pos.x, pos.y, pos.z) -- where Animal spawns
        Wait(5000)
        SpawnPedWithNavigation(name, coords2, coords, playerHeading, function(ped)
            -- Callback function executed when the ped is spawned
            print("Ped spawned:", ped)
            if ped then
            --    TriggerServerEvent("simotsu_hunting:removeBait", 'consumable_herbivore_bait')
            end
        end)
    elseif provisionType == "LEGENDARY_BAIT" then
        TriggerEvent("chat:addMessage", {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "You have applied the Legendary Bait. \n Prepare yourself for an Epic Fight!"}
        })
        Citizen.InvokeNative(0xB31A277C1AC7B7FF, PlayerPedId(), 1, 2, GetHashKey("KIT_EMOTE_TAUNT_BOOHOO_1"), 0, 0, 0, 0, 0)
        name = GetRandomAnimalName(provisionType)
        print(name)
        local playerPed = PlayerPedId()
        local pos, playerHeading = GetEntityCoords(playerPed), GetEntityHeading(playerPed)
        local coords = vector3(pos.x, pos.y, pos.z) -- Example coordinates (replace with desired coordinates)
        local coords2 = vector3(pos.x, pos.y, pos.z) -- where Animal spawns
        Wait(5000)
        SpawnPedWithNavigation(name, coords2, coords, playerHeading, function(ped)
            -- Callback function executed when the ped is spawned
            print("Ped spawned:", ped)
            if ped then
              --  TriggerServerEvent("simotsu_hunting:removeBait", 'consumable_legendary_bait')
            end
        end)
    end
    print(provisionType)
end)

function SpawnPed2(model, coords, heading, cb)
    model = (type(model) == 'number' and model or GetHashKey(model))
    print(model)
    Citizen.CreateThread(function()
        RequestModel(model)
        while not HasModelLoaded(model) do
            Citizen.Wait(0)
        end
        local ped = CreatePed(model, coords.x, coords.y, coords.z, heading, false, false)
        SetPedOutfitPreset(ped, true, false)
        SetEntityAsMissionEntity(ped, true, false)
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        local timeout = 0
        while not HasCollisionLoadedAroundEntity(ped) and timeout < 2000 do
            Citizen.Wait(0)
            timeout = timeout + 1
        end
        if cb then
            cb(ped)
        end
    end)
end

function SpawnPedWithNavigation(model, spawnCoords, baitCoords, heading, cb)
    model = (type(model) == 'number' and model or GetHashKey(model))

    Citizen.CreateThread(function()
        RequestModel(model)
        while not HasModelLoaded(model) do
            Citizen.Wait(0)
        end
                -- Check if the player is near any town before navigating towards the bait area
        if IsPlayerNearTown(baitCoords) then
            -- Player is near a town, do not spawn the animal
            TriggerEvent("chat:addMessage", {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "Player is near a town, cannot place bait here. \n Picking bait up..."}
            })
            return
        end
        Wait(Config.AnimalSpawnTimer)
        local ped = CreatePed(model, spawnCoords.x + math.random(15,20), spawnCoords.y + math.random(15,20), spawnCoords.z, heading, false, false)
        SetPedOutfitPreset(ped, true, false)
        SetEntityAsMissionEntity(ped, true, false)
        RequestCollisionAtCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z)

       local timeout = 0
       while not HasCollisionLoadedAroundEntity(ped) and timeout < 2000 do
      -- while not HasCollisionLoadedAroundEntity(ped) do
            Citizen.Wait(0)
            timeout = timeout + 1
       end

        -- Navigate towards the bait area
        TaskGoToCoordAnyMeans(ped, baitCoords.x, baitCoords.y, baitCoords.z, 1.0, 0, false, 0)

        if cb then
            cb(ped)
        end
    end)
end

function GetRandomAnimalName(provisionType)
   
    if provisionType == "PREDATOR_BAIT" then
        local index = math.random(1, #Config.PredatorBaitAnimals) -- Generate a random index within the range of the array
        return Config.PredatorBaitAnimals[index] -- Return the random animal name from the array
    elseif provisionType == "POTENT_PREDATOR_BAIT" then
        local index = math.random(1, #Config.PotentPredatorBaitAnimals) -- Generate a random index within the range of the array
        return Config.PotentPredatorBaitAnimals[index] -- Return the random animal name from the array
    elseif provisionType == "POTENT_HERBIVORE_BAIT" then
        local index = math.random(1, #Config.PotentHerbivoreBaitAnimals) -- Generate a random index within the range of the array
        return Config.PotentHerbivoreBaitAnimals[index] -- Return the random animal name from the array
    elseif provisionType == "HERBIVORE_BAIT" then
        local index = math.random(1, #Config.HerbivoreBaitAnimals) -- Generate a random index within the range of the array
        return Config.HerbivoreBaitAnimals[index] -- Return the random animal name from the array
    elseif provisionType == "LEGENDARY_BAIT" then
        local index = math.random(1, #Config.LegendaryBait) -- Generate a random index within the range of the array
        return Config.LegendaryBait[index] -- Return the random animal name from the array
    end
end

local townBoundaries = {
    { center = vector3(-856.25, -1288.84, 43.26), radius = 400.0 },  -- Blackwater
    { center = vector3(-3682.71, -2591.49, -12.87), radius = 300.0 },  -- Armadillo
    { center = vector3(-5509.97, -2968.5, 2.68), radius = 300.0 },  -- Tumbleweed
    { center = vector3(-1797.21, -399.36, 153.88), radius = 300.0 },  -- Strawberry
    { center = vector3(-282.8, 720.56, 114.94), radius = 300.0 },  -- Valentine
    { center = vector3(1325.27, -1319.55, 82.63), radius = 250.0 },  -- Rhodes
    { center = vector3(2652.94, -1277.88, 52.28), radius = 400.0 },  -- St Denis
    { center = vector3(2942.56, 1347.76, 44.1), radius = 400.0 },  -- Annesburg
    -- Add more towns here as needed
}

function IsPlayerNearTown(playerCoords)
    for _, town in ipairs(townBoundaries) do
        local distance = GetDistanceBetweenCoords(playerCoords.x, playerCoords.y, playerCoords.z, town.center.x, town.center.y, town.center.z, true)
        if distance <= town.radius then
            if Config.CannotPlaceInTown then
                return true  -- Player is near this town
            else
                return false
            end
        end
    end
    return false  -- Player is not near any town
end

-------------------Crafting------------