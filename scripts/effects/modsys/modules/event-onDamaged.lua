---
--- Generated by Luanalysis
--- Created by Lyr.
--- DateTime: 1/27/2021 1:54 PM
---


--[[
  EVENT:  DamageNotification
  CFG:    includeZeroDamage   boolean   false   include damage that did not deal lost health

--]]

if not Modsys then error("This script isn't supposed to be require'd yourself lol.") end
---@type Modsys, Event
local Modsys, Event = Modsys, Event

require "/scripts/status.lua"

---@class OnDamaged : Event
local OnDamaged = Event.new()

function OnDamaged:init()
  self.listener = damageListener("damageTaken", function(notifications)
    for _, n in pairs(notifications) do
      if --[[n.hitType == observedHitType and]] (self.cfg.includeZeroDamage or n.healthLost > 0) then
        self:emit(n)
      end
    end
  end)
end

function OnDamaged:update(dt)
  self.listener:update()
end

function OnDamaged:uninit()
  -- normal uninit
end