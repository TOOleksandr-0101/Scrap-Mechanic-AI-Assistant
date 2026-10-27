dofile( "$SURVIVAL_DATA/Scripts/game/worlds/Overworld.lua" )

AIOverworld = class( Overworld )

local TestNpcCandidates = {
    { uuid = unit_baby_woc, label = "baby_woc" },
    { uuid = unit_builderguideFarmer, label = "builderguideFarmer" },
    { uuid = unit_questnpchubert, label = "questnpchubert" },
    { uuid = unit_questnpclorenzo, label = "questnpclorenzo" },
    { uuid = unit_questnpcphe, label = "questnpcphe" },
    { uuid = unit_shipMechanic, label = "shipMechanic" }
}
local SpawnProbeHeight = 3.0
local GroundSnapDepth = 12.0
local GroundOffset = 0.05
local FollowOffset = 1.75
local FollowTeleportDistance = 18.0
local FollowStartDistance = 1.0
local FollowTickInterval = 4
local FollowRunDistance = 3.0

function AIOverworld.server_onCreate( self )
    Overworld.server_onCreate( self )
    self.sv.aiTestNpcs = {}
    self.sv.aiFollowTick = 0
    self.sv.aiCandidateIndex = 1
    print( "AIOverworld.server_onCreate" )
end

local function ai_getPlayerCharacter( player )
    if player and sm.exists( player ) and player.character and sm.exists( player.character ) then
        return player.character
    end
    return nil
end

local function ai_findGroundPosition( origin, direction, ignoreCharacter )
    local probeStart = origin + sm.vec3.new( 0, 0, SpawnProbeHeight )
    local probeEnd = origin - sm.vec3.new( 0, 0, GroundSnapDepth )
    local hit, result = sm.physics.raycast( probeStart, probeEnd, ignoreCharacter, sm.physics.filter.static + sm.physics.filter.dynamicBody )
    if hit then
        return result.pointWorld + sm.vec3.new( 0, 0, GroundOffset )
    end
    return origin + sm.vec3.new( 0, 0, GroundOffset )
end

local function ai_getCurrentCandidate( self )
    local index = self.sv.aiCandidateIndex or 1
    local candidate = TestNpcCandidates[index]
    if not candidate then
        self.sv.aiCandidateIndex = 1
        candidate = TestNpcCandidates[1]
    end
    return candidate
end

function AIOverworld.sv_e_spawnAiNpc( self, params )
    local player = params and params.player
    local npcName = params and params.npcName or "Sparks"
    local character = ai_getPlayerCharacter( player )
    if not character then
        return
    end

    self:sv_e_despawnAiNpc( { player = player } )

    local dir = character.direction
    local yaw = math.atan2( dir.y, dir.x ) - math.pi / 2
    local desiredPos = character.worldPosition - dir * FollowOffset
    local spawnPos = ai_findGroundPosition( desiredPos, dir, character )
    local candidate = ai_getCurrentCandidate( self )

    local unit = sm.unit.createUnit( candidate.uuid, spawnPos, yaw, {}, nil, true )
    if unit and sm.exists( unit ) then
        self.sv.aiTestNpcs[player.id] = {
            player = player,
            unit = unit,
            npcName = npcName,
            candidateLabel = candidate.label,
            mode = "follow"
        }

        if unit.character and sm.exists( unit.character ) then
            unit.character:setNameTag( npcName )
        end

        sm.event.sendToGame( "cl_n_npcStatus", { message = "Spawned candidate: " .. candidate.label } )
        print( "[AIOverworld] NPC spawned for", player.name, candidate.label )
    else
        sm.event.sendToGame( "cl_n_npcStatus", { message = "Spawn failed for candidate: " .. candidate.label } )
        print( "[AIOverworld] NPC spawn failed for", player.name, candidate.label )
    end
end

function AIOverworld.sv_e_despawnAiNpc( self, params )
    local player = params and params.player
    if not player or not self.sv.aiTestNpcs then
        return
    end

    local npcData = self.sv.aiTestNpcs[player.id]
    local unit = npcData and npcData.unit
    if unit and sm.exists( unit ) then
        sm.unit.destroyUnit( unit )
    end
    self.sv.aiTestNpcs[player.id] = nil
    print( "[AIOverworld] NPC despawned for", player.name )
end

function AIOverworld.sv_e_cycleAiNpcCandidate( self, params )
    self.sv.aiCandidateIndex = ( self.sv.aiCandidateIndex or 1 ) + 1
    if self.sv.aiCandidateIndex > #TestNpcCandidates then
        self.sv.aiCandidateIndex = 1
    end

    local candidate = ai_getCurrentCandidate( self )
    sm.event.sendToGame( "cl_n_npcStatus", { message = "Current candidate: " .. candidate.label } )

    local player = params and params.player
    if player then
        self:sv_e_despawnAiNpc( { player = player } )
    end
end

function AIOverworld.sv_e_setAiNpcMode( self, params )
    local player = params and params.player
    if not player or not self.sv.aiTestNpcs then
        return
    end

    local npcData = self.sv.aiTestNpcs[player.id]
    if npcData then
        npcData.mode = params.mode or "follow"
        sm.event.sendToGame( "cl_n_npcStatus", { message = "AI cow mode: " .. tostring( npcData.mode ) } )
    end
end

function AIOverworld.server_onFixedUpdate( self )
    Overworld.server_onFixedUpdate( self )

    if not self.sv.aiTestNpcs then
        return
    end

    self.sv.aiFollowTick = ( self.sv.aiFollowTick or 0 ) + 1
    if self.sv.aiFollowTick < FollowTickInterval then
        return
    end
    self.sv.aiFollowTick = 0

    for playerId, npcData in pairs( self.sv.aiTestNpcs ) do
        local player = npcData.player
        local unit = npcData.unit

        if not player or not sm.exists( player ) or not unit or not sm.exists( unit ) then
            self.sv.aiTestNpcs[playerId] = nil
        else
            local playerCharacter = ai_getPlayerCharacter( player )
            local npcCharacter = unit.character

            if not playerCharacter or not npcCharacter or not sm.exists( npcCharacter ) then
                self.sv.aiTestNpcs[playerId] = nil
            elseif npcCharacter:getWorld() == playerCharacter:getWorld() then
                local desiredPos = playerCharacter.worldPosition - playerCharacter.direction * FollowOffset
                local targetPos = ai_findGroundPosition( desiredPos, playerCharacter.direction, playerCharacter )
                local delta = targetPos - npcCharacter.worldPosition
                local flatDelta = sm.vec3.new( delta.x, delta.y, 0 )
                local distance = flatDelta:length()
                local mode = npcData.mode or "follow"

                if mode == "stay" then
                    sm.event.sendToCharacter( npcCharacter, "sv_n_updateTarget", { target = nil } )
                    unit:setFacingDirection( playerCharacter.direction )
                    unit:setMovementDirection( sm.vec3.new( 0, 0, 0 ) )
                    unit:setMovementType( "walk" )
                elseif distance > FollowTeleportDistance or mode == "come" then
                    sm.event.sendToCharacter( npcCharacter, "sv_n_updateTarget", { target = playerCharacter } )
                    npcCharacter:setWorldPosition( targetPos )
                    unit:setFacingDirection( playerCharacter.direction )
                    unit:setMovementDirection( sm.vec3.new( 0, 0, 0 ) )
                    unit:setMovementType( "walk" )
                    npcData.mode = "follow"
                elseif distance > FollowStartDistance then
                    sm.event.sendToCharacter( npcCharacter, "sv_n_updateTarget", { target = playerCharacter } )
                    local moveDir = flatDelta:normalize()
                    unit:setFacingDirection( moveDir )
                    unit:setMovementDirection( moveDir )
                    if distance > FollowRunDistance then
                        unit:setMovementType( "sprint" )
                    else
                        unit:setMovementType( "walk" )
                    end
                else
                    sm.event.sendToCharacter( npcCharacter, "sv_n_updateTarget", { target = playerCharacter } )
                    unit:setFacingDirection( playerCharacter.direction )
                    unit:setMovementDirection( sm.vec3.new( 0, 0, 0 ) )
                    unit:setMovementType( "walk" )
                end
            end
        end
    end
end
