class GBDeployableSlowVolume extends UTDeployableSlowVolume;

simulated function bool AllowSwitchTo(Weapon NewWeapon)
{
	return true;
}

DefaultProperties
{
}
