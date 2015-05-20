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
class GBArrowComponent extends ArrowComponent;

/** collision color */
var Color hitColor;
/** clear color */
var Color clearColor;
/** id of the arrow
 *  @note it must match the id of the 
 *      traceRay in TraceManager
 *      */
var string id;
/** indicates if the arrow collided */
var bool bHit;

/** length of the arrow in unreal units */
var const float arrowBaseSize;

/**
 * Changes the color of the arrow to hitColor
 */ 
function hit(){
	ArrowColor = hitColor;
	bHit = true;
}

/**
 * Changes the color of the arrow to the clearColor
 */ 
function clear(){
	ArrowColor = clearColor;
	bHit = false;
}

/**
 * Sets proper length of the arrow
 * 
 * @note Never set ArrowSize variable by hand, use this 
 *      function! 
 * 
 * @note The actual length od the arrow is computed as
 *      ArrowSize * ArrowBaseSize, where ArrowBaseSize 
 *      has been measured as 48 unreal units. So if we
 *      want to make the arrow as long as the length parameter
 *      in unreal units we have to divide the length parameter
 *      by BaseArrowSize * Scale.
 *      
 *      @param length Desired length in unreal units.
 */ 
function setLength(float length){
	ArrowSize = length/(arrowBaseSize * Scale);
}

DefaultProperties
{
	Scale=0.5
	arrowBaseSize=48.0
	//Scale3D=(X=1.0,Y=1.0,Z=1.0);
	ArrowColor=(R=0,G=0,B=255,A=0)
	hitColor=(R=255,G=0,B=0)
	clearColor=(R=0,G=255,B=0)
	bHit=false;
	ArrowSize=1.0
	AbsoluteScale=true;
	HiddenGame=false
	AlwaysLoadOnServer=true
	AlwaysLoadOnClient=true
}
