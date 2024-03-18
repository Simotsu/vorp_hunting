local VorpCore = {}
local huntxp 
local huntlvl
local VORPInv = exports["vorp_inventory"]:vorp_inventoryApi()

CreateThread(function()
    TriggerEvent("getCore", function(core)
        VorpCore = core;
    end)
    RegisterUsableItemsAsync()
end)

AddEventHandler("onResourceStart", function(resourceName)
    if (resourceName == "vorp_inventory") then
        RegisterUsableItemsAsync()
    end
end)

function RegisterUsableItemsAsync()
    Wait(3000)
    print(("Simotsu_Hunting: Loading %s items as consumables"):format(#Config["ItemToUse"]))
    for i=1, #Config.ItemToUse, 1 do
        TriggerEvent("vorpCore:registerUsableItem", Config["ItemToUse"][i]["Name"], function(data)
			TriggerEvent('simotsu_hunting:getinfo', data.source)
			Wait(100)
			if Config.BaitLevelSystem then
				if  huntxp < 400 then -- Level 2
					   TriggerClientEvent("chatMessage", -1, "Too Low", {255, 255, 0}, "You must be higher level in Hunting!")
				elseif  huntxp <= 900 then -- Level 4
					-- Allow player to use regular bait
					if Config["ItemToUse"][i]["ProvisionType"] == "PREDATOR_BAIT" or Config["ItemToUse"][i]["ProvisionType"] == "HERBIVORE_BAIT" then
						TriggerClientEvent("applyPredatorBaitEffect", data.source, Config["ItemToUse"][i]["ProvisionType"])
					else
					   TriggerClientEvent("chatMessage", -1, "Too Low", {255, 255, 0}, "You must be higher level in Hunting!")
					end
				elseif huntxp <= 2200 then -- Level 6
					-- Allow player to use regular and potent bait
					if Config["ItemToUse"][i]["ProvisionType"] == "POTENT_PREDATOR_BAIT" or Config["ItemToUse"][i]["ProvisionType"] == "POTENT_HERBIVORE_BAIT" or
						Config["ItemToUse"][i]["ProvisionType"] == "PREDATOR_BAIT" or Config["ItemToUse"][i]["ProvisionType"] == "HERBIVORE_BAIT" then
						TriggerClientEvent("applyPredatorBaitEffect", data.source, Config["ItemToUse"][i]["ProvisionType"])
					else
					   TriggerClientEvent("chatMessage", -1, "Too Low", {255, 255, 0}, "You must be higher level in Hunting!")
					end
				else -- Level 7 or higher
					-- Allow player to use all types of bait
					TriggerClientEvent("applyPredatorBaitEffect", data.source, Config["ItemToUse"][i]["ProvisionType"])
				end
			else
				TriggerClientEvent("applyPredatorBaitEffect", data.source, Config["ItemToUse"][i]["ProvisionType"])
			end
            
        end)
    end
end

RegisterServerEvent('simotsu_hunting:removeBait')
AddEventHandler('simotsu_hunting:removeBait', function(name)
	TriggerEvent("vorpCore:subItem", source, name, 1)
end)

RegisterServerEvent('simotsu_hunting:getinfo')
AddEventHandler('simotsu_hunting:getinfo', function(source)
    print(source)
    local user = VorpCore.getUser(source)
    local character = user.getUsedCharacter
    local charidentifier = character.charIdentifier
    MySQL.query("SELECT huntingxp FROM characters WHERE charidentifier = @charidentifier",
        {["@charidentifier"] = charidentifier},
        function(result)
            if result then
                -- Iterate over the rows returned by the query
                for _, row in ipairs(result) do
                    -- Access the values of huntingskill and huntingxp from each row
                    huntxp = row.huntingxp

                    -- Display the values

                    print("Hunting XP:", huntxp)
                end
            else
                -- Display an error message if the query was not successful
                print("Error executing query")
            end
        end)
end)

RegisterServerEvent('simotsu_hunting:addXP')
AddEventHandler('simotsu_hunting:addXP', function(source, newXP)
    print(source)
    local user = VorpCore.getUser(source)
    local character = user.getUsedCharacter
    local charidentifier = character.charIdentifier
	MySQL.query("UPDATE characters SET huntingxp = huntingxp + @newXP WHERE charidentifier = @charidentifier",
     {["@newXP"] = newXP, ["@charidentifier"] = charidentifier},
     function(result)
         if result then
             -- The query was successful
             print("XP added successfully")
         else
             -- Display an error message if the query was not successful
             print("Error executing query")
         end
    end)
end)



local function giveReward(context, data, skipfinal, entity)
--check players level add XP each item.
TriggerEvent("simotsu_hunting:getinfo", source)
	local _source = source
	local Character = VorpCore.getUser(_source).getUsedCharacter

	local money, gold, rolPoints, xp = 0, 0, 0, 0
	local givenItem, givenAmount, givenDisplay = {}, {}, {}
	local animal, found
	if context == "skinned" then
		animal = Config.SkinnableAnimals[data.model]
		if animal then
			found = true
			givenItem = animal.givenItem or {}
			givenAmount = animal.givenAmount or {}
			givenDisplay = animal.givenDisplay or {}
			money = animal.money or 0
			gold = animal.gold or 0
			rolPoints = animal.rolPoints or 0
			xp = animal.xp or 0
		end
	elseif context == "pelt" then
		animal = Config.Animals[data.model]
		if animal then
		print("PELT FOUND")
			found = true
			money = animal.money or 0
			if Config.PeltLevelSystem then
			if huntxp > 200 and huntxp < 400 then --lvl1
			money += 5.00
			elseif  huntxp > 400 and huntxp <= 700 then --lvl2
			money += 7.00
			elseif  huntxp > 700 and huntxp <= 900 then --lvl3
			money += 10.00
			elseif  huntxp > 900 and huntxp <= 1400 then --lvl4
			money += 12.00
			elseif  huntxp > 1400 and huntxp <= 2200 then --lvl5
			money += 15.00
			elseif  huntxp > 2200 then --lvl6
			money += 20.00
			end
			end
			gold = animal.gold or 0
			rolPoints = animal.rolPoints or 0
			xp = animal.xp or 0

			local multiplier = 1.0
			if (animal.poorQualityMultiplier and animal.poor) and (data.quality == animal.poor) then				
				multiplier = animal.poorQualityMultiplier
			elseif (animal.goodQualityMultiplier and animal.good) and (data.quality == animal.good) then
				multiplier = animal.goodQualityMultiplier				
			elseif (animal.perfectQualityMultiplier and animal.perfect) and (data.quality == animal.perfect) then
				multiplier = animal.perfectQualityMultiplier
			end

			money = money * multiplier
			gold = gold * multiplier
			rolPoints = rolPoints * multiplier
			xp = xp * multiplier
						--give player the XP then check players level to see if they can level up.
			--TriggerEvent('simotsu_hunting:addXP', source, xp)
		end
	elseif context == "carcass" then
		animal = Config.Animals[data.model]
		if animal then
			found = true
			givenItem = animal.givenItem or {}
			givenAmount = animal.givenAmount or {}
			givenDisplay = animal.givenDisplay or {}
			money = animal.money or 0
			if Config.CarcassLevelSystem then
			if huntxp > 200 and huntxp < 400 then --lvl1
			money = money * 1.25
			elseif  huntxp > 400 and huntxp <= 700 then --lvl2
			money = money * 1.5 
			elseif  huntxp > 700 and huntxp <= 900 then --lvl3
			money = money * 1.75
			elseif  huntxp > 900 and huntxp <= 1500 then --lvl4
			money = money * 2
			elseif  huntxp > 1500 and huntxp <= 2200 then --lvl5
			money = money * 2.5
			elseif  huntxp > 2200 then --lvl6
			money = money * 3
			end
			end
			gold = animal.gold or 0
			rolPoints = animal.rolPoints or 0
			xp = animal.xp or 0
		end
	end

	if found then
		local monies = {}
		local moneylinux = (math.floor(money * 100) / 100)
		if Config.Linux == true then
			if money ~= 0 then
				table.insert(monies, Config.Language.dollar .. moneylinux)
				Character.addCurrency(0, money)
			end
		else
			if money ~= 0 then
				table.insert(monies, Config.Language.dollar .. money)
				Character.addCurrency(0, money)
			end
		end

		if gold ~= 0 then
			table.insert(monies, gold .. " gold")
			Character.addCurrency(1, gold)
		end

		if rolPoints ~= 0 then
			table.insert(monies, rolPoints .. " rolPoints")
			Character.addCurrency(2, rolPoints)
		end

		if xp ~= 0 then
			Character.addXp(xp)
			TriggerEvent('simotsu_hunting:addXP', source, xp)
		end

		if #monies > 0 then
			VorpCore.AddWebhook("Hunting", Config.webhook,
				GetPlayerName(_source) .. " " .. "player received" .. table.concat(monies, ", "), nil, nil, nil, nil, nil)
			TriggerClientEvent("vorp:TipRight", _source, Config.Language.AnimalSold .. table.concat(monies, ", "), 4000)
		end

		if not skipfinal then
			local entity1 = NetworkGetEntityFromNetworkId(data.netid)
			DeleteEntity(entity1)
			TriggerClientEvent("simotsu_hunting:finalizeReward", _source, data.entity, data.horse)
		end

		local itemsAvailable = true
		local done = false

		if #givenItem ~= #givenAmount then
			print('Error: Please ensure givenItem and givenAmount have the same length in the items config.')
		elseif (givenItem ~= nil) and (#givenItem > 0) then
			local formattedGivenItems = {}
			local total = 0
			for k, v in ipairs(givenItem) do
				local nmb = 0

				if type(givenAmount[k]) == "table" then
					nmb = math.random(tonumber(givenAmount[k][1]) or 0, tonumber(givenAmount[k][2]) or 1)
				else
					if givenAmount[k] > 0 then
						nmb = givenAmount[k]
					else
						nmb = math.random(Config.ItemQuantity.Min, Config.ItemQuantity.Max)
					end
				end

				formattedGivenItems[k] = {
					nmb = nmb,
					item = v
				}

				total = total + nmb

				-- Check if there is enough to add, if not send message
				TriggerEvent("vorpCore:canCarryItem", tonumber(_source), v, nmb, function(canCarryItem)
					if canCarryItem ~= true then
						itemsAvailable = false
					end
					done = true
				end)

				while done == false do
					Wait(500)
				end
			end

			if itemsAvailable == false then
				TriggerClientEvent("vorp:TipRight", _source, Config.Language.FullInventory, 4000)
				TriggerClientEvent("simotsu_hunting:unlock", _source)
				return
			end

			-- Check if there is enough room in inventory in general.
			local invAvailable = VorpInv.canCarryItems(_source, total)
			if invAvailable ~= true then
				TriggerClientEvent("vorp:TipRight", _source, Config.Language.FullInventory, 4000)
				TriggerClientEvent("simotsu_hunting:unlock", _source)
				return
			end

			-- Give items
			local validDisplays = #givenItem == #givenDisplay
			local givenMsg = ""
			if #formattedGivenItems > 0 then
				if context == "skinned" then
					givenMsg = Config.Language.SkinnableAnimalstowed
				else
					givenMsg = "You received "
				end
				if not validDisplays then givenMsg = givenMsg .. "items..." end
			end
			for k, v in pairs(formattedGivenItems) do
				if validDisplays then
					if k > 1 then
						givenMsg = givenMsg .. Config.Language.join .. givenDisplay[k] .. ((v.nmb > 1) and "s" or "")
					else
						givenMsg = givenMsg .. givenDisplay[k] .. ((v.nmb > 1) and "s" or "")
					end
				end
				VorpInv.addItem(_source, v.item, v.nmb)
			end

			if givenMsg ~= "" then
				VorpCore.AddWebhook("Hunting", Config.webhook, GetPlayerName(_source) .. " player received" .. givenMsg,nil, nil, nil, nil, nil)
				TriggerClientEvent("vorp:TipRight", _source, givenMsg, 4000)
			end
		end
	end
	TriggerClientEvent("simotsu_hunting:unlock", _source)
end

RegisterServerEvent("simotsu_hunting:giveReward")
AddEventHandler("simotsu_hunting:giveReward", giveReward)


RegisterServerEvent("simotsu_hunting:getJob")
AddEventHandler("simotsu_hunting:getJob", function()
	local _source = source
	local User = VorpCore.getUser(_source)
	local Character = User.getUsedCharacter
	local job = Character.job -- character table

	TriggerClientEvent("simotsu_hunting:findJob", _source, job)
end)
--[[
RegisterServerEvent('useConsumablePredatorBait')
AddEventHandler('useConsumablePredatorBait', function()
    TriggerClientEvent('applyPredatorBaitEffect', source)
end)
]]
RegisterCommand("huntinglvl", function(source, args, rawCommand)
    local playerId = source
	local level = 0
	local totalleft = 0
	TriggerEvent('simotsu_hunting:getinfo', playerId)
	Wait(1000)
	if huntxp < 200 then
		level = 0
		totalleft = 200 - huntxp
	elseif huntxp > 200 then
		level = 1
		totalleft = 400 - huntxp
	elseif huntxp > 400 then
		level = 2
		totalleft = 700 - huntxp
	elseif huntxp > 700 then
		level = 3
		totalleft = 900 - huntxp
	elseif huntxp > 900 then
		level = 4
		totalleft = 1400 - huntxp
	elseif huntxp > 1400 then
		level = 5
		totalleft = 2200 - huntxp
	elseif huntxp > 2200 then
		level = 6
		totalleft = 0
	end
    TriggerClientEvent("chatMessage", -1, "Hunting Level", {255, 255, 0}, "Your hunting level is: " .. level)
    TriggerClientEvent("chatMessage", -1, "Hunting XP", {255, 255, 0}, "Your next hunting level is: " .. totalleft .. " XP away.")
end, false)