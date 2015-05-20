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


//=============================================================================
// DeathMatchPlus.
//=============================================================================
class BotDeathMatch extends UTDeathMatch
        config(GameBotsUT3);
`include(Globals.uci);
`define debug;

var BotServer           theBotServer;
var ControlServer       theControlServer;
var bool                bServerLoaded, bBoolResult;
var int                 NumRemoteBots;
var string GameClass;

var string RemoteBotController;

var class<BotServer> BotServerClass;

var class<ControlServer> ControlServerClass;

var PlayerReplicationInfo LevelPauserFeed;

//this is ID counter that is used for objects in UnrealScript that doesn't have
//exportable unique ID - (
//ped weapons, vehicles or projectiles)
var int GameBotsID;

var config int BotServerPort;
var config int ControlServerPort;

//enables vehicles in the game
var config bool bVehiclesEnabled;

//if set to true all weapons from map will be erased
var bool bShouldEraseAllWeapons;

//here we store if our connections to bot and cotrol server are protected by pass
//will force a bit changed initial protocol (to check password)
var bool bPasswordProtected;

//here we store Password for bot and control connections
var string Password;

//who initiated the password protection
var string PasswordByIP;

// This class is used for pausing the game. We supply it to WorldInfo.Pauser variable.
var PauserFeed WorldInfoPauserFeed;

// The supported maps
var class MapType;

//Here we store all available maps
var array<string> Maps;

//@todo for testing only!
struct ReplacedInfo{
	var NavigationPoint original;
	var NavigationPoint replacement;
};
var array<ReplacedInfo> replacedMap;

//will be filled up with all movers in the level
var array<InterpActor> MoverArray;
//will be filled up with all inv spots in the level
var array<PickupFactory> InvSpotArray;
//will be filled up with all doors in the level
var array<DoorMarker> DoorArray;
//will be filled up with all lift centers in the level
var array<LiftCenter> LiftCenterArray;

/**
 * Parses command line parameters.
 * @note this functions is called even before PreBeginPlay.
 * Here we get to know if the game should be password protected.
 * 
 * @param Options command line parameters
 * @param Error Error output
 */ 
event InitGame(string Options, out string Error )
{
    local string InOpt;
    local Mutator M;
	local GBPickupMutator GBMut;
	local int i,j;
	local NavigationPoint nav;

	//adds GBPickupMutator to the list of active mutators
/*	GBMut = Spawn(class'GBPickupMutator');
	if (BaseMutator != none){
		M = BaseMutator;
		while (M.NextMutator != none) M = M.NextMutator;
		M.NextMutator = GBMut;
		M = none;
	}
	else BaseMutator = GBMut;*/
/*
	for (i = 0; i < GBMut.PickupToReplace.Length; i++){
		`logDebug("oldClassName:" @ GBMut.PickupToReplace[i].OldClassName);
		`logDebug("newClassPath:" @ GBMut.PickupToReplace[i].NewClassPath);
	}
*/
    super.InitGame(Options, Error);

	/*foreach AllActors(class'NavigationPoint', nav){
		if (nav.IsA('UTItemPickupFactory')){
			//we have replaced this one and we need to connect the
			//replacement factory into navigation graph
			if(replacedMap.Find('original',nav) != INDEX_NONE){
				i = replacedMap.Find('original', nav);
				for (j = 0; j < nav.PathList.Length; j++){
					replacedMap[i].replacement.PathList.Add(nav.PathList[j]);
				}
				nav.PathList.Remove(0,nav.PathList.Length);
			}
			//the replacement is handled above
			else if (replacedMap.Find('replacement', nav) != INDEX_NONE){
				continue;
			}
			//that should not happen!
			else{
				`logError("not replaced UTItemPickupFactory:" @ nav);
			}
		}
		//we need to connect the replacement factories to the navigation graph
		else{
			for (i = 0; i < nav.PathList.Length; i++){
				if (replacedMap.Find('original',nav.PathList[i].End.Nav) != INDEX_NONE){
					j = replacedMap.Find('original', nav.PathList[i].End.Nav);
					nav.PathList[i].End.Nav = replacedMap[j].replacement;
					nav.PathList[i].End.Guid = replacedMap[j].replacement.NavGuid;
				}
			}
		}
	}
*/
	//`log("BotserverPort" $ BotServerPort);
	//`log("ControlServerPort" $ ControlServerPort);

    BotServerPort = Clamp(GetIntOption( Options, "BotServerPort", BotServerPort ),2000,32000);
    ControlServerPort = Clamp(GetIntOption( Options, "ControlServerPort", ControlServerPort ),2000,32000);


	//`log("BotserverPort" $ BotServerPort);
	//`log("ControlServerPort" $ ControlServerPort);
	`LogDebug("Options: " $ Options);

    InOpt = ParseOption( Options, "Password");
    if (InOpt != ""){
        bPasswordProtected = true;
        PasswordByIP = WorldInfo.GetAddressURL();
        Password = InOpt;
    }
    else
        bPasswordProtected = false;
	`LogDebug("bPasswordProtected: " $ bPasswordProtected);
	`LogDebug("InOpt: " $ InOpt);
}

//movers are static, we will put all movers to the dynamic array, this
//significantly decrease the time we need to process them all in checkVision() fc
//the same holds for navigation points
function initStaticObjectsArrays()
{
	local InterpActor M;
	local NavigationPoint N;

	foreach AllActors(class'InterpActor',M) {
		MoverArray[MoverArray.Length] = M;
	}

    foreach WorldInfo.AllNavigationPoints(class'NavigationPoint', N) {
		if (N.IsA('PickupFactory')) {
			if ((PickupFactory(N).OriginalFactory == none))//only cache NON replaced PickupFactories - will be exported as NAV message in checkNavPoints
				InvSpotArray[InvSpotArray.Length] = PickupFactory(N);
		} else if (N.IsA('DoorMarker')) {
			DoorArray[DoorArray.Length] = DoorMarker(N);
		} else if (N.IsA('LiftCenter')) {
			LiftCenterArray[LiftCenterArray.Length] = LiftCenter(N);
		}
	}
}

//This function is automaticaly called after beginning of the game
/**
 * Sets up control and bot servers.
 * 
 * @note PauserFeeds spawned here.
 * 
 * @todo Why are the maps loaded in special variable in BotDeathMatch?
 */ 
function PreBeginPlay()
{
	local int GameIndex, i;

	//local int GameIndex;
    Super.PreBeginPlay();

    theBotServer = Spawn(BotServerClass,self,'botServer');
    theBotServer.ListenPort = BotServerPort;

    theControlServer = Spawn(ControlServerClass,self,'controlServer');
    theControlServer.ListenPort = ControlServerPort;

    bServerLoaded = true;

        //HACK? Set to true, so the match will start imediatelly
        //We should implement support for StartMatch function...
    bQuickStart = true;

    GameBotsID = 0;
    WorldInfoPauserFeed = Spawn(class'PauserFeed');

        //RemoteBotConfig.Difficulty = AdjustedDifficulty;

    GameIndex = class'UTGame'.default.GameSpecificMapCycles.Find('GameClassName', BotDeathMatch(WorldInfo.Game).MapType.Name);
    Maps = class'UTGame'.default.GameSpecificMapCycles[GameIndex].Maps;

    LevelPauserFeed = Spawn(class'PauserFeed',self);

	`LogInfo("BotServerPort:"$theBotServer.Port$
			" ControlServerPort:"$theControlServer.Port);
}

/**
 * Spawns navigation grid and switches UTItemPickupFactories for thier
 *  respective GB equivalents.
 */ 
function PostBeginPlay(){
	local NavigationPoint nav;
	local GBPathMarker PathMarker;
	local UTItemPickupFactory itemPF, newPF;
	local array<UTItemPickupFactory> oldPFs;
	local int i;
	
	super.PostBeginPlay();
/*
	foreach AllActors(class'UTItemPickupFactory', itemPF){
		oldPFs.AddItem(itemPF);
	}

	for(i = 0; i < oldPFs.Length; i++){
		if(oldPFs[i].IsA('UTPickupFactory_HealthVial')){
			//newPF = Spawn(class'GBPickupFactory_HealthVial');
			newPF = Spawn(class'GBPickupFactory_MediumHealth');
			oldPFs[i].ReplacementFactory = newPF;
			newPF.OriginalFactory = oldPFs[i];
		}
		else if(oldPFs[i].IsA('UTPickupFactory_MediumHealth')){
			//newPF = Spawn(class'GBPickupFactory_MediumHealth');
			newPF = Spawn(class'GBPickupFactory_HealthVial');
			oldPFs[i].ReplacementFactory = newPF;
			newPF.OriginalFactory = oldPFs[i];
		}
		else if(oldPFs[i].IsA('UTPickupFactory_SuperHealth')){
			newPF = Spawn(class'GBPickupFactory_SuperHealth');
			oldPFs[i].ReplacementFactory = newPF;
			newPF.OriginalFactory = oldPFs[i];
		}
	}
*/
	//fills up our static object arrays
	initStaticObjectsArrays();
}

/**
 * Provides not gametype specific information
 * for NFO batch 
 * @note Attributes: GameType,WeaponStay,TimeLimit
 * @return String representation in GB protocol
 */ 
function string GetBasicGameInfo()
{
	local string strRet;
	
	strRet = "{Gametype " $ GameClass $
                "} {WeaponStay " $ class'GBUtil'.static.GetBoolString(bWeaponStay) $
                "} {TimeLimit " $ TimeLimit $ "}";
	`LogDebug(strRet);
	return strRet;
}

/**
 * Provides information about the game for NFO batch
 * @note Attributes: FragLimit
 * @return String representaion in GB protocol
 */ 
function string GetGameInfo()
{
    local string outStr;

    outStr = GetBasicGameInfo() $ " {FragLimit " $ GoalScore $ "}";

    return outStr;
}

/**
 * Sends game score to the client.
 * 
 * @note Messages: PLS
 * @note Attributes: Id, Score, Deaths
 */ 
function SendGameStatus(GBClientClass requester)
{
    local Controller C;

    foreach WorldInfo.AllControllers(class'Controller', C)
    {
        if( (C.IsA('RemoteBot')) && !C.IsA('Spectator') )
        {
            requester.SendLine("PLS {Id " $ /*requester.*/class'GBUtil'.static.GetUniqueId(C) $
                    "} {Score " $ int(C.PlayerReplicationInfo.Score) $
                    "} {Deaths " $ int(C.PlayerReplicationInfo.Deaths) $
                    "}");
        }
    }
}

//Used for restarting our RemoteBots
/**
 * Handles respawn.
 * Function has to be here since the FindPlayerStart function is located in the
 * UTGame.uc class, which is a super class of BotDeathMatch.uc (this class).
 * RemoteBot.uc can't call FindPlayerStart.
 */ 
function RemoteRestartPlayer( Controller aPlayer, optional vector startLocation, optional rotator startRotation )
{
	SpawnPawn(RemoteBot(aPlayer), startLocation, startRotation);
}


/**
 * Handles creating of a new agent.
 * 
 * @note Creates the controller.
 * 
 * @return Returns RemoteBot instance with provided settings.
 * 
 * @todo className seems to be unused.
 * @todo Notifying other bots not implemented yet.
 * @todo What to do if we fail to add bot to a team in teamGame??
 * 
 * @param theConnection connection the agent will be asociated with.
 * @param clientName player name
 * @param TeamNum team number
 * @param className class of the bot controller
 * @param DesiredSkin agents skin
 * @param DesiredSkill agents skill
 * @param ShouldLeadTarget indicates if the agent should have the
 * lead target abbility
 */ 
function RemoteBot AddRemoteBot
(
        BotConnection theConnection,
        string clientName,
        int TeamNum,
        optional string className,
        optional string DesiredSkin,
        optional float DesiredSkill,
        optional bool ShouldLeadTarget
)
{
    local RemoteBot NewBot;
	local CustomCharData skinData;
	local int index;
	local CustomCharMergeState st;
	local SkeletalMesh M;

    //I dont think location here is necessary. Its just controller class
    NewBot = Spawn(class<RemoteBot>(DynamicLoadObject(RemoteBotController, class'Class')),self);

    if ( NewBot == None ){
        `LogError("Cannot spawn controller class!");
            return None;
    }

    //hook up connection to socket
    NewBot.myConnection = theConnection;

    NewBot.bIsPlayer = true;

    // Set the player's ID.
    NewBot.PlayerReplicationInfo.PlayerID = CurrentID++;

    // Add custom GBReplicationInfo
    NewBot.myRepInfo = Spawn(class'GBReplicationInfo',NewBot);
    NewBot.myRepInfo.MyPRI = NewBot.PlayerReplicationInfo;

    //Increase numbers properly, so no epic bot will join the game
    NumRemoteBots++;
    NumPlayers++;

    if ( clientName != "" ){
        NewBot.PlayerReplicationInfo.PlayerName = clientName;
        changeName(newBot, clientName, true);
    }

    if (!AddRemoteBotToTeam(NewBot,TeamNum)){
        `LogError("Cannot add bot to team:" @ TeamNum);
        //NewBot.Destroy();
        //return None;
    }

    //Turns on strafing ability
    Newbot.StrafingAbility = 1.0;
	//Sets the skill. Value ranges from 0 to 7.
	if ((DesiredSkill > 0) && (DesiredSkill <= 7))
		Newbot.Skill = DesiredSkill;
	else
        Newbot.Skill = 7;
    //Shooting ahead of targets - disabled? - aiming is thing of a client
    NewBot.bLeadTarget = ShouldLeadTarget;

    //We will let the bots know that new bots came to server
    //RemoteNotifyloging(newBot);

	//Set Desired skin
	/*if(DesiredSkin != ""){
		index = class'UTCustomChar_Data'.default.Characters.Find('CharName', DesiredSkin);
		if(index != INDEX_NONE){
			skinData = class'UTCustomChar_Data'.default.Characters[index].CharData;
			`logDebug("Character found:" @ class'UTCustomChar_Data'.default.Characters[index].CharName);
			`logDebug("UTG:" @ UTGame(WorldInfo.Game));
			`logDebug("bNoCustomCharacters:" @ UTGame(WorldInfo.Game).bNoCustomCharacters);
			`logDebug("!WorldInfo.IsPlayInEditor():" @ !WorldInfo.IsPlayInEditor());
			`logDebug("NewData != CharacetrData:" @ skinData != UTPlayerReplicationInfo(NewBot.PlayerReplicationInfo).CharacterData);
			`logDebug("GameReplInfo:" @ UTGameReplicationInfo(WorldInfo.GRI));
			`logDebug("CharacterMesh before:" @ UTPlayerReplicationInfo(NewBot.PlayerReplicationInfo).CharacterMesh);
			UTPlayerReplicationInfo(NewBot.PlayerReplicationInfo).SetCharacterData(skinData);
			//UTGameReplicationInfo(WorldInfo.GRI).ProcessCharacterData(UTPlayerReplicationInfo(NewBot.PlayerReplicationInfo),false);
			//UTPlayerReplicationInfo(NewBot.PlayerReplicationInfo).RetryProcessCharacterData();
			UTGameReplicationInfo(WorldInfo.GRI).StartProcessingCharacterData();
			st = class'UTCustomChar_Data'.static.StartCustomCharMerge(skinData,UTPlayerReplicationInfo(NewBot.PlayerReplicationInfo).GetCustomCharTeamString(),none, CCTR_Self);
			//Sleep(10);
			M = class'UTCustomChar_Data'.static.FinishCustomCharMerge(st);
			UTPlayerReplicationInfo(NewBot.PlayerReplicationInfo).CharacterMesh = M;
			`logDebug("CharacterMesh after:" @ UTPlayerReplicationInfo(NewBot.PlayerReplicationInfo).CharacterMesh);
			`logDebug("CharData == skinData after change:" @ skinData == UTPlayerReplicationInfo(NewBot.PlayerReplicationInfo).CharacterData);
		}
		else `logWarn("Cannot find specified skin:" @ DesiredSkin);
	}
	else `logInfo("Desired skin not set.");*/

    return NewBot;
}

//Here we spawn and respawn the bot Pawn - thats the visible avatar of the bot
/**
 * Handles spawning of pawns for remote agents.
 * 
 * @note Messages: SPW
 * 
 * @note used for spawning pawns for new agents
 * and for respawning also.
 * 
 * @todo startLocation seems to be unused now.
 * @todo spawning at custom location is not implemented yet.
 * 
 * @param NewBot agent we are spawning the pawn for
 * @param startLocation location of the new pawn
 * @param startRotation rotator of the new pawn
 */ 
function SpawnPawn(RemoteBot NewBot, optional vector startLocation, optional rotator startRotation)
{
    local NavigationPoint startSpot;
    local int TeamNum;

    if (NewBot == None){
		`LogError("NewBot is None! ");
		return;
    }

    if (NewBot.Pawn != None){
        `LogError(" Pawn already spawned for" @ NewBot);
        return;
    }

	// Find a start location.
	TeamNum = ((NewBot.PlayerReplicationInfo == None) || (NewBot.PlayerReplicationInfo.Team == None)) ? 255 : NewBot.PlayerReplicationInfo.Team.TeamIndex;
	startSpot = FindPlayerStart(NewBot, TeamNum);

	if (startSpot != none) {
        NewBot.Pawn = SpawnDefaultPawnFor(NewBot, startSpot);
    } else {
        `LogError("StartSpot none!");
    }

	if (startLocation != vect(0,0,0)) {
		NewBot.ClientSetLocation(startLocation, startRotation);	
	}

    if (NewBot.Pawn == None) {
		`LogError("Cant spawn the pawn of bot "$NewBot);
        return;
    } else {
        // initialize and start it up
        NewBot.Pawn.SetAnchor(startSpot);
        /*if ( PlayerController(NewPlayer) != None )
        {
                PlayerController(NewPlayer).TimeMargin = -0.1;
                startSpot.AnchoredPawn = None; // SetAnchor() will set this since IsHumanControlled() won't return true for the Pawn yet
        }*/
        NewBot.Pawn.LastStartSpot = PlayerStart(startSpot);
        NewBot.Pawn.LastStartTime = WorldInfo.TimeSeconds;
        NewBot.Possess(NewBot.Pawn, false);
        NewBot.Pawn.PlayTeleportEffect(true, true);
        NewBot.ClientSetRotation(NewBot.Pawn.Rotation, TRUE);

        // activate spawned events
        /*if (WorldInfo.GetGameSequence() != None)
        {
                WorldInfo.GetGameSequence().FindSeqObjectsByClass(class'SeqEvent_PlayerSpawned',TRUE,Events);
                for (Idx = 0; Idx < Events.Length; Idx++)
                {
                        SpawnedEvent = SeqEvent_PlayerSpawned(Events[Idx]);
                        if (SpawnedEvent != None &&
                                SpawnedEvent.CheckActivate(NewBot,NewBot))
                        {
                                SpawnedEvent.SpawnPoint = startSpot;
                                SpawnedEvent.PopulateLinkedVariableValues();
                        }
                }
        }*/
    }

    //For disabling automatic pickup (items picked through command PICK)
    newBot.Pawn.bCanPickupInventory = !newBot.bDisableAutoPickup;

    //Multiply Pawn GroundSpeed by our custom GB SpeedMultiplier
    if (NewBot.SpeedMultiplier > 0) {//TODO?
        newBot.Pawn.GroundSpeed = newBot.SpeedMultiplier * newBot.Pawn.Default.GroundSpeed;
        NewBot.Pawn.AirSpeed = newBot.SpeedMultiplier * newBot.Pawn.Default.AirSpeed;
        NewBot.Pawn.WaterSpeed = newBot.SpeedMultiplier * newBot.Pawn.Default.WaterSpeed;
        NewBot.Pawn.LadderSpeed = newBot.SpeedMultiplier * newBot.Pawn.Default.LadderSpeed;    
    }


    //Notify spawning
    NewBot.myConnection.SendLine("SPW");
	//must be done after sending SPW
	if (!WorldInfo.bNoDefaultInventoryForPlayer){
		NewBot.bAddingDefaultInventory = true;
        AddDefaultInventory(NewBot.Pawn);
		NewBot.bAddingDefaultInventory = false;
    }
    SetPlayerDefaults(NewBot.Pawn);
    //NewBot.ClientSetRotation(aPlayer.Pawn.Rotation); //We want to preserve our rotation


        //Setting some initial Pawn properties
        //Newbot.Pawn.PeripheralVision = -0.3;
        //Newbot.Pawn.bAvoidLedges = false;
        //Newbot.Pawn.bStopAtLedges = false;
        //Newbot.Pawn.bCanJump = true;


        // broadcast a welcome message.
        //BroadcastLocalizedMessage(GameMessageClass, 1, NewBot.PlayerReplicationInfo);

    //NewBot.GotoState('Alive', 'DoStop'); //TODO: Really here?
	`LogDebug("NotifyTeamchanged: started");
	NewBot.Pawn.NotifyTeamChanged();
	`LogDebug("NotifyTeamchanged: ended");
	//UTPawn(NewBot.Pawn).Mesh    

	/*`LogDebug("=================Settings=================");
	`LogDebug("Pawn.bCanPickupInventory: " $ NewBot.Pawn.bCanPickupInventory ? "true" : "false");
	`LogDebug("NewBot.Controller: " $ string(NewBot.Pawn.Controller.Class));*/
}

/**
 * Abstract function used in team games
 * @note for more information look at implementation in class GBTeamDeathMatch
 */ 
function bool AddRemoteBotToTeam(Controller NewBot, int TeamNum)
{
    return true;
}


//Prevents epic bots from automatically joining the game
/**
 * @todo check how the epic bots are adding into the game
 */ 
function bool NeedPlayers()
{
    return false;
}

//Prevents epic bots from automatically joining the game
/**
 * @todo how is this preventing epic bots from joining?
 */ 
function bool BecomeSpectator(PlayerController P)
{
    if ( P.PlayerReplicationInfo == None || (NumSpectators >= MaxSpectators) || P.IsInState('RoundEnded') ) { return false; }

    return true;
}

defaultproperties
{
    bUseClassicHUD=false//true //if false, default HUD will be used...
    HUDType=class'UTHUD'//class'GameBotsUT3.GBHUD'
    NetWait=2
    CountDown=0
    bPauseable=True
    RemoteBotController="GameBotsUT3.RemoteBot"
	PlayerControllerClass=class'GameBotsUT3.GBPlayerController'
	//RemoteBotController="GameBotsUT3.LogBot"
    DefaultPawnClass=class'GameBotsUT3.GBPawn'
    BotServerClass=class'GameBotsUT3.BotServer'
    ControlServerClass=class'GameBotsUT3.ControlServer'
	MapType=class'UTDeatMatch'
    GameName="GameBotsUT3 DeathMatch"
    GameClass="BotDeathMatch"
    Acronym="DM"
    MapPrefix="DM"
    BotServerPort=3000
    ControlServerPort=3001
	bDebug=true
	bNoCustomCharacters=false
}