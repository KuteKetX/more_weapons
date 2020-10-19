AddCSLuaFile();

SWEP.Spawnable	= false;
SWEP.UseHands	= true;
SWEP.DrawAmmo	= true;
SWEP.Category	= "More weapons!";
SWEP.IsMWWeapon	= true;

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "Inaccuracy", nil);
	self:NetworkVar("Float", 1, "NextShotTime", nil);
	self:NetworkVar("Float", 2, "NextIdleTime", nil);
	self:NetworkVar("Int", 0, "AttacksQueued", nil);
	self:NetworkVar("Int", 1, "SpreadRandomSeed", nil);
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType);
	self:SetSpreadRandomSeed(0);
	--[[
	if (CLIENT) then
		local class = self:GetClass();
		if (!killicon.Exists(class) && self.UsesFontIcons) then
			killicon.AddFont(class, self.KillFont, self.KillIcon, Color(255, 80, 0, 255));
		else
			killicon.Add(class, self.KillIcon, Color(255, 80, 0, 255));
		end
	end
	]]--

	-- TODO: This is bad.
	self.Primary.ClipSize		= self.ClipSize;
	self.Primary.Ammo			= "smg1";
	self.Primary.DefaultClip	= self.ClipSize * 3;
	self.Primary.Automatic		= true;
	self.Secondary = nil;
end

function SWEP:GetCone()
	local owner = self:GetOwner();
	local speed = owner:GetAbsVelocity():Length2D();
	local frac = speed / owner:GetWalkSpeed();
	-- Normalize the fraction to steps of 0.1 to make it less jittery.
	frac = 0.1 * math.ceil(frac / 0.1);
	local inaccuracyMove = frac * self.InaccuracyMove;

	local baseInaccuracy = self.InaccuracyStand;
	if (owner:Crouching() && owner:IsFlagSet(FL_ONGROUND)) then
		baseInaccuracy = self.InaccuracyCrouch;
	end

	return math.rad(baseInaccuracy + self:GetInaccuracy() + inaccuracyMove);
end

-- https://developer.valvesoftware.com/wiki/CShotManipulator
function SWEP:GetSpreadVector(direction, inaccuracy)
	local heading	= direction:Angle();
	local right		= heading:Right();
	local up		= heading:Up();

	math.randomseed(math.random(0, 0x7FFFFFFF));

	local radius	= math.Rand(0, 1) * math.Rand(0.5, 1);
	local theta	= math.Rand(0, math.rad(360));
	-- Convert to cartesian (X/Y) coordinates
	local x = radius * math.sin(theta);
	local y = radius * math.cos(theta);

	return direction + x * inaccuracy * right + y * inaccuracy * up;
end

function SWEP:UpdateInaccuracy()
	local recoveryTime = self.RecoveryTimeStand;

	local inaccuracyDecay = (self.InaccuracyMax / recoveryTime) * FrameTime();
	self:SetInaccuracy(math.max(self:GetInaccuracy() - inaccuracyDecay, 0));
end

function SWEP:BulletTrace(start, endpos)
	return util.TraceLine({
		start = start,
		endpos = endpos,
		mask = MASK_SHOT,
		filter = self:GetOwner()
	});
end

function SWEP:TraceToExit(enterTrace, direction)
	local currentDistance = 0.0;
	local rayExtension = 4.0;

	while (currentDistance < 90) do
		currentDistance = math.min(currentDistance + rayExtension, 90);
	end
end

function SWEP:HandleBulletPenetration(enterTrace, direction)
	if (!self:TraceToExit(enterTrace, direction)) then
		return false;
	end

	return false;
end

function SWEP:MWFireBullets(shootPos, shootDir)
	local owner = self:GetOwner();
	local currentDistance = 0;
	local currentDamage = self.Damage;
	local currentPos = shootPos;
	local maxRange = self.Range * 16;

	while (currentDamage > 0) do
		local endPos = currentPos + (shootDir * (maxRange - currentDistance))
		local enterTrace = self:BulletTrace(currentPos, endPos);

		if (enterTrace.Fraction == 1) then
			break;
		end

		currentDistance = currentDistance + ((maxRange - currentDistance) * enterTrace.Fraction);
		currentDamage = currentDamage * math.pow(0.85, currentDistance / 1600);

		if (IsFirstTimePredicted()) then
			local a, b = Color(255, 0, 0, 127), Color(80, 255, 80, 255);

			if (SERVER) then
				a, b = Color(0, 0, 255, 127), Color(255, 255, 0, 255);
			end

			debugoverlay.Box(enterTrace.HitPos, Vector(-2, -2, -2), Vector(2, 2, 2), 4, a);
			debugoverlay.Line(enterTrace.StartPos, enterTrace.HitPos, 4, a, false);

			debugoverlay.EntityTextAtPosition(enterTrace.HitPos, 0, Format("Damage: %0.1f", currentDamage), 4, b);
			debugoverlay.EntityTextAtPosition(enterTrace.HitPos, 1, Format("Distance: %0.1fft", currentDistance / 16), 4, b);
		end

		owner:FireBullets({
			Src = currentPos,
			Dir = shootDir,
			Damage = currentDamage,
			Force = 2.4,
			Tracer = 0,
			Callback = function(attacker, trace, damageInfo)
				if (!IsFirstTimePredicted()) then
					return;
				end

				local effectData = EffectData();
				effectData:SetOrigin(trace.HitPos + trace.HitNormal);
				effectData:SetNormal(trace.HitNormal);
				util.Effect("AR2Impact", effectData);

				if (CLIENT) then
					local flash = DynamicLight(trace.HitPos:Length())
					if (flash) then
						flash.pos = trace.HitPos;
						flash.dir = trace.Normal;
						flash.innerangle = 0;
						flash.outerangle = 0;
						flash.r = 255;
						flash.g = 80;
						flash.b = 0;
						flash.brightness = 3;
						flash.Decay = 250;
						flash.Size = 16;
						flash.DieTime = CurTime() + 1
					end
				end
			end
		}, false);

		local penetration, newPos = self:HandleBulletPenetration();
		if (!penetration) then
			break;
		end
	end
end

function SWEP:FireQueuedAttacks()
	if (self:Clip1() == 0 || self:GetAttacksQueued() == 0 || self:GetNextShotTime() > CurTime()) then
		return;
	end

	-- We have to do this mess again to make firerate framerate independent lol.
	local numShots = 0;
	local fireDelay = (60 / self.FireRate);
	self:SetNextShotTime(CurTime());
	while (self:GetNextShotTime() <= CurTime()) do
		numShots = numShots + 1;
		self:SetNextShotTime(self:GetNextShotTime() + fireDelay);
	end

	if (numShots >= self:Clip1()) then
		numShots = self:Clip1();

		if (self.DryFireSound) then
			self:EmitSound(self.DryFireSound, 75, 100, 1, CHAN_AUTO);
		elseif (self.DryFire) then
			self:EmitSound(self.DryFire, 75, 100, 1, CHAN_AUTO);
		end
	end

	self:SetAttacksQueued(self:GetAttacksQueued() - numShots);
	self:SetInaccuracy(math.min(self:GetInaccuracy() + self.InaccuracyFire * numShots, self.InaccuracyMax));
	self:TakePrimaryAmmo(numShots);

	local owner = self:GetOwner();
	local aimVector = owner:GetAimVector();
	local shootPos = owner:GetShootPos();
	local randomSeed = self:GetSpreadRandomSeed();

	owner:MuzzleFlash();
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK);
	owner:SetAnimation(PLAYER_ATTACK1);
	self:SetNextIdleTime(CurTime() + self:SequenceDuration());
	math.randomseed(randomSeed);
	self:SetSpreadRandomSeed((randomSeed + 1) % 0x7FFFFFFF);

	for i = 1, numShots do
		self:EmitSound(self.FireSound, 75, 100, 1, CHAN_AUTO);
		self:MWFireBullets(shootPos, self:GetSpreadVector(aimVector, self:GetCone()));
	end
end

function SWEP:IdleThink()
	if (CurTime() <= self:GetNextIdleTime()) then
		return;
	end

	self:SendWeaponAnim(ACT_VM_IDLE);
	self:SetNextIdleTime(CurTime() + self:SequenceDuration());
end


function SWEP:Think()
	self:IdleThink();
	self:UpdateInaccuracy();
	self:FireQueuedAttacks();
end

function SWEP:PrimaryAttack()
	if (!self:CanPrimaryAttack()) then
		return;
	end

	-- We have to do this mess to make firerate framerate independent lol.
	local numAttacks = 0;
	local cycleTime = (60 / self.CycleRate);
	self:SetNextPrimaryFire(CurTime());
	while (self:GetNextPrimaryFire() <= CurTime()) do
		numAttacks = numAttacks + 1;
		self:SetNextPrimaryFire(self:GetNextPrimaryFire() + cycleTime);
	end

	self:SetAttacksQueued(math.min(self:GetAttacksQueued() + (self.BurstSize * numAttacks), self:Clip1()));
	self:FireQueuedAttacks();
end

function SWEP:SecondaryAttack()

end

function SWEP:DoDrawCrosshair(x, y)
	local owner = LocalPlayer();

	if (!IsValid(owner) || !owner:Alive()) then
		return;
	end

	local spreadFov = math.deg(self:GetCone());
	local screenFov = 0.5 * math.deg(2 * math.atan((ScrW() / ScrH()) * (3 / 4) * math.tan(0.5 * math.rad(owner:GetFOV())))); --To calculate your actual fov based on your aspect ratio
	local srAngle = 180 - (90 + screenFov);
	local scrSide = ((0.5 * ScrW()) * math.sin(math.rad(srAngle))) / math.sin(math.rad(screenFov));
	local arAngle = 180 - (90 + spreadFov);
	local fixedFov = (scrSide * math.sin(math.rad(spreadFov))) / math.sin(math.rad(arAngle))
	local maxFov = math.sqrt(((0.5 * ScrW()) ^ 2) + ((0.5 * ScrH()) ^ 2));

	if (spreadFov > 0 && fixedFov <= maxFov && spreadFov <= owner:GetFOV()) then
		local eyeTrace = owner:GetEyeTrace();
		local gap = math.ceil(fixedFov);
		local color = Color(0, 255, 0, 255);
		local hitEntity = eyeTrace.Entity;
		if (IsValid(hitEntity) && (hitEntity:IsPlayer() || hitEntity:IsNPC() || hitEntity:IsNextBot())) then
			color = Color(255, 0, 0);
		end

		surface.SetDrawColor(Color(0, 0, 0, 205));
		surface.DrawRect(x - 1, y - 1, 3, 3);
		surface.DrawRect((x - 1) + gap, y - 1, 8, 3);
		surface.DrawRect((x - 1) - (5 + gap), y - 1, 8, 3);
		surface.DrawRect((x - 1), (y - 1) + gap, 3, 8);
		surface.DrawRect((x - 1), (y - 1) - (5 + gap), 3, 8);

		surface.SetDrawColor(color);
		surface.DrawRect(x, y, 1, 1);
		surface.DrawRect(x + gap, y, 6, 1);
		surface.DrawRect(x - (5 + gap), y, 6, 1);
		surface.DrawRect(x, y + gap, 1, 6);
		surface.DrawRect(x, y - (5 + gap), 1, 6);
	end

	return true;
end