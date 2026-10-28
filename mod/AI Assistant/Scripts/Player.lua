dofile "$SURVIVAL_DATA/Scripts/game/SurvivalPlayer.lua"

Player = class( SurvivalPlayer )

g_localSurvivalPlayer = nil

function Player.server_onCreate( self )
    SurvivalPlayer.server_onCreate( self )
end

function Player.client_onCreate( self )
    SurvivalPlayer.client_onCreate( self )
    if self.player == sm.localPlayer.getPlayer() then
        g_localSurvivalPlayer = self
    end
end

function Player.client_onDestroy( self )
    if g_localSurvivalPlayer == self then
        g_localSurvivalPlayer = nil
    end
    SurvivalPlayer.client_onDestroy( self )
end

function Player.client_onRefresh( self )
    SurvivalPlayer.client_onRefresh( self )
    if self.player == sm.localPlayer.getPlayer() then
        g_localSurvivalPlayer = self
    end
end
