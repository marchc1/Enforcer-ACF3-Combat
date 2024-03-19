local EXTENSION = Enforcer.Extension "march.restrict_entityuse_automation"

EXTENSION.Name   = "Restrict Entity:Use Automation to Distance"
EXTENSION.Author = "March"

EXTENSION.Compatibility = {
    Require = {
        "Wiremod"
    }
}

local detours = Enforcer.Detours

function EXTENSION:Register()
    if SERVER then
        local max_distance = 250
        local function block(player, target)
            if not IsValid(player) then return false end
            if not IsValid(target) then return false end

            local dist = player:GetPos():Distance(target:GetPos())
            if dist < max_distance then return end

            Enforcer.Notify("Automation of the using of entities is blocked beyond " .. max_distance .. " source units.", nil, player)
            return false
        end

        detours.AddSENTDetour("gmod_wire_user", "TriggerInput", "block_usage", function(self, iname, ivalue)
            if iname == "Fire" and ivalue ~= 0 then
                local start = self:GetPos()
                local ply = self:GetPlayer()

                local trace = util.TraceLine( {
                    start = start,
                    endpos = start + (self:GetUp() * self:GetBeamLength()),
                    filter = { self },
                })

                return block(ply, trace.Entity)
            end
        end)
        detours.AddExpression2Detour("e:use()", "block_usage", function(e2, args)
            return block(e2.player, args[1])
        end)
        detours.AddStarfallTypeMethodDetour("Entity", "use", "block_usage", function(instance, ent)
            return block(instance.player, instance.Types.Entity.Unwrap(ent))
        end)
    end
end

function EXTENSION:Unregister()

end