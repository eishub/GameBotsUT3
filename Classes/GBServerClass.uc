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
class GBServerClass extends TcpLink abstract
        config(GameBotsUT3);
`include(Globals.uci);
`define debug;

//Port we want to connect to
var int DesiredPort;

//Port we are connected to
var int ListenPort;

var config int MaxConnections;

var bool bBound;
var config bool bDebug;

var int ConnectionCount;

//List of all connections spawned by this server
var GBClientClass ChildList;

//Indicates if the server has been locked by lock command.
var bool bLocked;

//List of closed connections waiting to be destroyed
var array<GBClientClass> closedConns;

//shouldn't happen
event ReceivedText( string Text )
{
    `LogError("ReceivedText called on server! Text: " $ Text);
}

//should never happen - accepted connections should be forwarded to a botconnection
event Accepted()
{
    `LogError("Accepted called on server!");
}

//called everytime a new botconnection is spawneds
/**
 * Handles registering new connections.
 * 
 * @note If the server reaches maximum number of connections
 * (32) it stops listening.
 * 
 * @param C new connection
 */ 
event GainedChild( Actor C )
{
    local GBClientClass NewChild;
    local GBClientClass IteratorChild;

	`LogDebug(C);

    Super.GainedChild(C);

    if (C.IsA('GBClientClass')) NewChild = GBClientClass(C);
	else {
        `LogError("Wrong child class! child.class: " $ C.Class);
        return;
    }

    if (ConnectionCount == 0) ChildList = NewChild;
	else {
            IteratorChild = ChildList;
            while (IteratorChild.Next != None) { //add child to the end of the list
                    IteratorChild = IteratorChild.Next;
            }
            IteratorChild.Next = NewChild;
    }

    ConnectionCount++;

    // if too many connections, close down listen.
    if(MaxConnections > 0 && ConnectionCount >= MaxConnections 
    	&& LinkState == STATE_Listening){
			`LogDebug("Server full closing down listen!");
            Close();
    }
}

/**
 * Handles revoking registration of closing connection.
 * 
 * @note If the server was not listening due to having maximum
 * number of connections it would start listening again.
 */ 
event LostChild( Actor C )
{
    local GBClientClass LostChild;
    local GBClientClass IteratorChild, Previous;

    Super.LostChild(C);

    if (C.IsA('GBClientClass')) LostChild = GBClientClass(C);
    else{
        `LogError("Wrong child class! child.class: " $ C.Class);
		return;
    }

    if (ConnectionCount == 0){
		`LogError("No connections!");
        return;
    }

    if (ConnectionCount == 1) ChildList = None;
    else{
        IteratorChild = ChildList;
        Previous = None;

        while (IteratorChild != LostChild) {
                Previous = IteratorChild;
                IteratorChild = IteratorChild.Next;
        }
        if (IteratorChild == None){
            `LogError("child not found!");
            return;
        }
        else {
            if (Previous == None) ChildList = IteratorChild.Next;
            else Previous.Next = IteratorChild.Next;
        }
    }

    ConnectionCount--;

    // if closed due to too many connections, start listening again.
    if (ConnectionCount < MaxConnections && LinkState != STATE_Listening){
        if (!bLocked){
            Listen();
			`LogDebug("Opening server again; LinkState: " 
				$ LinkState $ " ConnectionCount: " $ ConnectionCount);
        }
    }
	`LogDebug("child: " $ C);
}

/**
 * @todo Seems unused anywhere; consider deleting
 */
/*
function Initiate()
{
        `log("GBServerClass - Initate() should not be called");
}*/

/**
 * Notifies the server that some connection has closed.
 * 
 * @param conn closed connection
 */ 
function NotifyClosedConn(GBClientClass conn)
{
	closedConns.AddItem(conn);
}

/**
 * Ensures proper destruction of closed connections.
 */ 
function ClearClosedConn()
{
	local int i;
	for (i = 0; i < closedConns.Length; i++){
		closedConns[i].Destroy();
	}
	closedConns.Remove(0,closedConns.Length);
}

auto state running
{
Begin:
	ClearClosedConn();
	Sleep(5.0);
	goto('Begin');
}

defaultproperties
{
    MaxConnections=3
    bLocked=false
    AcceptClass=Class'GameBotsUT3.BotConnection'
	bDebug=true
}