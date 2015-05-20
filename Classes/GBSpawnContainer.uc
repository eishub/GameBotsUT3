/*
 * Container to spawn individual items
 */
class GBSpawnContainer extends Actor config(GameBotsUT3);

function postbeginplay()
{	
}

/**
 * Adds item to player inventory.
 */
function SpawnCopyFor(Pawn P)
{
}

/**
 * Should destroy item instead of respawn it.
 */
function SetRespawn()
{
	self.Destroy();
}
