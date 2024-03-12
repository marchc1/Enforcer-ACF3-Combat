local EXTENSION = Enforcer.Extension "march.block_entityuse_automation"

EXTENSION.Name   = "Block Entity:Use Automation"
EXTENSION.Author = "March"

EXTENSION.Compatibility = {
    Require = {
        "Wiremod"
    }
}

local detours = Enforcer.Detours

function EXTENSION:Register()
    if SERVER then
        detours.AddSENTDetour("gmod_wire_user", "TriggerInput", "block_usage", function()
            return false
        end)
        detours.AddExpression2Detour("e:use()", "block_usage", function()
            return false end
        )
        detours.AddStarfallTypeMethodDetour("Entity", "use", "block_usage", detours.DetourObject(function()
            return false
        end), nil, false, false)
    end
end

function EXTENSION:Unregister()

end