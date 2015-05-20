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
class GBCTFFlag extends UTCTFFlag
	abstract;

// States
//@note Modified to support GBCopyCTFGame class
auto state Home
{
	ignores SendHome, Score, Drop;

	function SameTeamTouch(Controller C)
	{
		local UTCTFFlag flag;

		if (C.PlayerReplicationInfo.bHasFlag)
		{
			// Score!
			flag = UTCTFFlag(UTPlayerReplicationInfo(C.PlayerReplicationInfo).GetFlag());
			GBCopyUTCTFGame(WorldInfo.Game).ScoreFlag(C, flag);
			SuccessfulCaptureSystem.SetActive(true);
			flag.Score();

		/*	if (C.Pawn != None && UTBot(C) != None && UTBot(C).Squad.GetOrders() == 'Attack')
			{
				UTBot(C).Pawn.SetAnchor(HomeBase);
				UTBot(C).Squad.SetAlternatePathTo(UTCTFSquadAI(UTBot(C).Squad).EnemyFlag.HomeBase, UTBot(C));
			} */
		}
	}
}

//@note Modified to support GBCopyCTFGame class
state Dropped
{
	ignores Drop;

	function SameTeamTouch(Controller c)
	{
		// returned flag
		GBCopyUTCTFGame(WorldInfo.Game).ScoreFlag(C, self);
		SendHome(C);
	}
}

defaultproperties
{
}