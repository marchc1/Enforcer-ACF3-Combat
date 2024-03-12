local EXTENSION = Enforcer.Extension "march.apply_force_visualizer"

EXTENSION.Name   = "Applyforce Visualizer"
EXTENSION.Author = "March"

EXTENSION.Compatibility = {
    Require = {
        "Wiremod"
    }
}

local detours = Enforcer.Detours
local center_applyforce = {}

-- Not ideal, should recode
local function DrawArrow(ent, dir, arrowLength, col)
    if arrowLength == 0 then return end

    if col == nil then
        col = Color(255,255,255,170)
    else
        col = Color(col.r, col.g, col.b, 170)
    end

    local mt = Matrix()

    if type(ent) == "Entity" then
        mt:Translate(ent:GetPos())
        mt:Rotate(dir:AngleEx(ent:GetUp()))
    else
        mt:Translate(ent)
        mt:Rotate(dir:Angle())
    end

    cam.PushModelMatrix(mt)

    local PushingIt = math.Clamp(arrowLength / 100, 0, 1)

    local arrowSize      = 12 * PushingIt  -- How wide the arrow head will be
    local arrowPokeySize = 54 * PushingIt  -- How tall the arrow head will be
    local arrowRate      = 2  -- How fast the arrow head spins
    local arrowFidelity  = 4  -- How many points the arrow head has

    render.DrawLine(Vector(0,0,0), Vector(arrowLength, 0, 0), col, false)

    for i = 0, arrowFidelity - 1 do
        local coff     = (math.pi / (arrowFidelity / i))       * 2
        local coffNext = (math.pi / (arrowFidelity / (i + 1))) * 2
        local s,  c  = math.sin(CurTime() * arrowRate + coff),     math.cos(CurTime() * arrowRate + coff)
        local sn, cn = math.sin(CurTime() * arrowRate + coffNext), math.cos(CurTime() * arrowRate + coffNext)

        -- The lines that draw from the arrow tip, to the base of the arrow head
        render.DrawLine(Vector(arrowLength - arrowPokeySize,s * arrowSize,c * arrowSize), Vector(arrowLength,0,0), col, false)
        -- The lines that draw from the base of the arrow head back into the arrow shaft
        render.DrawLine(Vector(arrowLength - arrowPokeySize, s * arrowSize, c * arrowSize), Vector(arrowLength-arrowPokeySize,0,0), col, false)
        -- The lines that attach the arrow head pieces together
        render.DrawLine(Vector(arrowLength - arrowPokeySize, s * arrowSize,c * arrowSize), Vector(arrowLength - arrowPokeySize, sn * arrowSize, cn * arrowSize), col, false)
    end
    cam.PopModelMatrix()
end

function EXTENSION:Register()
    if CLIENT then
        local enable = CreateConVar("enforcer_applyforcevisualizer_enable", 0, FCVAR_USERINFO, "Enables/disables the applyforce visualizer.")
        local localizeimpulse = CreateConVar("enforcer_applyforcevisualizer_localizeimpulse", 0, FCVAR_ARCHIVE, "If set to 1, will draw the force vectors localized to the entity having force applied to it. \n\nI cannot guarantee this will be perfectly accurate; there is a slight delay between network sending and when that data actually gets to you. However, unless there are extreme force and angle forces being applied, this should generally be suitable for localizing impulse.")
        net.Receive("applyforcevisualizersync", function(len)
            center_applyforce = {}

            local entities = net.ReadUInt(16)
            for i = 1, entities do
                center_applyforce[net.ReadEntity()] = {
                    impulse_average = net.ReadVector()
                }
            end
        end)

        hook.Add("PreDrawEffects", "march.applyforcevisualizer.render3D", function()
            if not enable:GetBool() then return end
            for ent, v in pairs(center_applyforce) do
                if IsValid(ent) then
                    local impulse = v.impulse_average
                    if localizeimpulse:GetBool() then
                        local localized_impulse = ent:WorldToLocal(ent:GetPos() + impulse)

                        local x, y, z = localized_impulse.x, localized_impulse.y, localized_impulse.z
                        local ax, ay, az = math.abs(x), math.abs(y), math.abs(z)
                        local nx, ny, nz = x < 0 and -1 or 1, y < 0 and -1 or 1, z < 0 and -1 or 1

                        DrawArrow(ent:GetPos(), ent:GetForward() * nx, ax, Color(255,90,40))
                        DrawArrow(ent:GetPos(), ent:GetRight() * ny, ay, Color(40,255,40))
                        DrawArrow(ent:GetPos(), ent:GetUp() * nz, az, Color(40,90,255))
                    else
                        local x, y, z = impulse.x, impulse.y, impulse.z
                        local ax, ay, az = math.abs(x), math.abs(y), math.abs(z)

                        local xdir, ydir, zdir = Vector(x,0,0), Vector(0,y,0), Vector(0,0,z)

                        DrawArrow(ent:GetPos(), xdir, ax, Color(255,90,40))
                        DrawArrow(ent:GetPos(), ydir, ay, Color(40,255,40))
                        DrawArrow(ent:GetPos(), zdir, az, Color(40,90,255))
                    end
                end
            end
        end)
        return
    end

    util.AddNetworkString("applyforcevisualizersync")

    local function applyForceCenterLog(entORphysobj, impulse)
        local ent, physobj
        if not IsValid(entORphysobj) then return false end

        local t = type(entORphysobj)
        if t == "Entity" then
            ent = entORphysobj
            physobj = entORphysobj:GetPhysicsObject()
        elseif t == "PhysObj" then
            physobj = entORphysobj
            ent = entORphysobj:GetEntity()
        else
            return false
        end

        if center_applyforce[ent] == nil then center_applyforce[ent] = {} end
        local applyforce_table = center_applyforce[ent]

        applyforce_table[#applyforce_table + 1] = {impulse = impulse / physobj:GetMass()}
    end

    detours.AddExpression2Detour("applyForce(v)", "log_applyforce", detours.DetourObject(function(self, args)
        return applyForceCenterLog(self.entity, args[1])
    end), nil, false, false)

    detours.AddExpression2Detour("e:applyForce(v)", "log_applyforce", detours.DetourObject(function(_, args)
        return applyForceCenterLog(args[1], args[2])
    end), nil, false, false)

    detours.AddWireGateDetour("entity_applyf", "log_applyforce", function(gate, ent, vec)
        return applyForceCenterLog(ent, vec)
    end)

    detours.AddStarfallTypeMethodDetour("Entity", "applyForceCenter", "log_applyforce", detours.DetourObject(function(sfent, impulse)
        local ent = debug.getmetatable(sfent).sf2sensitive[sfent]
        local vec = Vector(impulse[1], impulse[2], impulse[3])
        return applyForceCenterLog(ent, vec)
    end), nil, false, false)
    
    detours.AddStarfallTypeMethodDetour("PhysObj", "applyForceCenter", "log_applyforce", detours.DetourObject(function(sfent, impulse)
        local ent = debug.getmetatable(sfent).sf2sensitive[sfent]
        local vec = Vector(impulse[1], impulse[2], impulse[3])
        return applyForceCenterLog(ent, vec)
    end), nil, false, false)

    timer.Create("applyforcevisualizer.sync", 1 / 10, 0, function()
        net.Start("applyforcevisualizersync")

        net.WriteUInt(table.Count(center_applyforce), 16)

        for k, v in pairs(center_applyforce) do
            net.WriteEntity(k)

            local vav = Vector(0, 0, 0)
            for _, v2 in ipairs(v) do
                vav = vav + v2.impulse
            end

            vav = vav / #v
            net.WriteVector(vav)
        end

        local plys = {}
        for _, v in ipairs(player.GetHumans()) do
            if v:GetInfoNum("enforcer_applyforcevisualizer_enable", 0) == 1 then
                plys[#plys + 1] = v
            end
        end

        net.Send(plys)

        center_applyforce = {}
        timer.Adjust("applyforcevisualizer.sync", math.Rand(1 / 10, 1 / 15))
    end)
end

function EXTENSION:Unregister()

end