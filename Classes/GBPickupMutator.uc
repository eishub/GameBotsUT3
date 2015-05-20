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
class GBPickupMutator extends UTMutator
	config(GameBotsUT3);
`include(Globals.uci);

struct ReplacementInfo{
	/** class name of the pickup we want to get rid of */
	var name OldClassName;
	/** fully qualified path of the class to replace it with */
	var string NewClassPath;
};

struct ReplacedInfo{
	var PickupFactory original;
	var PickupFactory replacement;
};

var config array<ReplacementInfo> PickupToReplace;

function bool CheckReplacement(Actor Other)
{
	local UTItemPickupFactory itemPF, newPF;
	local class<UTItemPickupFactory> newPFClass;
	local UTDeployablePickupFactory newDPF;
	local BotDeathMatch game;
	local int i;

	game = BotDeathMatch(WorldInfo.Game);

	if(Other.IsA('UTItemPickupFactory')){
		itemPF = UTItemPickupFactory(Other);
		//`logDebug("PF:" @ itemPF);
		i = PickupToReplace.Find('OldClassName',itemPF.Class.Name);
		//`logDebug("index:" @ i);
		if (i != INDEX_NONE){
			if (PickupToReplace[i].NewClassPath != ""){
				newPFClass = class<UTItemPickupFactory>(DynamicLoadObject(PickupToReplace[i].NewClassPath,class'Class'));
				if (newPFClass != none){
					newPF = itemPF.Spawn(newPFClass);//,itemPF.Owner,,itemPF.Location, itemPF.Rotation);
					newPF.OriginalFactory = itemPF;
					itemPF.ReplacementFactory = newPF;
					game.replacedMap.Add(1);
					game.replacedMap[game.replacedMap.Length-1].original = itemPF;
					game.replacedMap[game.replacedMap.Length-1].replacement = newPF;
					itemPF.destroy();
					//game.replacedMap.AddItem(tempRI);
					//`logDebug(newPF @ "pathList length:" @ newPF.PathList.Length);
					//for(i = 0; i < newPF.PathList.Length; i++){
					//	`logDebug(newPF @ "to:" @ newPF.PathList[i].End.Nav);
					//}
					//`logDebug("replaced with:" @ newPF);
					return false;
				}
				else {
					`logError("Class" @ PickupToReplace[i].NewClassPath @ "not found!");
					return true;
				}
			}
			else return true;
		}
	}
	// Replace all deployables by switchable deployables
	// @note: we don't want this feature
/*	else if(Other.IsA('UTDeployablePickupFactory')) {
		newDPF = UTDeployablePickupFactory(Other);
		//`LogDebug("DeployablePickupClassName: " $ newDPF.DeployablePickupClass.Name);
		i = PickupToReplace.Find('OldClassName', newDPF.DeployablePickupClass.Name);
		if(i != INDEX_NONE) {
		//	`LogDebug("Found deployable pickup.");
			if(PickupToReplace[i].NewClassPath != "") {
				UTDeployablePickupFactory(Other).DeployablePickupClass = class<UTDeployable>(DynamicLoadObject(PickupToReplace[i].NewClassPath, class'Class'));
				UTDeployablePickupFactory(Other).InitializePickup();
			}
		}

	}*/

	return true;
}

DefaultProperties
{
	GroupNames[0]="WEAPONMOD"
	PickupToReplace[0]=(OldClassName="UTPickupFactory_HealthVial",NewClassPath="GameBotsUT3.GBPickupFactory_HealthVial")
	PickupToReplace[1]=(OldClassName="UTPickupFactory_MediumHealth",NewClassPath="GameBotsUT3.GBPickupFactory_MediumHealth")
	PickupToReplace[2]=(OldClassName="UTPickupFactory_SuperHealth",NewClassPath="GameBotsUT3.GBPickupFactory_SuperHealth")
	PickupToReplace[3]=(OldClassName="UTArmorPickup_Helmet",NewClassPath="GameBotsUT3.GBArmorPickup_Helmet")
	PickupToReplace[4]=(OldClassName="UTArmorPickup_ShieldBelt",NewClassPath="GameBotsUT3.GBArmorPickup_ShieldBelt")
	PickupToReplace[5]=(OldClassName="UTArmorPickup_Thighpads",NewClassPath="GameBotsUT3.GBArmorPickup_Thighpads")
	PickupToReplace[6]=(OldClassName="UTArmorPickup_Vest",NewClassPath="GameBotsUT3.GBArmorPickup_Vest")
	PickupToReplace[7]=(OldClassName="UTAmmo_AVRiL",NewClassPath="GameBotsUT3.GBAmmo_AVRiL")
	PickupToReplace[8]=(OldClassName="UTAmmo_BioRifle",NewClassPath="GameBotsUT3.GBAmmo_BioRifle")
	PickupToReplace[9]=(OldClassName="UTAmmo_BioRifle_Content",NewClassPath="GameBotsUT3.GBAmmo_BioRifle_Content")
	PickupToReplace[10]=(OldClassName="UTAmmo_Enforcer",NewClassPath="GameBotsUT3.GBAmmo_Enforcer")
	PickupToReplace[11]=(OldClassName="UTAmmo_FlakCannon",NewClassPath="GameBotsUT3.GBAmmo_FlakCannon")
	PickupToReplace[12]=(OldClassName="UTAmmo_LinkGun",NewClassPath="GameBotsUT3.GBAmmo_LinkGun")
	PickupToReplace[13]=(OldClassName="UTAmmo_RocketLauncher",NewClassPath="GameBotsUT3.GBAmmo_RocketLauncher")
	PickupToReplace[14]=(OldClassName="UTAmmo_ShockRifle",NewClassPath="GameBotsUT3.GBAmmo_ShockRifle")
	PickupToReplace[15]=(OldClassName="UTAmmo_SniperRifle",NewClassPath="GameBotsUT3.GBAmmo_SniperRifle")
	PickupToReplace[16]=(OldClassName="UTAmmo_Stinger",NewClassPath="GameBotsUT3.GBAmmo_Stinger")
	//PickupToReplace[17]=(OldClassName="UTDeployableSlowVolume",NewClassPath="GameBotsUT3.GBDeployableSlowVolume")

}
