DEFINE_BASECLASS("weapon_mw_base");
SWEP.Spawnable = true;
SWEP.AdminOnly = false;

-- General weapon stuff.
-- Weapon name.
SWEP.PrintName = "AK-47";
-- Weapon category.
SWEP.Category = "More Weapons!"
-- Slot
SWEP.Slot = 2;

-- Weapon appearance and sounds.
-- View model.
SWEP.ViewModel	= Model("models/weapons/v_rif_ak47.mdl");
-- World model.
SWEP.WorldModel = Model("models/weapons/w_rif_ak47.mdl");
-- Field of view of the viewmodel.
SWEP.ViewModelFOV = 78;
-- Changes if you are holding the gun left or right handed.
SWEP.ViewModelFlip = true;
-- How do you hold this gun?
SWEP.HoldType	= "ar2";
-- This sound will be played when the gun is fired.
SWEP.FireSound	= "Weapon_AK47.Single";
-- This sound will play together with fire sound when the last bullet is fired out of the gun, if you have a .wav file containing both the firing sound and some additional dry fire sound fill it into the var underneath.
SWEP.DryFire	= nil;
-- If defined (not nil) this sound will be played alone instead of both FireSound and DryFire being played.
SWEP.DryFireSound	= nil;

-- How many cycles per second this weapon can do, this is the delay between firing the gun again after shooting it.
SWEP.CycleRate	= 600;
-- How many rounds per second this weapon can shoot this shouldn't affect single shot weapons but if you have burst fire weapon this will directly affect the time between the individual shots are fired, if set to 0 the shots will be fired simultaneously in same frame, good for shotguns!
SWEP.FireRate	= 600;
-- Controls the burst size, this number must always be higher than 0.
SWEP.BurstSize	= 1;
-- How many bullets can fit in one magazine.
SWEP.ClipSize	= 30;
-- Initial or "raw" damage of the weapon at zero range against unarmored opponents.
SWEP.Damage		= 67;
-- Max distance that the bullet can travel before disappearing, in feet.
SWEP.Range      = 2346;
-- Base Inaccuracy of the weapon.
SWEP.InaccuracyStand    = 0.47;
-- Base Inaccuracy of the weapon when crouched.
SWEP.InaccuracyCrouch   = 0.39;
-- Inaccuracy from firing.
SWEP.InaccuracyFire	= 0.29;
-- Inaccuracy from movement.
SWEP.InaccuracyMove	= 0.77;
-- Max Inaccuracy from firing.
SWEP.InaccuracyMax	= 2.27;
-- How long does it take to regain max accuracy from max inaccuracy.
SWEP.RecoveryTimeStand  = 1.37;