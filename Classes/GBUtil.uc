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

class GBUtil extends Object abstract;

public static function string GetBoolString(bool boolean) 
{
	if (boolean) return "True";
	else return "False";
}

/**
 * Provides Unique inventory spot id.
 * 
 * @note Because PickupFactory is subclass of NavPoint it is 
 *      exported twice as a NavPoint in NAV batch and as inventory
 *      spot in INV batch. That causes problem with parser in Pogamut
 *      because the exported ids are the same. To solve that we add INV_
 *      prefix to the PickupFactory id.
 * 
 * @return Returns id of pickupFactory representing inventory
 *      spot with INV_ prefix.
 *      
 * @param PF PickupFactory representing the inventory spot.
 */ 
public static function string GetInventoryUniqueId(PickupFactory PF)
{
	return "INV_" $ PF;
}

/**
 * Provides PickupType string derived from weapon class
 * @return Returns GB PickupType for weapon
 * @param W Weapon class
 */ 
public static function string GetInventoryTypeFromWeapon(class<UTWeapon> W)
{
	local string strRet;
	local int i;
	strRet = Mid(W,InStr(W,"_") + 1);
	i = Instr(strRet,"_");
	if (i > -1) strRet = Left(strRet,i);
	return strRet;
}

/**
 * Provides the PickupType string for ITC message
 * 
 * @return PickupType string in GB procol
 * 
 * @param PF PickupFactory to export
 */ 
public static function string GetPickupTypeFromFactory(PickupFactory PF)
{
	local string strRet;

	if(PF.IsA('UTWeaponPickupFactory'))
		strRet = GetInventoryTypeFromFactory(PF) $ ".WeaponPickup";
	else if (PF.IsA('UTAmmoPickupFactory'))
		strRet = GetInventoryTypeFromFactory(PF) $ ".AmmoPickup";
	else if (PF.IsA('UTHealthPickupFactory'))
		strRet = GetInventoryTypeFromFactory(PF) $ ".HealthPickup";
	else if (PF.IsA('UTArmorPickupFactory'))
		strRet = GetInventoryTypeFromFactory(PF) $ ".ArmorPickup";
	else if (PF.IsA('UTDeployablePickupFactory'))   // A deployable is a weapon too
		strRet = GetInventoryTypeFromFactory(PF) $ ".WeaponPickup";
	/*else if (PF.IsA('UTPowerupPickupFactory'))    // Maybe a future option
		strRet = GetInventoryTypeFromFactory(PF) $ ".Powerup";*/
	else 
		strRet = GetInventoryTypeFromFactory(PF) $ ".Pickup";

	return strRet;
}

/**
 * Provides InventoryType string for ITC message
 * 
 * @note: add support for deployable weapons
 * @return Returns InventoryType string in GB protocol
 * 
 * @param PF PickupFactory to export
 */ 
public static function string GetInventoryTypeFromFactory(PickupFactory PF)
{
	local string strRet, h;
	local int i;

	//cuts the prefix ending with '_'
	strRet = Mid(PF.Class,InStr(PF.Class,"_") + 1);

	//cuts the prefix UTAmmo_ and adds Ammo suffix
	if (PF.IsA('UTAmmoPickupFactory')){
		i = Instr(strRet,"_");
		if (i > -1) strRet = Left(strRet,i);
		strRet $= "Ammo";
	}
	//cuts UTWeapon_ prefix and _content suffix
	else if (PF.IsA('UTWeaponPickupFactory')){
		h $= PF.InventoryType;
		strRet = Mid(h,InStr(h,"_") + 1);
		i = Instr(strRet,"_");
		if (i > -1) strRet = Left(strRet,i);
	}
	else if (PF.IsA('UTDeployablePickupFactory')) {
		return string(PF.InventoryType); 
	}
	// just return "WeaponLocker" because every weaponlocker is the same
	else if (PF.IsA('UTWeaponLocker')) {
		return "WeaponLocker"; 
	}
	// cut prefix UTPickupFactory, @note: maybe an option for the future
/*	else if (PF.IsA('UTPowerupPickupFactory')) {
		return strRet;
	} */

	return strRet;
}


public static function string GetPickupTypeFromInventory(Inventory INV)
{
	local string strRet;

	if (INV.IsA('UTDeployable')) {
		strRet = GetInventoryTypeFromInventory(INV) $ ".WeaponPickup";
	}
	else if (INV.IsA('UTWeapon')){
		strRet = GetInventoryTypeFromInventory(INV) $ ".WeaponPickup";
	}
	else strRet = GetInventoryTypeFromInventory(INV) $ ".Pickup";

	return strRet;
}

public static function string GetInventoryTypeFromInventory(Inventory INV)
{
	local string strRet;
	local Int i;

	if (INV.IsA('UTDeployable')) {
		return string(INV.Class); 
	}
	if (INV.IsA('UTWeapon')){
		strRet = Mid(INV.Class,InStr(INV.Class,"_") + 1);
		i = Instr(strRet,"_");
		if (i > -1) strRet = Left(strRet,i);
	}
	else if (INV.IsA('UTJumpBoots')){
		strRet = "JumpBoots";
	}
	else if (INV.IsA('UTTimedPowerup')){
		//just cut the UT from class name
		strRet = Mid(Inv.class,2);
	}
	else strRet = string(INV.Class);

	return strRet;
}

//Here the unique IDs are created from objects in UT
/**
 * Provides an unique ID for an Actor.
 * 
 * @return Returns Players ID for Players. For Pawns it returns name of 
 * asociated Controller and ID of controlling player. 
 * Otherwise it returns name of the Actor.
 * 
 * @param inputActor input Actor.
 */ 
public static function string GetUniqueId(Actor inputActor)
{
    if (inputActor == none)
        return "None";

    if (inputActor.IsA('Controller')){
        if (Controller(inputActor).PlayerReplicationInfo != none)
            return inputActor $ Controller(inputActor).PlayerReplicationInfo.PlayerID;

    } else if (inputActor.IsA('Pawn')) {
        if (Pawn(inputActor).Controller != none && Pawn(inputActor).Controller.PlayerReplicationInfo != none)
            return Pawn(inputActor).Controller $ Pawn(inputActor).Controller.PlayerReplicationInfo.PlayerID;
    }

    return string(inputActor);
}

/**
 * Provides initial amount of armor of a pawn class
 * @note Used UTPawn.GetShieldStrength() as a template
 * 
 * @todo Should this be here or should it exist at all??
 */ 
public static function int GetInitialArmor(class<UTPawn> pawnClass)
{
	return pawnClass.default.ShieldBeltArmor + pawnClass.default.VestArmor + 
		pawnClass.default.ThighpadArmor + pawnClass.default.HelmetArmor;
}

/**
 * Provides Maximum amount of Armor a pawn can have at a time.
 * @note Used UTPawn.GetShieldStrength() as a template.
 */ 
public static function int GetMaxArmor()
{
	return class'UTArmorPickup_ShieldBelt'.default.ShieldAmount + 
		class'UTArmorPickup_Vest'.default.ShieldAmount + 
		class'UTArmorPickup_Thighpads'.default.ShieldAmount + 
		class'UTArmorPickup_Helmet'.default.ShieldAmount;
}

DefaultProperties
{
}
