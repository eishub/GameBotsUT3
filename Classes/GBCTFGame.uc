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
class GBCTFGame extends GBCopyUTCTFGame_Content;
`include(Globals.uci);
`define debug;

function PreBeginPlay() {
    super.PreBeginPlay();

    // Hack?
    WorldInfo.GRI.RemovePRI(WorldInfo.GRI.PRIArray[1]);
    WorldInfo.GRI.RemovePRI(WorldInfo.GRI.PRIArray[0]);
}

function PostBeginPlay(){
	local GBCTFFlag redFlag, blueFlag;
	local UTCTFBase redBase, blueBase;
	local array<Actor> validBases;

	FindActorsOfClass(class'UTCTFRedFlagBase', validBases);
	redBase = UTCTFBase(validBases[0]);
	FindActorsOfClass(class'UTCTFBlueFlagBase', validBases);
	blueBase = UTCTFBase(validBases[0]);

	redFlag = Spawn(class'GBCTFRedFlag',redBase);
	redFlag.HomeBase = redBase;
	redBase.myFlag = redFlag;
	blueFlag = Spawn(class'GBCTFBlueFlag',blueBase);
	blueFlag.HomeBase = blueBase;
	blueBase.myFlag = blueFlag;

	RegisterFlag(redFlag,0);
	RegisterFlag(blueFlag,1);

	super.PostBeginPlay();
}

/**
 * Provides information about the game for NFO batch
 * @note Attributes: GoalTeamScore, MaxTeams, MaxTeamSize,
 *          RedBaseLocation, BlueBaseLocation
 * @return String representaion in GB protocol
 */ 
function string GetGameInfo()
{
    local string outStr;

    outStr = GetBasicGameInfo() @ 
    	"{GoalTeamScore " $ GoalScore $
		"} {MaxTeams 2"  $ //there are always two teams
		"} {MaxTeamSize" @ Teams[0].DesiredTeamSize $
		"} {RedBaseLocation" @ Teams[0].HomeBase.Location $
		"} {BlueBaseLocation" @ Teams[1].HomeBase.Location $
		"}";
    return outStr;
}

/**
 * Sends team scores to the client.
 * 
 * @note Messages: FLG
 * @note Attributes: Id, Location, Holder, Team, Reachable, Visible, State
 */ 
function SendGameStatus(GBClientClass requester)
{
	local UTCTFFlag F;
	local RemoteBot requesterBot;
	local string outString;

	super.SendGameStatus(requester);

	requesterBot = BotConnection(requester).theBot;
	if (requesterBot == none)
		return;

	foreach AllActors(class'UTCTFFlag', F){

			outString = "FLG {Id " $ class'GBUtil'.static.GetUniqueId(F) $
				"} {Team " $ F.Team.TeamIndex $
			//	"} {Reachable " $ actorReachable(F) $
				"} {State " $ F.GetStateName() $
				"}";

			//flag is NOT updated when it is held - we need to use holder to query info about location
			//and visibility!
			if(F.IsInState('Held') && F.Holder != none) {
      			if (requesterBot.InFOV(F.Holder.Location) && FastTrace(F.Holder.Location, requesterBot.Pawn.Location)) {
			    	outstring = outstring $" {Visible True} {Location " $ F.Holder.Location $
    			        "} {Holder " $ class'GBUtil'.static.GetUniqueId(F.Holder) $"}";
			  	} else if (F.Holder == requesterBot.Pawn) { //our pawn is holder
        			outstring = outstring $" {Visible True" $
            			"} {Location " $ F.Holder.Location $
		            	"} {Holder " $ class'GBUtil'.static.GetUniqueId(F.Holder) $"}";
        		} else {
		        	outString = outstring $" {Visible False}";
				}
			} else {
				if (requesterBot.InFOV(F.Location) && FastTrace(F.Location, requesterBot.Pawn.Location)) {
		        	outString = outstring $" {Visible True} {Location " $ F.Location $
	    		        "} {Holder None}";
				} else {
        			outString = outstring $" {Visible False}";
				}
			}
		requester.SendLine(outString);
	}
}

DefaultProperties
{
	bAllowTranslocator=false
	bUndrivenVehicleDamage=true
	bSpawnInTeamArea=true
	bScoreTeamKills=False
	MapPrefixes[0]="CTF"
	Acronym="CTF"
	TeamAIType(0)=class'UTGame.UTCTFTeamAI'
	TeamAIType(1)=class'UTGame.UTCTFTeamAI'
	bScoreVictimsTarget=true
	DeathMessageClass=class'UTTeamDeathMessage'
	FlagKillMessageName=FLAGKILL

	// Class used to write stats to the leaderboard
	OnlineStatsWriteClass=class'UTGame.UTLeaderboardWriteCTF'
	OnlineGameSettingsClass=class'UTGameSettingsCTF'

	bScoreDeaths=false
	MidgameScorePanelTag=CTFPanel

	TranslocatorClass=class'UTWeap_Translocator_Content'

	AnnouncerMessageClass=class'UTCTFMessage'
 	TeamScoreMessageClass=class'UTGameContent.UTTeamScoreMessage'

	MapType=class'UTCTFGame_Content'
	GameName="GameBotsUT3 Capture The Flag"
    GameClass="BotCTFGame"
	HUDType=class'UTCTFHUD'
}
