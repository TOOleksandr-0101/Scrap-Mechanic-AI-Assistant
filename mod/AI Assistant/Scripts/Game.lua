dofile "$SURVIVAL_DATA/Scripts/game/SurvivalGame.lua"
dofile( "$SURVIVAL_DATA/Scripts/game/managers/BabyWocManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/QuestManager.lua" )

Game = class( SurvivalGame )

local RequestPath = "$CONTENT_DATA/Cache/ai_bridge_request.json"
local ResponsePath = "$CONTENT_DATA/Cache/ai_bridge_response.json"
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
    ["night"] = 0.85,
    ["midnight"] = 0.0,
    ["morning"] = 0.25,
    ["noon"] = 0.5,
    ["day"] = 0.5,
    ["evening"] = 0.72,
    ["sunrise"] = 0.23,
    ["sunset"] = 0.77,
    ["ночь"] = 0.85,
    ["полночь"] = 0.0,
    ["утро"] = 0.25,
    ["день"] = 0.5,
    ["полдень"] = 0.5,
    ["вечер"] = 0.72,
    ["рассвет"] = 0.23,
    ["закат"] = 0.77
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
	print("Game.server_onCreate")
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
        lastExecutedActionResponseId = 0
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
    sm.game.bindChatCommand( "/ainpc", { { "string", "mode", true } }, "cl_onChatCommand", "Toggle NPC mode on or off" )
    sm.game.bindChatCommand( "/npcspawn", {}, "cl_onChatCommand", "Spawn a test NPC above the player" )
    sm.game.bindChatCommand( "/npcdespawn", {}, "cl_onChatCommand", "Remove the spawned test NPC" )
    sm.game.bindChatCommand( "/npcnext", {}, "cl_onChatCommand", "Switch to the next NPC test body" )
    sm.game.bindChatCommand( "/aifollow", {}, "cl_onChatCommand", "Set AI cow to follow mode" )
    sm.game.bindChatCommand( "/aistay", {}, "cl_onChatCommand", "Set AI cow to stay mode" )
    sm.game.bindChatCommand( "/aicome", {}, "cl_onChatCommand", "Call AI cow to come to you" )
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
        elseif response.error and response.error ~= "" then
            sm.gui.chatMessage( "[AI bridge error] " .. response.error )
        end

        if response.actions and #response.actions > 0 and response.id > ( self.ai.lastExecutedActionResponseId or 0 ) then
            self.ai.lastExecutedActionResponseId = response.id
            self.network:sendToServer( "sv_executeAiActions", { responseId = response.id, actions = response.actions } )
        end
    end
end

function Game.cl_onChatCommand( self, params )
    if params[1] == "/ainpc" then
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
        local position = nil
        if sm.localPlayer and sm.localPlayer.getPlayer and sm.localPlayer.getPlayer() then
            local localPlayer = sm.localPlayer.getPlayer()
            if localPlayer and localPlayer.character and sm.exists( localPlayer.character ) then
                local playerPos = localPlayer.character.worldPosition
                position = {
                    x = ai_round( playerPos.x ),
                    y = ai_round( playerPos.y ),
                    z = ai_round( playerPos.z )
                }
            end
        end

        local request = {
            id = self.ai.nextRequestId,
            prompt = prompt,
            playerName = "Player",
            sentAt = 0,
            npcEnabled = self.ai.npcEnabled,
            npcName = self.ai.npcName,
            history = self.ai.history,
            position = position,
            liveContext = {
                questState = ai_buildQuestContext()
            }
        }

        self.ai.lastSentRequestId = request.id
        self.ai.nextRequestId = self.ai.nextRequestId + 1
        ai_saveJson( RequestPath, request )
        sm.gui.chatMessage( "[" .. self.ai.npcName .. "] ..." )
        return
    end

    SurvivalGame.cl_onChatCommand( self, params )
end

function Game.sv_requestAiCowMode( self, params, player )
    if player and player.character and sm.exists( player.character ) then
        sm.event.sendToWorld( player.character:getWorld(), "sv_e_setAiNpcMode", { player = player, mode = params.mode } )
    else
        self.network:sendToClient( player, "cl_n_npcStatus", { ok = false, message = "AI cow mode failed: player character missing." } )
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

function Game.sv_executeAiActions( self, params, player )
    if not params or not params.actions or not player then
        return
    end

    for _, action in ipairs( params.actions ) do
        local name = action.name
        local args = action.args or {}
        local statusMessage = nil

        if name == "call_companion" then
            if not ai_followerIsActiveForPlayer( player ) then
                BabyWocManager.Sv_CallFollower( player )
                statusMessage = "Baby woc companion called."
            else
                statusMessage = "Baby woc companion already active."
            end
        elseif name == "dismiss_companion" then
            if ai_followerIsActiveForPlayer( player ) then
                BabyWocManager.Sv_CallFollower( player )
                statusMessage = "Baby woc companion dismissed."
            else
                statusMessage = "Baby woc companion was not active."
            end
        elseif name == "spawn_ai_cow" then
            if player.character and sm.exists( player.character ) then
                sm.event.sendToWorld( player.character:getWorld(), "sv_e_spawnAiNpc", { player = player, npcName = NpcName } )
                statusMessage = "AI cow spawn requested."
            end
        elseif name == "despawn_ai_cow" then
            if player.character and sm.exists( player.character ) then
                sm.event.sendToWorld( player.character:getWorld(), "sv_e_despawnAiNpc", { player = player } )
                statusMessage = "AI cow despawn requested."
            end
        elseif name == "set_ai_mode_follow" then
            if player.character and sm.exists( player.character ) then
                sm.event.sendToWorld( player.character:getWorld(), "sv_e_setAiNpcMode", { player = player, mode = "follow" } )
                statusMessage = "AI cow set to follow mode."
            end
        elseif name == "set_ai_mode_stay" then
            if player.character and sm.exists( player.character ) then
                sm.event.sendToWorld( player.character:getWorld(), "sv_e_setAiNpcMode", { player = player, mode = "stay" } )
                statusMessage = "AI cow set to stay mode."
            end
        elseif name == "set_ai_mode_come" then
            if player.character and sm.exists( player.character ) then
                sm.event.sendToWorld( player.character:getWorld(), "sv_e_setAiNpcMode", { player = player, mode = "come" } )
                statusMessage = "AI cow told to come."
            end
        elseif name == "set_time_of_day" then
            local timeValue = ai_findTimeOfDayValue( args )
            if timeValue ~= nil then
                self.sv.time.timeOfDay = timeValue
                self:sv_updateClientData()
                statusMessage = "Time of day set to " .. tostring( timeValue ) .. "."
            else
                statusMessage = "Time preset/value not recognized."
            end
        elseif name == "set_time_progress" then
            if args.enabled ~= nil then
                self.sv.time.timeProgress = args.enabled == true
                self:sv_updateClientData()
                statusMessage = "Time progression set to " .. tostring( self.sv.time.timeProgress ) .. "."
            end
        elseif name == "activate_quest" then
            local questSpec = ai_extractQuestSpecifier( args )
            local questName = ai_findQuestName( questSpec )
            if questName then
                QuestManager.Sv_TryActivateQuest( questName )
                statusMessage = "Quest activation requested: " .. questName
            else
                statusMessage = "Quest not found for activation."
            end
        elseif name == "complete_quest" then
            local questSpec = ai_extractQuestSpecifier( args )
            local questName = ai_findQuestName( questSpec )
            if questName then
                QuestManager.Sv_CompleteQuest( questName )
                statusMessage = "Quest completion requested: " .. questName
            elseif questSpec == "*" or questSpec == "all_active" or questSpec == "active" or questSpec == "current" or questSpec == "all current" then
                local activeQuests = QuestManager.Sv_GetActiveQuests and QuestManager.Sv_GetActiveQuests() or nil
                local completed = 0
                if activeQuests then
                    for questNameKey, _ in pairs( activeQuests ) do
                        QuestManager.Sv_CompleteQuest( questNameKey )
                        completed = completed + 1
                    end
                end
                statusMessage = "Active quest completion requested for " .. tostring( completed ) .. " quests."
            else
                statusMessage = "Quest not found for completion."
            end
        elseif name == "abandon_quest" then
            local questSpec = ai_extractQuestSpecifier( args )
            local questName = ai_findQuestName( questSpec )
            if questName then
                QuestManager.Sv_TryAbandonQuest( questName )
                statusMessage = "Quest abandon requested: " .. questName
            else
                statusMessage = "Quest not found for abandon."
            end
        end

        if statusMessage then
            self.network:sendToClient( player, "cl_n_aiActionStatus", { message = statusMessage } )
        end
    end
end

function Game.cl_n_npcStatus( self, params )
    sm.gui.chatMessage( "[NPC] " .. tostring( params.message ) )
end

function Game.cl_n_aiActionStatus( self, params )
    sm.gui.chatMessage( "[AI action] " .. tostring( params.message ) )
end
