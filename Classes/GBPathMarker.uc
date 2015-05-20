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
class GBPathMarker extends Actor;

`include(Globals.uci);

var NavigationPoint nav;
var Color cLink, cTeleporter, cProscribed, cTranslocator, cJumpPad;

var GBArrowComponent LinkArrow[10];
var GBArrowComponent widthRArrow[10];
var GBArrowComponent widthLArrow[10];

function PostBeginPlay(){
	
}

/**
 * Draws a sphere for the navPoint and arrows for every
 *  link that the navPoint has in it's PathList.
 */ 
function drawGrid(){
	local DrawSphereComponent sphere;
	local GBArrowComponent arrow;
	local ReachSpec rs;
	local float length;
	local Vector direction, translation, resNormal;
	local int i;

	//Define NavPoint visualizer
	sphere = new class'DrawSphereComponent';
	sphere.SphereRadius = 7;
	sphere.SphereColor = cLink;
	sphere.SetHidden(true);
	AttachComponent(sphere);

	i = 0;
	//Each path defined in pathList is visualised
	// by an arrow with color corresponding with the reachSpec of the path.
	foreach nav.PathList(rs){
		if (i >= 10)
			break;
			
		length = VSize(rs.End.Nav.Location - nav.Location);
		direction = rs.End.Nav.Location - nav.Location;
		arrow = new class'GBArrowComponent';
		arrow.setLength(length); 
		arrow.SetRotation(Rotator(direction));
		arrow.ArrowColor = getColor(rs);
		//translation = Normal(direction) * 15;
		//arrow.SetTranslation(translation);
		arrow.SetHidden(true);
		LinkArrow[i] = arrow;
		AttachComponent(arrow);

		resNormal = Normal((rs.End.Nav.Location - nav.Location) cross vect(0, 0, 1));
		//spawning arrows marking the width of the line
		//edgeWidthColor = MyMakeColor(200,200,0,255);
		arrow = new class'GBArrowComponent';
		arrow.setLength(length); 
		arrow.SetRotation(Rotator(direction));
		arrow.ArrowColor = getColor(rs);
		translation = resNormal * rs.CollisionRadius;
		arrow.SetTranslation(translation);
		arrow.SetHidden(true);
		widthLArrow[i] = arrow;
		AttachComponent(arrow);

		arrow = new class'GBArrowComponent';
		arrow.setLength(length); 
		arrow.SetRotation(Rotator(direction));
		arrow.ArrowColor = getColor(rs);
		translation = -resNormal * rs.CollisionRadius;
		arrow.SetTranslation(translation);
		arrow.SetHidden(true);
		widthRArrow[i] = arrow;
		AttachComponent(arrow);
		
		i++;
	}
}

/**
 * Hides or shows the links of the grid.
 */ 
function toggleHideGraph(){
	local int i;
	for (i = 0; i< 10; i++) {
		if (LinkArrow[i] == none)
			break;
		if (LinkArrow[i].HiddenGame) {
			LinkArrow[i].SetHidden(false);
		}
		else LinkArrow[i].SetHidden(true);		
	}
}
/**
 * Hides or shows the width of the links of the grid.
 */ 
function toggleHideLinkWidth(){		
	local int i;
	for (i = 0; i< 10; i++) {
		if (widthRArrow[i] == none || widthLArrow[i] == none)
			break;	
		if (widthRArrow[i].HiddenGame) {
			widthRArrow[i].SetHidden(false);
		}
		else widthRArrow[i].SetHidden(true);	
		if (widthLArrow[i].HiddenGame) {
			widthLArrow[i].SetHidden(false);
		}
		else widthLArrow[i].SetHidden(true);	
	}
}

/**
 * Hides or shows the navPoint sphere.
 */ 
function toggleHidePoint(){
	local DrawSphereComponent sp;

	foreach ComponentList(class'DrawSphereComponent', sp){
		if (sp.HiddenGame){
			sp.SetHidden(false);
		}
		else sp.SetHidden(true);
	}
}

/**
 * Returns color of the link based on reachFlags.
 */ 
function Color getColor(ReachSpec rs){
	if (rs.IsA('UTTranslocatorReachSpec')){
		return cTranslocator;
	}
	else if (rs.IsA('ProscribedReachSpec')){
		return cProscribed;
	}
	else if (rs.IsA('UTJumpPadReachSpec')){
		return cJumpPad;
	}
	else if (rs.reachFlags == 0){
		return cTeleporter;
	}
	else return cLink;
}

DefaultProperties
{
    /*DrawType=DT_StaticMesh
    StaticMesh=StaticMesh'UN_SimpleMeshes.TexPropCube_Dup'
    Skins(0)=Texture'EngineResources.WhiteSquareTexture'
    DrawScale=0.07*/
    bHidden=False
	Rotation=(0,0,0)
	cLink=(R=255,G=255,B=0,A=255) //Yellow
	cTeleporter=(R=0,G=0,B=255,A=255) // Blue
	cProscribed=(R=255,G=0,B=0,A=64) // Transparant Red
	cTranslocator=(R=127,G=0,B=127,A=255) // Pink
	cJumpPad=(R=255,G=0,B=255,A=255) // Purple
}