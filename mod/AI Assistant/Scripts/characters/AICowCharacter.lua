dofile "$SURVIVAL_DATA/Scripts/game/characters/BabyWocCharacter.lua"

AICowCharacter = class( BabyWocCharacter )

local RequestPath = "$CONTENT_DATA/Cache/ai_bridge_request.json"
local ResponsePath = "$CONTENT_DATA/Cache/ai_bridge_response.json"
local GuiData = sm.json.open( "$CONTENT_DATA/Gui/JsonGuis/AICow.gui" )

local function ai_loadJson( path )
	if sm.json.fileExists( path ) then
		return sm.json.open( path )
	end
	return nil
end

local function ai_saveJson( path, data )
	sm.json.save( data, path )
end

function AICowCharacter.client_onCreate( self )
	BabyWocCharacter.client_onCreate( self )
	self.cl.aiGui = nil
	self.cl.aiHistory = {}
	self.cl.aiNpcName = "MooMoo"
end

function AICowCharacter.client_onDestroy( self )
	BabyWocCharacter.client_onDestroy( self )
	if self.cl.aiGui and sm.exists( self.cl.aiGui ) and self.cl.aiGui:isActive() then
		self.cl.aiGui:close()
	end
	self.cl.aiGui = nil
end

function AICowCharacter.client_canInteract( self )
	local keyBindingText = sm.gui.getKeyBinding( "Use", true )
	sm.gui.setInteractionText( "", keyBindingText, "Talk to AI Cow" )
	return true
end

function AICowCharacter.client_onInteract( self, character, state )
	if state then
		self:cl_sendAiPrompt( "Say a short friendly hello as MooMoo the cow companion." )
		self:cl_openAiGui()
	end
end

function AICowCharacter.cl_openAiGui( self )
	if self.cl.aiGui and sm.exists( self.cl.aiGui ) and self.cl.aiGui:isActive() then
		self.cl.aiGui:close()
	end

	self.cl.aiGui = sm.jsonGui.createGui( { isInteractive = true, needsCursor = true, hidesHotbar = true } )
	self.cl.aiGui:render( GuiData )
	self.cl.aiGui:open()
end

function AICowCharacter.cl_sendAiPrompt( self, prompt )
	if not prompt or prompt == "" then
		return
	end

	local nextId = 1
	local existingRequest = ai_loadJson( RequestPath )
	local existingResponse = ai_loadJson( ResponsePath )
	if existingRequest and existingRequest.id then
		nextId = math.max( nextId, existingRequest.id + 1 )
	end
	if existingResponse and existingResponse.id then
		nextId = math.max( nextId, existingResponse.id + 1 )
	end

	local request = {
		id = nextId,
		prompt = prompt,
		playerName = "Player",
		sentAt = 0,
		npcEnabled = true,
		npcName = self.cl.aiNpcName,
		history = self.cl.aiHistory
	}

	self.cl.aiHistory[#self.cl.aiHistory + 1] = {
		role = "user",
		text = prompt
	}

	ai_saveJson( RequestPath, request )
	sm.gui.chatMessage( "[" .. self.cl.aiNpcName .. "] ..." )
end

function AICowCharacter.sv_n_setAiCowMode( self, params, player )
	if player and player.character and sm.exists( player.character ) then
		sm.event.sendToWorld( player.character:getWorld(), "sv_e_setAiNpcMode", { player = player, mode = params.mode } )
	end
end
