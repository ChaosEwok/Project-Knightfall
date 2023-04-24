require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"

-- Charged primary ability
NebKFEnhancedChargeFire = WeaponAbility:new()

function NebKFEnhancedChargeFire:init()
	self.weapon:setStance(self.stances.idle)

	self.cooldownTimer = 0
	self.chargeTimer = 0
	
	self.npcUser = world.entityType(activeItem.ownerEntityId()) == "npc"

	self.useChargeMuzzleOffset = false

	self.weapon.onLeaveAbility = function()
		self.weapon:setStance(self.stances.idle)
	end
end

function NebKFEnhancedChargeFire:update(dt, fireMode, shiftHeld)
	WeaponAbility.update(self, dt, fireMode, shiftHeld)

	self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

	if self.fireMode == (self.activatingFireMode or self.abilitySlot)
		and self.cooldownTimer == 0
		and not self.weapon.currentAbility
		and not world.lineTileCollision(mcontroller.position(), self:firePosition())
		and not status.resourceLocked("energy") then

		self:setState(self.charge)
	end
end

function NebKFEnhancedChargeFire:charge()
	self.weapon:setStance(self.stances.charge)

	self.chargeTimer = 0

	while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
		self.chargeTimer = self.chargeTimer + self.dt

		self.chargeLevel = self:currentChargeLevel()

		if self.chargeLevel.autoFire and (self.chargeTimer > self.chargeLevel.time) then
			break
		end
		
		if self.chargeLevel.chargeAnimationState and animator.animationState("firing") ~= self.chargeLevel.chargeAnimationState then
			animator.setAnimationState("firing", self.chargeLevel.chargeAnimationState)
		elseif not self.chargeLevel.chargeAnimationState and animator.animationState("firing") == "off" then
			animator.setAnimationState("firing", "charge")
		end
		
		--Movement Modifiers
		mcontroller.controlModifiers({
			runningSuppressed = self.chargeLevel.walkWhileCharging or self.walkWhileCharging or false,
			jumpingSuppressed = self.chargeLevel.allowJumping or self.allowJumping or false
		})

		coroutine.yield()
	end

	if self.chargeLevel and (self.chargeLevel.energyCost == 0 or status.overConsumeResource("energy", self.chargeLevel.energyCost)) then
		if self.chargeLevel.fireType == "single" and status.overConsumeResource("energy", self.chargeLevel.energyCost) then
			self:setState(self.single)
		elseif self.chargeLevel.fireType == "burst" then
			self:setState(self.burst)
		end
	end
end

function NebKFEnhancedChargeFire:single()
	if self.chargeLevel.chargeMuzzleOffset then
		self.useChargeMuzzleOffset = true
	end

	if world.lineTileCollision(mcontroller.position(), self:firePosition()) then
		animator.setAnimationState("firing", "off")
		self.cooldownTimer = self.chargeLevel.cooldown or 0
		self:setState(self.cooldown, self.cooldownTimer)
		return
	end
	
	self.weapon:setStance(self.stances.fire)
	
	self:fireProjectile()
	self:muzzleFlash()
	
	if self.chargeLevel.recoilKnockbackVelocity then
		--If not crouching or if crouch does not impact recoil
		if not (self.chargeLevel.crouchStopsRecoil and mcontroller.crouching()) then
			local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.chargeLevel.recoilKnockbackVelocity)
			--If aiming down and not in zero G, reset Y velocity first to allow for breaking of falls
			if (self.weapon.aimAngle <= 0 and not mcontroller.zeroG()) then
				mcontroller.setYVelocity(0)
			end
			mcontroller.addMomentum(recoilVelocity)
			if not self.npcUser then
				mcontroller.controlJump()
			end
		--If crouching
		elseif self.chargeLevel.crouchRecoilKnockbackVelocity then
			local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.chargeLevel.crouchRecoilKnockbackVelocity)
			mcontroller.setYVelocity(0)
			mcontroller.addMomentum(recoilVelocity)
		end
	end

	if self.stances.fire.duration then
		util.wait(self.stances.fire.duration)
	end

	self.cooldownTimer = self.chargeLevel.cooldown
	self:setState(self.cooldown, self.cooldownTimer)
end

function NebKFEnhancedChargeFire:burst()
	if self.chargeLevel.chargeMuzzleOffset then
		self.useChargeMuzzleOffset = true
	end
	
	if world.lineTileCollision(mcontroller.position(), self:firePosition()) then
		animator.setAnimationState("firing", "off")
		self.cooldownTimer = self.chargeLevel.cooldown or 0
		self:setState(self.cooldown, self.cooldownTimer)
		return
	end

	self.weapon:setStance(self.stances.fire)
	
	local shots = self.chargeLevel.burstCount
	while shots > 0 and status.overConsumeResource("energy", self.chargeLevel.energyCost) do
		self:fireProjectile()
		self:muzzleFlash()
		shots = shots - 1
		
		if self.chargeLevel.recoilKnockbackVelocity then
			--If not crouching or if crouch does not impact recoil
			if not (self.chargeLevel.crouchStopsRecoil and mcontroller.crouching()) then
				local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.chargeLevel.recoilKnockbackVelocity)
				--If aiming down and not in zero G, reset Y velocity first to allow for breaking of falls
				if (self.weapon.aimAngle <= 0 and not mcontroller.zeroG()) then
						mcontroller.setYVelocity(0)
				end
				mcontroller.addMomentum(recoilVelocity)
				if not self.npcUser then
					mcontroller.controlJump()
				end
			--If crouching
				elseif self.chargeLevel.crouchRecoilKnockbackVelocity then
				local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.chargeLevel.crouchRecoilKnockbackVelocity)
				mcontroller.setYVelocity(0)
				mcontroller.addMomentum(recoilVelocity)
			end
		end

		self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.chargeLevel.burstCount, 0, self.stances.fire.weaponRotation))
		self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.chargeLevel.burstCount, 0, self.stances.fire.armRotation))

		util.wait(self.chargeLevel.burstTime)
	end

	self.cooldownTimer = (self.chargeLevel.cooldown - self.chargeLevel.burstTime) * self.chargeLevel.burstCount
	self:setState(self.cooldown, self.cooldownTimer)
end

function NebKFEnhancedChargeFire:cooldown(duration)
	self.weapon:setStance(self.stances.cooldown)
	self.weapon:updateAim()

	local progress = 0
	util.wait(duration, function()
		local from = self.stances.cooldown.weaponOffset or {0,0}
		local to = self.stances.idle.weaponOffset or {0,0}
		self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

		self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
		self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

		progress = math.min(1.0, progress + (self.dt / duration))
	end)
end

function NebKFEnhancedChargeFire:muzzleFlash()
	animator.setGlobalTag("variant", math.random(1, self.chargeLevel.muzzleFlashVariants or 3))
	animator.burstParticleEmitter("muzzleFlash")
	animator.setAnimationState("firing", self.chargeLevel.fireAnimationState or "fire")
	animator.playSound(self.chargeLevel.fireSound or "fire")

	animator.setLightActive("muzzleFlash", true)
end

function NebKFEnhancedChargeFire:fireProjectile()
	local projectileCount = self.chargeLevel.projectileCount or 1

	local params = copy(self.chargeLevel.projectileParameters or {})
	params.power = (self.chargeLevel.baseDamage * config.getParameter("damageLevelMultiplier")) / projectileCount
	params.powerMultiplier = activeItem.ownerPowerMultiplier()
	params.speed = util.randomInRange(params.speed)

	if not projectileType then
		projectileType = self.projectileType
	end
	if type(projectileType) == "table" then
		projectileType = projectileType[math.random(#projectileType)]
	end

	local spreadAngle = util.toRadians(self.chargeLevel.spreadAngle or 0)
	local totalSpread = spreadAngle * (projectileCount - 1)
	local currentAngle = totalSpread * -0.5
	for i = 1, (projectileCount or self.projectileCount) do
		if params.timeToLive then
			params.timeToLive = util.randomInRange(params.timeToLive)
		end

		world.spawnProjectile(
				self.chargeLevel.projectileType,
				firePosition or self:firePosition(),
				activeItem.ownerEntityId(),
				self:aimVector(currentAngle, inaccuracy or self.chargeLevel.inaccuracy or 0),
				false,
				params
			)

		currentAngle = currentAngle + spreadAngle
	end
end

function NebKFEnhancedChargeFire:firePosition()
	local firePosition = vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
	if self.useChargeMuzzleOffset then
		firePosition = vec2.add(firePosition, self.chargeLevel.chargeMuzzleOffset)
	end
	return firePosition
end

function NebKFEnhancedChargeFire:aimVector(angleAdjust, inaccuracy)
	local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + angleAdjust + sb.nrand(inaccuracy, 0))
	aimVector[1] = aimVector[1] * mcontroller.facingDirection()
	return aimVector
end

function NebKFEnhancedChargeFire:currentChargeLevel()
	local bestChargeTime = 0
	local bestChargeLevel
	for _, chargeLevel in pairs(self.chargeLevels) do
		if self.chargeTimer >= chargeLevel.time and self.chargeTimer >= bestChargeTime then
			bestChargeTime = chargeLevel.time
			bestChargeLevel = chargeLevel
		end
	end
	return bestChargeLevel
end

function NebKFEnhancedChargeFire:uninit()

end
