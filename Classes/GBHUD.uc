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

/**
 *  Draws additional information on player`s screen.
 *  @note Features:
 *          - Visualizes navigation graph, names of navigation points
 *          - Additional player information (name, position, health bar, 
 *              movement vector, FOV, bots current route)
 *          - GB debug info (last command)
 *          - list of connected players
 *          - HUD help (anebled and disabled features with asociated keys)
 *          - Displays text bubbles
 */ 
class GBHUD extends UTHUD
        config(GameBotsUT3);
`include(Globals.uci);
//How many points we should shift in y coordinate to write next line of the text on the HUD
//properly
var float HUDLineShift;

//We will be drawing names of navigation points that are in radius below
var config float NavPointBeaconDrawDistance;

//private boolean
var private bool bPressedCtrl;

// custom Interaction through which we handle key inputs (thanks Wormbo :-) )
var Interaction KeyCaptureInteraction; 

//Some variables for setting what should be visible on the HUD
var config bool bDrawNavPointsNames;
var config bool bDisplayDebug;
var config bool bDisplayHelp;
var config bool bDisplayInformation;
var config bool bDisplayPlayerList;
var config bool bDisplayRoute;
var config bool bDisplayHealthBar;
var config bool bDisplayTextBubble;
var config bool bDisplayMyLocation;
var config int DrawNavPointsGrid;
var config bool bDisplayNavCubes;
var config int DisplayPlayerPositions;

//player view information- will be used in FOV checking code (InFOV fc)
var vector ViewLocation;
var rotator ViewRotation;

//setting of our custom colors
var int DefaultColorR, DefaultColorG, DefaultColorB, DefaultColorA;
var int EnabledColorR, EnabledColorG, EnabledColorB, EnabledColorA;
var int DisabledColorR, DisabledColorG, DisabledColorB, DisabledColorA;

//Cubes floating at NavPoint positions.
var array<GBPathMarker> pathMarkers;

var float TextBubbleMaxDist;

/**
 * Sets up the key capture interaction
 */ 
simulated function PostBeginPlay()
{
    local int iInput;
	local GBPathMarker PathMarker;
	local NavigationPoint nav;
    
    Super.PostBeginPlay();
    
    KeyCaptureInteraction = new(PlayerOwner) class'Interaction';
    KeyCaptureInteraction.OnReceivedNativeInputKey = ReceivedNativeInputKey;

    // insert before input interaction to capture movement keys, if necessary
    iInput = PlayerOwner.Interactions.Find(PlayerOwner.PlayerInput);
    PlayerOwner.Interactions.InsertItem(Max(iInput, 0), KeyCaptureInteraction);

	//spawn all path markers
	foreach WorldInfo.AllActors(class'NavigationPoint', nav){
		PathMarker = Spawn(class'GBPathMarker',,,nav.Location);
		PathMarker.nav = nav;
		PathMarker.DrawGrid();
	}

	bShowHUD = true;
}

/**
 * Main drawing loop. 
 * Here we draw GB specific info that needs to be redrawn every frame.
 */ 
//event PostRender() {
function DrawHUD() {
    local float XPos, YPos;

    //super.PostRender();

    //set up global variables ViewLocation and ViewRotation - will be used in FOV checking code (InFOV fc)
    GetPlayerViewInformation(ViewLocation, ViewRotation);

    XPos = 25;
    YPos = 25;

    if (bDisplayMyLocation)
        DrawMyLocation(XPos, YPos);

    if (bDisplayHelp)
        DrawHelp(XPos, YPos);

    if (bDisplayPlayerList)
        DrawPlayerList(XPos,YPos);

    if (DisplayPlayerPositions > 0)
        DrawPlayerDebug();

    if (bDisplayRoute)
        DrawCustomRoute();

    if (bDrawNavPointsNames)
        DrawNavPointsNames();
	//Navigation graph do not have to be redrawn each tick
	/*
    if (bDrawNavPointsGrid)
		ToggleShowNavGrid();
        //DrawNavPointsGrid();

	if (bDisplayNavCubes)
		ToggleShowNavSpheres();
	*/
	if (bDisplayInformation)
		DrawInformation(XPos,YPos);

    ProcessVisiblePawns();
}

/**
 * Draws healthbars and GB debug info for visible pawns.
 */ 
function ProcessVisiblePawns() {
    local GBReplicationInfo MyRepInfo;
    local Pawn P;
    local Vector PawnPos;
    local Vector CanvasPawnPos;

    foreach DynamicActors(Class'GBReplicationInfo', MyRepInfo) {
        if (MyRepInfo.getMyPawn() != none) {
            P = MyRepInfo.getMyPawn();
             //TODO: Check also distance?
            if (InFOV(P.Location, PlayerOwner.FovAngle, ViewLocation, ViewRotation) && PlayerOwner.LineOfSightTo(P)) {
                PawnPos = P.Location;
                PawnPos.Z += P.EyeHeight;
                CanvasPawnPos = Canvas.Project(PawnPos);

                if (bDisplayTextBubble)
					DrawTextBubble(P, CanvasPawnPos.X, CanvasPawnPos.Y);
                if (bDisplayHealthBar)
                    DrawHealthBar(P);
                if (bDisplayDebug)
                    DrawGBDebug(MyRepInfo, CanvasPawnPos.X, CanvasPawnPos.Y);
            }                  
        }
    }
}

/**
 * Visualizes bots current route.
 */ 
function DrawCustomRoute()
{
    local int i;
    local vector lastPoint, currentPoint, resVect, resNormal;
    local vector CanvasPosOne, CanvasPosTwo;
    local GBReplicationInfo MyRepInfo;

    foreach DynamicActors(Class'GBReplicationInfo', MyRepInfo) {
        for ( i=0; i<32; i++ ) {
			currentPoint = MyRepInfo.GetCustomRoute(i);

            if ( (lastPoint != vect(0,0,0)) && (currentPoint != vect(0,0,0))
                    && InFOV(lastPoint, PlayerOwner.FovAngle, ViewLocation, ViewRotation)
                    && InFOV(currentPoint, PlayerOwner.FovAngle, ViewLocation, ViewRotation))
            {
                //C.DrawText("From: "$lastPoint$" To: "$theBot.GetCustomRoute(i));
                CanvasPosOne = Canvas.Project(lastPoint);
                CanvasPosTwo = Canvas.Project(currentPoint);

                Canvas.Draw2DLine(CanvasPosOne.x, CanvasPosOne.y, CanvasPosTwo.x, CanvasPosTwo.y,MyMakeColor(255,0,0,255));

                resNormal = Normal((currentPoint - lastPoint) cross vect(0, 0, 1));
				resVect = currentPoint - (Normal(currentPoint - lastPoint) * 14);

                //Right line of the arrow
                CanvasPosOne = Canvas.Project(resVect + resNormal * 5);
                CanvasPosTwo = Canvas.Project(currentPoint);

                Canvas.Draw2DLine(CanvasPosOne.x, CanvasPosOne.y, CanvasPosTwo.x, CanvasPosTwo.y,MyMakeColor(255,0,0,255));
                //DrawDebugLine(resVect + resNormal * 5,currentPoint,0,255,0);

                //Left line of the arrow
                CanvasPosOne = Canvas.Project(resVect - resNormal * 5);
                CanvasPosTwo = Canvas.Project(currentPoint);

                Canvas.Draw2DLine(CanvasPosOne.x, CanvasPosOne.y, CanvasPosTwo.x, CanvasPosTwo.y,MyMakeColor(255,0,0,255));

                //Line connecting the ends of our arrow lines
                //DrawDebugLine(resVect + resNormal * 5,resVect - resNormal * 5,0, 255, 0);
            }
            lastPoint = currentPoint;
        }
    }
}

/**
 * Draws GB debug information. For now it displays last GB command.
 */ 
function DrawGBDebug(GBReplicationInfo GBRI, float ScreenLocX, float ScreenLocY)
{
    local float XL,YL;

    //last GB command
    Canvas.SetDrawColor(0,255,255,255);
    Canvas.StrLen(GBRI.GetLastGBCommand(), XL, YL);
    ScreenLocY += 50;
    Canvas.SetPos(ScreenLocX - 0.5*XL , ScreenLocY - YL);
    Canvas.DrawText(GBRI.GetLastGBCommand(),true);

    //last GB path
    //C.StrLen(P.LastGBPath, XL, YL);
    //ScreenLocY += 50;
    //C.SetPos(ScreenLocX - 0.5*XL , ScreenLocY - YL);
    //C.DrawText(P.LastGBPath,true);
}

/**
 * Draws the bots current health ammount using text and health bar
 */
function DrawHealthBar(Pawn P)
{
    local texture HealthTex;
    local vector PawnLocation, CanvasBarEndLocation, CanvasHealthTexLocation;
    local float BarLength, WhiteBarLength;
	local int armor;

	armor = 0;
	If (P.IsA('UTPawn')) {		
		armor += UTPawn(P).ShieldBeltArmor;
		armor += UTPawn(P).VestArmor;
		armor += UTPawn(P).ThighpadArmor;
		armor += UTPawn(P).HelmetArmor;	
	}
    PawnLocation = P.Location;
    //We will draw HealthTex a little bit higher
    PawnLocation.z += 20;
	CanvasHealthTexLocation = Canvas.Project(PawnLocation);
    Canvas.SetPos(CanvasHealthTexLocation.x, CanvasHealthTexLocation.y - 10);
    Canvas.SetDrawColor(155,0,0,255);
    Canvas.DrawText(P.Health $ "%" @ armor $"%",true);

	//Health bar will be 100 ut units big
	//We want to scale the bar according to the distance
    PawnLocation.z -= 100;
    CanvasBarEndLocation = Canvas.Project(PawnLocation);
    BarLength = CanvasBarEndLocation.y - CanvasHealthTexLocation.y;
	WhiteBarLength = BarLength;

    Canvas.SetPos( CanvasHealthTexLocation.x, CanvasHealthTexLocation.y );

    //First we will draw white bar showing 100 health
    //,MyMakeColor(255,255,255,255)
    Canvas.SetDrawColor(255,255,255,255);
    Canvas.DrawTile(Canvas.DefaultTexture, 6, BarLength, 0, 0, Canvas.DefaultTexture.SizeX, Canvas.DefaultTexture.SizeY );

    //Then prepare everything for the second red health bar
    Canvas.SetPos( CanvasHealthTexLocation.x,  CanvasHealthTexLocation.y );

    //We have to do this so (division later in DrawTile fc) because we loose
    //everything behind . because of replication (all floats truncated)
    BarLength = P.Health * BarLength;
    //,MyMakeColor(155,0,0,255)
    Canvas.SetDrawColor(155,0,0,255);
    if (P.Health > 0)
        Canvas.DrawTile(Canvas.DefaultTexture, 6, BarLength / 100, 0, 0, Canvas.DefaultTexture.SizeX, Canvas.DefaultTexture.SizeY );
		
	Canvas.SetPos( CanvasHealthTexLocation.x + 5, CanvasHealthTexLocation.y );
	//First we will draw white bar showing 100 armor
	Canvas.SetDrawColor(255,255,255,255);
	Canvas.DrawTile(Canvas.DefaultTexture, 6, WhiteBarLength, 0, 0, Canvas.DefaultTexture.SizeX, Canvas.DefaultTexture.SizeY );	

	//Then prepare everything for the second orange armor bar
	BarLength = armor * WhiteBarLength;

	Canvas.SetPos( CanvasHealthTexLocation.x + 5,  CanvasHealthTexLocation.y + Round(WhiteBarLength - BarLength / 100));	
	Canvas.SetDrawColor(255,140,0,255);
	if (armor > 0)
		Canvas.DrawTile(Canvas.DefaultTexture, 6, Round(BarLength / 100), 0, 0, Canvas.DefaultTexture.SizeX, Canvas.DefaultTexture.SizeY );		
}

/**
 * Draws text bubble with text of the last message this bot sent.
 * @param P - Pawn that is saying something
 * @param ScreenLocX - X coordinate of the pawn's position
 * @param ScreenLocY - Y coordinate of the pawn's position
 */ 
function DrawTextBubble(Pawn P, float ScreenLocX, float ScreenLocY)
{
	local Vector viewLocation;
	local float distance;
	local float textEndX, textEndY, drawStartX, drawStartY;
	local GBPawn GBP;

	GBP = GBPawn(P);

	/*`logDebug("Started");
	`logDebug("Pawn:" @ GBP);
	`logDebug("bDrawTextBubble:" @ class'GBUtil'.static.GetBoolString(GBP.bDrawTextBubble));
	`logDebug("CanSee:" @ class'GBUtil'.static.GetBoolString(PlayerOwner.CanSee(GBP)));
	`logDebug("GBP != Player.Pawn" @ class'GBUtil'.static.GetBoolString(GBP != PlayerOwner.Pawn));*/

	if(GBP != none && GBP.bDrawTextBubble && GBP != PlayerOwner.Pawn && PlayerOwner.CanSee(GBP)){
		//`logDebug("After big condition");
		viewLocation = PlayerOwner.Pawn.Location;
		viewLocation.Z += PlayerOwner.Pawn.EyeHeight;
		distance = VSize(viewLocation - GBP.Location);
		if( distance < TextBubbleMaxDist){
			Canvas.StrLen(GBP.bubbleText, textEndX, textEndY);
			//Draw bubble background
			drawStartX = ScreenLocX - 0.6 * textEndX;
			drawStartY = ScreenLocY - 0.75 * textEndY - (GBP.EyeHeight + 30);
			Canvas.SetDrawColor(255,255,255); //White
			Canvas.SetPos(drawStartX, drawStartY);
			Canvas.DrawTile(Canvas.DefaultTexture,textEndX * 1.2,textEndY * 1.5,0,0,Canvas.DefaultTexture.SizeX,Canvas.DefaultTexture.SizeY);
			//Draw bubble frame
			Canvas.SetDrawColor(0,0,0); //Black
			Canvas.SetPos(drawStartX, drawStartY);
			Canvas.DrawBox(textEndX * 1.2 + 1, textEndY * 1.5 + 1);
			//Draw bubble text
			drawStartX = ScreenLocX - 0.5 * textEndX;
			drawStartY = ScreenLocY - 0.5 * textEndY - (GBP.EyeHeight + 30);
			Canvas.SetPos(drawStartX, drawStartY);
			Canvas.DrawText(GBP.bubbleText, false);
		}
	}
}

/**
 * Displays information about navigation grid`s colors.
 * @note this should always be the last text displayed.
 * @todo check the text!
 */ 
function DrawInformation(out float ScreenLocX, out float ScreenLocY)
{
	Canvas.SetDrawColor(DefaultColorR,DefaultColorG,DefaultColorB,DefaultColorA);
    Canvas.SetPos(ScreenLocX, ScreenLocY);
	Canvas.DrawText("Reachability grid now has oriented edges. Colours info: if"$
	" one of the flags is R_PROSCRIBED or R_PLAYERONLY or R_FLY the colour of the"$
	" edge will be red regardless of any other flags. if the flag is R_JUMP and R_SPECIAL"$
	" the colour will be white. if the flag is R_JUMP the colour will be dark yellow."$
	" if the flag is not R_JUMP and if it is R_SPECIAL the colour will be blue."$
	" if none of these conditions were fullfilled yet and the flag is R_DOOR,"$
	" R_LADDER or R_SWIM the colour will be black. In other cases (flag can be"$
	" R_WALK or R_FORCED) the colour will be yellow. ",true);
	ScreenLocY += HUDLineShift;
}

/**
 * Draws bot`s position, name, distance (from our pawn), focus and FOV
 * @todo check the peripheral limit calculation
 *      added /2 to the formula and it seems more probable
 */ 
function DrawPlayerDebug()
{
    local GBReplicationInfo MyRepInfo;
    //some needed vectors
    local vector PawnVelocity, PawnPosition;
    //some vectors for canvas position counting
    local vector CanvasPawnPosition, CanvasPawnFocus;

    local vector CanvasPosOne, CanvasPosTwo;
    local string PlayerName, FocusName;
    local rotator fovLimit, PawnRotation;
    local float XL, YL;


    foreach DynamicActors(Class'GBReplicationInfo', MyRepInfo) {

        //We want to show here just relevant information
        if (!MyRepInfo.PawnIsNone() && MyRepInfo.getMyPawn() != PlayerOwner.Pawn) {
            /*if ( (PlayerOwner.ViewTarget != none) && (PlayerOwner.ViewTarget.Controller != none) && (PlayerOwner.ViewTarget.Controller.PlayerReplicationInfo != none ) && (PlayerOwner.ViewTarget.Controller.PlayerReplicationInfo == MyRepInfo.MyPRI) )
            {
                    continue;
            }*/
            PawnPosition = MyRepInfo.GetLocation();
            if (InFOV(PawnPosition, PlayerOwner.FovAngle, ViewLocation, ViewRotation)) {

                PlayerName = MyRepInfo.MyPRI.GetHumanReadableName();

                PawnVelocity = MyRepInfo.GetVelocity();

                //Need to draw the name and distance properly
				CanvasPawnPosition = Canvas.Project(PawnPosition);


                //Add information about distance and PlayerName
                if (MyRepInfo.MyPRI.Team != none) {
                    if (MyRepInfo.MyPRI.GetTeamNum() == 0)
                        Canvas.SetDrawColor(200,55,55,255); // red
                    else
                        Canvas.SetDrawColor(55,55,200,255); //blue
                } else
                    Canvas.SetDrawColor(200,55,55,255); // red

                PlayerName = VSize(PawnPosition - ViewLocation) $ " " $ PlayerName;
                Canvas.StrLen(PlayerName, XL, YL);
                Canvas.SetPos(CanvasPawnPosition.x - 0.5*XL , CanvasPawnPosition.y - YL);
                Canvas.DrawText(PlayerName,true);

                        
                if (MyRepInfo.MyPRI.bHasFlag) {
                    Canvas.SetDrawColor(255,255,255,255); //white
                    Canvas.SetPos(CanvasPawnPosition.x - 0.5 * XL - 10, CanvasPawnPosition.y - YL - 5);
					Canvas.DrawBox(XL + 10,YL + 5);
				}

                //draw velocity line
                //if (InFOV(PawnPosition + PawnVelocity, PlayerOwner.FovAngle, ViewLocation, ViewRotation))
                //{
                    CanvasPosTwo = Canvas.Project(PawnPosition + PawnVelocity);
                    Canvas.Draw2DLine(CanvasPawnPosition.x, CanvasPawnPosition.y, CanvasPosTwo.x, CanvasPosTwo.y,MyMakeColor(255,0,0,255));
                //}
				//DrawDebugLine(PawnPosition, PawnPosition + PawnVelocity, 255,0,0);

                //Draw3DLine(PawnPosition,PawnPosition + MyRepInfo.GetVelocity(),class'Canvas'.Static.MakeColor(255,0,0));


                        
                if (DisplayPlayerPositions >= 2){
                    //DrawFocus                             
                    CanvasPawnFocus = Canvas.Project(MyRepInfo.GetFocus());
                    FocusName = MyRepInfo.GetFocusName();

                    //if (InFOV(MyRepInfo.GetFocus(), PlayerOwner.FovAngle, ViewLocation, ViewRotation))
                    //{
                        CanvasPosTwo = Canvas.Project(MyRepInfo.GetFocus());

                        Canvas.Draw2DLine(CanvasPawnPosition.x, CanvasPawnPosition.y, CanvasPosTwo.x, CanvasPosTwo.y,MyMakeColor(255,255,255,255));
                    //}
					//DrawDebugLine(PawnPosition, MyRepInfo.GetFocus(),255,255,255);

					if (FocusName != ""){
						Canvas.StrLen(FocusName, XL, YL);
						Canvas.SetPos(CanvasPawnFocus.x - 0.5*XL , CanvasPawnFocus.y - YL);
						Canvas.DrawText(FocusName,true);
					}

					//DrawFOV - approx right now
					fovLimit.pitch = 0;
		            
					/**
					 * @todo check the peripheral vision limit calculation!
					 */ 
					//fovLimit.Yaw = ((acos(MyRepInfo.getMyPawn().PeripheralVision) * 57.2957795) * 182.1);
					fovLimit.yaw = ((acos(MyRepInfo.getMyPawn().PeripheralVision) * 57.2957795)* 182.1)/2;
					fovLimit.Roll = 0;

					PawnRotation = MyRepInfo.GetRotation();

					//First FOV line
					//if (InFOV(PawnPosition + vector(PawnRotation - fovLimit) * 300, PlayerOwner.FovAngle, ViewLocation, ViewRotation))
					//{
						CanvasPosTwo = Canvas.Project(PawnPosition + vector(PawnRotation - fovLimit) * 300);

						Canvas.Draw2DLine(CanvasPawnPosition.x, CanvasPawnPosition.y, CanvasPosTwo.x, CanvasPosTwo.y,MyMakeColor(255,255,0,255));
					//}
					//DrawDebugLine(PawnPosition, PawnPosition + vector(PawnRotation - fovLimit) * 300, 255,255,0);

						//Second FOV line
						//if (InFOV(PawnPosition + vector(PawnRotation + fovLimit) * 300, PlayerOwner.FovAngle, ViewLocation, ViewRotation))
						//{
							CanvasPosTwo = Canvas.Project(PawnPosition + vector(PawnRotation + fovLimit) * 300);

							Canvas.Draw2DLine(CanvasPawnPosition.x, CanvasPawnPosition.y, CanvasPosTwo.x, CanvasPosTwo.y,MyMakeColor(255,255,0,255));
						//}
					//DrawDebugLine(PawnPosition, PawnPosition + vector(PawnRotation + fovLimit) * 300, 255,255,0);

                }
            }
        }
    }
}


/**
 * Displays list of GB bots and their location, rotation and velocity
 */ 
function DrawPlayerList(out float ScreenLocX, out float ScreenLocY)
{
    local GBReplicationInfo MyRepInfo;

    Canvas.setDrawColor(DefaultColorR,DefaultColorG,DefaultcolorB,DefaultColorA);
    Canvas.SetPos(ScreenLocX, ScreenLocY);
    Canvas.DrawText("Player List: ",true);

    foreach DynamicActors(Class'GBReplicationInfo', MyRepInfo)
    {
        //We want to show here just relevant information
        if (!MyRepInfo.PawnIsNone())
        {
            ScreenLocY += HUDLineShift;
            Canvas.SetPos(ScreenLocX, ScreenLocY);
            Canvas.DrawText("Name: "$MyRepInfo.MyPRI.GetHumanReadableName() $
                " Location: "$MyRepInfo.GetLocation() $
                " Rotation: "$MyRepInfo.GetRotation() $
                " Velocity: "$MyRepInfo.GetVelocity(),true);
        }
    }

    ScreenLocY += HUDLineShift;
}

/**
 * Displays list of available features with associated keys and status (enabled/disabled).
 * 
 */
function DrawHelp(out float ScreenLocX, out float ScreenLocY)
{
        Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("GameBots 2004 HUD Help (Red features are off, green on):",true);
        ScreenLocY += HUDLineShift;
        
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + H - Enables/Disables this help",true);
        ScreenLocY += HUDLineShift;

    if (bDisplayInformation)
            Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        else
                Canvas.SetDrawColor(DisabledColorR,DisabledColorG,DisabledColorB,DisabledColorA);
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + I - Enables/Disables additional info (about reachability GRID, etCanvas.)",true);
        ScreenLocY += HUDLineShift;

    if (bDisplayMyLocation)
            Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        else
                Canvas.SetDrawColor(DisabledColorR,DisabledColorG,DisabledColorB,DisabledColorA);
    Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + M - Enables/Disables my location and rotation info.",true);
        ScreenLocY += HUDLineShift;

    if (bDrawNavPointsNames)
            Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        else
                Canvas.SetDrawColor(DisabledColorR,DisabledColorG,DisabledColorB,DisabledColorA);
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + N - Enables/Disables NavPoint names.",true);
        ScreenLocY += HUDLineShift;

    Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + '[' or ']' - Incerase/Decrease drawing range (" $ NavPointBeaconDrawDistance $ ")of NavPoint names.",true);
        ScreenLocY += HUDLineShift;

    if (bDisplayNavCubes)
            Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        else
                Canvas.SetDrawColor(DisabledColorR,DisabledColorG,DisabledColorB,DisabledColorA);
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + C - Enables/Disables Navigation Points cubes visualization.",true);
        ScreenLocY += HUDLineShift;

    if (DrawNavPointsGrid > 0)
            Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        else
                Canvas.SetDrawColor(DisabledColorR,DisabledColorG,DisabledColorB,DisabledColorA);
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + G - Enables/Disables reachability GRID.",true);
        ScreenLocY += HUDLineShift;

    if (bDisplayPlayerList)
            Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        else
                Canvas.SetDrawColor(DisabledColorR,DisabledColorG,DisabledColorB,DisabledColorA);
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + L - Enables/Disables Player List.",true);
        ScreenLocY += HUDLineShift;

    if (DisplayPlayerPositions > 0)
            Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        else
                Canvas.SetDrawColor(DisabledColorR,DisabledColorG,DisabledColorB,DisabledColorA);
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + P - Cycles through additional player info modes.",true);
        ScreenLocY += HUDLineShift;

    if (bDisplayRoute)
            Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        else
                Canvas.SetDrawColor(DisabledColorR,DisabledColorG,DisabledColorB,DisabledColorA);
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + R - Enables/Disables route drawing (when spectating the bot)",true);
        ScreenLocY += HUDLineShift;

    if (bDisplayHealthBar)
            Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        else
                Canvas.SetDrawColor(DisabledColorR,DisabledColorG,DisabledColorB,DisabledColorA);
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + B - Enables/Disables HealthBar",true);
        ScreenLocY += HUDLineShift;

    if (bDisplayTextBubble)
            Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        else
                Canvas.SetDrawColor(DisabledColorR,DisabledColorG,DisabledColorB,DisabledColorA);
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + U - Enables/Disables text bubbles",true);
        ScreenLocY += HUDLineShift;

    if (bDisplayDebug)
            Canvas.SetDrawColor(EnabledColorR,EnabledColorG,EnabledColorB,EnabledColorA);
        else
                Canvas.SetDrawColor(DisabledColorR,DisabledColorG,DisabledColorB,DisabledColorA);
        Canvas.SetPos(ScreenLocX, ScreenLocY);
        Canvas.DrawText("CTRL + D - Enables/Disables debug information",true);
        ScreenLocY += HUDLineShift;
}

/**
 * Displays our current location, rotation and velocity on the HUD
 */
function DrawMyLocation(out float ScreenLocX, out float ScreenLocY)
{
    local vector PlayerLocation, PlayerVelocity;
    local rotator myRotation;
    local string PlayerRotation;

    Canvas.setDrawColor(DefaultColorR,DefaultColorG,DefaultcolorB,DefaultColorA);
    //If we currently control Pawn, we will take its coordinates
    if (PlayerOwner.Pawn != none) {
        PlayerLocation = PlayerOwner.Pawn.Location;
        myRotation = PlayerOwner.Pawn.Rotation;
        //The ViewPitch is something else then Pawn rotation!!!
        //myRotation.Pitch = int(PlayerOwner.Pawn.ViewPitch) * 65556/255;
        PlayerRotation = string(myRotation);
        PlayerVelocity = PlayerOwner.Pawn.Velocity;
	} else if (PlayerOwner.ViewTarget != none) { //If are spectating someone, we will put his coordinates
        PlayerLocation = PlayerOwner.ViewTarget.Location;
        PlayerRotation = string(PlayerOwner.ViewTarget.Rotation);
        PlayerVelocity = PlayerOwner.ViewTarget.Velocity;
    } else { //Otherwise put coordinates of the Controller class (we are spectating now) don't have the body
        PlayerLocation = PlayerOwner.Location;
        PlayerRotation = string(PlayerOwner.Rotation);
        PlayerVelocity = PlayerOwner.Velocity;
    }
    Canvas.SetPos(ScreenLocX, ScreenLocY);
    Canvas.DrawText("My Location: "$PlayerLocation$" My Rotation:"$PlayerRotation$" My Velocity:"$PlayerVelocity,true);
    ScreenLocY += HUDLineShift;
}


/**
 *  Displays names of nearby navigation points.
 */ 
function DrawNavPointsNames()
{
    local NavigationPoint N;
    local vector CanvasPosition;

    local float XL,YL,floatDist;
    Canvas.setDrawColor(DefaultColorR,DefaultColorG,DefaultcolorB,DefaultColorA);

    foreach WorldInfo.AllNavigationPoints(class'NavigationPoint',N) {
        //distance = N.Location - ViewLocation;
        //floatDist = sqrt(square(N.Location.x - ViewLocation.x) + square(N.Location.y - ViewLocation.y) + square(N.Location.z - ViewLocation.z));
        floatDist = VSize(N.Location - ViewLocation);
		if (floatDist <= NavPointBeaconDrawDistance) {
            if(InFOV(N.Location, PlayerOwner.FovAngle, ViewLocation, ViewRotation) && PlayerOwner.FastTrace(N.Location, ViewLocation) )
            {
                CanvasPosition = Canvas.Project(N.Location);
                //This will draw the game Id of the NavPoint
                Canvas.StrLen(string(N), XL, YL);
                Canvas.SetPos(CanvasPosition.X - 0.5*XL , CanvasPosition.Y - YL);
                Canvas.DrawText(string(N),true);
            }
        }
    }
}

/**
 *  Displays the navigation points GRID in the game
 *  @note Obsolate! Do not use!
 *  @note Caused serious perfomance issues. The visualization of navigation graph
 *          was changed.
 *  @note Functionality of this function is handled in ToggleShowNavGrid
 */
function ObsoleteDrawNavPointsGrid()
{
  
}

/**
 * Displays/Hides small shpheres above navigation points 
 *      (vertices of navigation graph)
 * @note the edges of navigation graph are 
 *      displayed by ToggleShowNavGrid function
 */ 
function ToggleShowNavSpheres(){
	local GBPathMarker marker;
	foreach AllActors(class'GBPathMarker', marker){
		marker.toggleHidePoint();
	}
}


/**
 * Displays/Hides edges of the navigation graph
 * @note the vertices are displayed by ToggleShowNavSpheres function
 */ 
function ToggleShowNavGrid(){
	local GBPathMarker marker;
	foreach AllActors(class'GBPathMarker', marker){
		marker.toggleHideGraph();
	}
}
/**
 * Displays/Hides edges widths of the navigation graph
 * @note the vertices are displayed by ToggleShowNavSpheres function
 */ 
function ToggleShowNavGridWidth() {
	local GBPathMarker marker;
	foreach AllActors(class'GBPathMarker', marker){
		marker.toggleHideLinkWidth();
	}
}

/* ================================================ */
/* HELPER FUNCTIONS */
/* ================================================ */

/**
 * Returns CameraLocation and CameraRotation for our current Pawn (if any)
 *  or playerContorller (if we do not have a Pawn)
 */ 
function GetPlayerViewInformation(out vector CameraLocation, out rotator CameraRotation)
{
        if (PlayerOwner.Pawn != none) {
            CameraLocation = PlayerOwner.Pawn.Location;
            CameraRotation = PlayerOwner.Pawn.Rotation;
            //CameraRotation.Pitch = int(PlayerOwner.Pawn.ViewPitch) * 65556/255;
        } else {
            CameraLocation = PlayerOwner.Location;
            CameraRotation = PlayerOwner.Rotation;
        }
}

/**
 * Indicates if the location loc is in camera's field of view. 
 * @note Does not take into account occlusion by geometry!
 * @note Possible optimization: 
 *      Precompute cos(obsController.FovAngle / 2) for InFOV 
 *      - careful if it can change.
 *      
 * @param loc               target location
 * @param FovAngle          field of view angle
 * @param CameraLocation    location of our view point (e.g. Pawn`s eyes) 
 * @param CameraRotation    Rotation of our view point (e.g. Pawn`s rotation)
 * 
 * @return Returns true if the loc is in camera`s FOV
 */ 
function bool InFOV(vector loc, float FovAngle, vector CameraLocation, rotator CameraRotation) {
    local vector view;   // vector pointing in the direction obsController is looking.
    local vector target; // vector from obsController's position to the target location.

    view = vector(CameraRotation);

    target = loc - CameraLocation;
	
	//return Acos(Normal(view) dot Normal(target)) < FovAngle / 2;
    return Acos(Normal(view) dot Normal(target)) * 57.2957795 < FovAngle / 2; // Angle between view and target is less than FOV
    // 57.2957795 = 180/pi = 1 radian in degrees  --  convert from radians to degrees
}

/**
 * Checks for registered keys or commands.
 * @note ctrl is used for jump as default. Using ctrl for HUD control disables
 *      its other functions.
 * @param ControllerId       
 * @param InputKey          
 * @param InputAction       
 * @param AmountDepressed
 * @param bGamePad
 * 
 * @return Returns true if the key capture event should not be parsed in other 
 *      key capture interactions.
 */
function bool ReceivedNativeInputKey(int ControllerId, name InputKey, EInputEvent InputAction, float AmountDepressed, bool bGamepad)
{
    //`log("Key: " $ InputKey);
    if (InputKey == 'LeftControl' || InputKey == 'RightControl')
    if (InputAction == IE_Pressed)
        bPressedCtrl = True;
    else if (InputAction == IE_Released)
        bPressedCtrl = False;

     if (bPressedCtrl && InputAction == IE_Pressed)
     {
        switch (InputKey)
        {
			//Health bar
            case 'B':
                bDisplayHealthBar = !bDisplayHealthBar;
            break;
			//navigation graph vertices
            case 'C':
                bDisplayNavCubes = !bDisplayNavCubes;
				ToggleShowNavSpheres();
            break;
			//GB debug
            case 'D':
                bDisplayDebug = !bDisplayDebug;
            break;
			//navigation graph edges
            case 'G':
                DrawNavPointsGrid++;
                if (DrawNavPointsGrid > 2) {
                	DrawNavPointsGrid = 0;
					ToggleShowNavGrid();
					ToggleShowNavGridWidth();
                } else if (DrawNavPointsGrid == 2) {
					ToggleShowNavGridWidth();
                } else if (DrawNavPointsGrid == 1) {
					ToggleShowNavGrid();                
                }				
            break;
			//HUD help
            case 'H':
                bDisplayHelp = !bDisplayHelp;
            break;
			//navigation graph color info
            case 'I':
                bDisplayInformation = !bDisplayInformation;
            break;
			//player list
            case 'L':
                bDisplayPlayerList = !bDisplayPlayerList;
            break;
			//player`s location and rotation
            case 'M':
                bDisplayMyLocation = !bDisplayMyLocation;
            break;
			//navigation points` names
            case 'N':
                bDrawNavPointsNames = !bDrawNavPointsNames;
            break;
			//player positions
            case 'P':
                DisplayPlayerPositions += 1;
                if (DisplayPlayerPositions > 2)
                    DisplayPlayerPositions = 0;
            break;
			//bot`s curent route
            case 'R':
                bDisplayRoute = !bDisplayRoute;
            break;
			//@todo what is DoTest?
            case 'T':
                //DoTest();
            break;
			//text bubbles
            case 'U':
                bDisplayTextBubble = !bDisplayTextBubble;
            break;
			//increases distance in which the navigation points` names are shown
			case 'LeftBracket':
                if (NavPointBeaconDrawDistance < 4000)
                    NavPointBeaconDrawDistance += 100;
            break;
			//decreases distance in which the navigation points` names are shown
            case 'RightBracket':
                if (NavPointBeaconDrawDistance > 100)
                    NavPointBeaconDrawDistance -= 100;
            break;
			//@todo why?
            case 'LeftShift':


            break;
        }
        return true; //This means that this key combinations won't be parsed by other KeyEvents
    }
    return false;
}

/**
 * Creates a Color structure from specified basic color values
 * @note might be moved it into GBUtil
 * 
 * @param R red
 * @param G green
 * @param B blue
 * @param A alpha
 * 
 * @return Returns color structure.
 */ 
function Color MyMakeColor(int R, int G, int B, int A) {
    local Color myColor;

    myColor.R = R;
    myColor.G = G;
    myColor.B = B;
    myColor.A = A;

    return myColor;
}

DefaultProperties
{
    //enabled feature color
    EnabledColorR=0
    EnabledColorG=155
    EnabledColorB=55
    EnabledColorA=255
    //disabled feature color
    DisabledColorR=155
    DisabledColorG=0
    DisabledColorB=55
    DisabledColorA=255
    //default color
    DefaultColorR=255
    DefaultColorG=255
    DefaultColorB=255
    DefaultColorA=255

    HUDLineShift=15
	NavPointBeaconDrawDistance=500
	TextBubbleMaxDist=500
}