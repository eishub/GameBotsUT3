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
// RemoteBot.
// Based on Bot class
//=============================================================================
class RemoteBot extends UTBot
        config(GameBotsUT3);
`include(Globals.uci);
`define debug;

//var config bool bDebug;

//maybe link to bot's periphreal vision? UT bots need much less of an arc though
//like Pawn's PeriphrealVision, this value should be the cosine of the limits
//of visual field. (i.e. 0.707 = 45 degrees to each side, or a 90* arc.)
var config float remoteVisionLimit;

var int visionRadius;

//The socket to the agent
var BotConnection myConnection;

//The three remote vars compliment the my vars right below. The only one
//that ever needs to be duplicated is RemoteEnemy and myTarget
//just need RemoteDestination || myDestination and RFocus || myFocus

//Who the remote bot is trying to shoot at. Used by the aiming code.
var Actor RemoteEnemy;

//The spot the bot is shooting at
var FocusActor myTarget;
//DamageType of last hit - used in death notifications
var class<DamageType> lastDamageType;

//If false, we will update myTarget location according our current focal point
var bool bTargetLocationLocked;

//The spot the bot is moving to
var vector myDestination;
//The spot the bot is looking at
var vector myFocalPoint;

//Used for smooth movement, see StartUp state
var vector pendingDestination;

var class<UTPawn> PawnClass;

//This is an indicator that we are in StartUp:MoveContinuous state. We need this, so turn
//command work properly when the bot is moving continuous!
var bool movingContinuous;

//If true bot will respawn automatically when killed
var config bool bAutoSpawn;

//When true auto raytracing producing sync. ATR messsages will be on
var config bool bAutoTrace;

//If true we will draw trace lines (results of AutoTrace() functionsin BotConnection)
//in the game
var config bool bDrawTraceLines;

//If we should spawn an actor at the point the bot has set as focal point
var config bool bShowFocalPoint;

//If we should provide aim correct based on bot Skill also when shooting at Location
var config bool bPerfectLocationAim;

//If we should include FadeOut attribute into message text or not. for debug.
var config bool bIncludeFadeOutInMsg;

//maximum number we can multiply BaseSpeed of the bot
var config float MaxSpeed;

//Used for changing the bot appearance. see GBxPawn.Setup() function
var config string DesiredSkin;

//TODO: Probably not used anymore - delete
var bool bSecondJumpPossible;

//For disabling auto pickup, custom varialbe, will affect Pawn.bCanPickupInventory
var config bool bDisableAutoPickup;

//By this default pawn speed will be multiplied ranges from 0.1 to 2
var config float SpeedMultiplier;

//helper variable to store the direction we want to go with CMOVE
var vector cmoveDirection;

//this is here, so we can properly debug the bot in java. it is the adress we need
//to connect to in order to debug the bot (in Pogamut the bots are now run each one in
//different JVM)
var string jmx;

//holding last bump time to avoid sending the message repeatably
var float lastBumpTime;

//holding last wall hit to avoid sending the message repeatably
var float lastWallHit;

//1 - normal fire, 2 - alt fire, 0 - should not fire
var byte shouldFire;

var GBReplicationInfo myRepInfo;

//Used to set DoubleJump with custom force
var bool bPendingCustomJump;

//Handles autotraceing
var GBTraceManager traceManager;

//For correct export of default inventory
var bool bAddingDefaultInventory;

// array holding all the navigation points laying in a deployed volume
var array<NavigationPoint> navPointsInVolume;

//override - using translocator in this function
function Actor FaceActor(float StrafingModifier)
{
        return none;
}

//Called at the start of the match
function StartMatch()
{
        // SENDMESSAGE
        // !!! possible new message
}


//This function will properly destroy the pawn of this conroller (otherwise conflicts with game mechanics)
/**
 * Handles proper pawn destruction
 * @todo isnt this the cause of pawn destroyed crash?
 *      Solved for this moment. (13.4.2011)
 */ 
function DestroyPawn()
{
    if (Pawn == None)
            return;

    Pawn.Died(none, class'DamageType', Pawn.Location);
}

/**
 * Handles execution of RESPAWN command
 * 
 * @param startLocation location of new pawn
 * @param startRotation rotator of new pawn
 */ 
function RespawnPlayer(optional vector startLocation, optional rotator startRotation)
{
	local vector momentum;
	momentum.x = 0;
	momentum.y = 0;

    if (IsInState('Dead') && !bAutoSpawn) 
    {
        RemoteRestartPlayer(startLocation,startRotation);
    }
    else if (bAutoSpawn)
    {
        bAutoSpawn = false; //otherwise it would get respawned in Dead state without specifyed location, rotation
        DestroyPawn();
        GotoState('Dead');		
        NotifyDied(none, Pawn.Location, 0, class'DamageType', momentum);    // @note: needed because there is no proper bot-died handling
        RemoteRestartPlayer(startLocation,startRotation);
        bAutoSpawn = true;
    }
    else  if (!IsInState('Dead') && !bAutoSpawn)
    {
        DestroyPawn();
        GotoState('Dead');
		NotifyDied(none, Pawn.Location, 0, class'DamageType', momentum);    // @note: needed because there is no proper bot-died handling
        RemoteRestartPlayer(startLocation,startRotation);
    }
}

/**
 * Handles respawning of agent's pawn
 * 
 * @param startLocation location of new pawn
 * @param startRotation rotator of new pawn
 */ 
function RemoteRestartPlayer(optional vector startLocation, optional rotator startRotation) {	
    if( WorldInfo.Game.isA('BotDeathMatch')) {
        BotDeathMatch(WorldInfo.Game).RemoteRestartPlayer(self, startLocation, startRotation );
    }		
}

/**
 * Informs the client of team change event.
 * 
 * @note Messages: TEAMCHANGE
 * @note Attributes: Success, DesiredTeam
 */ 
function NotifyTeamChange(bool success, int teamId){
	local string outString;

	outString = "TEAMCHANGE" @ 
		"} {Success" $ class'GBUtil'.static.GetBoolString(success) $ 
		"} {DesiredTeam " $ teamId $
		"}" ;

	myConnection.SendLine(outString);
}

//===============================================================================
//= Shooting and damage
//===============================================================================

/**
 * Informs client of damage taken by the bot.
 * 
 * @note Messages: DAM
 * @note Attributes: Damage, Instigator
 * 
 * @note Instigator sent only when filled by engine and is in FOV of bot.
 * 
 * @param InstigatedBy Controller that hit the bot.
 * @param HitLocation
 * @param Damage Amount of damage taken.
 * @param damageType Type of damage.
 * @param Momentum 
 */ 
function NotifyTakeHit(Controller InstigatedBy, vector HitLocation, int Damage, class<DamageType> damageType, vector Momentum)
{
    local string outstring;

    LastUnderFire = WorldInfo.TimeSeconds;

    outstring = "DAM {Damage " $ Damage $ "}";

	outstring @= GetDamageTypeInfo(damageType, false);

    if (InstigatedBy != none && inFOV(InstigatedBy.Location)) {
        outstring @= "{Instigator " $ class'GBUtil'.static.GetUniqueId(InstigatedBy) $ "}";
    }

	lastDamageType = damageType;
    myConnection.SendLine(outstring);

	//if the pawn died notify client
	//Pawn is already unpossessed if it died!
	if (Pawn == none || Pawn.Health <= 0){
		NotifyDied(InstigatedBy, HitLocation, Damage, DamageType, Momentum);
	}

    //if ( (instigatedBy != None) && (instigatedBy != self) )
    //      damageAttitudeTo(instigatedBy, Damage);
}

/**
 * Handles sending DIE message to the cilent when pawn dies.
 * @note Messages: DIE
 * @note Attributes: Killer
 * 
 * @note sends the DIE message after the last DAM message.
 *  if it was handled in notifyKilled, the DIE was sent
 *  before the last DAM.
 * 
 * @param InstigatedBy Controller that hit the bot.
 * @param HitLocation
 * @param Damage Amount of damage taken.
 * @param damageType Type of damage.
 * @param Momentum 
 */ 
function NotifyDied(Controller InstigatedBy, vector HitLocation, int Damage, class<DamageType> damageType, vector Momentum)
{
	local string outstring, killerName, killedName;

	outstring = "DIE";
	outstring @= GetDamageTypeInfo(damageType, true);

	if (InstigatedBy != none)
        outstring $= " {Killer " $ class'GBUtil'.static.getUniqueId(InstigatedBy) $ "}";

	//DeathMessage string
	//outstring @= "{DeathString " $ damageType.static.DeathMessage(InstigatedBy.PlayerReplicationInfo,PlayerReplicationInfo) $ "}";
	killerName = InstigatedBy.PlayerReplicationInfo.PlayerName;
	killedName = PlayerReplicationInfo.PlayerName;
    outstring @= "{DeathString " $ WorldInfo.Game.ParseKillMessage(killerName, killedName, damageType.default.DeathString) $ "}";
	//outstring @= "{DeathString }";
	myConnection.SendLine(outstring);
}

/**
 * Handles sending info about bot death to the client
 * 
 * @note Masseges: DIE, KIL
 * @note Attributes: Id, KiledPawn (KIL), Killer (both), DeathString
 * 
 * @param Killer
 * @param Killed
 * @param KilledPawn
 */ 
function NotifyKilled(Controller Killer, Controller Killed, pawn KilledPawn)
{       
    local string outstring, killerName, killedName;
    
    if (Killed == self) {
		`LogInfo("Killed = self; not sending DIE!");
		return;
        /*outstring = "DIE";
		outstring @= GetDamageTypeInfo(lastDamageType,true);*/
    } else {
        outstring = "KIL {Id " $ class'GBUtil'.static.getUniqueId(Killed) $
        	"} {KilledPawn " $ KilledPawn $
        	"}";
		if (Killed.IsA('RemoteBot')){
		outstring @= GetDamageTypeInfo(RemoteBot(Killed).lastDamageType,true);
		}
    }

    if (Killer != none) 
        outstring $= " {Killer " $ class'GBUtil'.static.getUniqueId(Killer) $ "}";

	//DeathMessage string
	//outstring @= "{DeathString " $ RemoteBot(Killed).lastDamageType.static.DeathMessage(Killer.PlayerReplicationInfo,Killed.PlayerReplicationInfo) $ "}";
	killerName = Killer.PlayerReplicationInfo.PlayerName;
	killedName = Killed.PlayerReplicationInfo.PlayerName;
    outstring @= "{DeathString " $ WorldInfo.Game.ParseKillMessage(killerName, killedName, RemoteBot(Killed).lastDamageType.default.DeathString) $ "}";
    myConnection.SendLine(outstring);
}

/**
 * Called by our target when it is hit.
 * @note Messages: HIT
 * @note Attributes: Id, Damage
 * 
 * @param Target our target
 * @param Damage damage taken
 * @param damageType type of damage
 */ 
function NotifyHitTarget(Controller Target, int Damage, class<DamageType> damageType){
	local string outString;

	outString = "HIT {Id" @ class'GBUtil'.static.getUniqueId(Target) $
		"} {Damage" @ Damage $ 
		"}"; 
	outString @= GetDamageTypeInfo(damageType, false);

	myConnection.SendLine(outString);
}

/**
 * Exports info about given damageType
 * 
 * @note Messages: DAM,DIE,KIL
 * @note Attributes: DamageType, CausedByWorld, 
 *          CausedByWorld, BulletHit, VehicleHit,
 *          DirectDamage, WeaponName, Flaming, DeathString*
 * 
 * @note WeaponName might not be sent when it is not filled by the engine.
 * @note CausedByWorld, DirectDamage, BulletHit, VehicleHit is sent as is 
 *  in engine.
 * @note Flaming is aproximated by check if damage type id UTDmgType_Burning.
 * @note Not sending CausedByWorld missing in documantation!
 * @warning not sending DeathString because localized strings mess up with
 *          the parser!!! RESOLVED
 */ 
function string GetDamageTypeInfo(class<DamageType> damageType, bool bDeath){
	local string strRet;
	local class<UTDamageType> UTDT;

	strRet = "{DamageType " $ damageType $ 
            //"} {CausedByWorld " $ class'GBUtil'.static.GetBoolString(damageType.default.bCausedByWorld) $
            "}";

	UTDT = class<UTDamageType>(damageType);
	if (UTDT != none){
		strRet @= "{BulletHit " $ class'GBUtil'.static.GetBoolString(UTDT.default.bBulletHit) $
			"} {DirectDamage " $ class'GBUtil'.static.GetBoolString(UTDT.default.bDirectDamage) $
			"} {VehicleHit " $ class'GBUtil'.static.GetBoolString(UTDT.default.bVehicleHit) $
			"}";
		if (UTDT.default.DamageWeaponClass != none)
			strRet @= "{WeaponName " $ class'GBUtil'.static.GetInventoryTypeFromWeapon(UTDT.default.DamageWeaponClass) $
				"}";
		if (UTDT.IsA('UTDmgType_Burning'))
			strRet @= "{Flaming True}";
	}
	
	if(bDeath){
		strRet @= "{DeathString " $ damageType.default.DeathString $ "}";
		//strRet @= "{DeathString " $ damageType.DeathMessage() $ "}";
	}

	return strRet;
}

/* Added func RemoteKilled - should make things cleaner, called from GameTypeGame server
        25.10.2006 Michal Bida
*/
function RemoteKilled(Controller Killer, Controller Killed, Pawn KilledPawn, class<DamageType> damageType)
{
        local string outstring;

        outstring = "KIL {Id " $ class'GBUtil'.static.GetUniqueId(Killed) $
                "} {KilledPawn " $ KilledPawn $
        "} {Killer " $ class'GBUtil'.static.GetUniqueId(Killer) $
                "}";
        if (CanSee(KilledPawn))
        {
                outstring = outstring $ " {DamageType " $ damageType $
        //"} {DeathString " $ damageType.default.DeathString $
        //"} {WeaponName " $ damageType.default.DamageWeaponName $
        //"} {Flaming " $ damageType.default.bFlaming $
        //"} {CausedByWorld " $ damageType.default.bCausedByWorld $
        //"} {DirectDamage " $ damageType.default.bDirectDamage $
        //"} {BulletHit " $ damageType.default.bBulletHit $
        //"} {VehicleHit " $ damageType.default.bVehicleHit $
                "}";
        }

        myConnection.sendLine(outstring);
}

/* Added func RemoteDied - should make things cleaner, called from GameTypeGame server
        25.10.2006 Michal Bida
*/
function RemoteDied(Controller Killer, class<DamageType> damageType)
{
        myConnection.SendLine("DIE {Killer " $ /*myConnection.*/class'GBUtil'.static.GetUniqueId(Killer) $
                "} {DamageType " $ damageType $
        //"} {DeathString " $ damageType.default.DeathString $
        //"} {WeaponName " $ damageType.default.DamageWeaponName $
        //"} {Flaming " $ damageType.default.bFlaming $
        //"} {CausedByWorld " $ damageType.default.bCausedByWorld $
        //"} {DirectDamage " $ damageType.default.bDirectDamage $
        //"} {BulletHit " $ damageType.default.bBulletHit $
        //"} {VehicleHit " $ damageType.default.bVehicleHit $
                "}");
}

//Intercept FireWeapon - is called from other code
/**
 * @todo what is that for?
 */
function bool FireWeaponAt(Actor A) {
}

/**
 * Handles firing bot's weapon
 * 
 * @param bUseAltMode specifies if alternative 
 *      firing mode should be used
 */ 
function RemoteFireWeapon(bool bUseAltMode) {
    if ((Pawn == none) || (Pawn.Weapon == none))
        return;

    if (bUseAltMode) {
        shouldFire = 2;
        Pawn.Weapon.StartFire(1);
    } else {
        shouldFire = 1;
        Pawn.Weapon.StartFire(0);
    }
}

//Function which determines if our weapon should fire again or stop firing
/**
 * Determines if bot should fire again
 * 
 * @note something is wrong here! 
 *      why we handle firing in here?
 *      why we do not check bFinishedFiring?
 *      why we return always false?
 * 
 * @param bFinishedFire indicates if we have finished firing.
 * 
 * @return
 */ 
function bool WeaponFireAgain(bool bFinishedFire) { 
    if (Pawn == none || Pawn.Weapon == none || !Pawn.Weapon.HasAnyAmmo())
        return false;

    //`log("In WeaponFireAgain");
    if (shouldFire == 1)
        Pawn.Weapon.StartFire(0);
    else if (shouldFire == 2) 
        Pawn.Weapon.StartFire(1);

    return false;
}

//===============================================================================
//= Movement and navigation
//===============================================================================

//Called when the bot land on the ground after falling
function bool NotifyLanded(vector HitNormal, Actor FloorActor)
{
        myConnection.SendLine("LAND {HitNormal " $ HitNormal $ "}");
		
		/**@todo hack: should be done in Landed event in GBPawn, 
		 * but it is currently not working
		 */ 
		GBPawn(Pawn).MultiJumpRemaining = GBPawn(Pawn).MaxMultiJump;

        //restart, so we continue moving and not going back to our previous
        //destination, as we may be over it because of the fall
        if (movingContinuous)
                gotoState('Alive','MoveContRepeat');
        return true;
}

/**
 * Called on collision with other actor
 * @note Messages: BMP
 * @note Attributes: Id, Location
 * 
 * @param Other hit actor
 * @param HitNormal
 */ 
event bool NotifyBump(Actor Other, Vector HitNormal)
{
    local vector VelDir, OtherDir;
    local float speed;

    speed = VSize(Velocity);
    if ( speed > 10 ){
        VelDir = Velocity/speed;
        VelDir.Z = 0;
        OtherDir = Other.Location - Location;
        OtherDir.Z = 0;
        OtherDir = Normal(OtherDir);
        if ( (VelDir Dot OtherDir) > 0.8 )
        {
            Velocity.X = VelDir.Y;
            Velocity.Y = -1 * VelDir.X;
            Velocity *= FMax(speed, 280);
        }
    }

    if ( WorldInfo.TimeSeconds - 0.3 >= lastBumpTime ){
        myConnection.SendLine("BMP {Id " $ class'GBUtil'.static.GetUniqueId(Other) $
                "} {Location " $ Other.Location $"}");

        lastBumpTime = WorldInfo.TimeSeconds;
    }

    // Need to disable bumping ???
    //Disable('Bump');
    //TODO: Experiment with this?
    return false;
}

/**
 * Called on collision with a wall.
 * @note Messages: WAL
 * @note Attributes: Id, Normal, Location
 * 
 * @param HitNormal
 * @param Wall actor representing the wall
 */ 
event bool NotifyHitWall(vector HitNormal, actor Wall)
{
    if ( WorldInfo.TimeSeconds - 0.3 >= lastWallHit){
        myConnection.SendLine("WAL {Id " $ class'GBUtil'.static.GetUniqueId(Wall) $
                "} {Normal " $ HitNormal $ 
                "} {Location " $ Wall.Location $ "}");

        lastWallHit = WorldInfo.TimeSeconds;
    }
	//Returning true might cause NotifyHitWall to stop functioning
    return false;
}

/**
 * Called when our bot collides with a wall while falling
 */ 
event NotifyFallingHitWall(vector HitNormal, actor Wall){
	NotifyHitWall(HitNormal, Wall);
}

/**
 * Called when a pawn is about to fall off a ledge.
 * @note Messages: FAL
 * @note Attributes: fell, Location
 */ 
event MayFall(){
	local string outString;
	local bool fell;

	//fell = (pawn.Physics == PHYS_Falling) ? true : false;
	fell = !Pawn.bIsWalking;

	outString = "FAL {Fell" @ class'GBUtil'.static.GetBoolString(fell) $
		"} {Location" @ Pawn.Location $
		"}";

	myConnection.SendLine(outString);
}

event NotifyPostLanded()
{
        bNotifyPostLanded = false;
}

//overriding! so no code gets executed 
/**
 * @todo can we get around this?
 */
event NotifyMissedJump()
{

}

//overriding! so no code gets executed 
/**
 * @todo can we get around this?
 */
event MissedDodge()
{

}

/**
 * Called when our bot enters new volume
 * @note Messages: VCH
 * @note Attributes:
 * 
 * @param NewVolume
 */ 
event NotifyPhysicsVolumeChange( PhysicsVolume NewVolume )
{
	local string outString;
	local Vector gravity;

    //this code is taken from super class (Bot). Had to disable automatic jumping out of water
    //super class is not called anymore
    if ( newVolume.bWaterVolume )
    {
        bPlannedJump = false;
        if (!Pawn.bCanSwim)
            MoveTimer = -1.0;
        else if (Pawn.Physics != PHYS_Swimming)
            Pawn.setPhysics(PHYS_Swimming);
    }
    else if (Pawn.Physics == PHYS_Swimming)
    {
        if ( Pawn.bCanFly )
             Pawn.SetPhysics(PHYS_Flying);
        else
        {
            Pawn.SetPhysics(PHYS_Falling);
            /*if ( Pawn.bCanWalk && (Abs(Pawn.Acceleration.X) + Abs(Pawn.Acceleration.Y) > 0)
                    && (Destination.Z >= Pawn.Location.Z)
                    && Pawn.CheckWaterJump(jumpDir) )
            {
                    Pawn.JumpOutOfWater(jumpDir);
                    bNotifyApex = true;
                    bPendingDoubleJump = true;
            }*/
        }
    }

	gravity.Z = NewVolume.GetGravityZ();

    outString = "VCH {Id " $ class'GBUtil'.static.GetUniqueId(NewVolume) $
            "} {ZoneVelocity " $ NewVolume.ZoneVelocity $  //vector
            "} {ZoneGravity " $ gravity $  //vector
            "} {GroundFriction " $ NewVolume.GroundFriction $  //float
            "} {FluidFriction " $ NewVolume.FluidFriction $  //float
            "} {TerminalVelocity " $ NewVolume.TerminalVelocity $  //float
            "} {WaterVolume " $ class'GBUtil'.static.GetBoolString(NewVolume.bWaterVolume) $
            "} {PainCausing " $ class'GBUtil'.static.GetBoolString(NewVolume.bPainCausing) $
            "} {Destructive " $ class'GBUtil'.static.GetBoolString(NewVolume.bDestructive) $
            "} {DamagePerSec " $ NewVolume.DamagePerSec $ //float
            "} {DamageType " $ NewVolume.DamageType $
            "} {NoInventory " $ class'GBUtil'.static.GetBoolString(NewVolume.bNoInventory) $
            "} {MoveProjectiles " $ class'GBUtil'.static.GetBoolString(NewVolume.bMoveProjectiles) $
            "} {NeutralZone " $ class'GBUtil'.static.GetBoolString(NewVolume.bNeutralZone) $
            "}";

	myConnection.SendLine(outString);
}

//overriding so no code gets executed
/**
 * @todo can we get around this?
 */
event MayDodgeToMoveTarget()
{

}

/**
 * Handles Jumping of the bot by JUMP command
 * 
 * @param bDouble Indicates if bot should perform doublejump
 * @param force Sets JumpZ velocity
 * @param delay delay of the second jump of doubleJump
 * 
 * @note if force and delay is 0 then the default jump routines are used
 * @todo there is currently a bug when doubleJump is performed the 
 *      multiJumpRemaining variable in GBPawn is not renewed to MaxMultiJump
 *      value on landing, because the Landed event is not fired.
 *      hacked: I reset the MultiJumpRemaining valu in NotifyLanded func
 *          in RemoteBot
 */ 
function RemoteJump(bool bDouble, float force, float delay)
{
	// TODO: REDO
	local GBPawn P;

	P = GBPawn(Pawn);

    if (P == none)
            return;

	//`LogInfo("JUMP spec. bDouble:" @ class'GBUtil'.static.GetBoolString(bDouble) @
		//"Force:" @ force @ "Delay:" @ delay);
	bNotifyApex = true;
	//`LogInfo("bNotifyApex:" @ class'GBUtil'.static.GetBoolString(bNotifyApex));
	if (force == 0 && delay == 0){
		//is we do not need anything special use normal implementation
		if (bDouble){
			bPendingDoubleJump = true;
			P.DoJump(false);
		}
		else P.DoJump(false);
	}
	else if (delay == 0 && force != 0){
		//jump with custom force without delay
		if(bDouble){
			if(force - P.JumpZ > 0){
				bPendingCustomJump = true;
				P.customDoubleJumpZ = force - P.JumpZ;
				P.CustomJump(P.JumpZ,false);
			}
			else P.CustomJump(force,false); //not enough force to doubleJump
		}
		else P.CustomJump(force,false);
	}
	else if (force == 0 && bDouble){
		//delayed jump with standard force
		SetTimer(delay,false,'DelayedJump');
		P.DoJump(false);
	}
	else if(bDouble){
		//delayed jump with custom force
		if(force - P.JumpZ > 0){
			P.customDoubleJumpZ = force - P.JumpZ;				
			SetTimer(delay,false,'DelayedJump');
			P.CustomJump(P.JumpZ,false);
		}
		else P.CustomJump(force,false); //not enough force to doubleJump
	}
	/*else `LogWarn("Bad JUMP spec. bDouble:" @ class'GBUtil'.static.GetBoolString(bDouble) @
		"Force:" @ force @ "Delay:" @ delay);*/
}

/**
 * Handles delayed second jump set by JUMP command 
 */ 
function DelayedJump(){
	local GBPawn P;

	P = GBPawn(Pawn);
	if(P == none) return;

	if(P.customDoubleJumpZ == 0){
		P.DoDoubleJump(false);
	}
	else P.CustomDoubleJump(false);
}

//overriding! so no code gets executed 
/**
 * @todo suspended for handling double jumps
 */
/*
event NotifyJumpApex()
{

}*/

/**
 * Handles double jump with custom force with standard delay
 * 
 * @todo might be necessary to remove the obstacle collision code
 * @todo does not work, is not called from the engine
 *      solved: bNotifyApex must be set to true!
 */ 
event NotifyJumpApex()
{
	/*`LogDebug("bPendingDoubleJump:" @ class'GBUtil'.static.GetBoolString(bPendingDoubleJump));
	`LogDebug("CanDoubleJump():" @  class'GBUtil'.static.GetBoolString(GBPawn(Pawn).CanDoubleJump()));
	`LogDebug("MultiJumpRemaining:" @ GBPawn(Pawn).MultiJumpRemaining);
	`LogDebug("Physics:" @ GBPawn(Pawn).Physics);
	`LogDebug("bReadyToDoubleJump:" @ GBPawn(Pawn).bReadyTodoubleJump);*/
	super.NotifyJumpApex();
	if (bPendingCustomJump){
		Pawn.bWantsToCrouch = false;
		if ( UTPawn(Pawn).CanDoubleJump() )
			GBPawn(Pawn).CustomDoubleJump(false);
		bPendingCustomJump = false;
	}
}

/**
 * @todo does nothing
 */
function bool TryToDuck(vector duckDir, bool bReversed) {

}

//===============================================================================
//= Inventory
//===============================================================================

/**
 * Handles pickup messages for items not represented by Inventory class.
 *  These are Ammunition, Health a Armor pickups.
 *  Also sends AIN message for new ammo types that are not 
 *  already in our inventory.
 *  @note Messages: IPK, AIN
 *  @note Attributes: Id, InventoryId, Location, Amount, Type (for IPK)
 *          Id, Type, PickupType (for AIN)
 *          
 *  @note Id attribute uses PickupFactoryId
 *  @note InventoryId attribute is not send because these items do not appear
 *          in our inventory as objects
 *  @note AmountSec is not used by UT3 because no weapon has secondary ammo
 */ 
function HandleItemPickup(PickupFactory pickup, vector location, int amount){
	local string outString;
	local array<UTWeapon> WeaponList;
	local int i;
	local bool found;
	local UTAmmoPickupFactory AmmoPF;
	local UTInventoryManager INVManager;

	outString = "IPK {Id" @ class'GBUtil'.static.GetUniqueId(pickup) $
		"} {Location" @ location $
		"} {Amount" @ amount $
		"} {Type " @ class'GBUtil'.static.GetInventoryTypeFromFactory(pickup) $
		"} {Dropped false"$ //this item came from a pickup factory
		"}";

	myConnection.SendLine(outString);

	//handle the first pickup of ammo type we do not have
	if (pickup.IsA('UTAmmoPickupFactory')){
		AmmoPF = UTAmmoPickupFactory(pickup);
		if (Pawn != none && UTInventoryManager(Pawn.InvManager) != none){
			INVManager = UTInventoryManager(Pawn.InvManager);
			INVManager.GetWeaponList(WeaponList);
			for (i = 0; i < WeaponList.Length; i++){
				if (ClassIsChildOf(WeaponList[i].Class, AmmoPF.TargetWeapon))
					found = true;
			}

			for(i = 0; i < INVManager.AmmoStorage.Length; i++){
				if (INVManager.AmmoStorage[i].WeaponClass == AmmoPF.TargetWeapon)
					found = true;
			}
			
			if (!found){
				outString = "AIN {Id" @ class'GBUtil'.static.GetUniqueId(pickup) $
					"} {Type" @ class'GBUtil'.static.GetInventoryTypeFromFactory(pickup) $
					"} {PickupType" @ class'GBUtil'.static.GetPickupTypeFromFactory(pickup) $
					"}";
			}
		}
		else `logError("No pawn or bad InventoryManager!");
	}
}

/**
 * Informs the client that the bot has just received a new item in his inventory
 * @note Messages: AIN
 * @note Attributes: Id, Type, PickupType, Sniping, Melee,
 *          PrimaryInitialAmmo, MaxPrimaryAmmo, SecondaryInitialAmo,
 *          MaxSecondaryAmmo
 * @note Does not send info about new ammo type as it is not represented
 *      as Inventory class.
 * @warning Not sending additional information because it is missing in the
 *      Pogamut xml definition of AIN message!
 */ 
function NotifyAddInventory(inventory NewItem)
{
	local string outString;
	local UTWeapon newWeap;
	local UTWeaponLocker WL;
	local bool bWeaponLocker;
	local int ammo;

	super.NotifyAddInventory(NewItem);

	outString = "AIN {Id" @ class'GBUtil'.static.GetUniqueId(NewItem) $
		"} {Type" @ class'GBUtil'.static.GetInventoryTypeFromInventory(NewItem) $
		"} {PickupType" @ class'GBUtil'.static.GetPickupTypeFromInventory(NewItem) $
		"}";

	// dirty but i don't know how to do it another way
	bWeaponLocker = false;
	foreach Pawn.TouchingActors(class'UTWeaponLocker', WL){
		bWeaponLocker = true;
	}

	if (NewItem.IsA('UTWeapon')){
		newWeap = UTWeapon(NewItem);
		if(bWeaponLocker)
			ammo = newWeap.Class.default.LockerAmmoCount;
		else
			ammo = newWeap.Class.default.AmmoCount;

		outString @= "{Sniping" @ class'GBUtil'.static.GetBoolString(newWeap.bSniping) $
			"} {Melee" @ class'GBUtil'.static.GetBoolString(newWeap.bMeleeWeapon) $
			"} {PrimaryInitialAmmo" @ ammo $
			"} {MaxPrimaryAmmo" @ newWeap.MaxAmmoCount $
			"} {SecondaryInitialAmmo 0" $
			"} {MaxSecondaryAmmo 0}";
	}

	myConnection.SendLine(outString);
	`LogDebug(outString);

	//If adding default inventory we need to export IPK messages as well
	if (bAddingDefaultInventory){
		outString = "IPK {Id" @ class'GBUtil'.static.GetUniqueId(NewItem) $
			"} {InventoryId" @ class'GBUtil'.static.GetUniqueId(NewItem) $
			"} {Location" @ NewItem.Location $
			"} {Type" @ class'GBUtil'.static.GetPickupTypeFromInventory(NewItem) $
			"} {Dropped False}";

		if (NewItem.IsA('UTWeapon')){
			outString @= "{Amount" @ ammo $ "}";
		}

		myConnection.SendLine(outString);
	}
}

/**
 * Called when we pickup some inventory item
 * @note Messages: IPK
 * @note attributes: Id, InventoryId, Location, Amount, AmountSec, Type
 * 
 * @note Id and InventoryId are the same. We do not get info about the item lying
 *      on the ground.
 * @note AmountSec is not used by UT3 as no weapon has secondary ammo
 * @note Onlyworks for items that are represented by Inventory class
 *      Health, Armor and Ammo pickups do not call HandlePickup function.
 *      These are handled by HandleItemPickup function.
 * @note Dropped attribute cannot be send as we are not able to discern
 *      dropped pickups from regular ones because we receive only the information
 *      about the inventory item that is picked up and not about the source.
 */ 
function HandlePickup(Inventory Inv) {
	local string outString;
	local bool bWeaponLocker;
	local UTWeaponLocker WL;
	local int ammo;

	outString = "IPK {Id" @ class'GBUtil'.static.GetUniqueId(Inv) $
		"} {InventoryId" @ class'GBUtil'.static.GetUniqueId(Inv) $
		"} {Location" @ Inv.Location $
		//"} {AmountSec" $
		"} {Type" @ class'GBUtil'.static.GetInventoryTypeFromInventory(Inv) $
		"}";

	// dirty but i don't know how to do it another way
	bWeaponLocker = false;
	foreach Pawn.TouchingActors(class'UTWeaponLocker', WL){
		bWeaponLocker = true;
	}

	if(bWeaponLocker)
		ammo = UTWeapon(Inv).LockerAmmoCount;
	else
		ammo = UTWeapon(Inv).AmmoCount;

	if (Inv.IsA('UTWeapon')){
		outString @= "{Amount" @ ammo $ "}";
	}

	`logDebug("IPK: " $ outString);
	myConnection.SendLine(outString);
	super.HandlePickup(Inv);
}

/**
 * Called when pawn changes weapon.
 * @note Messages: WUP, CWP
 * @note Attributes:
 */ 
function NotifyChangedWeapon( Weapon PrevWeapon, Weapon NewWeapon ){
	local string strWUP, strCWP;

	//when pawn is spawned his initial weapon is none 
	//but he switches to one of his weapons
	if (UTWeapon(PrevWeapon) != none){
		strWUP = "WUP" @ GetShortWeaponInfo(UTWeapon(PrevWeapon), true);
		myConnection.SendLine(strWUP);
		`LogDebug(strWUP);
	}

	strCWP = "CWP" @ GetShortWeaponInfo(UTWeapon(NewWeapon), false);
	myConnection.SendLine(strCWP);
	`LogDebug(strCWP);
}

/**
 * Notifies the client about state of the weapon that is about to change.
 * @note Messages: WUP, CWP
 * @note Attributes: Id, PrimaryAmmo, SecondaryAmmo, InventoryType
 */ 
function string GetShortWeaponInfo(UTWeapon botWeap, bool WUP){
	local string strRet;
	
	if (botWeap != none){
		strRet = "{Id" @ class'GBUtil'.static.GetUniqueId(botWeap) $
			"} {PrimaryAmmo" @ botWeap.AmmoCount $
			"} {SecondaryAmmo 0}";
		
		if(WUP)	
			strRet @= "{InventoryType";
		else
			strRet @= "{Type";

		strRet @= class'GBUtil'.static.GetInventoryTypeFromWeapon(botWeap.Class) $ "}";
	}
	else 
		`LogWarn("received none as parameter");
	return strRet;
}

/**
 * Picks up target item.
 */ 
function RemotePickup(string target){
	local PickupFactory PF;
	local DroppedPickup DP;

	if(Pawn != none){
		foreach Pawn.TouchingActors(class'PickupFactory', PF){
			if (string(PF) == target){
				Pawn.bCanPickupInventory = true;
				PF.Touch(Pawn,Pawn.BaseSkelComponent, Pawn.Location, PF.Location - Pawn.Location);
				Pawn.bCanPickupInventory = false;
				break;
			}
		}
		foreach Pawn.TouchingActors(class'DroppedPickup', DP){
			if (string(DP) == target){
				Pawn.bCanPickupInventory = true;
				DP.Touch(Pawn,Pawn.BaseSkelComponent, Pawn.Location, PF.Location - Pawn.Location);
				Pawn.bCanPickupInventory = false;
				break;
			}
		}
	}
}

//===============================================================================
//= MISC
//===============================================================================

/**
 * Called when our bot hears a sound
 * @note Messages: HRN, HRP
 * @note Attributes: Source, Type, Rotation (both)
 * 
 * @param Loudness loudness of the sound
 * @param NoiseMaker
 * @param NoiseType
 */ 
event HearNoise(float Loudness, Actor NoiseMaker, optional Name NoiseType )
{
	local string outString;
	local Vector ourLoc;

	ourLoc = (Pawn != none) ? pawn.Location : Location;

	if (PickupFactory(NoiseMaker) != none){
		outString = "HRP {Type" @ 
			class'GBUtil'.static.GetInventoryTypeFromFactory(PickupFactory(NoiseMaker)) $
			"}";
	}
	else {
		outString = "HRN {Type" @
			NoiseMaker.Class $ "}";
	}

	outString @= "{Source" @ class'GBUtil'.static.GetUniqueId(NoiseMaker) $
		"} {Rotation" @ Rotator(NoiseMaker.Location - ourLoc) $
		"}";

    myConnection.SendLine(outString);
}

//overriding! so no code gets executed
/**
 * @todo can we get around this?
 */ 
event SeePlayer(Pawn SeenPlayer)
{

}

/**
 * Handles sending messages to all or to team.
 * 
 * @note Command: MESSAGE
 * 
 */
function RemoteBroadcast( string Id, coerce string Msg, bool bGlobal, float FadeOut )
{

    local RemoteBot recipient;

    if (bIncludeFadeOutInMsg)
        Msg = Msg $ " FadeOut=" $ FadeOut $ " s.";


    //Set the text bubble, which will be shown on the HUDs of Human players
    //when they see the bot
    if (Pawn != none){
        GBPawn(Pawn).SetTextBubble(Id, Msg, bGlobal, FadeOut);
    }

    if (Id != ""){
        //If we haven't found Id or Id doesn't belong to RemoteBot we will end
		foreach WorldInfo.AllControllers(class'RemoteBot',recipient){
			if (recipient.PlayerReplicationInfo.PlayerName == Id)
				recipient.RemoteNotifyClientMessage(self,Msg);
		}
        return;
    }

    if ( bGlobal || !WorldInfo.Game.bTeamGame ){
		//Send the message to the game channel
		WorldInfo.Game.Broadcast(self, Msg, 'Say');
		//Send the message to RemoteBots
		SendGlobalMessage( Msg );
		return;
    }

    if (WorldInfo.Game.bTeamGame){
        //Send the message to team channel
        WorldInfo.Game.BroadcastTeam(self, Msg, 'TeamSay');
        //Send the message to RemoteBots
        SendTeamMessage( Msg );
        return;
    }
}

/**
 * Event for receiving string messages, called manually
 * @note Messages: VMS
 * @note Params: Id, Name, Text
 * 
 * @param sender Controller sending us this message
 * @param M text of the message
 */
event RemoteNotifyClientMessage(Controller sender, coerce string M)
{
    //Could cause some parsing problems, so replacing
    M = Repl(M, "{", "_", false );
    M = Repl(M, "}", "_", false );

    myConnection.SendLine("VMS {Id "$ class'GBUtil'.static.GetUniqueId(sender) $
        "} {Name" @ sender.PlayerReplicationInfo.PlayerName $
        "} {Text" @ M $
        "}");
}

/**
 * Event for receiving string messages, called manually
 * @note Messages: VMT
 * @note Params: Id, Name, Text
 * 
 * @param sender Controller sending us this message
 * @param M text of the message
 */ 
event RemoteNotifyTeamMessage(Controller sender, coerce string M)
{
    //Could cause some parsing problems, so replacing
    M = Repl(M, "{", "_", false );
    M = Repl(M, "}", "_", false );

    myConnection.SendLine("VMT {Id "$ class'GBUtil'.static.GetUniqueId(sender) $
        "} {Name" @ sender.PlayerReplicationInfo.PlayerName $
        "} {Text" @ M $
        "}");
}

/**
 * Sends message to all RemoteBot team members.
 */
function SendTeamMessage(string M)
{
    local RemoteBot recipient;

	foreach WorldInfo.AllControllers(class'RemoteBot',recipient){
		if (recipient.PlayerReplicationInfo.TeamID == self.PlayerReplicationInfo.TeamID)
			recipient.RemoteNotifyTeamMessage(self,M);
	}
}


/**
 * Sends global message to all RemoteBots.
 */
function SendGlobalMessage(string M)
{
    local RemoteBot recipient;

	foreach WorldInfo.AllControllers(class'RemoteBot',recipient){
		recipient.RemoteNotifyClientMessage(self,M);
	}
}

/* SetOrders()
Called when player gives orders to bot
*/
/**
 * @todo does nothing
 */
function SetBotOrders(name NewOrders, Controller OrderGiver, bool bShouldAck) {}


//Pointless callback
function EnemyAcquired();

//All kinds of things can call this mostly special trigger points
function Trigger( actor Other, pawn EventInstigator )
{
    myConnection.SendLine("TRG {Actor " $ /*myConnection.*/class'GBUtil'.static.GetUniqueId(Other) $
            "} {EventInstigator " $ /*myConnection.*/class'GBUtil'.static.GetUniqueId(EventInstigator) $
            "}");
}


//Don't let engine pick nodes that must be impact jumped
/**
 * @todo can we get around this?
 */
function bool CanImpactJump()
{
        return false;
}

//Don't handle impact jumps or low gravity manuevers for bots
/** performs an impact jump; assumes the impact hammer is already equipped and ready to fire */
//function ImpactJump();

/**
 * @todo check what does this function do in UTBot
 */
function SetFall()
{
        if (Pawn.bCanFly)
        {
                Pawn.SetPhysics(PHYS_Flying);
                return;
        }
        if (bDebug)
                `log("In RemoteBot.uc: SetFall() enganged.");
        /*
        if ( Pawn.bNoJumpAdjust )
        {
                Pawn.bNoJumpAdjust = false;
                return;
        }
        else
        {
                bPlannedJump = true;
                Pawn.Velocity = EAdjustJump(Pawn.Velocity.Z,Pawn.GroundSpeed);
                Pawn.Acceleration = vect(0,0,0);
        } */
}

/**
 * Handles proper restart of RemoteBot after spawning new Pawn
 * 
 * @note This had to be ovveriden from UTBot because UTBot
 *      trasintioned to the Roaming state in this method. That
 *      was undesirable.
 * 
 * @param bVehicleTransition
 */ 
function Restart(bool bVehicleTransition)
{
	if ( !bVehicleTransition ){
		Pawn.Restart();
		if ( !bVehicleTransition )
			Enemy = None;
		ReSetSkill();
		//GotoState('Roaming','DoneRoaming');
		ClearTemporaryOrders();
	}
	else if ( Pawn != None )
		Pawn.Restart();
}

/**
 * Handles Pawn death
 * 
 * @note This had to be ovveriden from UTBot because
 *      it caused a crash when the Pawn died.
 *      
 * @param P Dead Pawn
 */ 
function PawnDied(Pawn P)
{
	local int idx; //Controller

	//UTBot
	//If it is not our Pawn return
	if ( Pawn != P ){
		`LogWarn("P is not our Pawn! P =" @ P @ "; Pawn =" @ Pawn); 
		return;
	}

	PendingMover = None;
	
	//Controller

	// abort any latent actions
	TriggerEventClass(class'SeqEvent_Death',self);
	for (idx = 0; idx < LatentActions.Length; idx++)
		if (LatentActions[idx] != None)
			LatentActions[idx].AbortFor(self);
	
	LatentActions.Length = 0;

	if ( Pawn != None ){
		SetLocation(Pawn.Location);
		Pawn.UnPossessed();
	}
	Pawn = None;

	// if we are a player, transition to the dead state
	if ( bIsPlayer )
		// only if the game hasn't ended,
		if ( !GamePlayEndedState() )
			// so that we can respawn
			GotoState('Dead');
	// otherwise destroy this controller
	else
		Destroy();
}


//**********************************************************************************
//Base RemoteBot AI, that controls the Pawn (makes him move)

auto state Alive 
{
        function BeginState(Name PreviousStateName) {
            `log("Alive,BeginState");
            ResetSkill();
			if (Pawn != none)
				Pawn.SetMovementPhysics();
            Reset();
			//@todo just for debugging to remove
			//bNotifyApex = true;
			//`LogInfo("bNotifyApex:" @ class'GBUtil'.static.GetBoolString(bNotifyApex));
        }

        function EndState(Name NextStateName) {
            `log("Alive,EndState");
        }

Begin:
		//`LogInfo("Alive Begin label started");
        movingContinuous = false;

        sleep(0.5);
        if (VSize(Pawn.Velocity) > 10) //HACK - if the bot can't reach the destination, he would continue running - bad behavior
            StopMovement();
        
        goto 'Begin';
//Stops current movement
DoStop:
        movingContinuous = false;
        StopMovement();
        goto 'Begin';
//handles movement to target location
Move:
        //`log("Alive,Move:, MoveTo( " $ myDestination $ ")");
        movingContinuous = false;
        //SetDestinationPosition(myDestination);
        if (Focus == none) {
            MoveTo(myDestination,,Pawn.bIsWalking);
            //MoveTo( pendingDestination, , ,);

            //There is an issue when the bot finish its movement, sometimes he goes a bit
            //over the target point, this caused turning back, because moveTo functions sets focalpoint
            //after it ends to its target point, to prevent this, we will set our own FocalPoint counted in advance
           FocalPoint = myFocalPoint;
        } else {
            MoveTo(myDestination, Focus,Pawn.bIsWalking);
            //MoveTo( pendingDestination, Focus, , );
        }
        goto 'Begin';   
//handles movement ot target actor
//@todo seems to be unused
MoveToActor:
        movingContinuous = false;
        if (Focus == none) {
            MoveToward(MoveTarget, , , , Pawn.bIsWalking);
            //There is an issue when the bot finish its movement, sometimes he goes a bit
            //over the target point, this caused turning back, because moveTo functions sets focalpoint
            //after it ends to its target point, to prevent this, we will set our own FocalPoint counted in advance
            FocalPoint = myFocalPoint;
        } else {
            MoveToward(MoveTarget, Focus, , true, Pawn.bIsWalking);
        }
        goto 'Begin';
//handles continuous movement forward
MoveContinuous:
        //to prevent that our focal point moves too much above or below us
        //remember we want to move
        myFocalPoint.z = Pawn.Location.z;
        cmoveDirection = vector(rotator(myFocalPoint - Pawn.Location));
//Resets continuous movement
MoveContRepeat:
        movingContinuous = true;
        MoveTo(Pawn.Location + 500 * cmoveDirection);

        myFocalPoint = Pawn.Location + 500 * cmoveDirection;
        FocalPoint = myFocalPoint;
        goto 'MoveContRepeat';
}

// This state was called somehow on our bot. That is highly undersirable.
// Overriding
state Roaming
{
        function BeginState(Name PreviousStateName)
        {
                `log("In Roaming STATE! Shouldnt be!");
                gotostate('Alive','Begin');
        }
Begin:
        gotostate('Alive','Begin');
}

state TakeHit
{
        //ignores seeplayer, hearnoise, bump, hitwall;
		
        function Timer();

Begin:
        //error("!!!TakeHit");
}

state GameEnded
{
ignores SeePlayer, EnemyNotVisible, HearNoise, TakeDamage, Bump, Trigger, HitWall, Falling, ReceiveWarning;

        function SpecialFire()
        {
        }
        function bool TryToDuck(vector duckDir, bool bReversed)
        {
                return false;
        }
        function SetFall()
        {
        }
        function LongFall()
        {
        }
        function Killed(pawn Killer, pawn Other, name damageType)
        {
        }
        function ClientDying(class<DamageType> DamageType, vector HitLocation)
        {
        }

        function BeginState(Name PreviousStateName)
        {
                `log("In GameEnded! BeginState");
                //Pawn.SimAnim.AnimRate = 0.0;
                bFire = 0;
                //bAltFire = 0;

                SetCollision(false,false,false);
                SetPhysics(PHYS_None);
                Velocity = vect(0,0,0);
                myConnection.SendLine("FIN");
        }
}

state Dead
{
ignores SeePlayer, HearNoise, KilledBy;

function BeginState(Name PreviousStateName)
{
        `LogInfo("State: Dead, fc BeginState()");

        //We can be sent to this state sometimes, when it is not desired ( by game mechanics)
        //Escaping here
        if (Pawn != none)
                gotostate('Alive','Begin');

        //This is taken from working AI in UT2004, probably needed to assure bot
        //will behave normally after restart - 02/03/07 Michal Bida
        movingContinuous = false;
        Enemy = None;
        Focus = None;
        RouteGoal = None;
        MoveTarget = None;
        shouldFire = 0;
        //Pawn = Spawn(class'UTGame.UTPawn',self,,,);

        Super.StopFiring(); //Not needed anymore to call super, but for sure.
/*      FormerVehicle = None;
        bFrustrated = false;
        BlockedPath = None;
        bInitLifeMessage = false;
        bPlannedJump = false;
        bInDodgeMove = false;
        bReachedGatherPoint = false;
        bFinalStretch = false;
        bWasNearObjective = false;
        bPreparingMove = false;
        bEnemyEngaged = false;
        bPursuingFlag = false;
*/


}
/*
function EndState()
{
        myConnection.sendLine("SPW2");
}*/
Begin:
        `LogInfo("In Dead:Begin:");
		
        //AutoSpawn policy
        if (Pawn != None)
                gotostate('Alive','Begin');
        //RemoteRestartPlayer(); //HACK
        if (bAutoSpawn)// && !WorldInfo.Game.bWaitingToStartMatch)
        {
                RemoteRestartPlayer();
        //      if (Pawn == none) //bug during restart?
        //              goto('Begin');
                //ServerRestartPlayer(); //Dunno if this is needed here - Could it cause troubles?
        }

        if (Pawn != None)
                gotostate('Alive','Begin');
/*      if (!WorldInfo.Game.bWaitingToStartMatch)
        {
                RemoteRestartPlayer();
        }
        if (Pawn != None)
                gotostate('StartUp','Begin');*/
        sleep(1.0);
        goto('Begin');

}



//-------------RemoteBot Specific Functions--------------------


// True if location loc is in bot's field of view. Does not take into account occlusion by geometry!
// Possible optimization: Precompute cos(obsController.FovAngle / 2) for InFOV - careful if it can change.
/**
 * Checks if the locationis in pawns field of view.
 * 
 * @note does not take the occlusion into account.
 * 
 * @return Returns true if the location is in pawns field of view.
 * 
 * @param loc checked location
 */ 
function bool InFOV(vector loc) {

	local vector view;   // vector pointing in the direction obsController is looking.
	local vector target; // vector from obsController's position to the target location.
	local Vector eyeLocation;

	if(Pawn == none){
		`LogWarn("Pawn is none");
		return false;
	}

	view = vector(Pawn.GetViewRotation());
	eyeLocation = Pawn.GetPawnViewLocation();
	target = loc - eyeLocation;

	return Acos(Normal(view) dot Normal(target)) < Acos(Pawn.PeripheralVision) / 2; // Angle between view and target is less than FOV
	// 57.2957795 = 180/pi = 1 radian in degrees  --  convert from radians to degrees
}


//Called by the gametype when someone else is injured by the bot
//TODO: From old gamebots, is not called anymore, TO REMOVE - mb
/*
function int HurtOther(int Damage, name DamageType, pawn injured)
{
        myConnection.SendLine("HIT" $ib$as$ "Id" $ib$ injured $ae$ib$as$
                "Damage" $ib$ Damage $ae$ib$as$
                "DamageType" $ib$ DamageType $ae);
} */

/**
 * Sends SLF message to the client.
 * @note Messages: SLF
 *       Attributes: Id, Vehicle, Rotation, Location,
 *              Velocity, Name, Team, Health, Weapon,
 *              PrimaryAmmo, Shooting, AltFiring, Armor,
 *              HelmetArmor, VestArmor, ThighpadArmor,
 *              ShieldBeltArmor, Crouched, Walking,
 *              FloorLocation, FloorNormal, PowerUp, PowerUpTime
 * @todo Weapon should return invetory id; test implementation 
 * @todo SecondaryAmmo, Adrenaline, SmallArmor, Combo, UDamageTime
 *          not used any more.
 * @todo Action needs to be implemented in bot.
 * @todo Armor and powerup exports need to be implemented
 *          to GB protocol.
 */ 
function checkSelf() {
    local string outstring, myId;
    local rotator PawnRotation;
    local bool bIsShooting, AltFiring;
	local int TeamIndex,PrimaryAmmo;
	local UTTimedPowerup PowerUp;
    local vector FloorLocation, FloorNormal;
	local float PowerUpTime;

	TeamIndex = (WorldInfo.Game.IsA('GBCopyUTTeamGame')) ? int(GetTeamNum()) : 255;

    if( Pawn != none ) {
        if( Pawn.Weapon != None)
            bIsShooting = Pawn.Weapon.IsFiring();
		
			// find multiple powerups
			//checkPowerUp();

			PowerUp = UTTimedPowerup(Pawn.FindInventoryType(class'UTTimedPowerUp',true));
			PowerUpTime = (PowerUp != none) ? PowerUp.TimeRemaining : 0.0;
			if(Pawn.Weapon != none){
				if(Pawn.Weapon.IsFiring())
					AltFiring = (Pawn.Weapon.CurrentFireMode == 0) ? false : true; 

			if(Pawn.Weapon.IsA('UTWeapon'))
				PrimaryAmmo = UTWeapon(Pawn.Weapon).AmmoCount;
		}

        PawnRotation = Pawn.Rotation;
        //PawnRotation.Pitch = int(Pawn.ViewPitch) * 65556/255;

        FloorNormal = vect(0,0,0);
        Trace(FloorLocation,FloorNormal,Pawn.Location + vect(0,0,-1000),Pawn.Location, false);

		myId = class'GBUtil'.static.GetUniqueId(self); 
        outstring = "SLF {Id SELF_" $ myId $
				"} {BotId " $ myId $
                "} {Vehicle False" $
                "} {Rotation " $ PawnRotation $
                "} {Location " $ Pawn.Location $
                "} {Velocity " $ Pawn.Velocity $
                "} {Name " $ PlayerReplicationInfo.PlayerName $
                "} {Team " $ TeamIndex $
                "} {Health " $ Pawn.Health $
				//We need to export id of the weapon bot is holding, not its type
                //"} {Weapon " $ string(Pawn.Weapon.Class) $
                "} {Weapon " $ class'GBUtil'.static.GetUniqueId(Pawn.Weapon) $
                "} {PrimaryAmmo "$ PrimaryAmmo $
                "} {Shooting " $ class'GBUtil'.static.GetBoolString(bIsShooting) $
				"} {AltFiring " $ class'GBUtil'.static.GetBoolString(AltFiring) $
                "} {Armor " $ UTPawn(Pawn).GetShieldStrength() $
                "} {HelmetArmor " $ int(UTPawn(Pawn).HelmetArmor) $
				"} {VestArmor " $ int(UTPawn(Pawn).VestArmor) $
				"} {ThighpadArmor " $ int(UTPawn(Pawn).ThighpadArmor) $
				"} {ShieldBeltArmor " $ int(UTPawn(Pawn).ShieldBeltArmor) $
                "} {Crouched " $ class'GBUtil'.static.GetBoolString(Pawn.bIsCrouched) $
                "} {Walking " $ class'GBUtil'.static.GetBoolString(Pawn.bIsWalking) $
                "} {FloorLocation " $ FloorLocation $
                "} {FloorNormal " $ FloorNormal $
                "} {PowerUp " $ ((PowerUp == None) ? "None" : class'GBUtil'.static.GetInventoryTypeFromInventory(PowerUp)) $
                "} {PowerUpTime " $ PowerUpTime $
                "}";

	//`log("Debug: bFire "$bFire$" bAltFire "$bAltFire);
        myConnection.sendLine(outstring);
    } else
        `LogWarn("Pawn is none in check self!");
}

/**
 * Check for powerups for this pawn and send the PWRUP message
 */
/*function checkPowerUp() {
	local UTTimedPowerup powerUp;
	local float powerUpTime;
	local string outString;

	// TODO: Traverse inventory, find powerups and display powerup message
	powerUp = UTTimedPowerup(Pawn.FindInventoryType(class'UTTimedPowerUp',true));
	while(powerUp != None)
	{
		powerUpTime = powerUp.TimeRemaining;
		outString = "PWRUP {Name " $ class'GBUtil'.static.GetInventoryTypeFromInventory(powerUp) $
					"} {Time " $ powerupTime $
					"}";
		myConnection.sendLine(outString);
		`logDebug(outString);
		powerUp = UTTimedPowerup(powerUp.Inventory);
	}
}*/

function checkPlayers() {
	local Controller C;
	local string outstring, WeaponClass, PlayerName;
	local rotator PawnRotation;
	local int Firing, TeamIndex;
	//!!! view rotation sometimes falls out of synch with rotation? wtf?

	foreach WorldInfo.AllControllers(class'Controller', C){
		if( C != self && C.Pawn != none && InFOV(C.Pawn.Location) && FastTrace(C.Pawn.Location,Pawn.Location)) {//to match peripheral vision

			TeamIndex = (C.PlayerReplicationInfo.Team != none) ? C.PlayerReplicationInfo.Team.TeamIndex : 255;

			WeaponClass = (C.Pawn.Weapon == none) ? "None" :
				class'GBUtil'.static.GetInventoryTypeFromWeapon(class<UTWeapon>(C.Pawn.Weapon.Class));
			//Firing: 1 for primary, 2 for secondary, 0 not firing 
			Firing = 0;
			//IsFiring returns 0 for primary 1 for secondary so we have to 
			//increase the return value by one to match our definition
			if(C.Pawn.Weapon != none && C.Pawn.Weapon.IsFiring()) {
				Firing = C.Pawn.Weapon.CurrentFireMode + 1; 
			}

			PawnRotation = C.Pawn.Rotation;
			//PawnRotation.Pitch = int(C.Pawn.ViewPitch) * 65535/255;
			PlayerName = (C.IsA('PlayerController')) ? "Player" : C.PlayerReplicationInfo.PlayerName;

			outstring = "PLR {Id " $ class'GBUtil'.static.GetUniqueId(C) $
				"} {Rotation " $ PawnRotation $
				"} {Location " $ C.Pawn.Location $
				"} {Velocity " $ C.Pawn.Velocity $
				"} {Name " $ PlayerName $
				"} {Team " $ TeamIndex $
				//"} {Reachable " $ actorReachable(C.Pawn) $  //This can consume quite a lot resources
				"} {Crouched " $ C.Pawn.bIsCrouched $
				"} {Weapon " $ WeaponClass $
				"} {Firing " $ Firing $
				"}";
			myConnection.sendLine(outstring);

        }//end if
	}//end for P=Level.ControllerList
}

function checkItems() {
	local PickupFactory Pickup;
	local DroppedPickup DP;
	local string outstring;

	foreach DynamicActors(class'PickupFactory',Pickup){
		//do not export replaced PickupFactories with INV
		if((VSize(Pawn.Location - Pickup.Location) <= visionRadius) && ((Pickup.GetStateName() == 'Pickup') || (Pickup.GetStateName() == 'LockerPickup')) && !Pickup.bHidden && CanSeeByPoints( Pawn.Location, Pickup.Location, Pawn.Rotation) && (Pickup.ReplacementFactory == none))	{
			outstring = myConnection.GetINVFromFactory(Pickup);
			outstring @= "{Visible True" $  "}";
			myConnection.SendLine(outstring);
		}
	}

	//export all visible DroppedPickups
	foreach DynamicActors(class'DroppedPickup', DP){
		if ((VSize(Pawn.Location - DP.Location) <= visionRadius) && InFOV(DP.Location) && FastTrace(DP.Location,Pawn.Location)){
			outstring = myConnection.GetINVFromDroppedPickup(DP);
			outstring @= "{Visible True" $ "}";
			myConnection.SendLine(outstring);
		}
	}	
}

function checkMovers() {
	local InterpActor M;
	local string outstring;
	local int l;
	local array<InterpActor> MoverArray;

	//export visible movers
	MoverArray = BotDeathMatch(WorldInfo.Game).MoverArray;
	for (l = 0; l < MoverArray.Length; l++) {
		M = MoverArray[l];
		if(M.MyMarker != none && (VSize(Pawn.Location - M.Location) <= visionRadius) && ( 
			( ( Abs(Pawn.Location.x - M.Location.x) < 300 ) && ( Abs(Pawn.Location.y - M.Location.y) < 300 ) && ( Abs(Pawn.Location.Z - M.Location.Z) < 300 ))
			|| (InFOV(M.Location) && FastTrace(M.Location,Pawn.Location))) 
			){
			outstring = myConnection.GetMOV(M,false);
			outstring @= "{Visible True}";
			myConnection.SendLine(outstring);
		}//end if
    }//end foreach
}

function checkProjectiles() {
	local Projectile Proj;
	local string outstring;
	local float projDistance;
	local float impactTime;
	//ImpactTime - used TimeToLocation
	//Direction - used Rotation
	//Export all visible projectiles

	// @NOTE: Proj.GetTimeToLocation gives a division by zero error for deployable weapons like a translocator
	foreach DynamicActors(class'Projectile', Proj){
		if((VSize(Pawn.Location - Proj.Location) <= visionRadius) && InFOV(Proj.Location)){
			projDistance = VSize(Pawn.Location - Proj.Location);
			if(Proj.Speed > 0)
				impactTime = projDistance / Proj.Speed;
			else
				impactTime = 0;

			outstring = "PRJ {Id " $ Proj $
				"} {ImpactTime " $ impactTime/*Proj.GetTimeToLocation(Pawn.Location)*/ $
				"} {Direction " $ Proj.Rotation $
				"} {Speed " $ Proj.Speed $
				"} {Velocity " $ Proj.Velocity $
				"} {Location " $ Proj.Location $
				"} {Origin " $ Proj.Instigator.Location $
				"} {DamageRadius " $ Proj.DamageRadius $
				"} {Type " $ Proj.Class $
				"}";
			`logDebug(outstring);
			myConnection.SendLine(outstring);
		}
	}
}

/**
 * Check if the bot can see a volume and sends a SVL message.
 * Currently only slow volumes are supported.
 */
function checkVolumes() {
	local UTSlowVolume_Content V;
	local array<NavigationPoint> currentNavPointsInVolume;
	local NavigationPoint P;
	local string outString;	
	local int i;
	
	foreach AllActors(class 'UTSlowVolume_Content', V)
	{
		foreach V.TouchingActors(class 'NavigationPoint', P)
		{
			if ((VSize(Pawn.Location - P.Location) <= 500) || (InFOV( P.Location ) && FastTrace(P.Location, Pawn.Location)))
			{
				currentNavPointsInVolume.AddItem(P);
				outString = "SVL {Id " $ P $ "} {Visible True}" $
					" {Type " $ V.Class $ "}";
				myconnection.SendLine(outString);
				`logDebug(outString);
			}
		}
	}

	// remove the old ones
	foreach navPointsInVolume(P)
	{
		if(currentNavPointsInVolume.Find(P) == INDEX_NONE)
		{
			outString = "SVL {Id " $ navPointsInVolume[i] $ "} {Visible False}" $
				" {Type " $ V.Class $ "}";
			myconnection.SendLine(outString);
			navPointsInVolume.RemoveItem(P);
			`logDebug(outString);
		}
	}

	navPointsInVolume = currentNavPointsInVolume;
}

function checkNavPoints() {
	local string outstring;
	local int temp, i;
	local array<PickupFactory> InvSpotArray;
	local array<LiftCenter> LiftCenterArray;
	//local array<xDomPoint> DomPointArray;
	//local xDomPoint D;
	local PickupFactory IS;
	local LiftCenter DR;

	InvSpotArray = BotDeathMatch(WorldInfo.Game).InvSpotArray;
	LiftCenterArray = BotDeathMatch(WorldInfo.Game).LiftCenterArray;
	//DomPointArray = BotDeathMatch(WorldInfo.Game).xDomPointArray;

	//if (myConnection.bSynchronousNavPoints) {
		/*for (i = 0; i < DomPointArray.Length; i++) {
			D = DomPointArray[i];
			if( D.ControllingTeam == none )
				temp = 255;
			else
				temp = D.ControllingTeam.TeamIndex;

			outstring = "NAV {Id " $ D $
				//"} {Location " $ D.Location $
				"} {Visible " $ InFOV( D.Location ) $
				//"} {Reachable " $ myActorReachable(N) $
				"} {DomPoint True" $
				"} {DomPointController " $ temp $
				"}";
    		myConnection.SendLine(outstring);

		}*/
		     
		for (i = 0; i < InvSpotArray.Length; i++) {
			IS = InvSpotArray[i];
			if ((VSize(Pawn.Location - IS.Location) <= visionRadius) && ((VSize(Pawn.Location - IS.Location) <= 120) || (InFOV( IS.Location ) && FastTrace(IS.Location, Pawn.Location))) ) {
				outstring = "NAV {Id " $ IS $
					//"} {Location " $ IS.Location $
					"} {Visible True" $
					//"} {Reachable " $ myActorReachable(IS) $
					"} {ItemSpawned " $ IS.IsInState('Pickup') || IS.IsInState('LockerPickup') $ "}";
				myConnection.SendLine(outstring);
			}
		}

		for (i = 0; i < LiftCenterArray.Length; i++) {
			DR = LiftCenterArray[i];
			if( (VSize(Pawn.Location - DR.Location) <= visionRadius) && ((VSize(Pawn.Location - DR.Location) <= 500) || (InFOV( DR.Location ) && FastTrace(DR.Location, Pawn.Location)))) {
				outstring = "NAV {Id " $ DR $
					"} {Location " $ DR.Location $
					"} {Visible True" $
					//"} {Reachable " $ myActorReachable(DR) $
				    "}";
				myConnection.SendLine(outstring);
			}
		}
	//}
}

/**
 * Provides Info about bot's vision.
 * 
 * @note Messages: PLR, MOV, INV, NAV, PRJ
 *       Attributes: Visible, Reachable*
 * @todo Reachable may be omited.
 * @todo gametype specific items must be added
 * @todo clean up the local variables
 * @note Replacement facories are not exported via NAV messages.
 * @note Replaced factories are not exported by INV messages.
 * @note PRJ.Direction - used Rotation
 * @note PRJ.ImpactTime - used GetTimeToLocation
 * @note VEH does not send armor
 */ 
function checkVision()
{
	if( Pawn == none ) {
		`logWarn("In CheckVision() - Pawn is none ");
		return;
	}

	checkPlayers();
	checkItems();
	checkMovers();
	checkProjectiles();
	checkNavPoints();
	checkVolumes();

	//checkSounds();
	//vehicles
	//Export all visible vehicles
	/*
	foreach DynamicActors(class'Vehicle', veh){
		if(InFOV(veh.Location) && FastTrace(veh.Location, Pawn.Location)){
			outstring = "VEH {Id " $ veh $
				"} {Rotation " $ veh.Rotation $
				"} {Location " $ veh.Location $
				"} {Velocity " $ veh.Velocity $
				"} {Visible True" $
				"} {Team " $ veh.GetTeamNum() $
				"} {Health " $ veh.Health $
				//"} {Armor " $ veh. $
				"} {Driver " $ class'GBUtil'.static.GetUniqueId(veh.Driver.Controller) $
				"} {Type " $ veh.Class $
				"}";
			if (veh.IsA('UTVehicle'))
					outstring @= "{TeamLocked " $ class'GBUtil'.static.GetBoolString(UTVehicle(veh).bTeamLocked) $ "}";
			myConnection.SendLine(outstring);
		}
	}*/
}

simulated event Destroyed()
{
        //Destroying bot Pawn
        DestroyPawn(); //kill him properly first
        if (Pawn != None) {
                Pawn.Destroy();//destroy him
                Pawn = None;
    }

        //Destroying actor for aiming our shooting on location
    if (myTarget != none) {
                myTarget.Destroy();
        }

        if (myConnection != none)
                myConnection.SendLine("FIN");
        else
                `log("Problem with sending FIN, myConnection = none");

    Super.Destroyed();
}

event PostBeginPlay(){
	super.PostBeginPlay();
	traceManager = Spawn(class'GameBotsUT3.GBTraceManager',self);
	traceManager.setup(self);
}

function ChangeWeapon();
state MoveToGoal
{
    function BeginState(Name PreviousStateName);

}

function ServerChangedWeapon(Weapon OldWeapon, Weapon NewWeapon);


//-----------------

defaultproperties
{
	visionRadius=5000
    remoteVisionLimit=0.707000
    SpeedMultiplier=1.0
    bDrawTraceLines=true
    bIncludeFadeOutInMsg=true
    bShowFocalPoint=false
    bPerfectLocationAim=false
    bSpeakingBots=true
    bAutoTrace=false
    bAutoSpawn=true
    MaxSpeed=2.00000
    DesiredSkin="ThunderCrash.JacobM"
    PawnClass=Class'GameBotsUT3.GBPawn'
	bNotifyApex=true
}