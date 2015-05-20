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

class ControlConnection extends GBClientClass
        config(GameBotsUT3);
`include(Globals.uci);
`define debug;

//Parent server
var ControlServer Parent;

var config float UpdateTime;

var() class<Actor> tempActorClass; //for actor spawns

//switches for exporting information after READY command
var config bool bExportGameInfo;
var config bool bExportMutators;
var config bool bExportITC;
var config bool bExportNavPoints;
var config bool bExportMovers;
var config bool bExportInventory;
var config bool bExportPlayers;

var bool bExportHumanPlayers;
var bool bExportRemoteBots;
var bool bExportUnrealBots;

//Accepted connection to a socket
/**
 * Handles accepting new connections.
 *
 */ 
event Accepted()
{
	`LogInfo("Control connection established.");
	`LogDebug("LinkMode: " $ LinkMode $ "LineMOde: " $ OutLineMode);

}

function PostBeginPlay()
{
    Parent = ControlServer(Owner);
	`LogDebug("Spawned control connection");
    super.PostBeginPlay();
}

/**
 * Handles processing of commands.
 * 
 * @param cmdType command header
 * 
 */ 
function ProcessAction(string cmdType)
{
	`LogDebug("commandType: " $ cmdType);

    switch(cmdType){
		case "ADDBOT":
            ReceivedAddBot();
        break;
        case "ADDINV":
            ReceivedAddInv();
        break;
		case "CLEAR":
            ReceivedClear();
        case "CONF":
            ReceivedConf();
        break;
        case "CONFGAME":
            ReceivedConfGame();
        break;
        case "CONSOLE":
            ReceivedConsole();
		break;
        case "CHANGEMAP":
            ReceivedChangeMap();
        break;
		case "CHANGETEAM":
            ReceivedChangeTeam();
        break;
		case "CHATTR":
            ReceivedChangeAtt();
        break;
        case "ENDPLRS":
            gotoState('running','NoPLRS');
        break;
		case "GETINVS":
            ReceivedGetInv();
        break;
		case "GETNAVS":
            ReceivedGetNavs();
        break;
        case "GETMAPS":
            ReceivedGetMaps();
        break;
        case "GETPLRS":
           ReceivedGetPLRS();
        break;
        case "PAUSE":
            ReceivedPause();
        break;
        case "PING":
            SendLine("PONG");
        break;
        case "QUIT":
            ReceivedQuit();
        break;
        case "KICK":
            ReceivedKick();
        break;
        /*case "READY":
            ReceivedReady();
        break;*/
        case "REC":
            ReceivedRec();
        break;
        case "RESPAWN":
            ReceivedRespawn();
        break;
        case "SETGAMESPEED":
            ReceivedSetGameSpeed();
        break;
        case "SETLOCK":
            ReceivedSetLock();
        break;
        case "SETPASS":
            ReceivedSetPass();
        break;
        case "SPAWNACTOR":
            ReceivedSpawnActor();
        break;
        case "STARTPLRS":
            ReceivedStartPlrs();
        break;
        case "STOPREC":
            ReceivedStopRec();
        break;
        case "TELEPORT":
			ReceivedTeleport();
		break;
    }//end switch
}

/**
 * Teleports the bot to the targeted location.
 * 
 * @note Command: TELEPORT
 * @note Answer:
 * 
 * @note Teleports bot.
 */
function ReceivedTeleport()
{
	local string target;	
    local vector v;
    local rotator r;
    local Controller C;
	local RemoteBot bot;
    local bool hasVector;

    target = GetArgVal("Id");

    if (target == "") {
        return;
    }

	ParseVector(v, "TargetLocation");
	ParseRot(r, "TargetRotation");
	
    foreach WorldInfo.AllControllers(class'Controller', C) {		
        if( class'GBUtil'.static.GetUniqueId(C) == target ) {			
            if (C.IsA('RemoteBot')) {                       
                 bot = RemoteBot(C);                                   
            }                               
        }
    }

	if (GetArgVal("TargetLocation") != "") {
        ParseVector(v, "TargetLocation");
        hasVector = true;		
    }

	if (bot != none){
		if (hasVector) {
			bot.ClientSetLocation(v,r);		
		} else {
			`LogWarn("No location for teleport");
		}
	}
	else `LogWarn("Bot not found id:" @ target);
}

/**
 * Adds Epic bot to the game.
 * 
 * @note Command: ADDBOT
 * @note Answer:
 * 
 * @todo check if the initialization works
 */ 
function ReceivedAddBot()
{
	local string botName;
	local vector loc;
	local rotator rot;
	local float skill;
	local int team, index;
	local UTBot newBot;
	local UTTeamInfo teamInfo;
	local CharacterInfo botInfo;   

	botName = GetArgVal("Name");
	ParseVector(loc, "StartLocation");
	ParseRot(rot, "StartRotation");
	skill = float(GetArgVal("Skill"));
	team = int(GetArgVal("Team"));

    `LogDebug("Botname: " $ botName);
    `LogDebug("Team: " $ team);
    `LogDebug("TeamGame: " $ WorldInfo.Game.bTeamGame);
	
    newBot = UTGame(WorldInfo.Game).AddNamedBot(botName, WorldInfo.Game.bTeamGame, team);
    newBot.Initialize(skill, botInfo);  
    newBot.ClientSetLocation(loc, rot);
    
	/*
	teamInfo = UTTeamInfo(newBot.PlayerReplicationInfo.Team);
	botInfo = teamInfo.GetBotInfo(newBot.PlayerReplicationInfo.PlayerName);
	index = class'UTCustomChar_Data'.default.Characters.Find('CharName', botName);
    `LogDebug("Index of bot found. " $ index);
	botInfo = class'UTCustomChar_Data'.default.Characters[index];
    `LogDebug("Agent retrieved.");
	
    */
}

function ReceivedAddInv()
{
	local string target, ClassTypeString;
	local Controller C;	
	local Actor UTObject;
	//local UTDroppedPickup Pickup;
	local UTPickupFactory Factory;

	target = GetArgVal("Id");

	if (target == "")
	{
		return;
	}

	ClassTypeString = GetArgVal("Type");
	ClassTypeString = "class'" $ ClassTypeString $ "'";	
	`LogDebug("Added inventory will be " @ ClassTypeString);

	//Allow to add just Pickup classes	
	foreach WorldInfo.AllControllers(class'Controller', C)
	{   
		if( class'GBUtil'.static.GetUniqueId(C) == target )
		{			
			UTObject = SpawnActor(ClassTypeString,C.Pawn.Location,);
				
		/*	if (UTObject.IsA('UTDroppedPickup')) {
				Pickup = UTDroppedPickup(UTObject);
				Pickup.GiveTo(C.Pawn);
			} else*/ if (UTObject.IsA('UTPickupFactory')) {
				Factory = UTPickupFactory(UTObject);
				Factory.SpawnCopyFor(C.Pawn);
				Factory.destroy();
			}
				
			`LogDebug("Added inventory will be " @ ClassTypeString);				
		}
	}
}

/**
 * Spawns actor
 * @param ClassTypeString: Item to spawn.
 * @param location: Location where to spawn.
 * @param rotation: orientation.
 * @return Spawned item.
 */
function Actor SpawnActor(string ClassTypeString, optional vector location, optional rotator rotation)
{
	local Actor UTObject, SpawnedActor;
	
	UTObject = Spawn(class<Actor>(DynamicLoadObject(ClassTypeString, class'Class')),self,,location,rotation);
			
	if (UTObject.IsA('UTWeapon') || UTObject.IsA('UTInventory')) {
		SpawnedActor = Spawn(class<Actor>(DynamicLoadObject("class'UTGame.UTDroppedPickup'", class'Class')),self,,location,rotation);
		UTDroppedPickup(SpawnedActor).Inventory = Inventory(UTObject);			
		UTDroppedPickup(SpawnedActor).InventoryClass = UTDroppedPickup(SpawnedActor).Inventory.Class;			
	} else {
		SpawnedActor = UTObject;			
	}		    

	`LogDebug("actor:" @ SpawnedActor @ ", loc:" @ SpawnedActor.Location);

	return SpawnedActor;
}

/**
 * Change specified bot variables.
 * @note Command: CHATT
 * @note Answer:
 * 
 * @note Adrenaline is not available in UT3.
 */ 
function ReceivedChangeAtt(){
	local string id,health;
	local Controller target;

	id = GetArgVal("Id");
	health = GetArgVal("Health");

	foreach WorldInfo.AllControllers(class'Controller', target) {
        if( class'GBUtil'.static.GetUniqueId(target) == id ) {
			if(health != "")
        		target.Pawn.Health = int(health);
            break;
        }
    }
}

/**
 * Changes current map.
 * @note Command: CHANGEMAP
 * @note Answer: MAPCHANGE
 * 
 * @note Will close all connections.
 */ 
function ReceivedChangeMap()
{
    local string target;
    local bool bResult;
    local GBClientClass G;
    local RemoteBot bot;
    local int i;

    target = GetArgVal("MapName");
    if (target != "")
    {
        //Check if the map exists in current map list
        bResult = false;
        for (i=0; i < BotDeathMatch(WorldInfo.Game).Maps.Length; i++ ) {
            if (target==BotDeathMatch(WorldInfo.Game).Maps[i]) {
                bResult = true;
                break;
            }
        }
		//Change just when the map is in MapList
        if (bResult) {
            // notify all remotebots of the mapchange
            foreach WorldInfo.AllControllers(class'RemoteBot', bot) {
                bot.myConnection.NotifyChangeMap(target);
            }
			//notify all control connections of map change
            for (G = Parent.ChildList; G != None; G = G.Next ) {
                G.NotifyChangeMap(target);
            }
			//Refuse new connections when changing map
            BotDeathMatch(WorldInfo.Game).theBotServer.bLocked = true;
            BotDeathMatch(WorldInfo.Game).theBotServer.Close();

            BotDeathMatch(WorldInfo.Game).theControlServer.bLocked = true;
            BotDeathMatch(WorldInfo.Game).theControlServer.Close();

			//Finally, make the game change the map
            WorldInfo.ServerTravel(target,false);
        }
    }
}

/**
 * Changes the team for selected controller.
 * 
 * @note Command: CHANGETEAM
 * @note Answer: TEAMCHANGE
 * 
 * @note Setting the Team parameter to 255 will pick the smallest team.
 */ 
function ReceivedChangeTeam(){
	local string id,msg;
	local int teamId;
	local bool success;
	local Controller target;

	id = GetArgVal("Id");
	teamId = int(GetArgVal("Team"));
	foreach WorldInfo.AllControllers(class'Controller', target) {
        if( class'GBUtil'.static.GetUniqueId(target) == id ) {
    		success = WorldInfo.Game.ChangeTeam(target,teamId,true);
			if (target.IsA('RemoteBot'))
				RemoteBot(target).NotifyTeamChange(success, teamId);
        }
    }

	msg = "TEAMCHANGE {Id " $ id $ 
		"} {Success " $ class'GBUtil'.static.GetBoolString(success) $ 
		"} {DesiredTeam " $ teamId $
		"}" ;
	GlobalSendLine(msg,true,false);
}

// this will do a dirty clear, sometimes bots remain on the server after disconnect
// this delete all actors that are pawns or controllers on the server
//
function ReceivedClear()
{
        local GBPawn P;
        local RemoteBot R;
        local BotConnection C;
        //local Controller C;

    foreach AllActors (class 'BotConnection', C)
        {
                C.Destroy();
        }

        foreach AllActors (class 'RemoteBot', R)
        {
                R.Destroy();
        }

        foreach AllActors (class 'GBPawn', P)
        {
                P.Destroy();
        }
}

/**
 * Handles the CONF command.
 * @note Command: CONF
 *       Attributes: Id
 * @note Answer: CONFCH
 */ 
function ReceivedConf()
{
    local string target;
    local Controller C;
	local RemoteBot RB;

    target = GetArgVal("Id");
    if (target == ""){
		`LogWarn("Received blank Id;");
        return;
    }

    foreach WorldInfo.AllControllers(class'Controller', C) {
        if( class'GBUtil'.static.GetUniqueId(C) == target ) {
			RB = RemoteBot(C);
            break;
        }
    }

    if (C == none){
		`LogWarn("Cannot find bot specified; Id: " $ target);
        return;
    }

	if (RB == none){
		`LogWarn("Specified Id do not match any RemoteBot Id: " $ target);
		return;
	}

    ConfigureBot(RB);

    SendNotifyConf(RemoteBot(C));
}

/**
 * Enables configuring various game variables.
 * @note Commnad: CONFGAME
 * @note Answer:
 * 
 * @note conf variabes: WeaponStay, GoalScore, TimeLimit, MaxLives
 * 
 * @todo WeaponThrowing does not work now. Would have to be
 *      implemeted as a whole.
 * @todo implement the messages and restart from doc
 */ 
function ReceivedConfGame()
{
    local int intNumber;

    if (GetArgVal("WeaponStay") != "")
    {
        UTGame(WorldInfo.Game).bWeaponStay = bool(GetArgVal("WeaponStay"));
    }
    if (GetArgVal("WeaponThrowing") != "")
    {
        //WorldInfo.Game.bAl .bAllowWeaponThrowing = bool(GetArgVal("WeaponThrowing"));
    }
    if (GetArgVal("GoalScore") != "")
    {
        intNumber = int(GetArgVal("GoalScore"));
        if (intNumber >= 1)
            WorldInfo.Game.GoalScore = intNumber;
    }
    if (GetArgVal("TimeLimit") != "")
    {
        intNumber = int(GetArgVal("TimeLimit"));
        if (intNumber >= 1)
            WorldInfo.Game.TimeLimit = intNumber;
    }
    if (GetArgVal("MaxLives") != "")
    {
        intNumber = int(GetArgVal("MaxLives"));
        if (intNumber >= 1)
            WorldInfo.Game.MaxLives = intNumber;
    }
    WorldInfo.Game.SaveConfig();
    WorldInfo.Game.GameReplicationInfo.SaveConfig();

}

/**
 * Executes a console command.
 * 
 * @note Command: CONSOLE
 * @note Answer:
 */ 
function ReceivedConsole()
{
    local string target;

    target = GetArgVal("Command");

    ConsoleCommand(target);
}

/**
 * Sends map list to the client.
 * @note Command: GETMAPS
 * @note Answer: SMAP, IMAP, EMAP
 */ 
function ReceivedGetMaps()
{
    local int i;

    SendLine("SMAP");
    for (i=0; i < BotDeathMatch(WorldInfo.Game).Maps.Length; i++ ) {
        SendLine("IMAP {Name " $ BotDeathMatch(WorldInfo.Game).Maps[i] $ "}");
    }
    SendLine("EMAP");
}

/**
 * Kicks selected player from the server.
 * @note Command: KICK
 * @note Answer:
 */ 
function ReceivedKick()
{
    local string target;
    local Controller C;
	local bool bfound;

    target = GetArgVal("Id");
    if (target == ""){
		`LogInfo("Id not specified!");
        return;
    }

	bfound = false;

    foreach WorldInfo.AllControllers(class'Controller', C) {
            if( class'GBUtil'.static.GetUniqueId(C) == target ) {
                if (C.isA('RemoteBot')) {
                    //TODO: Send "Kicked"?
					bfound = true;
					RemoteBot(C).myConnection.ReceivedDisconnect();  // handles FIN message
                }
                break;
            }
        }

	if (!bfound) `LogInfo("Bot not found! id =" @ target);
}

/**
 * Starts demo recording.
 * 
 * @note Command: REC
 * @note Answer: RECSTART
 */ 
function ReceivedRec()
{
    local string target;

    target = GetArgVal("FileName");
    ConsoleCommand("demorec "$target);
    sendLine("RECSTART");
}

/**
 * Respawns selected bot.
 * 
 * @note Command: RESPAWN
 * @note Answer: SPW
 */ 
function ReceivedRespawn() {
    local string target;	
    local vector v;
    local rotator r;
    local Controller C;
	local RemoteBot bot;
    local bool hasVector, hasRotator;

    target = GetArgVal("Id");

    if (target == "") {
        return;
    }

	ParseVector(v, "StartLocation");
	ParseRot(r, "StartRotation");

	// Not sure what these two are doing here.
    // ParseVector(v,"Location");
    // ParseRot(r,"Rotation");
    foreach WorldInfo.AllControllers(class'Controller', C) {		
        if( class'GBUtil'.static.GetUniqueId(C) == target ) {			
            if (C.IsA('RemoteBot')) {                       
                 bot = RemoteBot(C);                                   
            }                               
        }
    }

	if (GetArgVal("StartLocation") != "") {
        ParseVector(v, "StartLocation");
        hasVector = true;		
    }
    if (GetArgVal("StartRotation") != "") {
        ParseRot(r, "StartRotation");
        hasRotator = true;		
    }

	if (bot != none){
		if (hasVector && hasRotator) {
			bot.RespawnPlayer(v,r);			
		} else if (hasVector) {
			bot.RespawnPlayer(v);			
		} else {
			bot.RespawnPlayer();			
		}
	}
	else `LogWarn("Bot not found id:" @ target);
}

/**
 * Sets the game speed.
 * 
 * @note Commad: SETGAMESPEED
 * @note Answer:
 */ 
function ReceivedSetGameSpeed()
{
    local float speed;

    speed = float(GetArgVal("Speed"));

	//If Speed parameter is a number clamp it between 0.01 and 50
	//otherwise return
	if (speed != 0){
		speed = FClamp(speed, 0.01, 50);
		WorldInfo.Game.SetGameSpeed(speed);
        WorldInfo.Game.SaveConfig();
        WorldInfo.Game.GameReplicationInfo.SaveConfig();
	}
}

/**
 * Enables/Disables accepting of new connections on server.
 * 
 * @note Command: FsetSETLOCK
 * @note Answer:
 * 
 * @note the control server unlocks when last connection is closed.
 *      That is handled in ControlServer->LostChild
 */ 
function ReceivedSetLock()
{
    local string target;

    target = GetArgVal("BotServer");
    if (target != "")
    {
        if (bool(target)) {
            if (BotDeathMatch(WorldInfo.Game).theBotServer.LinkState == STATE_Listening) {
                BotDeathMatch(WorldInfo.Game).theBotServer.bLocked = true;
                BotDeathMatch(WorldInfo.Game).theBotServer.Close();
            }
        } else {
            if (BotDeathMatch(WorldInfo.Game).theBotServer.LinkState != STATE_Listening) {
                BotDeathMatch(WorldInfo.Game).theBotServer.bLocked = false;
                BotDeathMatch(WorldInfo.Game).theBotServer.Listen();
            }
        }
    }

    target = GetArgVal("ControlServer");
    if (target != "") {
        if (bool(target)) {
            if (BotDeathMatch(WorldInfo.Game).theControlServer.LinkState == STATE_Listening) {
                BotDeathMatch(WorldInfo.Game).theControlServer.bLocked = true;
                BotDeathMatch(WorldInfo.Game).theControlServer.Close();
            }
        } else {
            if (BotDeathMatch(WorldInfo.Game).theControlServer.LinkState != STATE_Listening) {
                BotDeathMatch(WorldInfo.Game).theControlServer.bLocked = false;
                BotDeathMatch(WorldInfo.Game).theControlServer.Listen();
            }
        }
    }
}

/**
 * Sets password for server.
 * @note Command: SETPASS
 * @note Answer:
 * 
 * @note If Password parameter is left blank or omited, the server
 *      will turn off the password protection.
 */ 
function ReceivedSetPass()
{
    local string target;

    target = GetArgVal("Password");

    if (target != "") {
        BotDeathMatch(WorldInfo.Game).bPasswordProtected = true;
        BotDeathMatch(WorldInfo.Game).PasswordByIP = string(RemoteAddr.Addr)$":"$string(RemoteAddr.Port);
        BotDeathMatch(WorldInfo.Game).Password = target;
    } else {
        BotDeathMatch(WorldInfo.Game).bPasswordProtected = false;
        BotDeathMatch(WorldInfo.Game).PasswordByIP = "";
        BotDeathMatch(WorldInfo.Game).Password = "";
    }
}

/**
 * Spawns selected actor in game enviroment.
 * 
 * @note Command: SPAWNACTOR
 * @note Answer: 
 * 
 * @note The class must be specified correctly!
 */ 
function ReceivedSpawnActor()
{	    
	local string ClassTypeString;
    local vector v;
    local rotator r;
    local Actor SpawnedActor;

    ParseVector(v,"Location");
    ParseRot(r,"Rotation");    
	ClassTypeString = "class'" $ GetArgVal("Type") $ "'";

	SpawnedActor = SpawnActor(ClassTypeString, v, r);
    
	`LogDebug("actor:" @ SpawnedActor @ ", loc:" @ SpawnedActor.Location);	
}

/**
 * Sets up synchronous PLRs batch.
 * @note Command: STARTPLRS
 * @note Answer:
 */ 
function ReceivedStartPlrs()
{
    local string tmp;

    tmp = GetArgVal("Humans");
    if (tmp != "") 
        bExportHumanPlayers = bool(tmp);

    tmp = GetArgVal("GBBots");
    if (tmp != "") 
        bExportRemoteBots = bool(tmp);

    tmp = GetArgVal("UnrealBots");
    if (tmp != "") 
        bExportUnrealBots = bool(tmp);

    gotoState('running','SendPLRS');
}

/**
 * Stops demo recording.
 * 
 * @note Command: STOPREC
 * @note Answer: RECEND
 */ 
function ReceivedStopRec()
{
    ConsoleCommand("stopdemo");
    sendLine("RECEND");
}

/**
 * @todo obsolate code consider erasing
 */ 
/*
function SendNotifyPause ( bool bGamePaused )
{
        local Controller C;
        local GBClientClass G;

        foreach WorldInfo.AllControllers(class'Controller', C) {
                if( C.IsA('RemoteBot') )
                {
                        if (bGamePaused)
                                RemoteBot(C).myConnection.SendLine("PAUSED");
                        else
                                RemoteBot(C).myConnection.SendLine("RESUMED");
                }
        }

        for (G = Parent.ChildList; G != None; G = G.Next )
        {
                if (bGamePaused)
                        G.SendLine("PAUSED");
                else
                        G.SendLine("RESUMED");
        }

}*/

//from CheatManager class - for inspiration
/*
function Summon( string ClassName )
{
        local class<actor> NewClass;
        local vector SpawnLoc;

        //if (!areCheatsEnabled()) return;

        `log( "Fabricate " $ ClassName );
        NewClass = class<actor>( DynamicLoadObject( ClassName, class'Class' ) );
        if( NewClass!=None )
        {
                if ( Pawn != None )
                        SpawnLoc = Pawn.Location;
                else
                        SpawnLoc = Location;
                Spawn( NewClass,,,SpawnLoc + 72 * Vector(Rotation) + vect(0,0,1) * 15 );
        }
        ReportCheat("Summon");
}
*/

/**
 * Handles the exporting of synchronous plrs batch.
 */ 
function ExportPlayersSync(){
	local Controller C;
	if (bExportHumanPlayers){
		foreach WorldInfo.AllControllers(class'Controller', C){
			if (C.IsA('PlayerController'))
				SendLine(GetPLR(C,false));
		}
	}
	foreach WorldInfo.AllControllers(class'Controller', C){
        if (C.IsA('RemoteBot')) {
            if (bExportRemoteBots) {
                SendLine(GetPLR(C,false));
            }
        }
        else if (!C.IsA('PlayerController')) {            
            SendLine(GetPLR(C,false));
        }
    }
}

auto state handshake
{
	function SendHello()
	{
		SendLine("HELLO_CONTROL_SERVER");
	}
}

state running
{
Running:
    SendAlive();
    SendLine("BEG {Time " $ WorldInfo.TimeSeconds $"}");
	ExportFlagInfo();
    SendLine("END {Time " $ WorldInfo.TimeSeconds $"}");
    sleep(UpdateTime);
    goto 'Running';
SendPLRS:
	SendAlive();
    SendLine("BEG {Time " $ WorldInfo.TimeSeconds $"}");
	ExportFlagInfo();
    ExportPlayersSync();
    SendLine("END {Time " $ WorldInfo.TimeSeconds $"}");
    sleep(UpdateTime);
    goto 'SendPLRS';
NoPLRS:
	SendAlive();
    sleep(UpdateTime);
    goto 'NoPLRS';
}


defaultproperties
{
    UpdateTime=1.0
	bAllowPause=True
    bExportGameInfo=true
    bExportMutators=true
    bExportITC=true
    bExportNavPoints=true
    bExportMovers=true
    bExportInventory=true
    bExportPlayers=true
	bExportRemoteBots=true
	bExportUnrealBots=true
	bExportHumanPlayers=true
	bDebug=true
}