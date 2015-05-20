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

class GBTraceManager extends Actor;

`include(Globals.uci);

/**
 * Represents single ray for autotraceing
 */ 
struct traceRay
{
	var string id;
	var Vector direction;
	var int length;
	var bool fastTrace, floorCorrection, traceActors;
};

/** current rays */
var array<traceRay> rays;
/** RemoteBot owning this raymanager */
var RemoteBot owner;
var bool bInitialized;

/**
 * Constructs ATR message batch for current ray setup.
 * 
 * @note Messages: ATR
 * @note Attributes: Id, From, To, FastTrace, FloorCorrection, 
 *      Result, HitNormal, HitLocation, TraceActors, HitId
 *      
 * @todo check the math. checked seems alright.
 */ 
function getTraceInfo(){
	local string tmp;
	local traceRay tmpRay;
	local Vector from, to, hitNorm, hitLoc, corrDirection, floorNorm, floorLoc;
	local Actor resActor;
	local bool res;
	local Vector eyesViewPoint;
	local Rotator eyeViewRot;

	if (owner != none && owner.Pawn != none){
		foreach rays(tmpRay){
			corrDirection = Vector(Rotator(tmpRay.direction) + owner.Pawn.Rotation);
			if (tmpRay.floorCorrection){
				owner.Trace(floorLoc, floorNorm, owner.Pawn.Location + Vect(0,0,-100), owner.Pawn.Location);
				corrDirection += floorNorm * (corrDirection dot floorNorm) * -1;
			}
			
			//apply the change in rotation
			GBPawn(owner.Pawn).changeRayRotation(tmpRay.id, Rotator(corrDirection) - owner.Pawn.Rotation);

			eyeViewRot = Rotator(corrDirection);
			eyesViewPoint = Vector(eyeViewRot);

			//`LogInfo("corrDirection vector:" @ corrDirection);
			//`LogInfo("corrDirection Rotator:" @ eyeViewRot);
			//`LogInfo("corrDirection vector2:" @ eyesViewPoint);

			owner.Pawn.GetActorEyesViewPoint(eyesViewPoint, eyeViewRot);
			from = owner.Pawn.Location;
			to = from + corrDirection * tmpRay.length;

			if (tmpRay.fastTrace){		
				res = !owner.FastTrace(to, from);
			}
			else {
				resActor = owner.Trace(hitLoc, hitNorm, to, from, tmpRay.traceActors);
				res = resActor != none;
			}

			tmp = "ATR {Id" @ tmpRay.id $
				"} {From" @ from $
				"} {To" @ to $
				"} {FastTrace" @ class'GBUtil'.static.GetBoolString(tmpRay.fastTrace) $
				"} {FloorCorrection" @ class'GBUtil'.static.GetBoolString(tmpRay.floorCorrection) $
				"} {Result" @ class'GBUtil'.static.GetBoolString(res) $
				"} {TraceActors" @ class'GBUtil'.static.GetBoolString(tmpRay.traceActors) $
				"}";

			if (tmpRay.fastTrace){
				tmp @= "{HitNormal" @ hitNorm $
					"} {HitLocation" @ hitLoc $
					"}";
			}
			else {
				if (tmpRay.traceActors){
					tmp @= "{HitId" @ class'GBUtil'.static.GetUniqueId(resActor) $ "}";
				}
			}

			//changes the color
			GBPawn(owner.Pawn).changeRayColState(tmpRay.id, res);

			owner.myConnection.SendLine(tmp);
			tmp = "";
		}
	}
}


/**
 * Adds new ray to the TraceManager.
 * 
 * @note If the floorCorrection is on you cannot trace orthogonally to the floor.
 * @note traceActors can be set to tru only if the fastTrace is off. Otherwise
 *      it is ignored.
 * 
 * @param id String id of the ray. 
 *      It is used to identify the ATR messages by the client.
 * @param direction
 *      Ray direction. Relative to the pawns rotation.
 * @param length Length of the ray in unreal units.
 * @param fastTrace indicates fast/normal trace.
 * @param floorCorrection Set to true to ensure that the ray is always 
 *      parallel with the floor.
 * @param traceActors Set to true if you want to trace actors as well as geometry.
 */ 
function bool addRay(string id, vector direction, int length, optional bool fastTrace = false, optional bool floorCorrection = true, optional bool traceActors = true){
	local traceRay newRay, tmpRay;
	local bool bRes;
	
	`LogDebug("started");

	bRes = true;

	foreach rays(tmpRay){
		if (tmpRay.id == id){
			bRes = false;
			break;
		}
	}

	if (bRes){
		newRay.id = id;
		newRay.direction = Normal(direction);
		newRay.length = length;
		newRay.fastTrace = fastTrace;
		newRay.floorCorrection = floorCorrection;
		newRay.traceActors = traceActors;
		if (owner.Pawn != none)
			GBPawn(owner.Pawn).addRayVisualization(length, direction, id);
		else `LogWarn("Adding ray:" @ id @ "for:" @ owner @"and pawn is none");

		rays.AddItem(newRay);
	}
	else `LogInfo("Ray of id" @ id @ "already exists.");

	`LogDebug("ended");
	return bRes;
}

/**
 * Removes existing ray in TraceManager.
 * 
 * @param id Id of the ray we want to remove.
 */ 
function bool removeRay(string id){
	local bool bRes;
	local traceRay tmpRay;

	`LogDebug("started");
	bRes = false;

	`LogDebug("id:" @ id);
	`LogDebug("Before:");
	foreach rays(tmpRay){
		`LogDebug("ray:" @ tmpRay.id);
	}
	foreach rays(tmpRay){
		if (tmpRay.id == id){
			rays.RemoveItem(tmpRay);
			GBPawn(owner.Pawn).removeRayVisualization(id);
			bRes = true;
			break;
		}
	}
	`LogDebug("After:");
	foreach rays(tmpRay){
		`LogDebug("ray:" @ tmpRay.id);
	}
	`LogDebug("ended");
	return bRes;
}

/**
 * Resets the TraceManager.
 * 
 * @note default rays are:
 *  StraightAhead - (1,0,0), length 250
 *  45toLeft - (1,-1,0), length 200
 *  45toRight - (1,1,0), length 200
 */ 
function resetRays(){
	`LogDebug("started");
	rays.Remove(0,rays.Length);

	addRay("StraightAhead", Vect(1,0,0), 250);
	addRay("45toLeft", Vect(1,1,0), 200);
	addRay("45toRight", Vect(1,-1,0), 200);
	`LogDebug("ended");
}

/**
 * Initializes the TraceManager to work with specified bot.
 * @note sets owner reference to our bot.
 * 
 * @param owner Pawn owning this instance.
 */ 
function setup(RemoteBot owner){
	`LogDebug("started");
	self.owner = owner;
	//The pawn has not yet been spawned. The default rays 
	resetRays();
	bInitialized = true;
	`LogDebug("ended");
}

/**
 * Notification on the pawn change. Adds visualizers for trace rays
 *      to new pawn.
 */ 
function notifyNewPawn(){
	local traceRay tmpRay;

	`LogDebug("started");
	foreach rays(tmpRay){
		GBPawn(owner.Pawn).addRayVisualization(tmpRay.length, tmpRay.direction, tmpRay.id);
	}

	`LogDebug("ended");
}

/**
 * Updates position of the ray emitters.
 * @todo check if the floor correction works!
 * @todo remove
 */ 
event Tick( float DeltaTime ){
	/*local traceRay tmpRay;
	local Vector floorNorm, floorLoc;
	local Rotator direction;

	if (owner != none && owner.Pawn != none){
		foreach rays(tmpRay){
			tmpRay.rayEmitter.SetLocation(owner.Pawn.Location);
			direction = owner.Pawn.Rotation + Rotator(tmpRay.direction);
			if (tmpRay.floorCorrection){
				owner.Trace(floorLoc, floorNorm, owner.Pawn.Location + Vect(0,0,-100), owner.Pawn.Location);
				direction = floorNorm * (direction dot floorNorm) * -1; 
			}
			tmpRay.rayEmitter.SetRotation(Rotator(direction));
			`LogDebug("ray:" @ tmpRay.id @ "; loc:" @ tmpRay.rayEmitter.Location @ "; rotation:" @ tmpRay.rayEmitter.Rotation);
			`LogDebug("pawn: loc:" @ owner.Pawn.Location @ "; rotation:" @ owner.Pawn.Rotation);
		}
	}*/

	//local Vector floorNorm, floorLoc;
	//local Rotator direction;
	
}

DefaultProperties
{
}
