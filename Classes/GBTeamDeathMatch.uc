/*
Gamebots UT Copyright (c) 2002, Andrew N. Marshal, Gal Kaminka
Gamebots Pogamut derivation Copyright (c) 2012, Petr Kucera, Michal Bida

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

   * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

This software must also be in compliance with the Epic Games Inc. license for mods which states the following: "Your mods must be distributed solely for free, period. Neither you, nor any other person or party, may sell them to anyone, commercially exploit them in any way, or charge anyone for receiving or using them without prior written consent of Epic Games Inc. You may exchange them at no charge among other end-users and distribute them to others over the Internet, on magazine cover disks, or otherwise for free." Please see http://www.epicgames.com/ut2k4_eula.html for more information.

*/

class GBTeamDeathMatch extends GBCopyUTTeamGame;
`include(Globals.uci);
`define debug;

event InitGame(string Options, out string Error )
{
	super.InitGame(Options, Error);

	bPlayersBalanceTeams = false;
}

/**
 * Provides information about the game for NFO batch
 * @note Attributes: GoalTeamScore, MaxTeams, MaxTeamSize
 * @return String representaion in GB protocol
 */ 
function string GetGameInfo()
{
    local string outStr;

    outStr = GetBasicGameInfo() @ 
    	"{GoalTeamScore " $ GoalScore $
		"} {MaxTeams 2"  $ //there are always two teams
		"} {MaxTeamSize" @ Teams[0].DesiredTeamSize $
		"}";

    return outStr;
}

/**
 * Sends team scores to the client.
 * 
 * @note Messages: TES
 * @note Attributes: Id, Score, Team
 */ 
function SendGameStatus(GBClientClass requester)
{
	local int i;
	local string outString;

	super.SendGameStatus(requester);

	for (i = 0; i < 2; i++){// there are always two teams!
		requester.SendLine("TES {Id " $ Teams[i].TeamIndex $
			"} {Team " $ Teams[i].TeamIndex $
			"} {Score " $ int(Teams[i].Score) $
			"}");
	}
}

/**
 * Adds Remotebot to specified team.
 * 
 * @param NewBot RemoteBot we are adding to team
 * @param TeamNum 0 for Red, 1 for Blue, 255 for smallest team; All other values
 *          will be treated as 255.
 * @return Returns true upon success, false otherwise.
 */ 
function bool AddRemoteBotToTeam(Controller NewBot, int TeamNum)
{
	local UTTeamInfo smallTeam;
	NewBot.PlayerReplicationInfo.bBot = true;

	if(Teams[0].Size > Teams[1].Size) smallTeam = Teams[1];
	else smallTeam = Teams[0];

	`LogDebug("TeamNum:" @ TeamNum);
	if (TeamNum < 2 && TeamNum >=0){
		return ChangeTeam(NewBot, TeamNum, true);
	}
	else {
		`LogInfo("Team number out of bounds. Using smallest team! TeamNum:" @ TeamNum);
		return ChangeTeam(NewBot, smallTeam.TeamIndex, true);
	}
}

/**
 * Disables team balancing.
 */
function BalanceTeams(optional bool bForceBalance)
{
}

DefaultProperties
{
	bScoreTeamKills=true
	bMustJoinBeforeStart=false
	bTeamGame=True
	TeamAIType(0)=class'UTGame.UTTeamAI'
	TeamAIType(1)=class'UTGame.UTTeamAI'
	EndMessageWait=1
	TeammateBoost=+0.3
	FriendlyFireScale=+0.0
	bMustHaveMultiplePlayers=true
	DefaultEnemyRosterClass="UTGame.UTTeamInfo"
	FlagKillMessageName=TAUNT
	bShouldPostRenderEnemyPawns=false

	Acronym="TDM"
	MapPrefixes[0]="DM"
 	HUDType=class'UTTeamHUD'

	// Class used to write stats to the leaderboard
	OnlineStatsWriteClass=class'UTGame.UTLeaderboardWriteTDM'
	OnlineGameSettingsClass=class'UTGameSettingsTDM'
	MidgameScorePanelTag=TDMPanel

	// We don't want players on opposing teams to be able to hear each other
	bIgnoreTeamForVoiceChat=false

	MapType=class'UTTeamGame'
	GameName="GameBotsUT3 Team DeathMatch"
    GameClass="BotDeathMatch"
}
