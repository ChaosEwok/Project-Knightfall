local fireTimer = 0
local fireInterval = 0.5 -- seconds between shots

function update(dt)
  if not self.ownerId or not world.entityExists(self.ownerId) then
    return
  end

  if animator.animationState("activation") == "active" then
    fireTimer = fireTimer + dt
    if fireTimer >= fireInterval then
      fireMissile()
      fireTimer = 0
    end
  end
end

function fireMissile()
  local ownerPos = world.entityPosition(self.ownerId)
  local target = findTarget(ownerPos)

  if target then
    world.spawnProjectile(
      "knightfall_HEmissilesmall", -- custom missile
      vec2.add(ownerPos, {5, 2}),  -- Adjust spawn offset
      self.ownerId,
      {target[1] - ownerPos[1], target[2] - ownerPos[2]},
      false,
      {
        power = 100,
        speed = 70,
        sourceEntity = self.ownerId
      }
    )
  end
end

function findTarget(position)
  local entities = world.playerQuery(position, 30)
  print("Entities found:", #entities) -- Debug print
  for _, entityId in ipairs(entities) do
    if world.entityEntityType(entityId) == "NPC" and not world.entityIsDead(entityId) then
      print("Found target at:", world.entityPosition(entityId)) -- Debug print
      return world.entityPosition(entityId)
    end
  end
  print("No valid target found.") -- Debug print
  return nil
end