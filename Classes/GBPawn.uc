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
class GBPawn extends UTPawn;
`include(Globals.uci);
`define debug;

var float customDoubleJumpZ;
var string bubbleText;
var bool bDrawTextBubble;

//Reference to the controller this pawn belonged to before UnPossessed event.
var Controller lastController;

/**
 * Handles jump with custom force
 * 
 * @param force jump force (jumpZ velocity)
 * @param bUpdating
 */ 
function bool CustomJump(float force, bool bUpdating){
	local float customJumpZ;

	//cannot jump higher than JumpZ
	if(force > JumpZ) customJumpZ = JumpZ;
	else customJumpZ = force;

	/**Modified code from UTPawn.doJump()*/

	// This extra jump allows a jumping or dodging pawn to jump again mid-air
	// (via thrusters). The pawn must be within +/- DoubleJumpThreshold velocity units of the
	// apex of the jump to do this special move.
	if ( !bUpdating && CanDoubleJump()&& (Abs(Velocity.Z) < DoubleJumpThreshold) && IsLocallyControlled() )
	{
		if ( PlayerController(Controller) != None )
			PlayerController(Controller).bDoubleJump = true;
		customDoubleJumpZ = force;
		CustomDoubleJump(bUpdating);
		MultiJumpRemaining -= 1;
		return true;
	}

	
	if (bJumpCapable && !bIsCrouched && !bWantsToCrouch && (Physics == PHYS_Walking || Physics == PHYS_Ladder || Physics == PHYS_Spider))
	{
		if ( Physics == PHYS_Spider )
			Velocity = customJumpZ * Floor;
		else if ( Physics == PHYS_Ladder )
			Velocity.Z = 0;
		else if ( bIsWalking )
			Velocity.Z = customJumpZ;
		else
			Velocity.Z = customJumpZ;

		if (Base != None && !Base.bWorldGeometry && Base.Velocity.Z > 0.f)
			if ( (WorldInfo.WorldGravityZ != WorldInfo.DefaultGravityZ) && (GetGravityZ() == WorldInfo.WorldGravityZ) )
				Velocity.Z += Base.Velocity.Z * sqrt(GetGravityZ()/WorldInfo.DefaultGravityZ);
			else
				Velocity.Z += Base.Velocity.Z;
		
		SetPhysics(PHYS_Falling);
		bReadyToDoubleJump = true;
		bDodging = false;
		if ( !bUpdating )
		    PlayJumpingSound();
		return true;
	}
	return false;
}

/**
 * Handles second jump of doubleJump with custom force
 * 
 * @param bUpdating
 */ 
function CustomDoubleJump(bool bUpdating){
	//Cannot jump higher than JumpZ + MultiJumpBoost
	if(customDoubleJumpZ > JumpZ + MultiJumpBoost) 
		customDoubleJumpZ = JumpZ + MultiJumpBoost;
	
	//modified UTPawn.doDoubleJump
	if ( !bIsCrouched && !bWantsToCrouch ){
		if ( !IsLocallyControlled() || AIController(Controller) != None )
			MultiJumpRemaining -= 1;
		
		Velocity.Z = customDoubleJumpZ;
		InvManager.OwnerEvent('MultiJump');
		SetPhysics(PHYS_Falling);
		BaseEyeHeight = DoubleJumpEyeHeight;
		if (!bUpdating)
			SoundGroupClass.Static.PlayDoubleJumpSound(self);
	}
	//reset customDoubleJumpZ
	customDoubleJumpZ = 0;
}

/**
 * Notifies that the pawn has landed.
 */ 
event Landed(vector HitNormal, actor FloorActor)
{	
	super.Landed(HitNormal, FloorActor);
}

/**
 * Handles damage taken by the pawn.
 *  We override this because when the bot dies the engine
 *  calls only NotifyKilled, so we would not received final DAM
 *  message. We add call to NotifyTakeHit.
 */ 
event TakeDamage(int Damage, Controller InstigatedBy, vector HitLocation, vector Momentum, class<DamageType> DamageType, optional TraceHitInfo HitInfo, optional Actor DamageCauser)
{
	local int ActualDamage;

	super.TakeDamage(Damage, InstigatedBy, HitLocation, Momentum, DamageType, HitInfo, DamageCauser);
	
	//we have to recalculate the actual damage taken after reductions
	ActualDamage = Damage;
	WorldInfo.Game.ReduceDamage(ActualDamage, self, instigatedBy, HitLocation, Momentum, DamageType);
	AdjustDamage(ActualDamage, Momentum, instigatedBy, HitLocation, DamageType, HitInfo);
	
	//lastController must be used because the pawn is probably already unpossessed
	if ( Health <= 0){
		lastController.NotifyTakeHit(InstigatedBy, HitLocation, ActualDamage, DamageType, Momentum);
	}

	if (InstigatedBy != none){
		if (InstigatedBy.IsA('RemoteBot')){
			RemoteBot(InstigatedBy).NotifyHitTarget(Controller, ActualDamage, damageType);
		}
		else {
			`LogInfo("I am hit by a not RemoteBot controller!");
		}
	}
	else {
		`LogInfo("InstigatedBy = none; not sending HIT message!");
	}
}

/**
 * Makes the bot dodge.
 * 
 * @todo double dodge and wall dodge
 * 
 * @param direction dodge direction
 * @param focusPoint location where the bot should look
 */ 
function bool CustomDodge(Vector direction, vector focusPoint){
	if ( Physics == PHYS_Falling ){
		TakeFallingDamage();
	}

	bDodging = true;
	--MultiDodgeRemaining;

	bReadyToDoubleJump = (JumpBootCharge > 0);
	Velocity = BotDodge(direction);

	SetPhysics(PHYS_Falling);
	SoundGroupClass.Static.PlayDodgeSound(self);
	return true;
}

/**
 * Adds a visualizer for a trace ray.
 * 
 * @param length Length of the arrow in unreal units
 * @param direction Direction of the arrow
 * @param id Id of the arrow. Must match the one in TraceManager.
 */ 
function addRayVisualization(int length, Vector direction, string id){
	local GBArrowComponent arrow;

	//`LogDebug("started");
	arrow = new class'GBArrowComponent';
	arrow.setLength(length);
	arrow.SetRotation(Rotator(direction));
	arrow.id = id;
	//`LogDebug("newArrow: id:" @ arrow.id @ "dir:" @ direction @ "rot:" @ arrow.Rotation); 
	AttachComponent(arrow);
	//`LogDebug("Pawn: rot:" @ Rotation @ "rot vec:" @ Vector(Rotation));
	//`LogDebug("newArrow: id:" @ arrow.id @ "dir:" @ direction @ "rot:" @ arrow.Rotation);
	//`LogDebug("sum rot:" @ Vector(Rotation + arrow.Rotation));
	//`LogDebug("sum vect:" @ Vector(Rotation) + Vector(arrow.Rotation));
	//`LogDebug("ended");
}

/**
 * Removes specified arrow.
 */ 
function removeRayVisualization(string id){
	local GBArrowComponent arrow;

	foreach ComponentList(class'GBArrowComponent', arrow){
		if (arrow.id == id){
			DetachComponent(arrow);
			break;
		}
	}
}

/**
 * Changes the color of the arrow to indicate collision.
 * 
 * @param id Id of the arrow.
 * @param hit true for collision, flase for clear
 */ 
function changeRayColState(string id, bool hit){
	local GBArrowComponent arrow;
	
	//`LogDebug("started");
	foreach ComponentList(class'GBArrowComponent',arrow){
		if (arrow.id == id){
			if(hit) arrow.hit();
			else arrow.clear();
			//`LogDebug("arrowPreUpdate: id:" @ arrow.id @ "hit:" @ arrow.bHit);
			//`LogDebug("arrowPreUpdate: id:" @ arrow.id @ "Rot:" @ arrow.Rotation); 
			arrow.ForceUpdate(false);
			//`LogDebug("arrowPostUpdate: id:" @ arrow.id @ "hit:" @ arrow.bHit); 
			break;
		}
	}
	//`LogDebug("ended");
}

/**
 * Changes the arrows rotation.
 * 
 * @note the newRotation will be used as 
 *      relative to the pawn's rotation.
 *      If you want to set an absolute rotation
 *      substract pawn's Rotation from the 
 *      newRotation parameter.
 * 
 * @param id Id of the arrow
 * @param newRotation
 */ 
function changeRayRotation(string id, Rotator newRotation){
	local GBArrowComponent arrow;
	
	//`LogDebug("started");
	foreach ComponentList(class'GBArrowComponent',arrow){
		if (arrow.id == id){
			arrow.SetRotation(newRotation);
			//`LogDebug("arrowPreUpdate: id:" @ arrow.id @ "Rot:" @ arrow.Rotation); 
			arrow.ForceUpdate(false);
			//`LogDebug("arrowPostUpdate: id:" @ arrow.id @ "Rot:" @ arrow.Rotation); 
			break;
		}
	}
	//`LogDebug("ended");
}

/**
 * Sets parameters for a new text bubble.
 * 
 * @param Id
 * @param M text of the message
 * @param bGlobal
 * @param fadeOut fade out time
 */ 
function SetTextBubble(string Id, string M, bool bGlobal, float fadeOut){
	bDrawTextBubble = true;
	SetTimer(fadeOut,false,'HideBubble');
	
	if(Id == "")
		bubbleText = M;
	else bubbleText = "To" @ Id $ ":" @ M;
}

/**
 * Hides text bubble when the fade out timer fires.
 */ 
function HideBubble(){
	bDrawTextBubble = false;
}

/*
function PostBeginPlay(){
	super.PostBeginPlay();

	`LogDebug("started");
	if (Controller.IsA('RemoteBot')){
		RemoteBot(Controller).traceManager.notifyNewPawn();
	}
	`Logdebug("ended");
}*/

function UnPossessed()
{
	`LogInfo("started");
	super.UnPossessed();
	`LogInfo("ended");
}


/**
 * Called when the bot is possessed by new controller
 * 
 * @note we notify the controller's traceManager that new pawn has been possessed.
 *      This is used to reinitialize the trace visualizations.
 */ 
function PossessedBy(Controller C, bool bVehicleTransition)
{
	`LogInfo("started");
	super.PossessedBy(C,bVehicleTransition);
	if (Controller.IsA('RemoteBot')){
		RemoteBot(Controller).traceManager.notifyNewPawn();
	}
	lastController = C;
	`LogInfo("ended");
}

/**
 * Destroys the autotraceing arrows on death
 */ 
function bool Died(Controller Killer, class<DamageType> damageType, vector HitLocation)
{
	local GBArrowComponent arrow;
	local array<GBArrowComponent> arrows;

	//super.Died(Killer, damageType, HitLocation);

	foreach ComponentList(class'GBArrowComponent', arrow){
		//removeRayVisualization(arrow.id);
		arrows.AddItem(arrow);
		//DetachComponent(arrow);
	}

	//It was necessary to detach the arrowComponents in two
	// separate loops for some reason
	foreach arrows(arrow){
		DetachComponent(arrow);
	}

	return super.Died(Killer, damageType, HitLocation);
}

function UpdateControllerOnPossess(bool bVehicleTransition)
{
	`LogInfo("started");
	super.UpdateControllerOnPossess(bVehicleTransition);
	`LogInfo("ended");
}

function SetMovementPhysics()
{
	`LogInfo("started");
	super.SetMovementPhysics();
	`LogInfo("ended");
}

function Restart()
{
	`LogInfo("started");
	super.Restart();
	`LogInfo("ended");
}



DefaultProperties
{
	bDrawTextBubble=false
}