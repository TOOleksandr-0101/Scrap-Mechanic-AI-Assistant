dofile "$SURVIVAL_DATA/Scripts/game/SurvivalGame.lua"
dofile( "$SURVIVAL_DATA/Scripts/game/managers/BabyWocManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/QuestManager.lua" )

Game = class( SurvivalGame )

local RequestPath = "$CONTENT_DATA/Cache/ai_bridge_request.json"
local ResponsePath = "$CONTENT_DATA/Cache/ai_bridge_response.json"
local SettingsPath = "$CONTENT_DATA/Cache/ai_settings.json"
local HeartbeatPath = "$CONTENT_DATA/Cache/ai_bridge_heartbeat.json"
local SettingsGuiPath = "$CONTENT_DATA/Gui/JsonGuis/AISettings.gui"

local SupportedModels = {
    Model_GPT4 = { id = "openai/gpt-4.1-mini", name = "GPT-4.1 Mini" },
    Model_Gemini = { id = "google/gemini-3.8-flash", name = "Gemini Flash" },
    Model_Claude = { id = "anthropic/claude-sonnet-5.5", name = "Claude Sonnet" },
    Model_DeepSeek = { id = "deepseek/deepseek-chat", name = "DeepSeek Chat" }
}

local SupportedLangs = {
    Lang_Auto = { id = "auto", name = "Auto" },
    Lang_RU = { id = "ru", name = "Russian (RU)" },
    Lang_EN = { id = "en", name = "English (EN)" }
}

local HistoryLimit = 8
local NpcName = "MooMoo"
local KnownQuestAliases = {
    ["quest_tutorial"] = "quest_tutorial",
    ["tutorial"] = "quest_tutorial",
    ["getting started"] = "quest_tutorial",
    ["gettingstarted"] = "quest_tutorial",

    ["quest_mechanicstation"] = "quest_mechanicstation",
    ["mechanic station"] = "quest_mechanicstation",
    ["mechanic station quest"] = "quest_mechanicstation",
    ["the mechanic station"] = "quest_mechanicstation",

    ["quest_mystery_call"] = "quest_mystery_call",
    ["mystery call"] = "quest_mystery_call",
    ["a stranger in need"] = "quest_mystery_call",

    ["quest_feed_the_farmers"] = "quest_feed_the_farmers",
    ["feed the farmers"] = "quest_feed_the_farmers",
    ["palate cleanser"] = "quest_feed_the_farmers",

    ["quest_clear_minidungeon"] = "quest_clear_minidungeon",
    ["clear minidungeon"] = "quest_clear_minidungeon",

    ["quest_find_construction_site"] = "quest_find_construction_site",
    ["find construction site"] = "quest_find_construction_site",

    ["quest_burnt_forest"] = "quest_burnt_forest",
    ["burnt forest"] = "quest_burnt_forest",

    ["quest_crashed_ship"] = "quest_crashed_ship",
    ["crashed ship"] = "quest_crashed_ship",

    ["quest_find_excavation"] = "quest_find_excavation",
    ["find excavation"] = "quest_find_excavation",
    ["excavation"] = "quest_find_excavation",

    ["quest_mine_master"] = "quest_mine_master",
    ["mine master"] = "quest_mine_master",

    ["quest_vault"] = "quest_vault",
    ["vault"] = "quest_vault",
    ["quest_vault_2"] = "quest_vault_2",
    ["vault 2"] = "quest_vault_2",
    ["quest_vault_3"] = "quest_vault_3",
    ["vault 3"] = "quest_vault_3",

    ["quest_warehouse_destruction"] = "quest_warehouse_destruction",
    ["warehouse destruction"] = "quest_warehouse_destruction",

    ["quest_bosstrain"] = "quest_bosstrain",
    ["bosstrain"] = "quest_bosstrain",
    ["second station"] = "quest_bosstrain",
    ["second station quest"] = "quest_bosstrain"
}
local PreferredQuestOrder = {
    "quest_tutorial",
    "quest_mechanicstation",
    "quest_mystery_call",
    "quest_feed_the_farmers",
    "quest_clear_minidungeon",
    "quest_find_construction_site",
    "quest_burnt_forest",
    "quest_crashed_ship",
    "quest_find_excavation",
    "quest_mine_master",
    "quest_vault",
    "quest_vault_2",
    "quest_vault_3",
    "quest_warehouse_destruction",
    "quest_bosstrain"
}
local QuestDisplayNames = {
    ["quest_tutorial"] = "Getting Started",
    ["quest_mechanicstation"] = "The Mechanic Station",
    ["quest_mystery_call"] = "A Stranger In Need",
    ["quest_feed_the_farmers"] = "Palate Cleanser",
    ["quest_clear_minidungeon"] = "Clear Minidungeon",
    ["quest_find_construction_site"] = "Find Construction Site",
    ["quest_burnt_forest"] = "Burnt Forest",
    ["quest_crashed_ship"] = "Crashed Ship",
    ["quest_find_excavation"] = "Find Excavation",
    ["quest_mine_master"] = "Mine Master",
    ["quest_vault"] = "Vault",
    ["quest_vault_2"] = "Vault 2",
    ["quest_vault_3"] = "Vault 3",
    ["quest_warehouse_destruction"] = "Warehouse Destruction",
    ["quest_bosstrain"] = "Second Station"
}
local TimeOfDayAliases = {
    ["night"] = 0.95,
    ["midnight"] = 0.0,
    ["morning"] = 0.25,
    ["noon"] = 0.5,
    ["day"] = 0.5,
    ["evening"] = 0.75,
    ["sunrise"] = 0.23,
    ["sunset"] = 0.77,
    ["ночь"] = 0.95,
    ["полночь"] = 0.0,
    ["утро"] = 0.25,
    ["день"] = 0.5,
    ["полдень"] = 0.5,
    ["вечер"] = 0.75,
    ["рассвет"] = 0.23,
    ["закат"] = 0.77
}

local KnownUnits = {
    ["c8bfb8f3-7efc-49ac-875a-eb85ac0614db"] = { name = "Haybot", threat = "medium", type = "hostile" },
    ["9f4fde94-312f-4417-b13b-84029c5d6b52"] = { name = "Farmbot", threat = "critical", type = "hostile" },
    ["8984bdbf-521e-4eed-b3c4-2b5e287eb879"] = { name = "Green Totebot", threat = "low", type = "hostile" },
    ["9360d346-3ff2-4925-a068-660cf5dd5267"] = { name = "Red Totebot", threat = "medium", type = "hostile" },
    ["2dea48a4-6a79-11ed-a1eb-0242ac120002"] = { name = "Yellow Totebot", threat = "medium", type = "hostile" },
    ["58992f50-ca36-44e1-8c47-4996d89d6a9a"] = { name = "Blue Totebot", threat = "medium", type = "hostile" },
    ["55fd93fa-09ed-4a26-bfa1-4601694d5127"] = { name = "Leaf Totebot", threat = "low", type = "hostile" },
    ["04761b4a-a83e-4736-b565-120bc776edb2"] = { name = "Tapebot", threat = "high", type = "hostile" },
    ["c3d31c47-0c9b-4b07-9bd4-8f022dc4333e"] = { name = "Red Tapebot", threat = "critical", type = "hostile" },
    ["97efd943-d176-479a-a6f4-46373327ddcd"] = { name = "Yellow Tapebot", threat = "high", type = "hostile" },
    ["c68914f8-d769-4638-9071-f7dbd1d97351"] = { name = "Green Tapebot", threat = "high", type = "hostile" },
    ["f3ded3f4-ddf9-441d-83f1-28b8cf2c7581"] = { name = "Green Tapebot", threat = "high", type = "hostile" },
    ["54a06cf0-c035-41a5-b19e-158496d35586"] = { name = "Green Tapebot", threat = "high", type = "hostile" },
    ["9dbbd2fb-7726-4e8f-8eb4-0dab228a561d"] = { name = "Taped Tapebot", threat = "high", type = "hostile" },
    ["fcb2e8ce-ca94-45e4-a54b-b5acc156170b"] = { name = "Taped Tapebot", threat = "high", type = "hostile" },
    ["68d3b2f3-ed4b-4967-9d22-8ee6f555df63"] = { name = "Taped Tapebot", threat = "high", type = "hostile" },
    ["b837888a-0480-4a34-bc34-d72261a14385"] = { name = "Cablebot", threat = "medium", type = "hostile" },
    ["531d0a62-6142-4c65-be24-9af58be4a730"] = { name = "Drillbot", threat = "critical", type = "hostile" },
    ["2ef81574-9b6a-4f79-8306-7f80fff2050b"] = { name = "Trashbot", threat = "low", type = "hostile" },
    ["c3434728-2724-4327-aba9-af168231d0b0"] = { name = "Trashbot", threat = "low", type = "hostile" },
    ["92da8324-3cfe-4529-ac1c-c71facda50a3"] = { name = "Minerbot", threat = "medium", type = "hostile" },
    ["8828e9d2-650c-11ed-9022-0242ac120002"] = { name = "Lootbot", threat = "none", type = "passive" },
    ["264a563a-e304-430f-a462-9963c77624e9"] = { name = "Woc", threat = "none", type = "passive" },
    ["4895b33a-ce8f-43d0-8c59-e406d37d8d6b"] = { name = "Baby Woc", threat = "none", type = "friendly" },
    ["48c03f69-3ec8-454c-8d1a-fa09083363b1"] = { name = "Glowbug", threat = "none", type = "passive" }
}

local LandmarkNames = {
    ["mechanicStation"] = "Mechanic Station",
    ["crashedShip"] = "Crashed Ship",
    ["hideout"] = "Hideout (Trader)",
    ["vegetableStation"] = "Vegetable Packing Station",
    ["fruitStation"] = "Fruit Packing Station",
    ["drillbotMountain"] = "Drillbot Mountain",
    ["labyrinth"] = "Labyrinth",
    ["garage"] = "Garage"
}

local function ai_loadJson( path )
    if sm.json.fileExists( path ) then
        return sm.json.open( path )
    end
    return nil
end

local function ai_saveJson( path, data )
    sm.json.save( data, path )
end

local function ai_pushHistory( self, role, text )
    if not self.ai.history then
        self.ai.history = {}
    end

    self.ai.history[#self.ai.history + 1] = {
        role = role,
        text = text
    }

    while #self.ai.history > HistoryLimit do
        table.remove( self.ai.history, 1 )
    end
end

local function ai_round( value )
    return math.floor( value * 10 + 0.5 ) / 10
end

local function ai_findQuestName( rawName )
    if not rawName or rawName == "" then
        return nil
    end

    local rawLower = string.lower( tostring( rawName ) )
    if KnownQuestAliases[rawLower] then
        return KnownQuestAliases[rawLower]
    end

    for alias, questName in pairs( KnownQuestAliases ) do
        if string.find( rawLower, alias, 1, true ) then
            return questName
        end
        if string.find( alias, rawLower, 1, true ) then
            return questName
        end
    end

    return nil
end

local function ai_extractQuestSpecifier( args )
    if type( args ) ~= "table" then
        return nil
    end

    local candidates = {
        args.quest,
        args.id,
        args.questId,
        args.quest_id,
        args.title,
        args.questTitle,
        args.quest_title,
        args.target,
        args.name
    }

    for _, value in ipairs( candidates ) do
        if value ~= nil and tostring( value ) ~= "" then
            return tostring( value )
        end
    end

    return nil
end

local function ai_findTimeOfDayValue( args )
    if args.time ~= nil then
        local timeValue = tonumber( args.time )
        if timeValue then
            return timeValue
        end
    end

    if args.preset ~= nil then
        local preset = string.lower( tostring( args.preset ) )
        return TimeOfDayAliases[preset]
    end

    if args.value ~= nil then
        local preset = string.lower( tostring( args.value ) )
        if TimeOfDayAliases[preset] then
            return TimeOfDayAliases[preset]
        end
    end

    return nil
end

local function ai_containsString( list, value )
    for _, item in ipairs( list ) do
        if item == value then
            return true
        end
    end
    return false
end

local function ai_buildQuestContext()
    local activeQuests = QuestManager.Cl_GetActiveQuests and QuestManager.Cl_GetActiveQuests() or {}
    local completedQuests = QuestManager.Cl_GetCompletedQuests and QuestManager.Cl_GetCompletedQuests() or {}

    local activeList = {}
    for questName, _ in pairs( activeQuests ) do
        activeList[#activeList + 1] = {
            id = questName,
            title = QuestDisplayNames[questName] or questName
        }
    end
    table.sort( activeList, function( a, b ) return a.id < b.id end )

    local completedList = {}
    for _, questName in ipairs( completedQuests ) do
        completedList[#completedList + 1] = {
            id = questName,
            title = QuestDisplayNames[questName] or questName
        }
    end

    local suggestedList = {}
    for _, questName in ipairs( PreferredQuestOrder ) do
        local status = "available"
        if activeQuests[questName] then
            status = "active"
        elseif ai_containsString( completedQuests, questName ) then
            status = "completed"
        end

        suggestedList[#suggestedList + 1] = {
            id = questName,
            title = QuestDisplayNames[questName] or questName,
            status = status
        }
    end

    return {
        activeQuests = activeList,
        completedQuests = completedList,
        suggestedQuestOrder = suggestedList
    }
end

local function ai_buildWorldContext( self )
    local timeData = self.cl and self.cl.time
    local rawTimeOfDay = timeData and timeData.timeOfDay or ( sm.game.getTimeOfDay and sm.game.getTimeOfDay() or 0.0 )
    local currentDay = math.floor( rawTimeOfDay )
    local todFraction = math.fmod( rawTimeOfDay, 1.0 )
    if todFraction < 0 then
        todFraction = todFraction + 1.0
    end

    local hour = ( todFraction * 24 ) % 24
    local minute = ( hour % 1 ) * 60
    local timeString = string.format( "%02d:%02d", math.floor( hour ), math.floor( minute ) )

    local phase = "day"
    if todFraction < ( 3 / 24 ) or todFraction >= ( 21 / 24 ) then
        phase = "night"
    elseif todFraction >= ( 3 / 24 ) and todFraction < ( 6 / 24 ) then
        phase = "dawn"
    elseif todFraction >= ( 6 / 24 ) and todFraction < ( 18 / 24 ) then
        phase = "day"
    elseif todFraction >= ( 18 / 24 ) and todFraction < ( 21 / 24 ) then
        phase = "dusk"
    end

    return {
        day = currentDay,
        timeOfDay = ai_round( todFraction ),
        timeString = timeString,
        phase = phase,
        timeProgress = ( timeData and timeData.timeProgress ~= nil ) and timeData.timeProgress or true,
        serverTick = sm.game.getServerTick and sm.game.getServerTick() or nil
    }
end

local function ai_buildPlayerContext()
    local player = sm.localPlayer and sm.localPlayer.getPlayer and sm.localPlayer.getPlayer() or nil
    if not player then
        return nil
    end

    local context = {
        name = player.name or "Player"
    }

    local character = player.character
    if character and sm.exists( character ) then
        local pos = character.worldPosition
        context.position = {
            x = ai_round( pos.x ),
            y = ai_round( pos.y ),
            z = ai_round( pos.z )
        }
        local dir = character.direction
        context.direction = {
            x = ai_round( dir.x ),
            y = ai_round( dir.y ),
            z = ai_round( dir.z )
        }
        context.isSwimming = character.isSwimming and character:isSwimming() or false
        context.isDiving = character.isDiving and character:isDiving() or false
        context.isCrouching = character.isCrouching and character:isCrouching() or false
        context.isSprinting = character.isSprinting and character:isSprinting() or false
        context.isSeated = character.isSeated and character:isSeated() or false
        context.isTumbling = character.isTumbling and character:isTumbling() or false
        context.isDowned = character.isDowned and character:isDowned() or false
    end

    if g_localSurvivalPlayer and g_localSurvivalPlayer.cl and g_localSurvivalPlayer.cl.stats then
        local stats = g_localSurvivalPlayer.cl.stats
        context.hp = ai_round( stats.hp or 100 )
        context.maxHp = ai_round( stats.maxhp or 100 )
        context.breath = ai_round( stats.breath or 100 )
        context.maxBreath = ai_round( stats.maxbreath or 100 )
        context.isConscious = ( g_localSurvivalPlayer.cl.isConscious ~= false )
    end

    local activeItem = sm.localPlayer and sm.localPlayer.getActiveItem and sm.localPlayer.getActiveItem() or nil
    if activeItem and tostring( activeItem ) ~= "00000000-0000-0000-0000-000000000000" then
        context.activeItem = tostring( activeItem )
    end

    return context
end

local function ai_inspectFollowerContainer( container, defaultName )
    if not container or not sm.exists( container ) then
        return { hasItem = false, count = 0, name = defaultName }
    end
    local getItemSuccess, uuid, count = pcall( function() return container:getItem( 0 ) end )
    if getItemSuccess and uuid and tostring( uuid ) ~= "00000000-0000-0000-0000-000000000000" and count and count > 0 then
        return {
            hasItem = true,
            count = count,
            name = defaultName,
            uuid = tostring( uuid )
        }
    end
    return { hasItem = false, count = 0, name = defaultName }
end

local function ai_buildCompanionContext( playerPos )
    local isActive = BabyWocManager.Cl_IsActive and BabyWocManager.Cl_IsActive() or false
    local followerData = BabyWocManager.Cl_GetFollowerData and BabyWocManager.Cl_GetFollowerData() or nil

    local companion = {
        active = isActive,
        name = NpcName,
        present = false,
        distanceToPlayer = nil,
        isSeated = false,
        backpack = {
            hasBaguette = false,
            hasGlowstick = false,
            baguette = { hasItem = false, count = 0, name = "longsandwich" },
            glowstick = { hasItem = false, count = 0, name = "glowstick" }
        }
    }

    if followerData then
        if followerData.baguetteContainer then
            local bagItem = ai_inspectFollowerContainer( followerData.baguetteContainer, "longsandwich" )
            companion.backpack.baguette = bagItem
            companion.backpack.hasBaguette = bagItem.hasItem
        end
        if followerData.glowstickContainer then
            local glowItem = ai_inspectFollowerContainer( followerData.glowstickContainer, "glowstick" )
            companion.backpack.glowstick = glowItem
            companion.backpack.hasGlowstick = glowItem.hasItem
        end

        if followerData.character and sm.exists( followerData.character ) then
            local charPos = followerData.character.worldPosition
            companion.present = true
            companion.position = {
                x = ai_round( charPos.x ),
                y = ai_round( charPos.y ),
                z = ai_round( charPos.z )
            }
            if followerData.character.isSeated then
                companion.isSeated = followerData.character:isSeated()
            end
            if playerPos then
                local dist = ( charPos - playerPos ):length()
                companion.distanceToPlayer = ai_round( dist )
            end
        end
    end

    return companion
end

local function ai_getCompassDirection( delta )
    -- In Scrap Mechanic: +Y is North, -Y is South, +X is East, -X is West
    local angle = math.deg( math.atan2( delta.x, delta.y ) )
    if angle < 0 then
        angle = angle + 360
    end

    if angle >= 337.5 or angle < 22.5 then
        return "North"
    elseif angle >= 22.5 and angle < 67.5 then
        return "North-East"
    elseif angle >= 67.5 and angle < 112.5 then
        return "East"
    elseif angle >= 112.5 and angle < 157.5 then
        return "South-East"
    elseif angle >= 157.5 and angle < 202.5 then
        return "South"
    elseif angle >= 202.5 and angle < 247.5 then
        return "South-West"
    elseif angle >= 247.5 and angle < 292.5 then
        return "West"
    else
        return "North-West"
    end
end

local function ai_getRelativeDirection( playerDir, delta )
    local fLen = math.sqrt( playerDir.x * playerDir.x + playerDir.y * playerDir.y )
    local dLen = math.sqrt( delta.x * delta.x + delta.y * delta.y )
    if fLen < 0.001 or dLen < 0.001 then
        return "ahead"
    end

    local fx = playerDir.x / fLen
    local fy = playerDir.y / fLen
    local dx = delta.x / dLen
    local dy = delta.y / dLen

    local dot = fx * dx + fy * dy
    local crossZ = fx * dy - fy * dx
    local relDeg = math.deg( math.atan2( crossZ, dot ) )

    local absDeg = math.abs( relDeg )
    if absDeg < 25 then
        return "ahead"
    elseif absDeg >= 155 then
        return "behind you"
    elseif relDeg > 0 then
        if absDeg < 70 then
            return "ahead-left"
        elseif absDeg < 115 then
            return "on your left"
        else
            return "behind-left"
        end
    else
        if absDeg < 70 then
            return "ahead-right"
        elseif absDeg < 115 then
            return "on your right"
        else
            return "behind-right"
        end
    end
end

local function ai_buildRadarContext( playerPos, playerDir )
    if not playerPos or not sm.physics or not sm.physics.getSphereContacts then
        return {
            threatLevel = "safe",
            hostileCount = 0,
            passiveCount = 0,
            nearestThreat = nil,
            enemies = {},
            animals = {},
            mobs = {}
        }
    end

    local success, contacts = pcall( sm.physics.getSphereContacts, playerPos, 60.0 )
    if not success or not contacts or not contacts.characters then
        return {
            threatLevel = "safe",
            hostileCount = 0,
            passiveCount = 0,
            nearestThreat = nil,
            enemies = {},
            animals = {},
            mobs = {}
        }
    end

    local mobs = {}
    local enemies = {}
    local animals = {}
    local hostileCount = 0
    local passiveCount = 0
    local nearestThreat = nil

    for _, char in ipairs( contacts.characters ) do
        if sm.exists( char ) and not char:isPlayer() then
            local charPos = char.worldPosition
            local delta = charPos - playerPos
            local dist = delta:length()

            local charUuid = nil
            local getUuidSuccess, uuidResult = pcall( function() return char:getCharacterType() end )
            if getUuidSuccess and uuidResult then
                charUuid = tostring( uuidResult )
            end

            if dist > 0.5 and dist <= 60.0 then
                local unitInfo = charUuid and KnownUnits[charUuid] or nil
                local mobName = unitInfo and unitInfo.name or "Unknown Entity"
                local mobType = unitInfo and unitInfo.type or "unknown"
                local threat = unitInfo and unitInfo.threat or "unknown"

                if mobType == "hostile" then
                    hostileCount = hostileCount + 1
                elseif mobType == "passive" or mobType == "friendly" then
                    passiveCount = passiveCount + 1
                end

                local compass = ai_getCompassDirection( delta )
                local relative = playerDir and ai_getRelativeDirection( playerDir, delta ) or "unknown"

                local entry = {
                    name = mobName,
                    type = mobType,
                    threat = threat,
                    distance = ai_round( dist ),
                    compass = compass,
                    direction = relative
                }
                mobs[#mobs + 1] = entry

                if mobType == "hostile" then
                    enemies[#enemies + 1] = entry
                    if not nearestThreat or dist < nearestThreat.distance then
                        nearestThreat = entry
                    end
                elseif mobType == "passive" or mobType == "friendly" then
                    animals[#animals + 1] = entry
                end
            end
        end
    end

    table.sort( mobs, function( a, b ) return a.distance < b.distance end )
    table.sort( enemies, function( a, b ) return a.distance < b.distance end )
    table.sort( animals, function( a, b ) return a.distance < b.distance end )

    local threatLevel = "safe"
    if hostileCount > 0 then
        if nearestThreat and ( nearestThreat.threat == "critical" or nearestThreat.distance < 15 ) then
            threatLevel = "danger"
        else
            threatLevel = "caution"
        end
    end

    return {
        threatLevel = threatLevel,
        hostileCount = hostileCount,
        passiveCount = passiveCount,
        nearestThreat = nearestThreat,
        enemies = enemies,
        animals = animals,
        mobs = mobs
    }
end

local function ai_buildLandmarksContext( playerPos )
    if not playerPos or not LogEntryManager or not LogEntryManager.Cl_GetLocations then
        return {}
    end

    local locations = nil
    local success, res = pcall( LogEntryManager.Cl_GetLocations )
    if success and res then
        locations = res
    end

    if not locations then
        return {}
    end

    local landmarkList = {}
    for locKey, locData in pairs( locations ) do
        local locPos = locData and ( locData.pos or locData ) or nil
        if locPos and type( locPos ) == "userdata" and locPos.x then
            local displayName = LandmarkNames[locKey] or locKey
            local delta = locPos - playerPos
            local dist = delta:length()
            local compass = ai_getCompassDirection( delta )

            landmarkList[#landmarkList + 1] = {
                id = locKey,
                name = displayName,
                distance = math.floor( dist + 0.5 ),
                compass = compass,
                position = {
                    x = ai_round( locPos.x ),
                    y = ai_round( locPos.y ),
                    z = ai_round( locPos.z )
                }
            }
        end
    end

    table.sort( landmarkList, function( a, b ) return a.distance < b.distance end )
    return landmarkList
end

-- Hook LogEntryManager to ensure LOGS.log_babywoc is ALWAYS considered unlocked in every world
if LogEntryManager then
    local orig_Sv_HasLog = LogEntryManager.Sv_HasLog
    function LogEntryManager.Sv_HasLog( uuid )
        if uuid == LOGS.log_babywoc or tostring( uuid ) == tostring( LOGS.log_babywoc ) then
            return true
        end
        if orig_Sv_HasLog then
            return orig_Sv_HasLog( uuid )
        end
        return false
    end

    local orig_Cl_HasLog = LogEntryManager.Cl_HasLog
    function LogEntryManager.Cl_HasLog( uuid )
        if uuid == LOGS.log_babywoc or tostring( uuid ) == tostring( LOGS.log_babywoc ) then
            return true
        end
        if orig_Cl_HasLog then
            return orig_Cl_HasLog( uuid )
        end
        return false
    end
end

function Game.server_onCreate( self )
    local originalCreateWorld = sm.world.createWorld
    sm.world.createWorld = function( filename, classname, terrainParams, seed )
        if filename == "$SURVIVAL_DATA/Scripts/game/worlds/Overworld.lua" and classname == "Overworld" then
            return originalCreateWorld( "$CONTENT_DATA/Scripts/worlds/AIOverworld.lua", "AIOverworld", terrainParams, seed )
        end
        return originalCreateWorld( filename, classname, terrainParams, seed )
    end

    SurvivalGame.server_onCreate( self )
    sm.world.createWorld = originalCreateWorld

    self.sv = self.sv or {}
    self.sv.cowSeatedSeat = nil
    self.sv.vehicleCheckTimer = 0
    self.sv.companionCheckTimer = 0
    self.sv.companionStayMode = false

    -- Ensure LOGS.log_babywoc is permanently unlocked in storage channel
    pcall( function()
        local logs = sm.storage.load( STORAGE_CHANNEL_LOGS ) or {}
        if not isAnyOf( LOGS.log_babywoc, logs ) then
            logs[#logs + 1] = LOGS.log_babywoc
            sm.storage.save( STORAGE_CHANNEL_LOGS, logs )
        end
        if g_logEntryManager and sm.exists( g_logEntryManager ) then
            LogEntryManager.Sv_AddLog( LOGS.log_babywoc, true )
        end
    end )

	print("Game.server_onCreate")
end

function Game.server_onFixedUpdate( self, timeStep )
    SurvivalGame.server_onFixedUpdate( self, timeStep )
    self:sv_ensureCompanionActive( timeStep )
    self:sv_updateCompanionVehicle( timeStep )
end

function Game.sv_ensureCompanionActive( self, timeStep )
    self.sv = self.sv or {}
    self.sv.companionCheckTimer = ( self.sv.companionCheckTimer or 0 ) + timeStep
    if self.sv.companionCheckTimer < 1.5 then
        return
    end
    self.sv.companionCheckTimer = 0

    local players = sm.player.getAllPlayers()
    if not players or #players == 0 then
        return
    end

    local player = players[1]
    if not player or not sm.exists( player ) or not player.character or not sm.exists( player.character ) then
        return
    end

    -- Ensure log_babywoc is marked unlocked in LogEntryManager
    if g_logEntryManager and sm.exists( g_logEntryManager ) then
        pcall( function() LogEntryManager.Sv_AddLog( LOGS.log_babywoc, true ) end )
    end

    local followerData = BabyWocManager.Sv_GetFollowerData and BabyWocManager.Sv_GetFollowerData() or nil
    local hasValidUnit = followerData and followerData.unit and sm.exists( followerData.unit )

    if hasValidUnit then
        -- Cow is active! Make sure game scripts haven't marked it immovable unless player ordered stay mode
        if followerData.unit.character and sm.exists( followerData.unit.character ) then
            if not self.sv.companionStayMode then
                if followerData.unit.character:isImmovable() then
                    pcall( function() followerData.unit.character:setImmovable( false ) end )
                end
            end
        end
        if followerData.playerToFollow ~= player then
            followerData.playerToFollow = player
        end
    else
        -- No active unit in BabyWocManager. Check if a baby woc character exists nearby in the world
        local pPos = player.character.worldPosition
        local success, contacts = pcall( sm.physics.getSphereContacts, pPos, 45.0 )
        local existingUnit = nil
        local existingChar = nil
        if success and contacts and contacts.characters then
            for _, ch in ipairs( contacts.characters ) do
                if sm.exists( ch ) and ch:isNpc() then
                    local t = tostring( ch:getCharacterType() )
                    if t == tostring( unit_baby_woc ) or string.find( t:lower(), "baby" ) or string.find( t:lower(), "woc" ) then
                        existingChar = ch
                        local u = ch:getUnit()
                        if u and sm.exists( u ) then
                            existingUnit = u
                            break
                        end
                    end
                end
            end
        end

        if existingUnit and sm.exists( existingUnit ) then
            -- Unfreeze and register directly into BabyWocManager!
            if existingChar and sm.exists( existingChar ) then
                pcall( function() existingChar:setImmovable( false ) end )
            end
            pcall( function() BabyWocManager.Sv_RegisterFollower( existingUnit, player ) end )
        else
            -- No cow exists anywhere near the player (e.g. brand new world start).
            -- Summon a new companion cow!
            self.sv.companionSpawnCooldown = ( self.sv.companionSpawnCooldown or 0 ) - 1.5
            if ( self.sv.companionSpawnCooldown or 0 ) <= 0 then
                self.sv.companionSpawnCooldown = 4.0
                if not followerData or not followerData.pendingUnitRequestTick then
                    pcall( function() BabyWocManager.Sv_CallFollower( player ) end )
                end
            end
        end
    end
end

local function ai_getCompanionCharacter( player )
    local followerData = BabyWocManager.Sv_GetFollowerData and BabyWocManager.Sv_GetFollowerData() or nil
    if followerData then
        if followerData.unit and sm.exists( followerData.unit ) and followerData.unit.character and sm.exists( followerData.unit.character ) then
            return followerData.unit.character, followerData.playerToFollow or player
        end
        if followerData.character and sm.exists( followerData.character ) then
            return followerData.character, followerData.playerToFollow or player
        end
    end

    if not player then
        local players = sm.player.getAllPlayers()
        if players and #players > 0 then
            player = players[1]
        end
    end

    if player and sm.exists( player ) and player.character and sm.exists( player.character ) then
        local pPos = player.character.worldPosition
        local success, contacts = pcall( sm.physics.getSphereContacts, pPos, 35.0 )
        if success and contacts and contacts.characters then
            for _, ch in ipairs( contacts.characters ) do
                if sm.exists( ch ) and ch:isNpc() then
                    local t = tostring( ch:getCharacterType() )
                    if t == tostring( unit_baby_woc ) or string.find( t:lower(), "baby" ) or string.find( t:lower(), "woc" ) then
                        return ch, player
                    end
                end
            end
        end
    end
    return nil, player
end

function Game.sv_executeAiAttack( self, player )
    local cowChar, p = ai_getCompanionCharacter( player )
    local originPos = nil
    if cowChar and sm.exists( cowChar ) then
        originPos = cowChar.worldPosition
    elseif player and player.character and sm.exists( player.character ) then
        originPos = player.character.worldPosition
    end

    if not originPos then
        return false, "Could not locate companion or player position."
    end

    -- Scan for hostile characters within 35m
    local bestEnemy = nil
    local bestDist = 35.0
    local success, contacts = pcall( sm.physics.getSphereContacts, originPos, 35.0 )
    if success and contacts and contacts.characters then
        for _, char in ipairs( contacts.characters ) do
            if sm.exists( char ) and char:isNpc() and ( not cowChar or char ~= cowChar ) then
                local charType = tostring( char:getCharacterType() )
                local isHostile = ( charType == tostring( unit_haybot ) or
                                   charType == tostring( unit_totebot_green ) or
                                   charType == tostring( unit_totebot_blue ) or
                                   charType == tostring( unit_totebot_red ) or
                                   charType == tostring( unit_totebot_yellow ) or
                                   charType == tostring( unit_tapebot ) or
                                   charType == tostring( unit_tapebot_red ) or
                                   charType == tostring( unit_farmbot ) or
                                   charType == tostring( unit_cablebot ) or
                                   string.find( charType:lower(), "bot" ) )
                if isHostile then
                    local d = ( char.worldPosition - originPos ):length()
                    if d < bestDist then
                        bestDist = d
                        bestEnemy = char
                    end
                end
            end
        end
    end

    if not bestEnemy or not sm.exists( bestEnemy ) then
        return false, "No hostile robots detected within 35 meters."
    end

    local enemyPos = bestEnemy.worldPosition
    local hitDir = ( enemyPos - originPos ):safeNormalize( sm.vec3.new( 0, 0, 1 ) )

    -- Leap companion to enemy
    if cowChar and sm.exists( cowChar ) then
        pcall( function()
            cowChar.worldPosition = enemyPos - hitDir * 1.2 + sm.vec3.new( 0, 0, 0.25 )
        end )
    end

    -- Apply knockback
    pcall( function() ApplyKnockback( bestEnemy, hitDir, 5000 ) end )

    -- Apply damage to unit
    local enemyUnit = bestEnemy:getUnit()
    local damageDealt = 45
    if enemyUnit and sm.exists( enemyUnit ) then
        pcall( function()
            sm.event.sendToUnit( enemyUnit, "sv_e_receiveDamage", {
                damage = damageDealt,
                source = "impact",
                hitPos = enemyPos,
                impact = hitDir * 5000
            } )
        end )
    end

    -- Sound and visual effects
    pcall( sm.effect.playEffect, "Sledgehammer - Hit", enemyPos )
    pcall( sm.effect.playEffect, "Babywoc - Moo", originPos )

    local msg = NpcName .. " headbutted the enemy for " .. tostring( damageDealt ) .. " damage!"
    if player and sm.exists( player ) then
        self.network:sendToClient( player, "cl_n_npcStatus", { message = msg } )
    end
    return true, msg
end

function Game.sv_requestAiAttack( self, params, player )
    self:sv_executeAiAttack( player )
end

function Game.sv_updateCompanionVehicle( self, timeStep )
    self.sv = self.sv or {}
    self.sv.vehicleCheckTimer = ( self.sv.vehicleCheckTimer or 0 ) + timeStep
    if self.sv.vehicleCheckTimer < 0.25 then
        return
    end
    self.sv.vehicleCheckTimer = 0

    local cowChar, player = ai_getCompanionCharacter( nil )
    if not cowChar or not player then
        return
    end

    local playerChar = ( player.character and sm.exists( player.character ) ) and player.character or nil
    if not playerChar or playerChar:isDowned() then
        if self.sv.cowSeatedSeat or cowChar:isSeated() or cowChar:getLockingInteractable() ~= nil then
            if self.sv.cowSeatedSeat and sm.exists( self.sv.cowSeatedSeat ) then
                pcall( function() self.sv.cowSeatedSeat:setSeatCharacter( nil ) end )
            end
            self.sv.cowSeatedSeat = nil
            local lockingIt = cowChar:getLockingInteractable()
            if lockingIt and sm.exists( lockingIt ) then
                pcall( function()
                    if lockingIt:hasSeat() then lockingIt:setSeatCharacter( nil ) end
                    cowChar:setLockingInteractable( nil )
                end )
            end
        end
        return
    end

    local isPlayerSeated = playerChar:isSeated()

    if isPlayerSeated then
        local driverSeat = playerChar:getLockingInteractable()
        if not driverSeat or not sm.exists( driverSeat ) or not driverSeat:hasSeat() then
            return
        end

        local driverBody = driverSeat:getBody()
        if not driverBody or not sm.exists( driverBody ) then
            return
        end

        -- If cow is already in our recorded passenger seat, make sure it's still valid
        if self.sv.cowSeatedSeat then
            if sm.exists( self.sv.cowSeatedSeat ) and ( self.sv.cowSeatedSeat:getSeatCharacter() == cowChar or cowChar:getLockingInteractable() == self.sv.cowSeatedSeat ) then
                -- Keep cow character locked to seat position and velocity with the vehicle
                pcall( function()
                    cowChar.worldPosition = self.sv.cowSeatedSeat.shape.worldPosition + sm.vec3.new( 0, 0, 0.25 )
                    cowChar.velocity = driverBody.velocity
                end )
                return
            else
                self.sv.cowSeatedSeat = nil
            end
        end

        -- Scan ONLY the exact same creation (all bodies connected to the driver's vehicle)
        if not cowChar:isSeated() and cowChar:getLockingInteractable() == nil then
            local creationBodies = driverBody:getCreationBodies()
            local bestSeat = nil
            local bestDist = 999999
            local driverPos = driverSeat.shape.worldPosition

            for _, body in ipairs( creationBodies ) do
                if sm.exists( body ) then
                    for _, shape in ipairs( body:getShapes() ) do
                        if sm.exists( shape ) then
                            local it = shape.interactable
                            if it and sm.exists( it ) and it:hasSeat() and it ~= driverSeat then
                                local occChar = it:getSeatCharacter()
                                if occChar == nil or occChar == cowChar then
                                    local dist = ( shape.worldPosition - driverPos ):length()
                                    if dist < bestDist then
                                        bestDist = dist
                                        bestSeat = it
                                    end
                                end
                            end
                        end
                    end
                end
            end

            if bestSeat then
                local seatedOk = false
                pcall( function()
                    bestSeat:setSeatCharacter( cowChar )
                    if bestSeat:getSeatCharacter() == cowChar or cowChar:isSeated() then
                        seatedOk = true
                    end
                end )

                if not seatedOk then
                    pcall( function()
                        cowChar:setLockingInteractable( bestSeat )
                        cowChar.worldPosition = bestSeat.shape.worldPosition + sm.vec3.new( 0, 0, 0.25 )
                        seatedOk = true
                    end )
                end

                if seatedOk then
                    self.sv.cowSeatedSeat = bestSeat
                    pcall( sm.effect.playEffect, "Babywoc - Moo", bestSeat.shape.worldPosition )
                    self.network:sendToClient( player, "cl_n_npcStatus", { message = NpcName .. " hopped into the passenger seat!" } )
                end
            end
        end
    else
        -- Player is on foot! If companion was seated in passenger seat, unseat and place next to player
        if self.sv.cowSeatedSeat or cowChar:isSeated() or cowChar:getLockingInteractable() ~= nil then
            if self.sv.cowSeatedSeat and sm.exists( self.sv.cowSeatedSeat ) then
                pcall( function() self.sv.cowSeatedSeat:setSeatCharacter( nil ) end )
            end
            self.sv.cowSeatedSeat = nil

            local lockingIt = cowChar:getLockingInteractable()
            if lockingIt and sm.exists( lockingIt ) then
                pcall( function()
                    if lockingIt:hasSeat() then
                        lockingIt:setSeatCharacter( nil )
                    end
                    cowChar:setLockingInteractable( nil )
                end )
            end

            local dropPos = playerChar.worldPosition + playerChar.direction * 1.5
            pcall( function() cowChar.worldPosition = dropPos end )
            pcall( sm.effect.playEffect, "Babywoc - Moo", dropPos )
            self.network:sendToClient( player, "cl_n_npcStatus", { message = NpcName .. " hopped out of the vehicle." } )
        end
    end
end

function Game.client_onCreate( self )
    SurvivalGame.client_onCreate( self )

    self.ai = {
        nextRequestId = 1,
        lastSeenResponseId = 0,
        lastSentRequestId = 0,
        pollAccumulator = 0,
        pending = false,
        commandsBound = false,
        npcEnabled = true,
        npcName = NpcName,
        history = {},
        lastExecutedActionResponseId = 0,
        lastActionResults = nil
    }

    local existingRequest = ai_loadJson( RequestPath )
    local existingResponse = ai_loadJson( ResponsePath )
    if existingRequest and existingRequest.id then
        self.ai.nextRequestId = math.max( self.ai.nextRequestId, existingRequest.id + 1 )
        self.ai.lastSentRequestId = math.max( self.ai.lastSentRequestId, existingRequest.id )
    end
    if existingResponse and existingResponse.id then
        self.ai.lastSeenResponseId = existingResponse.id
        self.ai.nextRequestId = math.max( self.ai.nextRequestId, existingResponse.id + 1 )
    end
end

function Game.client_onClientDataUpdate( self, clientData, channel )
    SurvivalGame.client_onClientDataUpdate( self, clientData, channel )

    if not self.ai then
        return
    end

    if channel == 1 and not self.ai.commandsBound then
        self:bindChatCommands()
        self.ai.commandsBound = true
        sm.gui.chatMessage( "[" .. self.ai.npcName .. "] online. Use /aiask <message> or /ainpc off" )
    end
end

function Game.bindChatCommands( self )
    SurvivalGame.bindChatCommands( self )

    -- Guarantee Survival developer & cheat commands are always available
    sm.game.bindChatCommand( "/unlimited", {}, "cl_onChatCommand", "Use the unlimited inventory" )
    sm.game.bindChatCommand( "/limited", {}, "cl_onChatCommand", "Use the limited inventory" )
    sm.game.bindChatCommand( "/god", {}, "cl_onChatCommand", "Mechanic characters will take no damage" )
    sm.game.bindChatCommand( "/ammo", { { "int", "quantity", true } }, "cl_onChatCommand", "Give ammo (default 100)" )
    sm.game.bindChatCommand( "/spudgun", {}, "cl_onChatCommand", "Give the spudgun" )
    sm.game.bindChatCommand( "/gatling", {}, "cl_onChatCommand", "Give the potato gatling gun" )
    sm.game.bindChatCommand( "/shotgun", {}, "cl_onChatCommand", "Give the fries shotgun" )
    sm.game.bindChatCommand( "/sunshake", {}, "cl_onChatCommand", "Give 1 sunshake" )
    sm.game.bindChatCommand( "/baguette", {}, "cl_onChatCommand", "Give 1 revival baguette" )
    sm.game.bindChatCommand( "/keycard", {}, "cl_onChatCommand", "Give 1 keycard" )
    sm.game.bindChatCommand( "/powercore", {}, "cl_onChatCommand", "Give 1 powercore" )
    sm.game.bindChatCommand( "/components", { { "int", "quantity", true } }, "cl_onChatCommand", "Give <quantity> components (default 10)" )
    sm.game.bindChatCommand( "/glowsticks", { { "int", "quantity", true } }, "cl_onChatCommand", "Give <quantity> glowsticks (default 20)" )
    sm.game.bindChatCommand( "/foodplease", {}, "cl_onChatCommand", "Give 5 of each edible type" )
    sm.game.bindChatCommand( "/seedsplease", {}, "cl_onChatCommand", "Give 20 of each seed type and some soil" )
    sm.game.bindChatCommand( "/tumble", { { "bool", "enable", true } }, "cl_onChatCommand", "Set tumble state" )
    sm.game.bindChatCommand( "/die", {}, "cl_onChatCommand", "Kill the player" )
    sm.game.bindChatCommand( "/unstuck", {}, "cl_onChatCommand", "Unstuck the player" )
    sm.game.bindChatCommand( "/sethp", { { "number", "hp", false } }, "cl_onChatCommand", "Set player hp value" )
    sm.game.bindChatCommand( "/setbreath", { { "number", "breath", false } }, "cl_onChatCommand", "Set player breath value" )
    sm.game.bindChatCommand( "/aggroall", {}, "cl_onChatCommand", "All hostile units will be made aware of player" )
    sm.game.bindChatCommand( "/stopraid", {}, "cl_onChatCommand", "Cancel all incoming raids" )
    sm.game.bindChatCommand( "/disableraids", { { "bool", "enabled", false } }, "cl_onChatCommand", "Disable raids if true" )
    sm.game.bindChatCommand( "/noaggro", { { "bool", "enable", true } }, "cl_onChatCommand", "Toggles the player as a target" )

    local autocomplete = {}
    if g_unitSpawnNames then
        for k, _ in pairs( g_unitSpawnNames ) do
            autocomplete[#autocomplete+1] = k
        end
    end
    sm.game.bindChatCommand( "/spawn", { { "string", "unitName", true, autocomplete }, { "int", "amount", true } }, "cl_onChatCommand", "Spawn a unit: 'woc', 'tapebot', 'totebot', 'haybot'" )

    sm.game.bindChatCommand( "/ainpc", { { "string", "mode", true } }, "cl_onChatCommand", "Toggle NPC mode on or off" )
    sm.game.bindChatCommand( "/npcspawn", {}, "cl_onChatCommand", "Spawn a test NPC above the player" )
    sm.game.bindChatCommand( "/npcdespawn", {}, "cl_onChatCommand", "Remove the spawned test NPC" )
    sm.game.bindChatCommand( "/npcnext", {}, "cl_onChatCommand", "Switch to the next NPC test body" )
    sm.game.bindChatCommand( "/aifollow", {}, "cl_onChatCommand", "Set AI cow to follow mode" )
    sm.game.bindChatCommand( "/aistay", {}, "cl_onChatCommand", "Set AI cow to stay mode" )
    sm.game.bindChatCommand( "/aicome", {}, "cl_onChatCommand", "Call AI cow to come to you" )
    sm.game.bindChatCommand( "/aiattack", {}, "cl_onChatCommand", "Order companion to attack nearby hostile bots" )
    sm.game.bindChatCommand( "/aisettings", {}, "cl_onChatCommand", "Open AI Assistant Settings" )
    sm.game.bindChatCommand( "/aimenu", {}, "cl_onChatCommand", "Open AI Assistant Settings" )
    sm.game.bindChatCommand( "/ai", {}, "cl_onChatCommand", "Open AI Assistant Settings" )
    sm.game.bindChatCommand(
        "/aiask",
        {
            { "string", "word1", false },
            { "string", "word2", true },
            { "string", "word3", true },
            { "string", "word4", true },
            { "string", "word5", true },
            { "string", "word6", true },
            { "string", "word7", true },
            { "string", "word8", true },
            { "string", "word9", true },
            { "string", "word10", true },
            { "string", "word11", true },
            { "string", "word12", true },
            { "string", "word13", true },
            { "string", "word14", true },
            { "string", "word15", true },
            { "string", "word16", true },
            { "string", "word17", true },
            { "string", "word18", true },
            { "string", "word19", true },
            { "string", "word20", true },
            { "string", "word21", true },
            { "string", "word22", true },
            { "string", "word23", true },
            { "string", "word24", true }
        },
        "cl_onChatCommand",
        "Send a prompt to the AI bridge."
    )
end

function Game.client_onUpdate( self, dt )
    SurvivalGame.client_onUpdate( self, dt )

    if not self.ai then
        return
    end

    self.ai.pollAccumulator = self.ai.pollAccumulator + dt
    if self.ai.pollAccumulator < 1.0 then
        return
    end
    self.ai.pollAccumulator = 0

    local response = ai_loadJson( ResponsePath )
    if response and response.id and response.id > self.ai.lastSeenResponseId then
        self.ai.lastSeenResponseId = response.id
        self.ai.pending = false

        if response.reply and response.reply ~= "" then
            ai_pushHistory( self, "assistant", response.reply )
            sm.gui.chatMessage( "[" .. self.ai.npcName .. "] " .. response.reply )

            local followerData = BabyWocManager.Cl_GetFollowerData and BabyWocManager.Cl_GetFollowerData() or nil
            local soundPos = nil
            if followerData and followerData.character and sm.exists( followerData.character ) then
                soundPos = followerData.character.worldPosition
            elseif sm.localPlayer and sm.localPlayer.getPlayer and sm.localPlayer.getPlayer() then
                local lp = sm.localPlayer.getPlayer()
                if lp and lp.character and sm.exists( lp.character ) then
                    soundPos = lp.character.worldPosition
                end
            end
            if soundPos then
                pcall( sm.effect.playEffect, "Babywoc - Moo", soundPos )
            end
        elseif response.error and response.error ~= "" then
            sm.gui.chatMessage( "[AI bridge error] " .. response.error )
        end

        if response.actions and #response.actions > 0 and response.id > ( self.ai.lastExecutedActionResponseId or 0 ) then
            self.ai.lastExecutedActionResponseId = response.id
            self.network:sendToServer( "sv_executeAiActions", { responseId = response.id, actions = response.actions } )
        end
    end

    if self.cl.settingsGui and sm.exists( self.cl.settingsGui ) and self.cl.settingsGui:isActive() then
        self.cl.settingsHeartbeatTimer = ( self.cl.settingsHeartbeatTimer or 0 ) + dt
        if self.cl.settingsHeartbeatTimer >= 1.5 then
            self.cl.settingsHeartbeatTimer = 0
            self:cl_updateSettingsGui()
            self.cl.settingsGui:render( self.cl.settingsGuiJson )
        end
    end
end

function Game.cl_onChatCommand( self, params )
    if params[1] == "/aisettings" or params[1] == "/aimenu" or params[1] == "/ai" then
        self:cl_openSettingsGui()
        return
    elseif params[1] == "/ainpc" then
        local mode = params[2]
        if mode == "off" then
            self.ai.npcEnabled = false
            sm.gui.chatMessage( "[" .. self.ai.npcName .. "] NPC mode disabled." )
        else
            self.ai.npcEnabled = true
            sm.gui.chatMessage( "[" .. self.ai.npcName .. "] NPC mode enabled." )
        end
        return
    elseif params[1] == "/npcspawn" then
        self.network:sendToServer( "sv_requestNpcSpawn" )
        sm.gui.chatMessage( "[NPC] spawn requested." )
        return
    elseif params[1] == "/npcdespawn" then
        self.network:sendToServer( "sv_requestNpcDespawn" )
        sm.gui.chatMessage( "[NPC] despawn requested." )
        return
    elseif params[1] == "/npcnext" then
        self.network:sendToServer( "sv_requestNpcNext" )
        sm.gui.chatMessage( "[NPC] switching candidate..." )
        return
    elseif params[1] == "/aifollow" then
        self.network:sendToServer( "sv_requestAiCowMode", { mode = "follow" } )
        sm.gui.chatMessage( "[AI Cow] follow mode." )
        return
    elseif params[1] == "/aistay" then
        self.network:sendToServer( "sv_requestAiCowMode", { mode = "stay" } )
        sm.gui.chatMessage( "[AI Cow] stay mode." )
        return
    elseif params[1] == "/aicome" then
        self.network:sendToServer( "sv_requestAiCowMode", { mode = "come" } )
        sm.gui.chatMessage( "[AI Cow] come mode." )
        return
    elseif params[1] == "/aiattack" then
        self.network:sendToServer( "sv_requestAiAttack" )
        sm.gui.chatMessage( "[" .. self.ai.npcName .. "] Attack order received!" )
        return
    elseif params[1] == "/aiask" then
        local words = {}
        for i = 2, #params do
            if params[i] and params[i] ~= "" then
                words[#words + 1] = params[i]
            end
        end

        local prompt = table.concat( words, " " )
        if not prompt or prompt == "" then
            sm.gui.chatMessage( "Usage: /aiask hello there" )
            return
        end
        
        ai_pushHistory( self, "user", prompt )
        self.ai.pending = true

        local playerContext = ai_buildPlayerContext()
        local rawPlayerPos = nil
        local rawPlayerDir = nil
        if sm.localPlayer and sm.localPlayer.getPlayer and sm.localPlayer.getPlayer() then
            local localPlayer = sm.localPlayer.getPlayer()
            if localPlayer and localPlayer.character and sm.exists( localPlayer.character ) then
                rawPlayerPos = localPlayer.character.worldPosition
                rawPlayerDir = localPlayer.character.direction
            end
        end

        local companionContext = ai_buildCompanionContext( rawPlayerPos )
        local worldContext = ai_buildWorldContext( self )
        local radarContext = ai_buildRadarContext( rawPlayerPos, rawPlayerDir )
        local landmarksContext = ai_buildLandmarksContext( rawPlayerPos )

        local request = {
            id = self.ai.nextRequestId,
            prompt = prompt,
            playerName = ( playerContext and playerContext.name ) and playerContext.name or "Player",
            sentAt = 0,
            npcEnabled = self.ai.npcEnabled,
            npcName = self.ai.npcName,
            history = self.ai.history,
            position = playerContext and playerContext.position or nil,
            liveContext = {
                world = worldContext,
                player = playerContext,
                companion = companionContext,
                radar = radarContext,
                landmarks = landmarksContext,
                questState = ai_buildQuestContext(),
                lastActionResults = self.ai.lastActionResults
            }
        }

        self.ai.lastActionResults = nil
        self.ai.lastSentRequestId = request.id
        self.ai.nextRequestId = self.ai.nextRequestId + 1
        ai_saveJson( RequestPath, request )
        sm.gui.chatMessage( "[" .. self.ai.npcName .. "] ..." )
        return
    end

    SurvivalGame.cl_onChatCommand( self, params )
end

function Game.sv_requestAiCowMode( self, params, player )
    local mode = params and params.mode or "follow"
    local cowChar, p = ai_getCompanionCharacter( player )
    local playerChar = ( player and player.character and sm.exists( player.character ) ) and player.character or nil

    if mode == "come" then
        self.sv.companionStayMode = false
        if cowChar and sm.exists( cowChar ) and playerChar then
            local arrivePos = playerChar.worldPosition + playerChar.direction * 1.5
            pcall( function()
                cowChar.worldPosition = arrivePos
                cowChar:setImmovable( false )
            end )
            pcall( sm.effect.playEffect, "Babywoc - Moo", arrivePos )
            self.network:sendToClient( player, "cl_n_npcStatus", { message = NpcName .. " ran over to you!" } )
        else
            BabyWocManager.Sv_CallFollower( player )
            self.network:sendToClient( player, "cl_n_npcStatus", { message = NpcName .. " summoned to your side." } )
        end
    elseif mode == "stay" then
        self.sv.companionStayMode = true
        if cowChar and sm.exists( cowChar ) then
            pcall( function() cowChar:setImmovable( true ) end )
            pcall( sm.effect.playEffect, "Babywoc - Moo", cowChar.worldPosition )
            self.network:sendToClient( player, "cl_n_npcStatus", { message = NpcName .. " is staying here." } )
        end
    elseif mode == "follow" then
        self.sv.companionStayMode = false
        if cowChar and sm.exists( cowChar ) then
            pcall( function() cowChar:setImmovable( false ) end )
            pcall( sm.effect.playEffect, "Babywoc - Moo", cowChar.worldPosition )
            self.network:sendToClient( player, "cl_n_npcStatus", { message = NpcName .. " is following you." } )
        end
    end

    if player and player.character and sm.exists( player.character ) then
        pcall( function()
            sm.event.sendToWorld( player.character:getWorld(), "sv_e_setAiNpcMode", { player = player, mode = mode } )
        end )
    end
end

function Game.sv_requestNpcSpawn( self, _, player )
    if player and player.character and sm.exists( player.character ) then
        sm.event.sendToWorld( player.character:getWorld(), "sv_e_spawnAiNpc", { player = player, npcName = NpcName } )
    else
        self.network:sendToClient( player, "cl_n_npcStatus", { ok = false, message = "NPC spawn failed: player character missing." } )
    end
end

function Game.sv_requestNpcDespawn( self, _, player )
    if player and player.character and sm.exists( player.character ) then
        sm.event.sendToWorld( player.character:getWorld(), "sv_e_despawnAiNpc", { player = player } )
    else
        self.network:sendToClient( player, "cl_n_npcStatus", { ok = false, message = "NPC despawn failed: player character missing." } )
    end
end

function Game.sv_requestNpcNext( self, _, player )
    if player and player.character and sm.exists( player.character ) then
        sm.event.sendToWorld( player.character:getWorld(), "sv_e_cycleAiNpcCandidate", { player = player } )
    else
        self.network:sendToClient( player, "cl_n_npcStatus", { ok = false, message = "NPC switch failed: player character missing." } )
    end
end

local function ai_followerIsActiveForPlayer( player )
    local followerData = BabyWocManager.Sv_GetFollowerData and BabyWocManager.Sv_GetFollowerData() or nil
    if followerData and followerData.playerToFollow == player then
        return true
    end
    return false
end

local MaxActionsPerRequest = 3

function Game.sv_executeAiActions( self, params, player )
    if not params or not params.actions or not player then
        return
    end

    local results = {}

    for index, action in ipairs( params.actions ) do
        local name = tostring( action.name or "" )
        local args = ( type( action.args ) == "table" ) and action.args or {}

        if index > MaxActionsPerRequest then
            results[#results + 1] = {
                name = name,
                status = "limit_exceeded",
                message = "Maximum actions limit (3) exceeded for this turn."
            }
        else
            local status = "unsupported"
            local message = "Action not supported."

            if name == "call_companion" then
                if not ai_followerIsActiveForPlayer( player ) then
                    BabyWocManager.Sv_CallFollower( player )
                    status = "success"
                    message = "Baby woc companion summoned."
                else
                    status = "success"
                    message = "Baby woc companion is already active."
                end
            elseif name == "dismiss_companion" then
                if ai_followerIsActiveForPlayer( player ) then
                    BabyWocManager.Sv_CallFollower( player )
                    status = "success"
                    message = "Baby woc companion dismissed."
                else
                    status = "failure"
                    message = "Baby woc companion was not active."
                end
            elseif name == "spawn_ai_cow" then
                if player.character and sm.exists( player.character ) then
                    sm.event.sendToWorld( player.character:getWorld(), "sv_e_spawnAiNpc", { player = player, npcName = NpcName } )
                    status = "success"
                    message = "AI cow spawn requested."
                else
                    status = "failure"
                    message = "Player character does not exist."
                end
            elseif name == "despawn_ai_cow" then
                if player.character and sm.exists( player.character ) then
                    sm.event.sendToWorld( player.character:getWorld(), "sv_e_despawnAiNpc", { player = player } )
                    status = "success"
                    message = "AI cow despawn requested."
                else
                    status = "failure"
                    message = "Player character does not exist."
                end
            elseif name == "set_ai_mode_follow" then
                self:sv_requestAiCowMode( { mode = "follow" }, player )
                status = "success"
                message = NpcName .. " set to follow mode."
            elseif name == "set_ai_mode_stay" then
                self:sv_requestAiCowMode( { mode = "stay" }, player )
                status = "success"
                message = NpcName .. " set to stay mode."
            elseif name == "set_ai_mode_come" then
                self:sv_requestAiCowMode( { mode = "come" }, player )
                status = "success"
                message = NpcName .. " called to your side."
            elseif name == "set_time_of_day" then
                local timeValue = ai_findTimeOfDayValue( args )
                if timeValue ~= nil then
                    local currentDay = math.floor( self.sv.time.timeOfDay )
                    self.sv.time.timeOfDay = currentDay + sm.util.clamp( timeValue, 0.0, 0.9999 )
                    if self.sv.syncTimer then
                        self.sv.syncTimer.count = self.sv.syncTimer.ticks
                    end
                    self:sv_updateClientData()
                    status = "success"
                    message = "Time set to " .. tostring( timeValue ) .. " on Day " .. tostring( currentDay ) .. "."
                else
                    status = "invalid_args"
                    message = "Time preset or value not recognized (must be a number between 0.0 and 1.0 or preset name)."
                end
            elseif name == "set_time_progress" then
                if args.enabled ~= nil then
                    self.sv.time.timeProgress = ( args.enabled == true )
                    if self.sv.syncTimer then
                        self.sv.syncTimer.count = self.sv.syncTimer.ticks
                    end
                    self:sv_updateClientData()
                    status = "success"
                    message = "Time progression set to " .. tostring( self.sv.time.timeProgress ) .. "."
                else
                    status = "invalid_args"
                    message = "Argument 'enabled' (boolean) is required."
                end
            elseif name == "activate_quest" then
                local questSpec = ai_extractQuestSpecifier( args )
                if not questSpec then
                    status = "invalid_args"
                    message = "No quest id specified in args.quest."
                else
                    local questName = ai_findQuestName( questSpec )
                    if questName then
                        QuestManager.Sv_TryActivateQuest( questName )
                        status = "success"
                        message = "Quest '" .. questName .. "' activated."
                    else
                        status = "not_found"
                        message = "Quest '" .. tostring( questSpec ) .. "' not found in known quests."
                    end
                end
            elseif name == "complete_quest" then
                local questSpec = ai_extractQuestSpecifier( args )
                if not questSpec then
                    status = "invalid_args"
                    message = "No quest id specified in args.quest."
                elseif questSpec == "*" or questSpec == "all_active" or questSpec == "active" or questSpec == "current" or questSpec == "all current" then
                    local activeQuests = QuestManager.Sv_GetActiveQuests and QuestManager.Sv_GetActiveQuests() or nil
                    local count = 0
                    if activeQuests then
                        for questNameKey, _ in pairs( activeQuests ) do
                            QuestManager.Sv_CompleteQuest( questNameKey )
                            count = count + 1
                        end
                    end
                    status = "success"
                    message = "Completed " .. tostring( count ) .. " active quests."
                else
                    local questName = ai_findQuestName( questSpec )
                    if questName then
                        QuestManager.Sv_CompleteQuest( questName )
                        status = "success"
                        message = "Quest '" .. questName .. "' completed."
                    else
                        status = "not_found"
                        message = "Quest '" .. tostring( questSpec ) .. "' not recognized."
                    end
                end
            elseif name == "abandon_quest" then
                local questSpec = ai_extractQuestSpecifier( args )
                if not questSpec then
                    status = "invalid_args"
                    message = "No quest id specified in args.quest."
                else
                    local questName = ai_findQuestName( questSpec )
                    if questName then
                        QuestManager.Sv_TryAbandonQuest( questName )
                        status = "success"
                        message = "Quest '" .. questName .. "' abandoned."
                    else
                        status = "not_found"
                        message = "Quest '" .. tostring( questSpec ) .. "' not recognized."
                    end
                end
            elseif name == "emote" then
                local emoteType = string.lower( tostring( args.type or args.name or args.emote or "moo" ) )
                local effectName = "Babywoc - Moo"
                if emoteType == "panic" or emoteType == "scared" or emoteType == "fear" then
                    effectName = "Babywoc - Panic"
                elseif emoteType == "eat" or emoteType == "munch" or emoteType == "feed" then
                    effectName = "Babywoc - Eat"
                elseif emoteType == "sniff" or emoteType == "investigate" then
                    effectName = "Babywoc - Sniff"
                elseif emoteType == "whistle" then
                    effectName = "Babywoc - Whistle"
                elseif emoteType == "moo" or emoteType == "happy" or emoteType == "cheer" then
                    effectName = "Babywoc - Moo"
                end

                local targetPos = nil
                local cowChar, p = ai_getCompanionCharacter( player )
                if cowChar and sm.exists( cowChar ) then
                    targetPos = cowChar.worldPosition
                elseif player.character and sm.exists( player.character ) then
                    targetPos = player.character.worldPosition
                end

                if targetPos then
                    self.network:sendToClients( "cl_n_playAiEffect", {
                        effect = effectName,
                        position = { x = targetPos.x, y = targetPos.y, z = targetPos.z }
                    } )
                    status = "success"
                    message = "Companion expressed emote: " .. emoteType .. "."
                else
                    status = "failure"
                    message = "Could not locate companion or player position for emote."
                end
            elseif name == "attack_target" or name == "attack" then
                local ok, attackMsg = self:sv_executeAiAttack( player )
                status = ok and "success" or "failure"
                message = attackMsg
            else
                status = "unsupported"
                message = "Action '" .. name .. "' is not supported by game server."
            end

            results[#results + 1] = {
                name = name,
                status = status,
                message = message
            }
        end
    end

    self.network:sendToClient( player, "cl_n_aiActionResults", { responseId = params.responseId, results = results } )
end

function Game.cl_n_playAiEffect( self, params )
    if params and params.effect and params.position then
        local pos = sm.vec3.new( params.position.x, params.position.y, params.position.z )
        pcall( sm.effect.playEffect, params.effect, pos )
    end
end

function Game.cl_n_aiActionResults( self, params )
    if not self.ai then
        return
    end

    self.ai.lastActionResults = params.results

    if params.results then
        for _, res in ipairs( params.results ) do
            local tag = ( res.status == "success" ) and "[AI action]" or "[AI action: " .. tostring( res.status ) .. "]"
            sm.gui.chatMessage( tag .. " " .. tostring( res.message ) )
        end
    end
end

function Game.cl_n_npcStatus( self, params )
    sm.gui.chatMessage( "[NPC] " .. tostring( params.message ) )
end

function Game.cl_n_aiActionStatus( self, params )
    sm.gui.chatMessage( "[AI action] " .. tostring( params.message ) )
end

function Game.cl_loadAiSettings( self )
    local settings = ai_loadJson( SettingsPath )
    if not settings then
        settings = {
            apiKey = "",
            model = "openai/gpt-4.1-mini",
            language = "auto"
        }
    end
    if not settings.model or settings.model == "" then
        settings.model = "openai/gpt-4.1-mini"
    end
    if not settings.language or settings.language == "" then
        settings.language = "auto"
    end
    self.aiSettings = settings
    return settings
end

function Game.cl_saveAiSettings( self, settings )
    self.aiSettings = settings
    ai_saveJson( SettingsPath, settings )
end

function Game.cl_e_openAiSettings( self )
    self:cl_openSettingsGui()
end

function Game.cl_openSettingsGui( self )
    if self.cl.settingsGui and sm.exists( self.cl.settingsGui ) and self.cl.settingsGui:isActive() then
        self.cl.settingsGui:close()
    end

    self:cl_loadAiSettings()
    self.cl.tokenDraft = self.aiSettings.apiKey or ""

    if not self.cl.settingsGuiJson then
        self.cl.settingsGuiJson = sm.json.open( SettingsGuiPath )
    end

    self.cl.settingsGui = sm.jsonGui.createGui( { isInteractive = true, bNeedsCursor = true, hidesHotbar = true } )
    self:cl_updateSettingsGui()
    self.cl.settingsGui:render( self.cl.settingsGuiJson )
end

function Game.cl_updateSettingsGui( self )
    if not self.cl.settingsGuiJson then return end

    local json = self.cl.settingsGuiJson
    local settings = self.aiSettings or self:cl_loadAiSettings()

    -- Token Input and Status
    local tokenInput = FindWidget( json, "TokenInput" )
    if tokenInput then
        tokenInput.Caption = self.cl.tokenDraft or ""
    end

    local tokenStatus = FindWidget( json, "TokenStatusLabel" )
    if tokenStatus then
        if settings.apiKey and #settings.apiKey > 8 then
            local prefix = string.sub( settings.apiKey, 1, 8 )
            local suffix = string.sub( settings.apiKey, -4 )
            tokenStatus.Caption = "Token: Configured (" .. prefix .. "..." .. suffix .. ")"
            tokenStatus.TextColour = "0.3 0.9 0.3 1"
        else
            tokenStatus.Caption = "Token: Not set! Enter token above and click Save."
            tokenStatus.TextColour = "0.95 0.3 0.3 1"
        end
    end

    -- Model Status
    local modelStatus = FindWidget( json, "CurrentModelLabel" )
    if modelStatus then
        modelStatus.Caption = "Active Model: " .. ( settings.model or "openai/gpt-4.1-mini" )
        modelStatus.TextColour = "0.3 0.9 0.3 1"
    end

    -- Language Status
    local langStatus = FindWidget( json, "CurrentLangLabel" )
    if langStatus then
        local langTitle = "Auto"
        if settings.language == "ru" then
            langTitle = "Russian (RU)"
        elseif settings.language == "en" then
            langTitle = "English (EN)"
        end
        langStatus.Caption = "Active Language: " .. langTitle
        langStatus.TextColour = "0.3 0.9 0.3 1"
    end

    -- Bridge Heartbeat
    local bridgeStatus = FindWidget( json, "BridgeStatusLabel" )
    if bridgeStatus then
        local heartbeat = ai_loadJson( HeartbeatPath )
        if heartbeat and heartbeat.status == "online" then
            bridgeStatus.Caption = "Bridge Status: Online (Ready)"
            bridgeStatus.TextColour = "0.3 0.9 0.3 1"
        else
            bridgeStatus.Caption = "Bridge Status: Offline (Run Start_AI_Assistant.bat)"
            bridgeStatus.TextColour = "0.95 0.5 0.2 1"
        end
    end
end

function Game.cl_onTokenEdit( self, widgetName, text )
    self.cl.tokenDraft = text
end

function Game.cl_onTokenEnter( self, widgetName, text )
    self.cl.tokenDraft = text
    self:cl_onClickSaveToken( "SaveTokenBtn" )
end

function Game.cl_onClickSaveToken( self, widgetName )
    local settings = self.aiSettings or self:cl_loadAiSettings()
    local trimmed = self.cl.tokenDraft and string.gsub( self.cl.tokenDraft, "^%s*(.-)%s*$", "%1" ) or ""
    settings.apiKey = trimmed
    self:cl_saveAiSettings( settings )
    self:cl_updateSettingsGui()
    if self.cl.settingsGui and sm.exists( self.cl.settingsGui ) and self.cl.settingsGui:isActive() then
        self.cl.settingsGui:render( self.cl.settingsGuiJson )
    end
    sm.gui.chatMessage( "[MooMoo] Settings saved: API token updated!" )
end

function Game.cl_onClickModel( self, widgetName )
    local modelInfo = SupportedModels[widgetName]
    if modelInfo then
        local settings = self.aiSettings or self:cl_loadAiSettings()
        settings.model = modelInfo.id
        self:cl_saveAiSettings( settings )
        self:cl_updateSettingsGui()
        if self.cl.settingsGui and sm.exists( self.cl.settingsGui ) and self.cl.settingsGui:isActive() then
            self.cl.settingsGui:render( self.cl.settingsGuiJson )
        end
        sm.gui.chatMessage( "[MooMoo] Model switched to: " .. modelInfo.name )
    end
end

function Game.cl_onClickLanguage( self, widgetName )
    local langInfo = SupportedLangs[widgetName]
    if langInfo then
        local settings = self.aiSettings or self:cl_loadAiSettings()
        settings.language = langInfo.id
        self:cl_saveAiSettings( settings )
        self:cl_updateSettingsGui()
        if self.cl.settingsGui and sm.exists( self.cl.settingsGui ) and self.cl.settingsGui:isActive() then
            self.cl.settingsGui:render( self.cl.settingsGuiJson )
        end
        sm.gui.chatMessage( "[MooMoo] Companion language: " .. langInfo.name )
    end
end

function Game.cl_onClickCloseSettings( self, widgetName )
    if self.cl.settingsGui and sm.exists( self.cl.settingsGui ) and self.cl.settingsGui:isActive() then
        self.cl.settingsGui:close()
    end
    self.cl.settingsGui = nil
end

function Game.cl_onSettingsClosed( self )
    self.cl.settingsGui = nil
end
