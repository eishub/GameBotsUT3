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
class GBCTFBlueFlag extends GBCTFFlag;

var ParticleSystemComponent BlueGlow;

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();
	SkelMesh.AttachComponentToSocket(BlueGlow,'PoleEmitter');
}


defaultproperties
{
	MessageClass=class'UTCTFMessage'

	Begin Object Class=ParticleSystemComponent Name=BlueParticle
		Translation=(X=0.0,Y=0.0,Z=0.0)
		Template=ParticleSystem'CTF_Flag_IronGuard.Effects.P_CTF_Flag_IronGuard_Idle_Blue'
		bAcceptsLights=false
		bAutoActivate=true
	End Object
	BlueGlow=BlueParticle

	Begin Object Class=ParticleSystemComponent Name=ScoreEffect
		Translation=(X=0.0,Y=0.0,Z=0.0)
		Template=ParticleSystem'Pickups.Flag.Effects.P_Flagbase_FlagCaptured_Blue'
		bAcceptsLights=false
		bAutoActivate=false
	End Object
	SuccessfulCaptureSystem=ScoreEffect
	Components.Add(ScoreEffect)

	Begin Object Name=TheFlagSkelMesh
		SkeletalMesh=SkeletalMesh'CTF_Flag_IronGuard.Mesh.S_CTF_Flag_IronGuard'
		PhysicsAsset=PhysicsAsset'CTF_Flag_IronGuard.Mesh.S_CTF_Flag_IronGuard_Physics'
		Materials(1)=Material'CTF_Flag_IronGuard.Materials.M_CTF_Flag_IG_Flagblue'
	End Object

	Begin Object name=FlagLightComponent
		LightColor=(R=64,G=128,B=255)
	End Object

	RespawnEffect=ParticleSystem'CTF_Flag_IronGuard.Effects.P_CTF_Flag_IronGuard_Spawn_Blue'

	ReturnedSound=SoundCue'A_Gameplay.CTF.Cue.A_Gameplay_CTF_FlagReturn_Cue'
	DroppedSound=SoundCue'A_Gameplay.CTF.Cue.A_Gameplay_CTF_FlagDropped01Cue'
	PickupSound=SoundCue'A_Gameplay.CTF.Cue.A_Gameplay_CTF_FlagPickedUp01Cue'
}
