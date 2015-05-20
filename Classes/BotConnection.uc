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
// BotConnection.
// Based connection class
//=============================================================================
class BotConnection extends GBClientClass
	config(GameBotsUT3);
`include(Globals.uci);
`define debug;
//------------Variables---------------------------

// delay between visionUpdates
var config float visionTime;

// on / off all synchronous messages
var config bool bSynchronousMessagesOff;

var RemoteBot theBot;

var Actor tempActor;

var Actor FocusActor;

//switches for exporting information after READY command
/*var config bool bExportGameInfo;
var config bool bExportMutators;
var config bool bExportITC;
var config bool bExportNavPoints;
var config bool bExportMovers;
var config bool bExportInventory;
var config bool bExportPlayers;*/

//===============================================================================
//= General utility functions
//===============================================================================


//------------Events---------------------------

// triggered when a socket connection with the server is established
event Accepted()
{
	`LogInfo("Accepted BotConnection");
    //TODO HACK
	visionTime = 0.25;
}

/**
 * Handles proper destruction of objects.
 * 
 * @todo check what is going on with the pawn
 */ 
event Destroyed()
{
	super.Destroyed();
    if ( theBot != None && theBot.Pawn != None ){
        theBot.SetLocation(theBot.Pawn.Location);
        theBot.Pawn.RemoteRole = ROLE_SimulatedProxy;
        theBot.Pawn.UnPossessed();
        theBot.Pawn.Destroy();
    }

    if (theBot != None)
        theBot.Destroy();

    if (FocusActor != None)
        FocusActor.Destroy();
}

//------------Functions---------------------------


//Main function for processing commands
/**
 * Handles processing of commands.
 * 
 * @param cmdType command header
 * 
 * @todo *Resolved* In ControlConnection we handle part of the handshake.
 *      This part seems to be missing here.
 *      Resolved by handling whole handshake in state code
 */ 
function ProcessAction(string cmdType)
{
	//`LogDebug("commandType: " $ cmdType);

    if (theBot != none)
        theBot.myRepInfo.SetMyLastGBCommand(lastGBCommand);

    switch(cmdType)
    {
		case "ADDRAY":
            ReceivedAddRay();
        break;
        case "CONF":
            ReceivedConf();
        break;
		case "CHATTR":
            ReceivedChangeAtt();
        break;
		case "CHANGEWEAPON":
            ReceivedChangeWeapon();
        break;
		case "CHECKREACH":
            ReceivedCheckReach();
        break;
        case "CMOVE":
            ReceivedCMove();
        break;
		case "DISCONNECT":
            ReceivedDisconnect();
        break;
		case "DODGE":
            ReceivedDodge();
        break;
		case "ENTER":
            ReceivedEnter();
        break;
        case "INIT":
            InitBot();
        break;
		case "GETINVS":
            ReceivedGetInv();
        break;
		case "GETNAVS":
            ReceivedGetNavs();
        break;
        case "GETPATH":
            ReceivedGetPath();
        break;
        case "JUMP":
            ReceivedJump();
        break;
        case "MESSAGE":
            ReceivedMessage();
        break;
        case "MOVE":
            ReceivedMove();
        break;
		case "PICK":
            ReceivedPick();
        break;
        case "PING":
            SendLine("PONG");
        break;
        case "QUIT":
            ReceivedQuit();
        break;
        case "READY":
            ReceivedReady();
        break;     
        case "REC":
			ReceivedRec();
		break;
		 case "REMOVERAY":
			ReceivedRemoveRay();
		break;
        case "RESPAWN":
            ReceivedRespawn();
        break;
        case "ROTATE":
            ReceivedRotate();
        break;
        case "SETCROUCH":
            ReceivedSetCrouch();
        break;
        case "SETROUTE":
            ReceivedSetRoute();
        break;
        case "SETWALK":
            ReceivedSetWalk();
        break;
        case "SHOOT":
            ReceivedShoot();
        break;
        case "STOP":
            ReceivedStop();
        break;
        case "STOPSHOOT":
            ReceivedStopShoot();
        break;
		case "THROW":
            ReceivedThrow();
        break;
		case "TRACE":
            ReceivedTrace();
        break;
        case "TURNTO":
            ReceivedTurnTo();
        break;
    }//end switch
}

//===============================================================================
//= Initialization and configuration
//===============================================================================

//Init recieved from client
/**
 * Initialises the connection and the agent.
 * @note Command: INIT
 *       Attributes: Name, Team, ManualSpawn, AutoTrace,
 *          Location, Rotation, Skin, DesiredSkill,
 *          ShouldLeadTarget, AutoPickupOff, Jmx, ClassName
 * @note Answer: INITED, CONFCH
 * @note Message: INITED
 *       Attributes: BotId, HealthStart, HealthFull, HealthMax, 
 *       ShieldStrengthStart, ShieldStrengthMax, VestArmorMax, 
 *       VestArmorStart, ThighpadArmorMax, ThighpadArmorStart,
 *       HelmetArmorMax, HelmetArmorStart, ShieldBeltArmorMax,
 *       ShieldBeltArmorStart, MaxMultiJump, DamageScaling, 
 *       GroundSpeed, WaterSpeed, AirSpeed, LadderSpeed, AccelRate, 
 *       JumpZ, MultiJumpBoost, MaxFallSpeed, DodgeSpeedFactor, 
 *       DodgeSpeedZ, AirControl
 * @note Handles creating the Controller as well as the Pawn.
 *
 * @todo Redo the state stuff when RemoteBot states are redone.
 * @todo AutoTrace needs to be done when the tracing subsystem is done
 * @todo Skin not implemented yet
 * @todo ClassName Not using variant pawn clases
 * @note AdrenalineStart, AdrenalineMax not used in UT3
 * @todo ShieldStrengthMax/Start + xArmorx needs to be redone in GB protocol
 *          acording to new armor handling in UT3
 * @todo MultiJumpBoost not used in GB, can be exported
 * @todo DodgeSpeedFactor missing source
 */ 
function InitBot()
{
    local string clientName, className, temp, DesiredSkin, outstring;
    local int teamNum;
    local vector StartLocation;
    local rotator StartRotation;
    local float DesiredSkill;
    local bool ShouldLeadTarget;

    clientName = GetArgVal("Name");
    DesiredSkin = GetArgVal("Skin");
    className = GetArgVal("ClassName");

    temp = GetArgVal("Team");
	teamNum = (temp != "") ? int(temp) : 255;

    temp = GetArgVal("DesiredSkill");
	DesiredSkill = (temp != "") ? float(temp) : -1.0; //-1 -> default value will be used

    temp = GetArgVal("ShouldLeadTarget");
	ShouldLeadTarget = (temp != "") ? bool(temp) : false;

    // add the bot into the game
    theBot = BotDeathMatch(WorldInfo.Game).AddRemoteBot(
            self,
            clientName,
			//1,
            teamNum,
            className,
            DesiredSkin,
			//"Aspect",
            DesiredSkill,
            ShouldLeadTarget
    );

    //Here the spawning of the pawn is handled - after weve got controler created
    if(theBot != None) {
		//@todo what is that?
        FocusActor = Spawn(class'FocusActor',self);
        theBot.myTarget = Spawn(class'FocusActor',theBot);

        theBot.bAutoSpawn = true; //@todo HACK??
        if (GetArgVal("ManualSpawn") != "")
                theBot.bAutoSpawn = !bool(GetArgVal("ManualSpawn"));

        if (GetArgVal("AutoPickupOff") != "")
                theBot.bDisableAutoPickup = bool(GetArgVal("AutoPickupOff"));

        theBot.jmx = GetArgVal("Jmx");

        if (GetArgVal("AutoTrace")!= "")
                theBot.bAutoTrace = bool(GetArgVal("AutoTrace"));

        theBot.ResetSkill(); //initialize difficulty and enable movement?
        SendNotifyConf(theBot);
            
		outstring = "INITED {BotId " $ class'GBUtil'.static.GetUniqueId(theBot) $
            "} {HealthStart " $ theBot.PawnClass.Default.Health $
            "} {HealthFull " $ theBot.PawnClass.Default.HealthMax $
            "} {HealthMax " $ theBot.PawnClass.Default.SuperHealthMax $
            "} {ShieldStrengthStart " $ class'GBUtil'.static.GetInitialArmor(theBot.PawnClass) $
            "} {ShieldStrengthMax " $ class'GBUtil'.static.GetMaxArmor() $
		//	"} {VestArmorMax " $ class'UTArmorPickup_Vest'.default.ShieldAmount $
		//	"} {VestArmorStart " $ theBot.PawnClass.default.VestArmor $
		//	"} {ThighpadArmorMax " $ class'UTArmorPickup_Thighpads'.default.ShieldAmount $
		//	"} {ThighpadArmorStart " $ theBot.PawnClass.default.ThighpadArmor $
		//	"} {HelmetArmorMax " $ class'UTArmorPickup_Helmet'.default.ShieldAmount $
		//	"} {HelmetArmorStart " $ theBot.PawnClass.default.HelmetArmor $
		//	"} {ShieldBeltArmorMax " $ class'UTArmorPickup_ShieldBelt'.default.ShieldAmount $
		//	"} {ShieldBeltArmorStart " $ theBot.PawnClass.default.ShieldBeltArmor $
            "} {MaxMultiJump " $ theBot.PawnClass.Default.MaxMultiJump $
            "} {DamageScaling " $ theBot.PawnClass.Default.DamageScaling $
            "} {GroundSpeed " $ theBot.PawnClass.Default.GroundSpeed $
            "} {WaterSpeed " $ theBot.PawnClass.Default.WaterSpeed $
            "} {AirSpeed " $ theBot.PawnClass.Default.AirSpeed $
            "} {LadderSpeed " $ theBot.PawnClass.Default.LadderSpeed $
            "} {AccelRate " $ theBot.PawnClass.Default.AccelRate $
            "} {JumpZ " $ theBot.PawnClass.Default.JumpZ $
            "} {MultiJumpBoost " $ theBot.PawnClass.Default.MultiJumpBoost $
            "} {MaxFallSpeed " $ theBot.PawnClass.Default.MaxFallSpeed $
            //"} {DodgeSpeedFactor " $ theBot.PawnClass.Default.DodgeSpeedFactor $
            "} {DodgeSpeedZ " $ theBot.PawnClass.Default.DodgeSpeedZ $
            "} {AirControl " $ theBot.PawnClass.Default.AirControl $
            "}";

		SendLine(outstring);

		//Spawnig the pawn here
        if ( GetArgVal("Location")!="" ) {
			ParseVector(StartLocation,"Location");

            if ( GetArgVal("Rotation")!="" ) {
                ParseRot(StartRotation,"Rotation");
                BotDeathMatch(WorldInfo.Game).SpawnPawn(theBot,StartLocation,StartRotation);
            }
            else
                BotDeathMatch(WorldInfo.Game).SpawnPawn(theBot,StartLocation, );
        }
        else if ( GetArgVal("Rotation")!="" ){
            ParseRot(StartRotation,"Rotation");
            BotDeathMatch(WorldInfo.Game).SpawnPawn(theBot, ,StartRotation);
        }

		theBot.RemoteRestartPlayer();

        if (theBot.Pawn != none)
            theBot.GotoState('Alive', 'Begin');
        else
            theBot.GotoState('Dead', 'Begin');

        //gotoState('monitoring','Running');
    }
    else
		`LogError("Cannot add bot! Bot class is none!");
}

/**
 * Handles the CONF command.
 * @note Command: CONF
 * @note Answer: CONFCH
 * 
 * @note handled in GBClientClass
 */ 
function ReceivedConf()
{
    if (theBot == none){
		`LogWarn("No bot to configure; theBot == none");
        return;
    }

    ConfigureBot(theBot);

    SendNotifyConf(theBot);
}

/**
 * Change specified bot variables.
 * @note Command: CHATT
 * @note Answer:
 * 
 * @note Adrenaline is not available in UT3.
 */ 
function ReceivedChangeAtt(){
	local string health;

	health = GetArgVal("Health");
	
	if(health != "" && theBot.Pawn != none)
		theBot.Pawn.Health = int(health);
}

/**
 * Disconnects the bot.
 * @note Command: DISCONNECT
 * @note Answer:
 */ 
function ReceivedDisconnect(){
	GotoState('notifyServerClosed');
}

//===============================================================================
//= Movement and navigation
//===============================================================================

/**
 * Searches for the path to specified location
 *  and sends list of navigation points to the client.
 * 
 * @note Command: GETPATH
 * @note Answer: IPTH batch
 * 
 * @note Messages: IPTH, SPTH, EPTH
 * @note Attributes: RouteId, Location (IPTH)
 *          MessageId (SPTH)
 */ 
function ReceivedGetPath()
{
    local vector v;
    local string id, Target;
	local NavigationPoint N;
	local bool bFound;
    local int i;

    if ( theBot == None ){
		`LogWarn("Bot none");
        return;
    }

    
    //clear the old path
    for ( i = 0; i < theBot.RouteCache.Length; i++ ){
        if ( theBot.RouteCache[i] == None )
            break;
        else
            theBot.RouteCache[i] = None;
    }
	
	Target = GetArgVal("Target");

	//If Target is provided we use it and skip Location
	if(Target != ""){
		//Find NavigationPoint specified by Target
		bFound = false;
		foreach WorldInfo.AllNavigationPoints(class'NavigationPoint', N){
			if(string(N) == Target){
				bFound = true;
				break;
			}
		}

		if(bFound)
			theBot.FindPathToward(N);
	}
	else {
		//If Target is not provided use Location instead
		ParseVector(v,"Location");
		theBot.FindPathTo(v);
	}

    id = GetArgVal("Id");

	//Send path specification to the client
    SendLine("SPTH {MessageId " $ id $ "}");
    for ( i = 0; i < theBot.RouteCache.Length; i++ ){
        if ( theBot.RouteCache[i] == None )
            break;
        else
            SendLine("IPTH {RouteId " $ theBot.RouteCache[i] $ 
            	"} {Location " $ theBot.RouteCache[i].Location $
            	"}");
    }
    SendLine("EPTH");
}

/**
 * Handles CMOVE command. The bot moves forward 
 *  according to his current rotation until interrupted
 *  by other move command.
 *  
 * @note Command: CMOVE
 * @note Answer: None
 */ 
function ReceivedCMove()
{
    local rotator yawRotation;

    if (theBot == None || theBot.Pawn == None){
		`LogWarn("Bot or Pawn none");
        return;
    }

    //We need to reset focus, otherwise the focus would reset focal point to its own location
    theBot.Focus = None;

	//Set FocalPoint in front of the bot
    yawRotation.Yaw = theBot.Pawn.Rotation.Yaw;
    theBot.myFocalPoint = theBot.Pawn.Location + 500 * vector(yawRotation);
	//Order the bot to move forward
    theBot.GotoState('Alive','MoveContinuous');
}

/**
 * Jumps the bot's pawn on command
 * 
 * @note Command: JUMP
 * @note Answer: none
 * @note Attributes: DoubleJump, Delay, Force
 * 
 * @todo Delay
 */ 
function ReceivedJump()
{
    local string tmp;
    local bool bDouble;
	local float force, delay;

    if (theBot == None || theBot.Pawn == None){
        `LogWarn("Bot or Pawn none.");
    	return;
    }

    bDouble = false;
    tmp = GetArgVal("DoubleJump");
    if (tmp != "")
        bDouble = bool(tmp);

	force = 0;
	tmp = GetArgVal("Force");
	if(tmp != "")
		force = float(tmp);

	delay = 0;
	tmp = GetArgVal("Delay");
	if(tmp != "")
		delay = float(tmp);

    theBot.RemoteJump(bDouble, force, delay);
}

/**
 * Makes the bot dodge toward set direction.
 * @note Command: DODGE
 * @note Answer:
 * 
 * @todo check if it functions well!
 */ 
function ReceivedDodge(){
	local string tmp;
	local Vector direction, focusPoint;
	local bool wall, doubleDodge;
	
	if(theBot == none || theBot.Pawn == none){
		`LogInfo("Bot or Pawn none.");
		return;
	}

	if (GetArgVal("Direction") != "")
		ParseVector(direction,"Direction");
	if (GetArgVal("FocusPoint") != "")
		ParseVector(focusPoint, "FocusPoint");
	tmp = GetArgVal("Wall");
	if (tmp != "")
		wall = (tmp ~= "True") ? true : false;
	tmp = GetArgVal("Double");
	if (tmp != "")
		doubleDodge = (tmp ~= "True") ? true : false;

	direction = Normal(Vector(theBot.Pawn.Rotation) + direction);

	GBPawn(theBot.Pawn).CustomDodge(direction, focusPoint);
}

/**
 * Moves the bot towards specified Location
 * 
 * @note Command: MOVE
 * @note Answer: 
 * 
 * @note Focus on location is done by creating a helper actor
 *  and setting the focus on it. That is neccesarity because
 *  the bot cannot focus on location.
 *  
 * @todo evacuate code that is identical in ReceivedTurnTo function
 *  into standalone method.
 */ 
function ReceivedMove()
{
    local vector v,v2,focusLoc;
    local string focusId;
    local Actor tmpFocus, A;
    local Controller C;
    local NavigationPoint N;

    if (theBot == None || theBot.Pawn == None){
		`LogWarn("Bot or Pawn none.");
        return;
    }

    //if first location not specified, we wont move
    if (GetArgVal("FirstLocation") == ""){
		`LogInfo("FirstLocation not specified.");
        return;
    }

    ParseVector(v,"FirstLocation");
    focusId = GetArgVal("FocusTarget");

    //set the destinations we want to move to
    theBot.myDestination = v;
    theBot.Destination = v;

	//get second destination
    if (GetArgVal("SecondLocation")!="") {
            ParseVector(v2,"SecondLocation");
            theBot.pendingDestination = v2;
    } else {
            theBot.pendingDestination = v;
    }

    if(focusId == "") {
        if (GetArgVal("FocusLocation")!="") {
            ParseVector(focusLoc,"FocusLocation");
            //Set correct location to helper actor
			FocusActor.SetLocation(focusLoc);
			//set the bot focus to our helper actor
            theBot.Focus = FocusActor;
            //theBot.myFocus = FocusActor;
            //Set FocalPoint accordingly (it would change to desired values anyway)
            theBot.myFocalPoint = FocusActor.Location;
            theBot.FocalPoint = theBot.myFocalPoint;
        } else {
            //we reset old focus, if none focus set, the bot will turn towards destination
            theBot.Focus = none;
            //@todo: reset also target?

            //set myFocalPoint to prevent unwanted turning back at the end of movement
            //myFocalPoint will be set at the end of movement
            if (GetArgVal("SecondLocation") != "")
                theBot.myFocalPoint = v2 + 500 * vector(rotator(v2 - v));
            else
                theBot.myFocalPoint = v + 500 * vector(rotator(v - theBot.Pawn.Location));
        }
    } else { 
    	//We have Id of the object we want to face
        //First we determine if it is a bot id
        tmpFocus = None;
		foreach WorldInfo.AllControllers(class'Controller', C) {
            if( class'GBUtil'.static.GetUniqueId(C) == focusId) {
                if( C.Pawn != none && theBot.Pawn.LineOfSightTo(C.Pawn)) {
                    tmpFocus = C.Pawn;
                    break;
                }
            }
        }
        //we found it is a bot id, lets set it as our focus
        if (tmpFocus != none) {
            //point the bot at the location of the target
            theBot.FocalPoint = tmpFocus.Location;
            theBot.myFocalPoint = tmpFocus.Location;
            theBot.Focus = tmpFocus;
        } else { // it was not a bot id - try navigation points
            foreach WorldInfo.AllNavigationPoints(class'NavigationPoint', N){
                if( class'GBUtil'.static.GetUniqueId(N) == focusId) {
                    if(theBot.Pawn.LineOfSightTo(N)) {
                        tmpFocus = N;
                        break;
                    }
                }               
            }       
            //can be navpoint or some of the items have unique id                   
            //if succes, then set this object as our focus object
			//!changed tempActor to tempFocus!
            if (tmpFocus != none) {
                theBot.Focus = tmpFocus;
                theBot.myFocalPoint = tmpFocus.Location;
                theBot.FocalPoint = tmpFocus.Location;
            }
			else {
				//it is neither a Controller id nor a NavPoint id
				//lets try all actors
				foreach WorldInfo.AllActors(class'Actor', A){
					if( class'GBUtil'.static.GetUniqueId(A) == focusId) {
						if(theBot.Pawn.LineOfSightTo(A)) {
							tmpFocus = A;
							break;
						}
					}
				}
				//we have found an actor with matching id
				if (tmpFocus != none) {
					theBot.Focus = tmpFocus;
					theBot.myFocalPoint = tmpFocus.Location;
					theBot.FocalPoint = tmpFocus.Location;
				}
			}
        }
    }
	//Start the movement
    theBot.GotoState('Alive','Move');
}

/**
 * Turns bot toward specified location or actor
 * 
 * @note Command: TURNTO
 * @note Answer: None
 * 
 * @todo refactor this method so the setting of the actual
 *  variable of RemoteBots is handled in RemoteBot.
 * @todo evacuate code that is identical in ReceivedMove function
 *  into standalone method.
 */ 
function ReceivedTurnTo()
{
    local Controller C;
    local NavigationPoint N;
    local vector v;
    local rotator r;
    local string target;

    if (theBot == none || theBot.Pawn == None)
        return;

    target = GetArgVal("Target");
    if(target == "") {
        ParseRot(r,"Rotation");
        if(r.Yaw == 0 && r.Pitch == 0 && r.Roll == 0) {
            //neither target nor rotation is defined
            ParseVector(v,"Location");
            theBot.FocalPoint = v;
            theBot.myFocalPoint = v;
            //We erase possible focus actors
            theBot.Focus = None;

            if (theBot.movingContinuous)
                theBot.GotoState('Alive','MoveContinuous');
        } else {
            //Rotation is defined but target is not
            theBot.myFocalPoint = theBot.Pawn.Location + ( vector(r) * 500);
            theBot.FocalPoint = theBot.myFocalPoint;

            //We erase possible focus actors
            theBot.Focus = None;

            if (theBot.movingContinuous)
                theBot.GotoState('Alive','MoveContinuous');
        }
    } 
    else {
        //target defined
        //First we try to find if we should focus to a player or bot
        foreach WorldInfo.AllControllers(class'Controller', C) {
            if( target == class'GBUtil'.static.GetUniqueId(C) ) {
                break;
            }
        }//end for

        if (C != None) {
            //Pawn must exists and must be visible
            if ((C.Pawn != None) && theBot.Pawn.LineOfSightTo(C.Pawn)) {
                //We set the Controller as our target
                theBot.FocalPoint = C.Pawn.Location;
                theBot.myFocalPoint = C.Pawn.Location;
                theBot.Focus = C.Pawn;

                if (theBot.movingContinuous)
                    theBot.GotoState('Alive','MoveContinuous');

            } else {
				if (C.Pawn == none) 
					`LogInfo("Pawn is none. Controller:" @ C);
                return;
            }
        } else {
            tempActor = none;
            //try navigation points
            foreach WorldInfo.AllNavigationPoints(class'NavigationPoint', N){
                if( class'GBUtil'.static.GetUniqueId(N) == target) {
                    if(theBot.Pawn.LineOfSightTo(N)) {
                        tempActor = N;
                        break;
                    }
                }               
            }       
            
            //Actor must be visible
            if ((tempActor != None) && theBot.Pawn.LineOfSightTo(tempActor)) {
                theBot.Focus = tempActor;
                theBot.myFocalPoint = tempActor.Location;
                theBot.FocalPoint = theBot.myFocalPoint;

                if (theBot.movingContinuous)
                    theBot.GotoState('Alive','MoveContinuous');
            } else {
                return;
            }
        }
    }
}

/**
 * Rotates the bot given amount
 * 
 * @note Command: Rotate
 * @note Answer: None
 */ 
function ReceivedRotate()
{
    local string target;
    local rotator r;
    local int i;

    if (theBot.Pawn == None)
        return;

    target = GetArgVal("Axis");
    r = theBot.Pawn.GetViewRotation();
    i = int(GetArgVal("Amount"));
    if(target == "Vertical") {              
        r.Pitch += i;           
    } else {                
        r.Yaw += i;
    }

    theBot.myFocalPoint = theBot.Pawn.Location + ( vector(r) * 500);
    theBot.FocalPoint = theBot.myFocalPoint;
    theBot.Focus = None; //theBot.Pawn.Location + ( vector(r) * 1000);

    if (theBot.movingContinuous)
        theBot.GotoState('Alive','MoveContinuous');

    //We comment this so turning commands do not interupt moving commands.
    //theBot.StopWaiting();
    //theBot.GotoState('Startup', 'Turning');
}

/**
 * Makes the bot crouch or stand
 * 
 * @note Command: SETCROUCH
 * @note Answer: None
 */ 
function ReceivedSetCrouch()
{
    local string target;

    if (theBot == None || theBot.Pawn == None)
        return;

    target = GetArgVal("Crouch");
    
    theBot.Pawn.ShouldCrouch( bool(target) );
}

/**
 * Makes the bot walk or run
 * 
 * @note Command: SETWALK
 * @note Answer: None
 * 
 * @todo WalkAnim, RuAnim look how this is done
 *      check if it should be suported in UT3.
 */ 
function ReceivedSetWalk()
{
    local string target;

    if (theBot == None || theBot.Pawn == None)
        return;

    target = GetArgVal("Walk");
    
    theBot.Pawn.bIsWalking = bool(target);
}

/**
 * Stops bot movement
 * 
 * @note Command: STOP
 * @note Answer: None
 */ 
function ReceivedStop()
{
    if (theBot == None || theBot.Pawn == None)
        return;

    theBot.GotoState('Alive', 'DoStop');
}

/**
 * Draws line between specified locations
 * 
 * @note Command: SETROUTE
 * @note Answer: None
 * 
 * @todo check this implementation in HUD implementation context
 */ 
function ReceivedSetRoute()
{
    local vector v;
    local int i;

    if (theBot == None)
        return;

	//Erases actual visible route
    if (bool(GetArgVal("Erase"))) {
        for (i=0;i<32;i++) {
            theBot.myRepInfo.SetCustomRoute(vect(0,0,0),i);
        }
    }

	//Stes new route
    for (i=0;i<32;i++) {
        ParseVector(v ,"Point"$i );
        theBot.myRepInfo.SetCustomRoute(v,i);
    }
}

/**
 * Informs the client of reachability of specified 
 *  actor or location.
 *  
 * @note Command: CHECKREACH
 * @note Answer: RCH
 */ 
function ReceivedCheckReach(){
	local string id, target, outString;
	local Vector loc;
	local bool bReachable;
	local Actor tmp;

	id = GetArgVal("Id");
	target = GetArgVal("Target");
	ParseVector(loc, "Location");

	if (target != ""){
		foreach AllActors(class'Actor', tmp){
			if (string(tmp) ~= target){
				bReachable = theBot.ActorReachable(tmp);
				break;
			}
		}
	}
	else {
		bReachable = theBot.PointReachable(loc);
	}

	outString = "RCH {Id" @ id $
		"} {Reachable" @ class'GBUtil'.static.GetBoolString(bReachable) $
		"} {From" @ theBot.Location $
		"}";

	SendLine(outString);
}

//===============================================================================
//= Shooting
//===============================================================================

/**
 * Handles Shoot command
 * 
 * @note Command: Shoot
 *
 */ 
function ReceivedShoot()
{
    local rotator r;
    local string Target;
    local Controller C;
	local Projectile Proj;
    local vector v;
    local bool targetLocked;

    if (theBot == None || theBot.Pawn == None)
        return;

    targetLocked = false;
    theBot.bTargetLocationLocked = false;
	//we look for target in AllActors and set it as our target
    Target = GetArgVal("Target");
    if( Target != "") {
    	//is it a projectile?
    	if (InStr(Target, "UTProj")!=-1) {
    		foreach DynamicActors(class'Projectile',Proj) {
    		   if (Target == class'GBUtil'.static.getUniqueId(Proj)) {
                   if (theBot.LineOfSightTo(Proj)) {
                        theBot.Focus = Proj;
						theBot.myRepInfo.myFocus = Proj.Location;
        				theBot.Enemy = None;
        				theBot.RemoteEnemy = None;
        				theBot.Target = Proj;

        				theBot.FocalPoint = Proj.Location;
        				theBot.myFocalPoint = Proj.Location;
        				targetLocked = true;
                   }
      		       break;
    		   }
            }
		}
		else
		{
			foreach WorldInfo.AllControllers(class'Controller', C) {
			//We wont start shooting at non visible targets
				if( (class'GBUtil'.static.GetUniqueId(C) == target) &&
					(C.Pawn != None) &&
					(theBot.LineOfSightTo(C.Pawn))
				)
				{
					//We will set desired bot as our enemy
					theBot.Focus = C.Pawn;
					theBot.Enemy = C.Pawn;
					theBot.RemoteEnemy = C;

					theBot.myFocalPoint = C.Pawn.Location;
					theBot.FocalPoint = C.Pawn.Location;                                                  
					targetLocked = true;
					break;
				}
			}
		}
    }

	//If Target is not specified we try Location argument
    if (!targetLocked && GetArgVal("Location") != ""){
        ParseVector(v,"Location");

        theBot.myTarget.SetLocation(v);
        theBot.bTargetLocationLocked = true;

        //We are shooting at a location. We will set the FocalPoint
        theBot.FocalPoint = theBot.myTarget.Location;
        theBot.myFocalPoint = theBot.myTarget.Location;

        theBot.Focus = theBot.myTarget;
        theBot.Enemy = None;
    }

    theBot.RemoteFireWeapon(bool(GetArgVal("Alt")));
}

/**
 * Handles STOPSHOOT command
 * 
 * @note Command: STOPSHOOT
 */ 
function ReceivedStopShoot()
{
        if (theBot == None)
                return;

        theBot.shouldFire = 0;
        theBot.StopFiring();
}

//===============================================================================
//= Inventory
//===============================================================================

/**
 * Changes bots weapon.
 * @note Command: CHANGEWEAPON
 * @note Answer:
 * @note id can be set to best. In that case we select best weapon.
 */ 
function ReceivedChangeWeapon(){
	local string weapId;
	local Inventory currInv;
	local UTWeapon targetWeapon;
	
	weapId = GetArgVal("Id");	
	
	if (weapId ~= "best"){
		theBot.StopFiring();
		theBot.SwitchToBestWeapon();
	}
	else{
		for (currInv = theBot.Pawn.InvManager.InventoryChain; currInv != none; currInv = currInv.Inventory){
			if (string(currInv) == weapId && currInv.IsA('UTWeapon')){
				targetWeapon = UTWeapon(currInv);
				break;
			}
		}
		if (targetWeapon == none){
			`LogInfo("Invalid weapon id:" @ weapId);
		}
		else {
			theBot.StopFiring();
			`LogDebug("Set current weapon: " $ targetWeapon);
			theBot.Pawn.InvManager.SetCurrentWeapon(targetWeapon);
		}
	}
}

/**
 * Handles AddInventory command.
 * @note Command: ADDINV
 * @note Answer:
 * 
 * @todo add check if the cheats are allowed
 * @todo so far it exports ITC only for weapons
 */ 
function ReceivedAddInventory(){
	local string targetClass, type, ITC;
	local class<Inventory> inv;
	local bool bAlreadyExported;
	local ExportedITC ex;
	local Inventory createdInv;

	if (theBot == none || theBot.Pawn == none){
		`LogWarn("Bot or Pawn is none");
		return;
	}

	type = GetArgVal("Type");
	
	targetClass = GetInventoryClass(type);

	inv = class<Inventory>(DynamicLoadObject(targetClass, class'Class'));
	
	bAlreadyExported = false;

	foreach exportedITCs(ex){       //Check if we have already exported this
		if(ex.INV == inv)
			bAlreadyExported = true;
	}

	if (inv != none){
		createdInv = theBot.Pawn.InvManager.CreateInventory(inv,false);
		if (createdInv.IsA('UTWeapon') && !bAlreadyExported){
			ITC = "ITC {InventoryType " $ class'GBUtil'.static.GetInventoryTypeFromWeapon(class<UTWeapon>(createdInv.Class)) $
			"} {PickupType " $ class'GBUtil'.static.GetPickupTypeFromInventory(createdInv) $
			"} {ItemCategory Weapon}" @
			GetWeaponITCDetails(class<UTWeapon>(createdInv.Class));
			SendLine(ITC);
		}
	}
	else `LogWarn("Bad class name. Type =" @ type);
	

	//if (
}

/**
 * Recostructs an Inventory class name from pickupType
 */ 
function string GetInventoryClass(string pickupType){
	local string strRet;
	local array<string> parts;

	ParseStringIntoArray(pickupType, parts, ".", true);
	
	if (parts[1] == "WeaponPickup"){
		strRet = "UTWeap_" $ parts[0];
		if (parts[0] == "BioRifle" || parts[0] == "Avril")
			strRet $= "_Content";
	}/*
	else if (parts[1] == "AmmoPickup"){
		strRet = "UTAmmo_" $ parts[0];
	}
	else if (parts[1] == "ArmorPickup"){
		strRet = "UTArmorPickup_" $ parts[0];
	}
	else if (parts[1] == "HealthPickup"){
		strRet = "UT
	}*/
	else strRet = "UT" $ parts[0];

	return strRet;
}

/**
 * The bot is commanded to throw his weapon.
 * @note Command: THROW
 * @note Answer: THROWN
 */ 
function ReceivedThrow(){
	local string outString;

	if (theBot.Pawn.CanThrowWeapon()){
		outString = "THROWN {Id" @ class'GBUtil'.static.GetUniqueId(theBot.Pawn.Weapon) $ "}";
		theBot.Pawn.ThrowActiveWeapon();
		theBot.Pawn.InvManager.SwitchToBestWeapon(false);
		SendLine(outString);
	}
	else {
		`LogInfo("Cannot throw a weapon.");
	}
}

/**
 * Picks up touching item.
 * 
 * @note Command: PICK
 * @note Answer:
 */ 
function ReceivedPick(){
	local string target;

	if (theBot == none)
		return;

	target = GetArgVal("Id");
	if (target != "")
		theBot.RemotePickup(target);
}

//===============================================================================
//= Vehicles
//===============================================================================

/**
 * Enters specified vehicle.
 * 
 * @note Command: ENTER
 * @note Answer: ENTERED, LOCKED
 * 
 * @note if the bot is too far away, no answer is sent.
 */ 
function ReceivedEnter(){
	local Vehicle vh;
	local string vehicleId, outString;

	vehicleId = GetArgVal("Id");

	foreach AllActors(class'Vehicle', vh){
		if (string(vh) == vehicleId)
			break;
	}

	if(vh.TryToDrive(theBot.Pawn)){
		outString = "ENTERED {Id" @ class'GBUtil'.static.GetUniqueId(vh) $
			"} {Type" @ vh.Class $
			"} {Location" @ vh.Location $
			"}";
	}
	else if (VSize(theBot.Pawn.Location - vh.Location) > 50.0){
		outString = "";
	}
	else{
		outString = "Locked {Id" @ class'GBUtil'.static.GetUniqueId(vh) $
			"} {Type" @ vh.Class $
			"} {Location" @ vh.Location $
			"}";
	}

	if (outString != "")
		SendLine(outString);
}

/**
 * Exits our current vehicle.
 * 
 * @note Command: LEAVE
 * @note Answer:
 */ 
function ReceivedLeave(){
	if (theBot.Pawn.IsA('Vehicle'))
		Vehicle(theBot.Pawn).DriverLeave(true);
}

/**
 * Turns toward target and runs straight to it.
 * 
 * @note Command: DRIVETO
 * @note Answer:
 */ 
function DriveTo(){
	local string target;
	local Actor targetActor;

	if(theBot != none || theBot.Pawn != none){
		target = GetArgVal("Target");

		foreach AllActors(class'Actor', targetActor){
			if (string(targetActor) == target)
				break;
		}
		
		theBot.MoveTarget = targetActor;
		theBot.GotoState('Alive','MoveToActor');
	}
}
//===============================================================================
//= Traceing
//===============================================================================

/**
 * Adds custom ray to the TraceManager;
 * 
 * @note Command: ADDRAY
 * @note Answer:
 * 
 * @note sending Default as id resets the TraceManager to default
 *      values:
 *           StraightAhead - (1,0,0), length 250
 *	         45toLeft - (1,-1,0), length 200
 *           45toRight - (1,1,0), length 200
 */ 
function ReceivedAddRay(){
	local string id;
	local bool fastTrace, floorCorrection, traceActors;
	local int length;
	local Vector direction;

	id = GetArgVal("Id");
	length = int(GetArgVal("Length"));
	fastTrace = bool(GetArgVal("FastTrace"));
	floorCorrection = bool(GetArgVal("FloorCorrection"));
	traceActors = bool(GetArgVal("TraceActors"));
	ParseVector(direction,"Direction");

	`LogDebug("Ray: id=" $ id @ "length=" $ length @ "fastTarce=" $ fastTrace
		@ "floorCorrection=" $ floorCorrection @ "traceActors=" $ traceActors
		@ "direction=" $ direction);

	if (theBot != none && theBot.traceManager != none){
		if (id == "Default"){
			theBot.traceManager.resetRays();
		}
		else {
			theBot.traceManager.addRay(id,direction,length,fastTrace,floorCorrection,traceActors);
		}
	}
	else if (theBot != none && theBot.traceManager == none){
		`LogError("TraceManager = none");
	}
	else `LogError("Bot = none");
}

/**
 * Removes specified ray from TraceManager
 * 
 * @note Command: REMOVERAY
 * @note Answer:
 */ 
function ReceivedRemoveRay(){
	local string id;

	id = GetArgVal("Id");

	if (theBot != none && theBot.traceManager != none){
		theBot.traceManager.removeRay(id);
	}
	else if (theBot != none && theBot.traceManager == none){
		`LogError("TraceManager = none");
	}
}

/**
 * Sends info about collisions along defined line. Faster than TRACE but
 *   caries less information.
 * 
 * @note Command: FTRACE
 * @note Answer: FTR
 */ 
function ReceivedFTrace(){
	local string id, outString;
	local Vector from, to;
	local bool res;

	id = GetArgVal("Id");
	ParseVector(from, "From");
	ParseVector(to, "To");

	if (theBot != none){
		res = FastTrace(to, from);
		outString = "FTR {Id" @ id $
			"} {From" @ from $ 
			"} {To" @ to $
			"} {Result" @ class'GBUtil'.static.GetBoolString(res) $
			"}";
		SendLine(outString);
	}
}

/**
 * Sends info about collisions along defined line. 
 * 
 * @note Command: TRACE
 * @note Answer: TRC
 */ 
function ReceivedTrace(){
	local string id, outString;
	local bool bTraceActors;
	local Vector from, to, hitLoc, hitNorm;
	local Actor resActor;

	id = GetArgVal("Id");
	bTraceActors = bool(GetArgVal("TraceActors"));
	ParseVector(from, "From");
	ParseVector(to, "To");

	if (theBot != none){
		resActor = Trace(hitLoc, hitNorm, to, from,bTraceActors);
		outString = "TRC {Id" @ id $
			"} {From" @ from $ 
			"} {To" @ to $
			"} {Result" @ class'GBUtil'.static.GetBoolString(resActor != none) $
			"} {HitNormal" @ hitNorm $
			"} {HitLocation" @ hitLoc $
			"} {HitID" @ class'GBUtil'.static.GetUniqueId(resActor) $
			"} {TraceActors" @ class'GBUtil'.static.GetBoolString(bTraceActors) $
			"}";
		SendLine(outString);
	}
}

//===============================================================================
//= Other
//===============================================================================

/**
 * Exports game score as synchronous batch.
 * 
 * @note Messages: PLS, TES
 */ 
function ExportGameStatus(){
	BotDeathMatch(WorldInfo.Game).SendGameStatus(self);
}

/**
 * Handles sending messages.
 * 
 * @note Command: MESSAGE
 * @note Answer:
 */ 
function ReceivedMessage()
{
    local string target, text;
    local bool boolResult;
    local float FadeOut;

    if (theBot == None ){
		`logWarn("theBot is none! Cannot send message.");
        return;
    }

    //Note - currently only allow messages under 256 chars
    target = GetArgVal("Id");
    text = GetArgVal("Text");
    boolResult = bool(GetArgVal("Global"));
    FadeOut = float(GetArgVal("FadeOut"));
    if(text != "")
		theBot.RemoteBroadcast(target,text,boolResult,FadeOut);
}

/**
 * Respawns our pawn.
 * 
 * @note Command: RESPAWN
 * @note Answer:
 */ 
function ReceivedRespawn() {
    local Vector v;
    local Rotator r;
    local bool hasVector, hasRotator;

    if (theBot != none ) {
        if (GetArgVal("StartLocation") != "") {
            ParseVector(v,"FirstLocation");
            hasVector = true;
        }
        if (GetArgVal("StartRotation") != "") {
            ParseRot(r, "StartRotation");
            hasRotator = true;
        }

        if (hasVector && hasRotator) {
            theBot.RespawnPlayer(v,r);
        } else if (hasVector) {
            theBot.RespawnPlayer(v);
        } else {
            theBot.RespawnPlayer();
        }
    }
}
/**
 * @todo check if this function is not obsolate 
 *  due to new handshake handling
 */ 
function ReceivedReady()
{
        ExportStatus();
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
 * Stops demo recording.
 * 
 * @note Command: STOPREC
 * @note Answer: RECEND
 */ 
function ReceivedStopRec()
{
    ConsoleCommand("stopdemo", True);
    SendLine("RECEND");
}


//----------------- STATES

auto state handshake
{
	function SendHello()
	{
		SendLine("HELLO_BOT");
	}

SendNFO:
	SendNFO();
	GotoState('waitingForINIT');
}

state waitingForINIT
{
	function ProcessAction(string cmdType)
	{
		switch(cmdType){
			case "INIT":
				GotoState('waitingForINIT','RecINIT');
			break;
        }
	}
Begin:
	Sleep(1.0);
	goto('Begin');
RecInit:
	InitBot();
	GotoState('running','Running');
}

state running
{
Running:
	if (bSynchronousMessagesOff)
        goto 'SynchronousOff';
    if((theBot != none) && !theBot.IsInState('Dead') && !theBot.IsInState('GameEnded') )
    {
        //This is where synchronous batch messages are sent
        SendLine("BEG {Time " $ WorldInfo.TimeSeconds $"}");

        //`log("Measuring Time of synchronous batch: ");
        //StopWatch(false);

		ExportGameStatus();
        theBot.checkSelf();
        theBot.checkVision();
		theBot.traceManager.getTraceInfo();
        //StopWatch(true);
        SendLine("END {Time " $ WorldInfo.TimeSeconds $"}");

    }
    //theBot.bDebug = true;
    if (theBot != none && theBot.bDebug && !theBot.IsInState('Alive'))
            `log(theBot.getStateName());
    sleep(visionTime);
    //goto 'Running';
	//goto 'End';

	//theBot.checkVision();

	

	//`LogInfo("PeripheralVision: " $ theBot.Pawn.PeripheralVision);

/*
	foreach WorldInfo.AllActors(class'Projectile', P){
		`LogInfo(P);
		if(P.Instigator != none && P.Instigator.Controller != none)
			`LogInfo("Instigator ShotTarget: " $ P.Instigator.Controller.ShotTarget);
		else `LogInfo("Projectile Instigator or Controller none");
	}
*/

	//theBot.traceManager.getTraceInfo();
	//sleep(0.3);
	goto 'Running';
	//goto 'End';
SynchronousOff:
    if (!bSynchronousMessagesOff)
        goto 'Running';
    sleep(1);
    goto 'SynchronousOff';

End:
	SendLine("BEG {Time " $ WorldInfo.TimeSeconds $"}");
    SendLine("END {Time " $ WorldInfo.TimeSeconds $"}");
}

defaultproperties
{
	bDebug=true
}