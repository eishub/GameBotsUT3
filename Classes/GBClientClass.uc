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


class GBClientClass extends TcpLink abstract
        config(GameBotsUT3);
`include(Globals.uci);
`define debug;
//Maximum number of arguments
const ArgsMaxCount = 15;

// the main variables where we have incoming messages stored
var string ReceivedData;
var string ReceivedArgs[ArgsMaxCount];
var string ReceivedVals[ArgsMaxCount];

//for `logging purposes
var string lastGBCommand;

// enables disables cheating - invulnerability, spawning items for bots
var config bool bAllowCheats;

// if control server or bots can or cannot pause the game
var config bool bAllowPause;
var bool bPaused;

var GBClientClass Next; //create list of all classes

//switches for exporting information after READY command
var config bool bExportGameInfo;
var config bool bExportMutators;
var config bool bExportITC;
var config bool bExportNavPoints;
var config bool bExportMovers;
var config bool bExportInventory;
var config bool bExportPlayers;

var config bool bDebugSend;

struct ExportedITC
{
	var class<PickupFactory> PF;
	var class<Inventory> INV;
};

//List of exported ITCs to eliminate double exports
 var array<ExportedITC> exportedITCs;

//===============================================================================
//= Basic network utils and functionality
//===============================================================================

/**
 * Handles incoming commands. 
 * 
 * @note Parses them into ReceivedArgs and ReceivedVals
 * variables for further processing by ProcessAction method.
 * 
 * @param S Unparsed command.
 * 
 * @todo Might be safer to parse the command into local variables
 * and then pass them to the ProcessAction. Might perform worse due to
 * a lot of copying though.
 */ 
function ReceivedLine(string S)
{
    local string cmdType, argBody, rem;
    local int endloc, wordsplit, attrNum;

	//`LogDebug(S);

    wordsplit = InStr(S," ");
    if( wordsplit == -1)
            wordsplit = Len(S);

    cmdType = left(S,wordsplit);
    rem = mid(S,InStr(S,"{"));

    attrNum = 0;
    // clear previously received attr/val pairs
    while(attrNum < ArgsMaxCount){
		if (ReceivedArgs[attrNum] == "")
				break;

		ReceivedArgs[attrNum] = "";
		ReceivedVals[attrNum] = "";

		attrNum++;
    }

    attrNum = 0;

    //iterate through attr/val pairs, storring them in the
    //parallel arrays ReceivedArgs and ReceivedVals
    while(attrNum < ArgsMaxCount && rem != ""){
        endloc = InStr(rem,"}");
        argBody = mid(rem,1,(endloc - 1));

        wordsplit = InStr(argBody," ");
        ReceivedArgs[attrNum] = left(argBody,wordsplit);
        ReceivedVals[attrNum] = mid(argBody,(wordsplit + 1));

        rem = mid(rem,1); //advance
        rem = mid(rem,InStr(rem,"{"));
        attrNum++;
    }

    cmdType = Caps(cmdType);

    ProcessAction(cmdType);
}

/**
 * Handles incoming data.
 * 
 * @note Parses the data into lines which are then processed
 *  by ReceivedLine method.
 *  
 *  @todo BUG: when connection is opened with putty, it seems to send
 *  some binary data not ending with CR which end stored in the ReceivedData
 *  variable. This messes the first command send to the server. 
 *  Check if this is caused by the putty or it is really a bug.
 *  
 *  @param Text Received data.
 */ 
event ReceivedText( string Text )
{
	local int i;
	local string S;

	//`LogDebug(Text);
    ReceivedData = ReceivedData $ Text;
    //for `logging purposes
    lastGBCommand = Text;

    // remove a LF which arrived in a new packet
    // and thus didn't get cleaned up by the code below
    if(Left(ReceivedData, 1) == Chr(10))
            ReceivedData = Mid(ReceivedData, 1);
    i = InStr(ReceivedData, Chr(13));
    while(i != -1){
        S = Left(ReceivedData, i);
        i++;
        // check for any LF following the CR.
        if(Mid(ReceivedData, i, 1) == Chr(10)) i++;

        ReceivedData = Mid(ReceivedData, i);

        ReceivedLine(S);

        if(LinkState != STATE_Connected)
                return;

        i = InStr(ReceivedData, Chr(13));
    }
}

function ProcessAction(string cmdType)
{
    //Shouldnt be called, just for inheritance
	`LogError("Should not be called; abstract function!");
}

/**
 * Returns value of given argument.
 * 
 * @return Returns "" if there is no argument of given name.
 * 
 * @param argName Name of given argument.
 */ 
function string GetArgVal(string argName)
{
    local int i;
	local string retVal;
	retVal = "";
    while (i < 9 && ReceivedArgs[i] != ""){
        if (ReceivedArgs[i] ~= argName){
            retVal = ReceivedVals[i];
			break;
        }
        i++;
    }

    return retVal;
}

// should use int's for locations rather than floats
// we don't need to be that precise
/**
 * Transforms value of given argument into a vector.
 * @note It either parses the the arguments string value or 
 * gets the vector values from arguments "x", "y", "z".
 * 
 * @param v output vector
 * @param vecName name of the argument
 * 
 * @todo It might return a vector instead of filling an output parameter.
 */ 
function ParseVector(out vector v, string vecName)
{
    local int i;
    local string rem;
    local string delim;

    delim = " ";

    rem = GetArgVal(vecName);	

    if(rem != ""){
        if( InStr(rem,delim) == -1 )
                delim = ",";
        i = InStr(rem,delim);
        v.X = float(left(rem,i));
        rem = mid(rem,i+1);
        i = InStr(rem,delim);
        v.Y = float(left(rem,i));
        v.Z = float(mid(rem,i+1));
    }
    else{
        v.x = float( GetArgVal("x") );
        v.y = float( GetArgVal("y") );
        v.z = float( GetArgVal("z") );
    }
}

// function for parsing rotation
/**
 * Transforms value of given argument into a rotator.
 * @note It either parses the the arguments string value or 
 * gets the rotator values from arguments "pitch", "yaw", "roll".
 * 
 * @param rot output rotator
 * @param rotName name of the argument
 * 
 * @todo It might return a rotator instead of filling an output parameter.
 */ 
function ParseRot(out rotator rot, string rotName)
{
    local int i;
    local string rem;
    //local float y,p,r;
    local string delim;

    delim = " ";

    rem = GetArgVal(rotName);
    if(rem != ""){
		if( InStr(rem,delim) == -1 )
				delim = ",";
		i = InStr(rem,delim);
		rot.Pitch = float(left(rem,i));
		rem = mid(rem,i+1);
		i = InStr(rem,delim);
		rot.Yaw = float(left(rem,i));
		rot.Roll = float(mid(rem,i+1));
    }
    else{
        rot.Pitch = float( GetArgVal("pitch") );
        rot.Yaw = float( GetArgVal("yaw") );
        rot.Roll = float( GetArgVal("roll") );
    }
}

//Send a line to the client
/**
 * Sends output to client using SendText method.
 * 
 * @param Text output text
 * @param bNoCRLF indicator if the output should be ended with CRLF
 */ 
function SendLine(string Text, optional bool bNoCRLF)
{
	if (bDebugSend) `LogDebug(TimeStamp() $ ":" $ Text);
    if(bNoCRLF)
        SendText(Text);
    else
        SendText(Text$Chr(13)$Chr(10));
}

/**
 * Sends output to all clients
 * 
 * @param Text output text
 * @param bNotifyAllControlServers
 * @param bNotifyAllBots
 * @param bNoCRLF indicates if the output should be ended with CRLF
 */ 
function GlobalSendLine(
	string Text, 
	bool bNotifyAllControlServers, 
	bool bNotifyAllBots, 
	optional bool bNoCRLF
	)
{
    local GBClientClass G;

    if ((BotDeathMatch(WorldInfo.Game).theControlServer != none) && bNotifyAllControlServers)
        for (G = BotDeathMatch(WorldInfo.Game).theControlServer.ChildList; G != None; G = G.Next )
            G.SendLine(Text, bNoCRLF);

    if (bNotifyAllBots)
        for (G = BotDeathMatch(WorldInfo.Game).theBotServer.ChildList; G != None; G = G.Next )
            if (BotConnection(G).theBot != none) G.SendLine(Text, bNoCRLF);
}

//===============================================================================
//= General game commands
//===============================================================================

/**
 * Pauses the game.
 * @note Command: PAUSE
 * @note Answer: PAUSED
 */ 
function ReceivedPause(){
	local bool bWasPaused;

	if (!bAllowPause)
		return;
	if ((WorldInfo.bPlayersOnly == true) || (WorldInfo.Pauser != none))
		bWasPaused = true;
	else
		bWasPaused = false;

	if (GetArgVal("PauseBots")!="")
	{
		WorldInfo.bPlayersOnly = bool(GetArgVal("PauseBots"));
	}
	if (GetArgVal("PauseAll")!="")
	{
		if (bool(GetArgVal("PauseAll")))
		{
			if (WorldInfo.Pauser == None)
			{
				WorldInfo.Pauser = BotDeathMatch(WorldInfo.Game).WorldInfoPauserFeed;
			}
		}
		else
		{
			WorldInfo.Pauser = None;
		}
	}

	if (bWasPaused == true)
	{
		if ((WorldInfo.bPlayersOnly == false) && (WorldInfo.Pauser == none))
			SendResumed();
	}
	else
	{
		if ((WorldInfo.bPlayersOnly == true) || (WorldInfo.Pauser != none))
			SendPaused(); //send pause message
	}
}

function SendResumed(){
	SendLine("RESUMED");
	SendGameInfo();
}

function SendPaused(){
	SendLine("PAUSED");
	SendGameInfo();
}

/**
 * Closes the connection.
 * @note Command: QUIT
 * @note Answer: FIN
 */ 
function ReceivedQuit(){
	GotoState('notifyServerClosed');
}

/**
 * Notifies the client that map change is in progress.
 */ 
function NotifyChangeMap(string mapName){
	SendLine("MAPCHANGE {MapName "$mapName$"}");
    SendFin();
}

//===============================================================================
//= Configure command handling
//===============================================================================

/**
 * Configures bot acording to the CONF command received
 * @note Command: CONF
 *       Attributes: ManualSpawn, AutoTrace, Invulnerable,
 *                      Name, SpeedMultiplier, RotatioRate, VisionTime,
 *                      ShowDebug, ShowFocalPoint, DrawTraceLines,
 *                      SynchronousOff, AutoPickupOff
 * 
 * @todo AutoTrace, DrawTraceLines are not done properly
 *          needs to redone when the tracing subsystem is done.
 * @todo Action Needs to be implmented in the RemoteBot first.
 * 
 * @param RB RemoteBot to configure
 */ 
function ConfigureBot(RemoteBot RB)
{
	local string string1;
	local float floatNumber;
	local Rotator rot;

	if (GetArgVal("AutoTrace") != "")
        RB.bAutoTrace = bool(GetArgVal("AutoTrace"));
    if (GetArgVal("ManualSpawn") != "")
       RB.bAutoSpawn = !bool(GetArgVal("ManualSpawn"));
    if (GetArgVal("ShowFocalPoint")!="")
        RB.bShowFocalPoint = bool(GetArgVal("ShowFocalPoint"));
    if (GetArgVal("ShowDebug")!="")
        RB.bDebug = bool(GetArgVal("ShowDebug"));
    if (GetArgVal("Name") != ""){
        string1 = GetArgVal("Name");
		RB.PlayerReplicationInfo.PlayerName = string1;
        WorldInfo.Game.changeName( RB, string1, true );
    }
    if (GetArgVal("SpeedMultiplier") != ""){
        floatNumber = float(GetArgVal("Speed"));
        if ( (floatNumber >= 0.1) && (floatNumber <= RB.MaxSpeed) )
        {
            RB.SpeedMultiplier = floatNumber;
            if (RB.Pawn != none) {
                RB.Pawn.GroundSpeed = floatNumber * RB.Pawn.Default.GroundSpeed;
                RB.Pawn.AirSpeed = floatNumber * RB.Pawn.Default.AirSpeed;
                RB.Pawn.WaterSpeed = floatNumber * RB.Pawn.Default.WaterSpeed;
                RB.Pawn.LadderSpeed = floatNumber * RB.Pawn.Default.LadderSpeed;
            }
        }
    }
	if(GetArgVal("RotationRate") != ""){
		ParseRot(rot, "RotationRate");
		if(rot != rot(0,0,0)){
			RB.RotationRate = rot;
			if(RB.Pawn != none)
				RB.Pawn.RotationRate = rot;
		}
	}
	if(GetArgVal("Invulnerable") != ""){
		RB.bGodMode = bool(GetArgVal("Invulnerable"));
	}
    if (GetArgVal("DrawTraceLines") != "")
        RB.bDrawTraceLines = bool(GetArgVal("DrawTraceLines"));
    if (GetArgVal("VisionTime") != "")
    {
        floatNumber = float(GetArgVal("VisionTime"));
        if ((floatNumber >= 0.1) && (floatNumber <= 2))
            RB.myConnection.visionTime = floatNumber;
    }
    if (GetArgVal("SynchronousOff") != "")
    {
        RB.myConnection.bSynchronousMessagesOff = bool(GetArgVal("SynchronousOff"));
    }
    if (GetArgVal("AutoPickupOff") != "")
    {
        RB.bDisableAutoPickup = bool(GetArgVal("AutoPickupOff"));
        if (RB.Pawn != none)
            RB.Pawn.bCanPickupInventory = !RB.bDisableAutoPickup;
    }
}

/**
 * Sends CONFCH message to the client. This message is used to
 * inform the client of changes made to the configuration after
 * processing the CONF command. Also notifies all control servers.
 * @note Messages: CONFCH
 *       Attributes: Id, BotId, ManualSpawn, AutoTrace, Invulnerable,
 *                      Name, SpeedMultiplier, RotatioRate, VisionTime,
 *                      ShowDebug, ShowFocalPoint, DrawTraceLines,
 *                      SynchronousOff, AutoPickupOff
 * @todo AutoTrace, DrawTraceLines needs to be redone when the
 *      tracing subsystem is done.
 * @todo Action needs to be implemented in the RemoteBot first
 * @todo RotationRate returns RottionRate of the pawn if possible
 *      otherwise it returns RotationRate of the controller.
 *       
 * @param theBot RemoteBot instance we want to send info about
 */ 
function SendNotifyConf(RemoteBot theBot)
{
        local string outstring;
        local string confchId, BotId;
		local Rotator rot;

		BotId = class'GBUtil'.static.GetUniqueId(theBot);
        confchId = BotId $ "_CONFCH";
		rot = (theBot.Pawn != none) ? theBot.Pawn.RotationRate : theBot.RotationRate;

        outstring="CONFCH {Id " $ confchId $
                "} {BotId " $ BotId $
                "} {ManualSpawn " $ class'GBUtil'.static.GetBoolString(!theBot.bAutoSpawn) $
                "} {AutoTrace " $ class'GBUtil'.static.GetBoolString(theBot.bAutoTrace) $
			    "} {Invulnerable " $ class'GBUtil'.static.GetBoolString(theBot.bGodMode) $
                "} {Name " $ theBot.PlayerReplicationInfo.PlayerName $
                "} {SpeedMultiplier " $ theBot.SpeedMultiplier $
				"} {RotationRate " $ rot $
                "} {VisionTime " $ theBot.myConnection.VisionTime $
                "} {ShowDebug " $ class'GBUtil'.static.GetBoolString(theBot.bDebug) $
                "} {ShowFocalPoint " $ class'GBUtil'.static.GetBoolString(theBot.bShowFocalPoint) $
                "} {DrawTraceLines " $ class'GBUtil'.static.GetBoolString(theBot.bDrawTraceLines) $
                "} {SynchronousOff " $ class'GBUtil'.static.GetBoolString(theBot.myConnection.bSynchronousMessagesOff) $
                "} {AutoPickupOff " $ class'GBUtil'.static.GetBoolString(theBot.bDisableAutoPickup) $
                "}";

        //notify that variables changed
        theBot.myConnection.SendLine(outstring);

        //notify all control servers that variables changed
        GlobalSendLine(outstring,true,false);
}
//===============================================================================
//= Game info exporting
//===============================================================================

/**
 * Handles sending the NFO message to client.
 * @note Messages: NFO
 *       Atrributes: GamePaused, BotsPaused, Level
 */ 
function SendGameInfo()
{
        local string gameInfoStr, PauseResult, outString;

        gameInfoStr = BotDeathMatch(WorldInfo.Game).GetGameInfo();

        if (WorldInfo.Pauser != None)
        	PauseResult = "True";
        else
        	PauseResult = "False";

        outString = "NFO " $ "{GamePaused " $ PauseResult $
                "} {BotsPaused " $ class'GBUtil'.static.GetBoolString(WorldInfo.bPlayersOnly) $
                "} {Level " $ WorldInfo.GetMapName(true) $
                "} " $ gameInfoStr;   //last part may differ according to the game type
		SendLine(outString);
		`logDebug(outString);
	//SendLine(getNFO(WorldInfo));
}

/*
public static function string getNFO(WorldInfo WI)
{
	local string strRet, gametypeSpecific;

	if (BotDeathMatch(WI.Game) != none){
		gametypeSpecific = "{FragLimit " 
			$ BotDeathMatch(WI.Game).GoalScore $ "}";
	}
	else if (UTTeamGame(WI.Game) != none){
		gametypeSpecific = "{GoalTeamScore " $ UTTeamGame(WI.Game).GoalScore
			$ "} {MaxTeams 2"
			$ "} {MaxTeamSize " $ UTTeamGame(WI.Game).MaxPlayersAllowed
			$ "}";
	}

	strRet = "NFO {Gametype " $ WI.GetGameClass() $
		"} {Level " $ WI.GetMapName(true) $
		"} {WeaponStay " $ GetBoolString(UTGame(WI.Game).bWeaponStay) $
		"} {TimeLimit " $ WI.Game.TimeLimit $
		"} {GamePaused " $ GetBoolString(WI.Pauser != none) $
		"} {BotsPaused " $ GetBoolString(Wi.bPlayersOnly) $
		"} " $ gametypeSpecific;
	return strRet;
}
*/

//===============================================================================
//= Mutators exporting
//===============================================================================

/**
 * Sends MUT batch to the client
 * @note Messages: SMUT,MUT,EMUT
 */ 
function ExportMutators()
{
    local Mutator M;

	if(bDebug){
		M = WorldInfo.Game.BaseMutator;
		`LogDebug("BaseMutator = " $ M );
	}

    SendLine("SMUT");
    for (M = WorldInfo.Game.BaseMutator; M != None; M = M.NextMutator){
        SendLine("MUT {Id " $ M $
            "} {Name " $ M.Name $
            "}");
    }
    SendLine("EMUT");
}

//===============================================================================
//= Movers exporting
//===============================================================================

/**
 * Sends MOV batch to the client
 * @note Messages: SMOV,EMOV
 */ 
function ExportMovers() {
    local InterpActor IA;
	local string outString;
    
    SendLine("SMOV");
    foreach AllActors(class'InterpActor', IA) {
		outString = GetMOV(IA, true);
		if(IA.MyMarker != none)
			SendLine(outString);
		//else 
			//`LogInfo("Irrelevant mover: " $ OutString );
    }
    SendLine("EMOV");
}

/**
 * Provides MOV info message for InterpActor.
 * @note Messages: MOV
 *       Attributes: Id, Type*, State*, NavPointMarker*,
 *			Location, Velocity, BasePos*, BaseRot*, Visible*, 
 *			Reachable*, DamageTrig*, IsMoving,  MoveTime*, 
 *			OpenTime, DelayTime*
 * @todo Visible, Reachable is not sent right now.
 *      Better handled else where.
 * @todo DamageTrig, MoveTime, DelayTime
 *          missing relevant source; not sent!
 * @todo BasePos, BaseRot relevant only when NavPointMarker != none
 * @todo NavPointMarker is often none?
 * @todo State InterpActor does not seems to have
 *          any states; not sent!
 * @todo Type is derived from MyMarker class name; current implementation
 *      works only for DoorMarker and LiftCenter
 *      
 * @return Returns GB protocol string. MOV message
 * 
 * @param IA InterpActor providing info for message
 * @param bExportStatic Indicates if static info 
 *          should be exported
 */ 
function string GetMOV(InterpActor IA, bool bExportStatic) {
    local string strRet;
	local string Id, Type; //strState;
	local NavigationPoint NavPointMarker;
	local Vector Location, Velocity, BasePos;
	local Rotator BaseRot, nullRot;
	local bool  IsMoving; //Visible, Reachable, DamageTrig;
	local float OpenTime;//, MoveTime, DelayTime;
    
	Id = class'GBUtil'.static.GetUniqueId(IA);
	Location = IA.Location;
	//Visible = false;
	//Reachable = false;
	//DamageTrig = false;
	//Derives mover type from type of asociated NavPoint
	//Works for Lift and Door derived from LiftCenter_X and DoorMarker_X
	Type $= Left(IA.MyMarker,4); 
	IsMoving = IA.bIsMoving;
	Velocity = IA.Velocity;
	//MoveTime = 1.0f;
	OpenTime = IA.StayOpenTime;
	BasePos = (IA.MyMarker != none) ? IA.MyMarker.Location : vect(0,0,0);
	BaseRot = (IA.MyMarker != none) ? IA.MyMarker.Rotation : nullRot;
	//DelayTime = 0.0f;
	//strState $= IA.GetStateName();
	NavPointMarker = IA.MyMarker;

	strRet = "MOV {Id " $ Id $ 
		"} {Location " $ Location $ 
		//"} {Visible " $ class'GBUtil'.static.GetBoolString(Visible) $
		"} {IsMoving " $ class'GBUtil'.static.GetBoolString(IsMoving) $
		"} {Velocity " $ Velocity $
		//"} {State " $ strState $
		"}";

	if(bExportStatic)
		strRet @= "{Type " $ Type $
			"} {OpenTime " $ OpenTime $
			"} {BasePos " $ BasePos $
			"} {BaseRot " $ BaseRot $
			"} {NavPointMarker " $ NavPointMarker $
			//"} {DamageTrig " $ class'GBUtil'.static.GetBoolString(DamageTrig) $
			//"} {MoveTime " $ MoveTime $
			//"} {DelayTime " $ DelayTime $
			"}";

	return strRet;
}

//===============================================================================
//= Navigation Poits exporting
//===============================================================================

/**
 * Sends NAV and INGP batches to the client
 * Exports info about all navigation points and the
 *  navigation graph
 * @note Messages: NAV, SNAV, ENAV, INGP, SNGP, ENGP
 *       Attributes: Id, Location, Velocity (NAV)
 *          Id, Flags, CollisionR, CollisionH (INGP)
 *          
 * @note replacement factories are not exported via NAV message because they
 *          are not used as navigation points by navigation points.
 * @todo TranslocZOffset, TranslocTargetTag, OnlyTranslocator,
 *          ForceDoubleJump, NeededJump, NeverImpactJump, 
 *          NoLowGravity, CalculatedGravityZ (IGNP) are not sent;
 *          missing relevant source
 */ 
function ExportNavPoints()
{
    local string outString;
    local NavigationPoint N;
    local int i,PathListLength;
	local int reachFlags;

    SendLine("SNAV");

    foreach WorldInfo.AllNavigationPoints(class'NavigationPoint', N){
		//do not export replacement factories as NAV
    	if (N.IsA('PickupFactory')){
    		if (PickupFactory(N).OriginalFactory != none) continue;
    	}
        outString = "NAV {Id " $ N $
                "} {Location " $ N.Location $
				"} {Velocity " $ N.Velocity $
                "}";

        outString @= GetNavPointCategoryDetails(N);
        SendLine(outString);

        PathListLength = N.PathList.Length;
        SendLine("SNGP");
        for (i = 0; i < PathListLength; i++)
        {
			reachFlags = N.PathList[i].reachFlags;

			if (N.PathList[i].isA('ProscribedReachSpec')) {
				reachFlags += 128;				
			}

            outString = "INGP {Id " $ N.PathList[i].End.Nav $
                    "} {Flags " $ reachFlags $					
                    "} {CollisionR " $ N.PathList[i].CollisionRadius $
                    "} {CollisionH " $ N.PathList[i].CollisionHeight $
					"} {OnlyTranslocator " $ N.PathList[i].isA('UTTranslocatorReachSpec') $
                    "}";
            SendLine(outString);	

            if (N.PathList[i].isA('ProscribedReachSpec')) {
                reachFlags -= 128;
            }		
        }
        SendLine("ENGP");
    }
    SendLine("ENAV");
}

/**
 * Provides Navigation Point category specific deatils
 * @note Masseges: NAV
 *       Attributes: Item, ItemClass, ItemSpawned, DoorOpened,
 *          Mover, LiftOffset, LiftJumpExit, NoDoubleJump,
 *          InvSpot, PlayerStart, TeamNumber, Door, LiftCenter,
 *          LiftExit, JumpSpot, Teleporter, AIMarker, JumpDest,
 *          Rotation, Roaming,Spot, SnipingSpot, PreferedWeapon,
 *          Visible, Reachable
 * @return Returns part of the NAV message.
 * @todo CTFFlag, FlagOfTeam - not in documentation
 * @todo There are other interesting types of NavPoint not specified
 *          in documentation (PortalMarker, Objective, UTVehicleFactory, Ladder)
 * @todo NoDoubleJump always returns default value, missing relevant source
 * @todo Item might return wrong value, should match the relevant INV id?
 * @note DomPoint, DomPointController are not relevant for UT3
 * @todo AIMarker, Rotation, RoamingSpot, SnipingSpot, PreferedWeapon
 *          seems to be missing relevant source in UT3
 * @todo JumpSpot is now used for JumpPads; is that right??
 * 
 * @param NavPoint 
 * @param bHandshake True for additional hanshake info
 * 
 */ 
function string GetNavPointCategoryDetails(
	NavigationPoint NavPoint, optional bool bHandshake = true)
{
	local string strRet;
	local string Flag, details;
	//PickupFactory variables
	local string  ItemClass;
	local bool ItemSpawned;
	local string Item;

	//Flag = "PathNode";
	
	if (NavPoint.IsA('PickupFactory')){
		Flag = "InvSpot";
		ItemClass = class'GBUtil'.static.GetPickupTypeFromFactory(PickupFactory(NavPoint));
		ItemSpawned = NavPoint.IsInState('Pickup');
		if(PickupFactory(NavPoint).ReplacementFactory != none)
			Item = class'GBUtil'.static.GetInventoryUniqueId(PickupFactory(NavPoint).ReplacementFactory);
		else Item = class'GBUtil'.static.GetInventoryUniqueId(PickupFactory(NavPoint));

		if(bHandshake)
			details = "{Item " $ Item $//"INV_" $ NavPoint $
				"} {ItemClass " $ ItemClass $
				"} {ItemSpawned " $ class'GBUtil'.static.GetBoolString(ItemSpawned) $
				"}";
		else
			details = "{ItemSpawned " $
				class'GBUtil'.static.GetBoolString(ItemSpawned) $ "}";
		//details = GetNavInventoryDetails(PickupFactory(NavPoint),bHandShake);
	}
	else if (NavPoint.IsA('PlayerStart')){
		Flag = "PlayerStart";
		if(NavPoint.IsA('UTTeamPlayerStart'))
			details = "{TeamNumber " $ UTTeamPlayerStart(NavPoint).TeamNumber $
				"}";
	}
	else if (NavPoint.IsA('DoorMarker')){
		Flag = "Door";
		if(bHandshake)
			details = "{Mover " $ DoorMarker(NavPoint).MyDoor $
				"} {DoorOpened " $ class'GBUtil'.static.GetBoolString(
					DoorMarker(NavPoint).bDoorOpen) $
				"}";
	}
	else if (NavPoint.IsA('LiftCenter')){
		Flag = "LiftCenter";
		if(bHandshake)
			details = "{Mover " $ LiftCenter(NavPoint).MyLift $
				"} {LiftOffset " $ LiftCenter(NavPoint).LiftOffset $
				"}";
	}
	else if (NavPoint.IsA('LiftExit')){
		Flag = "LiftExit";
		if(bHandshake)
			details = "{Mover " $ LiftExit(NavPoint).MyLiftCenter.MyLift $
				"} {NoDoubleJump " $ class'GBUtil'.static.GetBoolString(false) $
				"}";
			if (NavPoint.IsA('UTJumpLiftExit'))
				details @= "{LiftJumpExit " $ class'GBUtil'.static.GetBoolString(true) $ 
					"}";
			else
				details @= "{LiftJumpExit " $ class'GBUtil'.static.GetBoolString(
					LiftExit(NavPoint).MyLiftCenter.bJumpLift) $ 
					"}";
	}
	else if (NavPoint.IsA('JumpPad'))
		Flag = "JumpSpot";
	else if (NavPoint.IsA('Teleporter'))
		Flag = "Teleporter";
	/*else if (NavPoint.IsA('UTCTFBase')){  // TODO: Not yet implemented in the parser and documentation
		//Flag = "CTFBase";
		details = "{FlagOfTeam " $ UTCTFBase(NavPoint).GetTeamNum() $ "}";
	}*/
	else if (NavPoint.IsA('PortalMarker')){
		`LogDebug("PortalMarker found: " $ NavPoint);
		//Flag = "PortalMarker";
	}
	else if (NavPoint.IsA('Ladder')){
		`LogDebug("Ladder found: " $ NavPoint);
		//Flag = "Ladder";
	}
	else if (NavPoint.IsA('UTVehicleFactory')){
		`LogDebug("UTVehicleFacory found: " $ NavPoint);
		//Flag = "UTVehicleFactory";
	}
	else if (NavPoint.IsA('Objective')){
		`LogDebug("Objective found: " $ NavPoint);
		//Flag = "Objective";
	}

	if(Flag != "") strRet = "{" $ Flag $ " True" $ "}";
	if (details != "") strRet @= details;

	return strRet;
}

/**
 * Sends INAV batch to the client.
 * @note Command: GETNAVS
 * @note Answer: SNAV, INAV, ENAV, INGP, SNGP, ENGP
 */ 
function ReceivedGetNavs(){
	ExportNavPoints();
}

//===============================================================================
//= Inventory items exporting
//===============================================================================

/**
 * Sends the INV batch to the client
 * @note Messages: SINV,INV,EINV
 * 
 * @note Replaced factories are not exported via INV message because they do not
 *          provide any items.
 */ 
function ExportInventory()
{
	local string outString;
	local PickupFactory P;
	local DroppedPickup DP;

    SendLine("SINV");
    foreach DynamicActors(class'PickupFactory',P){
		//do not export replaced PickupFactories with INV
    	if (P.ReplacementFactory != none)
			continue;
		outString = GetINVFromFactory(P);
		SendLine(outString);
    }

	foreach DynamicActors(class'DroppedPickup',DP){
		outString = GetINVFromDroppedPickup(DP);
		SendLine(outString);
	}
    SendLine("EINV");
}

function ReceivedGetInv(){
	ExportInventory();
}

/**
 * Provides INV message for PickupFactory
 * @note Messages: INV
 *       Attributes: Id, NavPointId, Type, Visible,
 *          Reachable, Dropped, Location, Amount
 * @return Returns INV message
 * 
 * @note Id adds INV_ prefix to the PickupFactory name
 * @note Visible, Reachable not sent in handshake. Handled
 *      in checkVision in RemoteBot.
 * @note Type returns item name with suffix coresponding with
 *          it's type
 * @note NavPointId is PickupFactory name as
 *      it is also a NavPoint for pickupfactories that provides an Inventory
 *      class item to the bot. PikcupFactories that do not provide an Inventory
 *      class instance their corresponding OriginalFactory id is used, because
 *      these factories were replaced with a mutator.
 * 
 * @param PF PickupFactory providing the information
 */ 
function string GetINVFromFactory(PickupFactory PF)
{
	local string strRet;
	local string Id, NavPointId, Type;
	local bool Dropped;//,Visible, Reachable;
	local Vector Location;
	local int Amount;

	Id = class'GBUtil'.static.GetInventoryUniqueId(PF);//"INV_" $ class'GBUtil'.static.GetUniqueId(PF);
	//if this is the replacement factory export it's original factory as NavPointID
	if (PF.OriginalFactory != none)
		NavPointId = class'GBUtil'.static.GetUniqueId(PF.OriginalFactory);
	else
		NavPointId = class'GBUtil'.static.GetUniqueId(PF);
	//Visible = false;
	Location = PF.Location;
	//Reachable = false;
	Amount = GetPickupAmountFromFactory(PF);
	Type = class'GBUtil'.static.GetPickupTypeFromFactory(PF);
	Dropped = false;

    strRet = "INV {Id " $ Id $
		"} {NavPointId " $ NavPointId $
		//"} {Visible " $ class'GBUtil'.static.GetBoolString(Visible) $
        "} {Location " $ Location $
		//"} {Reachable " $ class'GBUtil'.static.GetBoolString(Reachable) $
        "} {Amount " $ Amount $
        "} {Type " $ Type $
        "} {Dropped " $ class'GBUtil'.static.GetBoolString(Dropped) $
        "} ";

	return strRet;
}

/**
 * Provides INV message for DroppedPickup class
 * @note Messages: INV
 *       Attributes: Id, NavPointId, Type, Visible,
 *          Reachable, Dropped, Location, Amount
 * @return Returns INV message
 * @todo id check if returns right value
 * @note Visible, Reachable not sent. Handled
 *         in RemoteBot checkVision
 * @todo Type experimentaly set to ItemName
 * @todo NavPointId might not work
 * 
 * @param DP DroppedPickup providing the information
 */ 
function string GetINVFromDroppedPickup(DroppedPickup DP)
{
	local string strRet;
	local string Id, NavPointId, Type;
	local bool Dropped;//,Visible, Reachable; 
	local Vector Location;
	local int Amount;

	Id = class'GBUtil'.static.GetUniqueId(DP);
	NavPointId = class'GBUtil'.static.GetUniqueId(DP.PickupCache);
	//Visible = false;
	Location = DP.Location;
	//Reachable = false;
	Amount = GetPickupAmountFromDroppedPickup(DP);
	Type = string(DP.InventoryClass);   // Inventory.ItemName is null for powerups so we return the classtype
	Dropped = true;

    strRet = "INV {Id " $ Id $
		"} {NavPointId " $ NavPointId $
		//"} {Visible " $ class'GBUtil'.static.GetBoolString(Visible) $
        "} {Location " $ Location $
		//"} {Reachable " $ class'GBUtil'.static.GetBoolString(Reachable) $
        "} {Amount " $ Amount $
        "} {Type " $ Type $
        "} {Dropped " $ class'GBUtil'.static.GetBoolString(Dropped) $
        "} ";
	return strRet;
}
 
function int GetPickupAmountFromFactory(PickupFactory PF)
{
	local int amount;

	if(PF.IsA('UTWeaponPickupFactory'))
		amount = class<UTWeapon>(PF.InventoryType).default.AmmoCount;
	else if (PF.IsA('UTAmmoPickupFactory'))
		amount = UTAmmoPickupFactory(PF).AmmoAmount;
	else if (PF.IsA('UTHealthPickupFactory'))
		amount = UTHealthPickupFactory(PF).HealingAmount;
	else if (PF.IsA('UTArmorPickupFactory'))
		amount = UTArmorPickupFactory(PF).ShieldAmount;
	else if (PF.IsA('UTWeaponLocker'))
		amount = 1;	
	else amount  = 0;

	return amount;
}

function int GetPickupAmountFromDroppedPickup(DroppedPickup DP)
{
	local int amount;
	local Inventory inv;

	inv = DP.Inventory;

	if (inv.IsA('UTWeapon'))
		amount = UTWeapon(inv).AmmoCount;
	else if (DP.IsA('UTDroppedShieldBelt'))
		amount = UTDroppedShieldBelt(DP).ShieldAmount;
	else amount = 1;

	return amount;
}
//===============================================================================
//= Players exporting
//===============================================================================

/**
 * Sends PLR batch to the client
 * @note Messages: PLR, SPLR, EPLR
 */ 
function ExportPlayers(optional bool bLimitedInfo)
{
    local Controller C;
   
	SendLine("SPLR");
    foreach WorldInfo.AllControllers(class'Controller', C)
        SendLine(GetPLR(C,bLimitedInfo));
	SendLine("EPLR");
}

/**
 * Sends PLR batch to the client.
 * @note Command: GETPLRS
 * @note Answer: SPLR, PLR, EPLR
 */ 
function ReceivedGetPLRS(){
	ExportPlayers(true);
}

/**
 * Provides the PLR message for a Controller
 * @note Messages: PLR
 *       Attributes: Id, Jmx, Name, Action*, Weapon,
 *       Visible*, Reachable*, Rotation, Location, Velocity, 
 *       Team, Firing
 * @return Returns PLR message
 * 
 * @note Reachable not sent. Irrelevant for handshake.
 * @note Visible not sent right now. Is irrelevant for handshake
 *          and is best handled elsewhere.
 * @todo Action not implemented yet
 * @todo Firing need to be verified
 *          verified!
 * 
 * @param C Controller providing the info
 * @param bLimitedInfo if true short version of the message
 *          is returned; including attributes: Id, Name, Team
 */ 
function string GetPLR(Controller C, bool bLimitedInfo)
{
	local string strRet;
    local string Id, Jmx, PlrName, Action, Weapon;
	//local bool Visible, Reachable;
	local Rotator Rotation;
	local Vector Location, Velocity;
	local int Team, Firing;

	Id = class'GBUtil'.static.GetUniqueId(C);
	PlrName = (C.IsA('PlayerController')) ? "Player" : C.PlayerReplicationInfo.PlayerName;
	Team = (C.PlayerReplicationInfo.Team != none) ? 
		C.PlayerReplicationInfo.Team.TeamIndex : 255;
	//Visible = false;
	//Reachable = false;

    strRet = "PLR {Id " $ Id $
        "} {Name " $ PlrName $
        "} {Team " $ Team $
        //"} {Visible " $ class'GBUtil'.static.GetBoolString(Visible) $
		//"} {Reachable " $ class'GBUtil'.static.GetBoolString(Reachable) $
        "}";

    if (!bLimitedInfo) {
        if (C.IsA('RemoteBot') && RemoteBot(C).jmx != ""){
			Jmx = RemoteBot(C).jmx;
			Action = "None";
			strRet @= "{Jmx " $ Jmx $ 
				"} {Action " $ Action $
				"}";
        }

        if (C.Pawn != none){
            Location = C.Pawn.Location;
			Rotation = C.Pawn.Rotation;
			Velocity = C.Pawn.Velocity;
			Weapon = (C.Pawn.Weapon == none) ? "None" :
				class'GBUtil'.static.GetInventoryTypeFromWeapon(class<UTWeapon>(C.Pawn.Weapon.Class));
			//Firing: 1 for primary, 2 for secondary, 0 not firing 
			Firing = 0;
			//IsFiring returns 0 for primary 1 for secondary so we have to 
			//increase the return value by one to match our definition
			if(C.Pawn.Weapon != none && C.Pawn.Weapon.IsFiring()) {
				Firing = C.Pawn.Weapon.CurrentFireMode +1; 
			}
        }
        else {
            Location = C.Location;
			Rotation = C.Rotation;
			Velocity = C.Velocity;
        }

		strRet @= "{Location " $ Location $
                "} {Rotation " $ Rotation $
                "} {Velocity " $ Velocity $
                "}";
		if (C.Pawn != none ) 
			strRet @= "{Weapon " $ Weapon $
                "} {Firing " $ Firing $
                "}";
    }
	return strRet;
}

//===============================================================================
//= Item classes exporting
//===============================================================================

/**
 * Sends ITC batch to the client
 * @note Messages: SITC,ITC,EITC
 */ 
function ExportItemClasses() 
{
	local PickupFactory P;
	local bool bAlreadyExported;
	local ExportedITC ex;

    SendLine("SITC");

	ExportBasicEquipment();

	foreach DynamicActors(class'PickupFactory',P){
		foreach exportedITCs(ex){       //Check if we have already exported this
			if(ex.PF == P.Class && ex.INV == P.inventoryType)
				bAlreadyExported = true;
		}
		if(!bAlreadyExported){          //Send ITC and add to the exported list
			SendLine(GetITCFromFactory(P),false);
			ex.INV = P.InventoryType;
			ex.PF = P.Class;
			exportedITCs.AddItem(ex);
		}
		bAlreadyExported = false;       //reset exported indicator
	}

    SendLine("EITC");
}

/**
 * Sends ITC for basic equipment
 * @note Messages: ITC
 * @note Basic equipment might not be present
 * on the map so we have to export it manually.
 * @todo Works only for weapons.
 * @todo InventoryType and PickupType might return wrong value
 * @todo Translocator exported for team games even if translocator
 *          is not used.
 * @todo should use UTGame.DefaultInventory
 * 
 * @return Returns info about exported ITCs
 */ 
function ExportBasicEquipment()
{
	local array< class<Inventory> > defInventory;
	local class<UTWeapon> W;
	local string ITCmsg;

	defInventory = BotDeathMatch(WorldInfo.Game).DefaultInventory;
	foreach defInventory(W) {
		ITCmsg = "ITC {InventoryType " $ class'GBUtil'.static.GetInventoryTypeFromWeapon(W) $
			"} {PickupType " $ Mid(W,7) $ ".WeaponPickup" $
			"} {ItemCategory Weapon}" @
			GetWeaponITCDetails(W);
		SendLine(ITCmsg, false);
	}
}

/**
 * Provides text of the ITC message for given PickupFactory
 * @note Messages: ITC
 *       Attributes: InventoryType, PickupType
 * @return Returns ITC message in GB protocol
 * @todo InventoryType, PickupType must be redone to work properly
 * 
 * @param PF PickupFactory to export
 */ 
function string GetITCFromFactory(PickupFactory PF)
{
	local string strRet;
	strRet $= "ITC {InventoryType " $ class'GBUtil'.static.GetInventoryTypeFromFactory(PF) $
			"} {PickupType " $ class'GBUtil'.static.GetPickupTypeFromFactory(PF) $
			//"} {RespawnTime " $ PF.InventoryType.default.RespawnTime $
			"}" @ GetItemCategoryDetails(PF);
	return strRet;
}

/**
 * Provides ITC message attributes that are ItemType specific
 * @note Messages: ITC
 *       Attributes: ItemCategory, Amount, SuperHealth, RespawnTime
 * @return Returns part of the ITC message
 * @todo RespawnTime experimental!
 * 
 * @param PF PickupFactory to export 
 */ 
function string GetItemCategoryDetails(PickupFactory PF)
{
	local string strRet;

	if(PF.IsA('UTWeaponPickupFactory')){
		strRet = "{ItemCategory Weapon} " $ 
			//"{RespawnTime " $ PF.InventoryType.default.RespawnTime $ "}" @
			GetWeaponITCDetails(class<UTWeapon>(PF.InventoryType));
	}
	else if(PF.IsA('UTAmmoPickupFactory')){
		strRet = "{ItemCategory Ammo} " $
			//"{RespawnTime " $ UTItemPickupFactory(PF).RespawnTime $ "}" @
			GetAmmoITCDetails(UTAmmoPickupFactory(PF));
	}
	else if(PF.IsA('UTHealthPickupFactory')){
		strRet = "{ItemCategory Health} " $
			//"{RespawnTime " $ UTItemPickupFactory(PF).RespawnTime $ 
			//"} 
			"{Amount " $ UTHealthPickupFactory(PF).HealingAmount $ 
			"} {SuperHeal " $ class'GBUtil'.static.GetBoolString(UTHealthPickupFactory(PF).bSuperHeal) $ "}";
	}
	else if(PF.IsA('UTArmorPickupFactory')){
		strRet = "{ItemCategory Armor} " $
			//"{RespawnTime " $ UTItemPickupFactory(PF).RespawnTime $
			//"} 
			"{Amount " $ UTArmorPickupFactory(PF).ShieldAmount $ "}";
	}
	else if(PF.IsA('UTPowerupPickupFactory')){
		strRet = "{ItemCategory Other}"; //@
			//"{RespawnTime " $ PF.InventoryType.default.RespawnTime $ "}";
	}
	else if(PF.IsA('UTDeployablePickupFactory')) {  // The deployables are part of the weapon category
		strRet = "{ItemCategory Weapon} " $
			GetWeaponITCDetails(class<UTWeapon>(PF.InventoryType));
	}
	else
		strRet = "{ItemCategory Other}";

	return strRet;
}

/**
 * Provides weapon details for ITC message
 * @note Messages: ITC
 *       Attributes: Melee, Sniping, UsesAltAmmo
 * @return Returns part of ITC message
 * @note UsesAltAmmo is not needed for UT3; not sent!
 *       
 * @param W Weapon to export
 */ 
function string GetWeaponITCDetails(class<UTWeapon> W)
{
	local string strRet;
	local string Melee,Sniping;//,UsesAltAmmo;
	local string PriAmmoDetails,PriProjectileDetails,PriFireModeDetails;
	local string SecAmmoDetails,SecProjectileDetails,SecFireModeDetails;

	Melee = class'GBUtil'.static.GetBoolString(W.default.bMeleeWeapon);
	Sniping = class'GBUtil'.static.GetBoolString(W.default.bSniping);
	//UsesAltAmmo = class'GBUtil'.static.GetBoolString(false);

	if(W.default.FiringStatesArray.length > 0){
		PriFireModeDetails = GetFireModeITCDetails(W,0);
		PriAmmoDetails = GetAmmoInfo(W,0);
		PriProjectileDetails = GetProjectileITCDetails(
			W.default.WeaponProjectiles[0],0);
	}

	if(W.default.FiringStatesArray.length > 1){
		SecFireModeDetails = GetFireModeITCDetails(W,1);
		SecAmmoDetails = GetAmmoInfo(W,1);
		SecProjectileDetails = GetProjectileITCDetails(
			W.default.WeaponProjectiles[1],1);
	}

	strRet = "{Melee " $ Melee $
		"} {Sniping " $ Sniping $
		//"} {UsesAltAmmo " $ UsesAltAmmo $
		"}" @ PriFireModeDetails @ PriAmmoDetails @ PriProjectileDetails @
		SecFireModeDetails @ SecAmmoDetails @ SecProjectileDetails;
	return strRet;
}

/**
 * Provides ITC attributes for weapon firing mode
 * @note Messages: ITC
 *       Attributes: FireMode, SplashDamage, SplashJump, RecomSplashDamage,
 *			Tossed, LeadTarget, InstantHit, FireOnRelease, WaitForRelease,
 *			ModeExclusive, FireRate, BotRefireRate, AimError, Spread,
 *			DamageAtten, AmmoPerFire, AmmoClipSize, SpreadStyle, FireCount,
 *			Damage, MaxDamage, MinDamage
 * @return Returns part of the ITC message
 * @note AmmoClipSize,SpreadStyle, FireCount, WaitForRelease
 *          missing relevant source in UT3; not sent!
 * @todo ModeExclusive,DamageAtten,BotRefireRate possibly return wrong
 *          values.
 * @note MaxDamage, MinDamage seems to be not used in UT3; not sent!
 *          
 * @param W Weapon class providing info
 * @param fireMode 0 for primary, 1 for secondary
 */ 
function string GetFireModeITCDetails(class<UTWeapon> W, byte fireMode)
{
	local string strRet, prefix;
	local string FMode; 
	local bool SplashDamage, SplashJump, RecomSplashDamage,
		Tossed, LeadTarget, InstantHit, FireOnRelease, ModeExclusive;
		//WaitForRelease;
	local float FireRate, BotRefireRate, AimError, Spread, DamageAtten,
		Damage;//, MaxDamage, MinDamage;
	local int AmmoPerFire;//, AmmoClipSize, SpreadStyle, FireCount;
	local class<Projectile> P;
	local EWeaponFireType FireType;
	
	prefix = (fireMode == 0) ? "Pri" : "Sec";
	P = (W.default.WeaponProjectiles.length > fireMode) 
		? W.default.WeaponProjectiles[fireMode] : none;
	FireType = (W.default.WeaponFireTypes.length > fireMode)
		? W.default.WeaponFireTypes[fireMode] : EWFT_None;

	FMode = W $ "_FireMode_" $ fireMode;
	SplashDamage = (P != none) ? P.default.DamageRadius > 0 : false;
	SplashJump = W.default.bSplashJump;
	RecomSplashDamage = W.default.bRecommendSplashDamage;
	Tossed = (P != none) ? P.default.Physics == PHYS_Falling : false;
	LeadTarget = W.default.bLeadTarget;
	InstantHit = FireType == EWFT_InstantHit;
	FireOnRelease = W.default.ShouldFireOnRelease.length > fireMode 
		&& W.default.ShouldFireOnRelease[fireMode] > 0;
	//WaitForRelease = false;
	ModeExclusive = true;
	FireRate = W.default.FireInterval[fireMode];
	BotRefireRate = FireRate;
	AmmoPerFire = W.default.ShotCost[fireMode];
	//AmmoClipSize = 0;
	AimError = W.default.AimError;
	Spread = W.default.Spread[fireMode];
	//SpreadStyle = 0;
	//FireCount = 0;
	DamageAtten = 1;

	strRet = "{" $ prefix $ "FireModeType " $ FMode $
		"} {" $ prefix $ "SplashDamage " $ 
			class'GBUtil'.static.GetBoolString(SplashDamage) $
		"} {" $ prefix $ "SplashJump " $ 
			class'GBUtil'.static.GetBoolString(SplashJump) $
		"} {" $ prefix $ "RecomSplashDamage " $ 
			class'GBUtil'.static.GetBoolString(RecomSplashDamage) $
		"} {" $ prefix $ "Tossed " $ 
			class'GBUtil'.static.GetBoolString(Tossed) $
		"} {" $ prefix $ "LeadTarget " $ 
			class'GBUtil'.static.GetBoolString(LeadTarget) $
		"} {" $ prefix $ "InstantHit " $ 
			class'GBUtil'.static.GetBoolString(InstantHit) $
		"} {" $ prefix $ "FireOnRelease " $ 
			class'GBUtil'.static.GetBoolString(FireOnRelease) $
		//"} {" $ prefix $ "WaitForRelease " $ 
			//class'GBUtil'.static.GetBoolString(WaitForRelease) $
		"} {" $ prefix $ "ModeExclusive " $ 
			class'GBUtil'.static.GetBoolString(ModeExclusive) $
		"} {" $ prefix $ "FireRate " $ FireRate $
		"} {" $ prefix $ "BotRefireRate " $ BotRefireRate $
		"} {" $ prefix $ "AmmoPerFire " $ AmmoPerFire $
		//"} {" $ prefix $ "AmmoClipSize " $ AmmoClipSize $
		"} {" $ prefix $ "AimError " $ AimError $
		"} {" $ prefix $ "Spread " $ Spread $
		//"} {" $ prefix $ "SpreadStyle " $ SpreadStyle $
		//"} {" $ prefix $ "FireCount " $ FireCount $
		"} {" $ prefix $ "DamageAtten " $ DamageAtten $
		"}";
	
	if(InstantHit){
		Damage = W.default.InstantHitDamage[fireMode];
		//MaxDamage = Damage;
		//MinDamage = Damage;
		strRet @= "{" $ prefix $ "Damage " $ Damage $
			//"} {" $ prefix $ "MaxDamage " $ MaxDamage $
			//"} {" $ prefix $ "MinDamage " $ MinDamage $
			"}";
	}

	return strRet;
}

/**
 * Provides ITC attributes of projectile for ammo or weapon
 * @note Messages: ITC
 *       Attributes: ProjType, Damage, Speed, MaxSpeed, LifeSpan, 
 *      	DamageRadius, TossZ, MaxEffectDistance
 * @return Returns part of the ITC message
 * @todo TossZ and MaxEffectDistance are always blank
 * 
 * @param P Projectile class providing the info
 * @param fireMode 0 for primary, 1 for secondary
 */ 
function string GetProjectileITCDetails(class<Projectile> P, byte fireMode)
{
	local string strRet, prefix;
	local string ProjType;
	local float Damage, Speed, MaxSpeed, LifeSpan, 
		DamageRadius, TossZ, MaxEffectDistance;

	prefix = (fireMode == 0) ? "Pri" : "Sec"; 

	if(P != none){
		ProjType = string(P);
		Damage = P.default.Damage;
		Speed = P.default.Speed;
		MaxSpeed = P.default.MaxSpeed;
		LifeSpan = P.default.LifeSpan;
		DamageRadius = P.default.DamageRadius;
		TossZ = class<UTProjectile>(P).default.TossZ;
		MaxEffectDistance = class<UTProjectile>(P).default.MaxEffectDistance;

		strRet = "{" $ prefix $ "ProjType " $ ProjType $
			"} {" $ prefix $ "Damage " $ Damage $
			"} {" $ prefix $ "Speed "$ Speed $
			"} {" $ prefix $ "MaxSpeed " $ MaxSpeed $
			"} {" $ prefix $ "LifeSpan " $ LifeSpan $
			"} {" $ prefix $ "DamageRadius " $ DamageRadius $
			"} {" $ prefix $ "TossZ " $ TossZ $
			"} {" $ prefix $ "MaxEffectDistance " $ MaxEffectDistance $
			"}";
	}
	return strRet;
}

/**
 * Provides ITC attributes about ammunition
 * which are used for weapon as well
 * @note Messages: ITC
 *       Attributes: AmmoType, ArmorStops, AlwaysGibs, Special,DetonatesGoop,
 *  		SuperWeapon,ExtraMomZ, InitialAmount, MaxAmount, MaxRange, DamageType
 * @return Returns part of the ITC mesage.addin
 * @note Special and DetonatesGoop missing relevant source; not sent!
 * @todo AmmoType is now derived from weapon InventoryType or none for 
 *          melee weapons. Check if this is correct.
 * 
 * @param W Weapon class asocited with the ammo
 * @param fireMode 0 for primary, 1 for secondary
 */ 
function string GetAmmoInfo(class<UTWeapon> W, byte fireMode)
{
	local string strRet,prefix;
	local string AmmoType, ArmorStops, AlwaysGibs, SuperWeapon,ExtraMomZ;
			//Special,DetonatesGoop;
	local int InitialAmount, MaxAmount;
	local float MaxRange;
	local class<DamageType> DamageType;

	if(W != none){
		AmmoType = class'GBUtil'.static.GetInventoryTypeFromWeapon(W) $ "Ammo";
		InitialAmount = W.default.AmmoCount;
		MaxAmount = W.default.MaxAmmoCount;
		MaxRange = W.default.WeaponRange;
		if(W.default.WeaponFireTypes[fireMode] == EWFT_InstantHit)
			DamageType = W.default.InstantHitDamageTypes[fireMode];
		else 
		{
			if(W.default.WeaponProjectiles[fireMode] != None)
				DamageType = W.default.WeaponProjectiles[fireMode].default.MyDamageType;
		}

		if(DamageType != none){
			ArmorStops = class'GBUtil'.static.GetBoolString(DamageType.default.bArmorStops);
			AlwaysGibs = class'GBUtil'.static.GetBoolString(DamageType.default.bAlwaysGibs);
			//Special = class'GBUtil'.static.GetBoolString(false);
			//DetonatesGoop = class'GBUtil'.static.GetBoolString(false);
			SuperWeapon = class'GBUtil'.static.GetBoolString(W.default.bSuperWeapon);
			ExtraMomZ = class'GBUtil'.static.GetBoolString(DamageType.default.bExtraMomentumZ);
		}

		prefix = (fireMode == 0) ? "Pri" : "Sec";

		strRet = "{" $ prefix $ "AmmoType " $ AmmoType $
			"} {" $ prefix $ "InitialAmount " $ InitialAmount $
			"} {" $ prefix $ "MaxAmount " $ MaxAmount $
			"} {" $ prefix $ "MaxRange " $ MaxRange $
			"} {" $ prefix $ "DamageType " $ DamageType $ 
			"}";
		if(DamageType != none)
			strRet @= "{" $ prefix $ "ArmorStops " $ ArmorStops $
				"} {" $ prefix $ "AlwaysGibs " $ AlwaysGibs $
				//"} {" $ prefix $ "Special " $ Special $
				//"} {" $ prefix $ "DetonatesGoop " $ DetonatesGoop $
				"} {" $ prefix $ "SuperWeapon " $ SuperWeapon $
				"} {" $ prefix $ "ExtraMomZ " $ ExtraMomZ $ 
				"}";
	}
	return strRet;
}

/**
 * Provides ITC details for ammunition
 * @note Messages: ITC
 *       Attributes: Amount
 * @return Returns part of the ITC message
 * 
 * @param A Pickup factory representing the ammunition
 */ 
function string GetAmmoITCDetails(UTAmmoPickupFactory A)
{
	local string strRet;
	local int Amount;
	if(A != none){
		Amount = A.AmmoAmount;

		strRet = GetAmmoInfo(A.TargetWeapon, 0) @
			"{Amount " $ Amount $ "}";
	}
	return strRet;
}

//===============================================================================
//= FlagInfo exporting
//===============================================================================
function ExportFlagInfo() {
	local UTCTFFlag F;
	local string outstring;

	if (WorldInfo.Game.IsA('GBCTFGame')){
		foreach AllActors (class'UTCTFFlag', F)
		{
			outstring = "FLG {Id " $ class'GBUtil'.static.GetUniqueId(F) $
				"} {Team " $ F.Team.TeamIndex $
			//	"} {Reachable " $ actorReachable(F) $
				"} {State " $ F.GetStateName() $
				"}";

			//when a flag is held its location is not updated by engine =(
			if(F.IsInState('Held') && F.Holder != none)
			{
				outstring = outstring $ " {Location " $ F.Holder.Location $
					"} {Holder " $ class'GBUtil'.static.GetUniqueId(F.Holder) $"}";
			}
			else
			{
				outstring = outstring $" {Location " $ F.Location $"}";
			}
			SendLine(outstring);
		}
	}		
}

//===============================================================================
//= Miscealaeous
//===============================================================================

/**
 * Handles sending handshake NFO batch
 */ 
function ExportStatus()
{
    SendLine("SHS"); //HandShake start
        if (bExportGameInfo)
                SendGameInfo();
        if (bExportMutators)
                ExportMutators(); //SMUT, MUT, EMUT messages
        if (bExportITC)
                ExportItemClasses(); //SITC, ITC, EITC messages
        if (bExportNavPoints)
                ExportNavPoints();
        if (bExportMovers)
                ExportMovers();
        if (bExportInventory)
                ExportInventory(); //temporary disabled
        if (bExportPlayers) 
                ExportPlayers(false); //true for limited info
	SendLine("EHS"); //HandShake end
}

/**
 * Sends Alive message to the client
 */ 
function SendAlive()
{
	SendLine("ALIVE {Time " $ WorldInfo.TimeSeconds $ "}");
}

function SendFIN()
{
	 SendLine("FIN");
}

/**
 * Called when connection is closed 
 * on remote end or Close function is called.
 */ 
event Closed()
{
	super.Closed();
	if (!IsInState('NotifyServerClosed', false))
		GotoState('NotifyServerClosed');
}

/**
 * Called when the destroy() is called on GBClientClass.
 * 
 * @todo Can destruction happen before closing?
 */ 
event Destroyed()
{
	if (LinkState == STATE_Connected){
		SendFIN();
		Close();
   }
   super.Destroyed();
}

/**
 * Handles basic handshake.
 * @note Sends HELLO message and waits for READY.
 * Then it either continues with password check or
 * sends basic NFO batch.
 */ 
auto state handshake
{
	function ProcessAction(string cmdType)
	{
		switch(cmdType){
			case "READY":
				GotoState('handshake','Ready');
			break;
        }
	}

	function SendHello()
	{
		SendLine("HELLO_GBClinet");
	}

	function SendNFO()
	{
		ExportStatus();
	}

Begin:
	SendHello();
	goto 'Waiting';
Ready:
	 if (BotDeathMatch(WorldInfo.Game).bPasswordProtected)
		GotoState('checkPassword','Begin');
	else GotoState('handshake','SendNFO');
SendNFO:
	SendNFO();
	GotoState('running','Running');
Waiting:
	Sleep(1.0);
	goto 'Waiting';
}

state checkPassword
{
	function ProcessAction(string cmdType)
	{
		switch(cmdType){
			case "PASSWORD":
				GotoState('checkPassword','Password');
			break;
        }
	}

	function SendPassword()
	{
			SendLine("PASSWORD {BlockedByIP " $ BotDeathMatch(WorldInfo.Game).PasswordByIP $ "}");
	}

	function SendPasswdOK()
	{
		SendLine("PASSWDOK");
	}

	function SendPasswdWrong()
	{
		SendLine("PASSWDWRONG");
	}

	/**
	 * Checks the clients password 
	 * @note part of handshake procedure
	 * @return Returns true if the
	 * password is correct, false otherwise.
	 */ 
	function bool CheckReceivedPassword()
	{
		local string passwd;
		local bool ret;
		ret = false;
		passwd = GetArgVal("Password");

		if (passwd == BotDeathMatch(WorldInfo.Game).Password)
			ret = true;
	   
		return ret;
	}

Begin:
	SendPassword();
	goto 'Waiting';
Password:
	if (CheckReceivedPassword()){
        SendPasswdOK();
	    GotoState('handshake','SendNFO');
    } else {
        SendPasswdWrong();
        GotoState('notifyServerClosed');
    }
Waiting:
	Sleep(1.0);
	goto'Waiting';
}

state running
{
Waiting:
        sleep(1.0);
        SendAlive();
        goto 'Waiting';
Running:
        SendAlive();
        sleep(1.0);
        goto 'Running';
}

state notifyServerClosed
{
Begin:
	SendFIN();
	Close();
	GBServerClass(Owner).NotifyClosedConn(self);
}

defaultproperties
{
	bAllowPause=True
    bExportGameInfo=true
    bExportMutators=true
    bExportITC=true
    bExportNavPoints=true
    bExportMovers=true
    bExportInventory=true
    bExportPlayers=true
	bDebug=true
	bDebugSend=false
}