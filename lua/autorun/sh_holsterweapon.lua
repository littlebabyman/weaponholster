local CVarFlags = {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}
local LadderCVar = CreateConVar("holsterweapon_ladders", 1, CVarFlags, "Enable holstering your weapon on ladders.", 0, 1)
local LadderForceCVar = CreateConVar("holsterweapon_ladders_forceall", 0, CVarFlags, "Force holstering all weapons on ladders.", 0, 1)
local UndrawCVar = CreateConVar("holsterweapon_undraw", 1, CVarFlags, "Allow playing weapon draw animation backwards, as a fallback.", 0, 1)
local WeaponCVar = CreateConVar("holsterweapon_weapon", "", CVarFlags, "Weapon to holster to. Invalid weapon returns default holster. Will remove previous holster-weapon on change.")
local BindCVar = CreateClientConVar("holsterweapon_key", 18, true)
local MemoryCVar = CreateClientConVar("holsterweapon_rememberlast", 1, true, true, "Remember the previous weapon you changed from before holstering.", 0, 1)
local holster = "weaponholster"
local vt, xd, db = file.Exists("wos/dynabase/registers/vuth_extendedanimations.lua", "LUA"), file.Exists("models/xdreanims/m_anm_base.mdl", "GAME"), file.Exists("models/player/wiltos/anim_dynamic_pointer.mdl", "GAME")

local function GetAnimation(mdl)
    return mdl:SelectWeightedSequence(ACT_VM_HOLSTER) != -1 && mdl:SelectWeightedSequence(ACT_VM_HOLSTER) || mdl:LookupSequence("holster") != -1 && mdl:LookupSequence("holster") || mdl:SelectWeightedSequence(ACT_VM_DRAW) != -1 && mdl:SelectWeightedSequence(ACT_VM_DRAW) || mdl:LookupSequence("draw") != -1 && mdl:LookupSequence("draw") || (mdl:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW) != -1 && mdl:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW)) || -1
end

local PLAYER = FindMetaTable("Player")

local weaponOverrides = {gmod_camera = true, gmod_tool = true, weapon_physgun = true}

if CLIENT then
    hook.Add("PopulateToolMenu", "CATAddHolsterOptions", function()
        spawnmenu.AddToolMenuOption("Options", "Chen's Addons", "SimpleHolsterOptions", "Simple Holster", "", "", function(panel)
            local sv, anim = vgui.Create("DForm", panel), vgui.Create("DForm", panel)
            panel:AddItem(sv)
            panel:AddItem(anim)
            sv:SetLabel("Server")
            sv:CheckBox("Holstering in ladders", "holsterweapon_ladders")
            sv:CheckBox("Force holster tools", "holsterweapon_ladders_forceall")
            sv:ControlHelp("Holsters physics gun, tool gun, and camera on ladders.")
            sv:TextEntry("Holstering weapon", "holsterweapon_weapon")
            sv:Help("Weapon class name to have as the ''the holster'', or leave blank for default (recommended).")
            sv:ControlHelp("Right click a weapon in the spawnmenu and click ''copy to clipboard'' to get its class name.")
            sv:CheckBox("Remember last weapons", "holsterweapon_rememberlast")
            sv:CheckBox("Enable ''backwards weapon draw''", "holsterweapon_undraw")
            anim:SetLabel("Animations")
            -- anim:Help("Third Person Animations")
            anim:Help("Buttons open Workshop pages for addons containing extra goodies.\nThese allow player models to use ladder climbing animations, if applicable.")
            if !vt then
                local button = vgui.Create("DButton", anim)
                button:SetText("Extended Player Animations")
                button.DoClick = function()
                    gui.OpenURL("https://steamcommunity.com/workshop/filedetails/?id=2922279661")
                end
                anim:AddItem(button)
            else
                anim:Help("Extended Player Animations is installed!")
            end
            if !(xd || db) || (xd && db) then
                if (xd && db) then
                    anim:Help("Please, do not have xdReanims and DynaBase installed at the same time!")
                else
                    anim:Help("Please, install either xdReanims or Dynabase.")
                end
                local button = vgui.Create("DButton", anim)
                button:SetText("xdReanims")
                button.DoClick = function()
                    gui.OpenURL("https://steamcommunity.com/workshop/filedetails/?id=2143558752")
                end
                anim:AddItem(button)
                local button = vgui.Create("DButton", anim)
                button:SetText("DynaBase")
                button.DoClick = function()
                    gui.OpenURL("https://steamcommunity.com/workshop/filedetails/?id=2916561591")
                end
                anim:AddItem(button)
            elseif xd then
                anim:Help("xdReanims is installed!")
            elseif db then
                anim:Help("DynaBase is installed!")
            end
        end)
    end)

    local HLAZCvar = GetConVar("hlaz_sv_holster")
    local SSCVar = GetConVar("ss_sv_holsteranims")

    function SimpleHolster()
        local ply = LocalPlayer()
        if !ply:Alive() || ply.Holstering then return end
        local weapon, lastweapon, holsterweapon = ply:GetActiveWeapon(), ply:GetPreviousWeapon(), ply:GetWeapon(holster)
        local vm = ply:GetViewModel()

        HLAZCvar = HLAZCvar || GetConVar("hlaz_sv_holster")
        SSCVar = SSCVar || GetConVar("ss_sv_holsteranims")
        
        local based = IsValid(weapon) && !(weapon.ArcCW || weapon.ARC9 || weapon.ArcticTacRP || weapon.IsTFAWeapon || weapon.CW20Weapon || weapon.IsFAS2Weapon || weapon.IsUT99Weapon || weapons.IsBasedOn(weapon:GetClass(), "weapon_ss2_base") || weapons.IsBasedOn(weapon:GetClass(), "weapon_ut2004_base") || (weapons.IsBasedOn(weapon:GetClass(), "weapon_hlaz_base") && HLAZCvar:GetBool()) || (weapons.IsBasedOn(weapon:GetClass(), "weapon_ss_base") && SSCVar:GetBool()))
        local t = 0

        ply.Holstering = true

        local hasanim = IsValid(vm) && vm:SelectWeightedSequence(ACT_VM_HOLSTER) != -1
        if IsValid(weapon) && IsValid(vm) && ((LadderCVar:GetBool() && ply.InLadder) || based) then
            local anim = hasanim && vm:SelectWeightedSequence(ACT_VM_HOLSTER) || (IsValid(weapon) && weapon:GetClass() == "weapon_slam" && vm:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW) || vm:SelectWeightedSequence(ACT_VM_DRAW))
            t = vm:SequenceDuration(anim) * (hasanim && 1 || 0.5)
        end

        ply.HolsterWep = (weapon != holsterweapon && lastweapon || ply.HolsterWep)

        timer.Create("holstertimer_client", t, 1, function()
            ply.Holstering = false
            if LadderCVar:GetBool() && ply:GetMoveType() != MOVETYPE_LADDER && ply.InLadder && !IsValid(weapon) && (ply:Alive() && IsValid(lastweapon)) then
                input.SelectWeapon(lastweapon)
                ply.InLadder = false
            end
            if !IsValid(weapon) || !IsValid(ply:GetActiveWeapon()) then return end
            if weapon == holsterweapon && (ply:Alive() && IsValid(lastweapon)) then
                input.SelectWeapon(lastweapon)
            elseif (ply:Alive() && IsValid(holsterweapon)) then
                input.SelectWeapon(holsterweapon)
            end
        end)

        net.Start("holstering", false)
        net.WriteBool(based)
        net.SendToServer()
    end

    net.Receive("sendholster", function()
        holster = net.ReadString()
    end)

    net.Receive("holstering", function()
        local lp = LocalPlayer()
        local vec = net.ReadNormal()
        lp:SetSaveValue("m_vecLadderNormal", vec)
        if !IsValid(lp) || !IsValid(lp:GetViewModel()) then return end
        hook.Run("OnViewModelChanged", lp:GetViewModel())
        if MemoryCVar:GetBool() then lp:SetSaveValue("m_hLastWeapon", lp.HolsterWep || lp:GetPreviousWeapon()) end
    end)

    concommand.Add("holsterweapon", SimpleHolster, nil, "Holster You're Weapon.")

    hook.Add("PlayerBindPress", "SimpleHolsterSlot0", function(ply, bind, pressed, code)
        if bind == "slot0" && !input.LookupBinding("holsterweapon") && !IsFirstTimePredicted() then SimpleHolster() end
    end)

    local ENTITY = FindMetaTable("Entity")
    local eGetTable = ENTITY.GetTable
    local pAlive = PLAYER.Alive
    local eGetInternalVariable = ENTITY.GetInternalVariable
    local eGetVelocity = ENTITY.GetVelocity
    local pGetActiveWeapon = PLAYER.GetActiveWeapon
    local eGetClass = ENTITY.GetClass
    local eGetMoveType = ENTITY.GetMoveType
    
    hook.Add("CreateMove", "HolsterThink", function(cmd)
        local ply = LocalPlayer()
    
        if !IsValid(ply) then
            return
        end
    
        local plyTable = eGetTable(ply)
    
        local weapon = pGetActiveWeapon(ply)
        local validwep = IsValid(weapon)
        local wepClass = validwep && eGetClass(weapon)
        if (pAlive(ply) && LadderCVar:GetBool() && (LadderForceCVar:GetBool() || !weaponOverrides[wepClass])) then
            local vert = !game.SinglePlayer() && eGetInternalVariable(ply, "m_vecLadderNormal").z <= 0.9 or eGetVelocity(ply).z != 0
            local holstered = validwep && eGetClass(weapon) == holster
            local based = validwep && !holstered && (weapons.IsBasedOn(wepClass, "mg_base") or weapons.IsBasedOn(wepClass, "kf_zed_pill"))
    
            if based or plyTable.Holstering then
                return
            end
    
            local moveType = eGetMoveType(ply)
            
            if moveType == MOVETYPE_LADDER && !plyTable.InLadder && validwep && !plyTable.Holstering && vert then
                SimpleHolster()

                plyTable.InLadder = true
            elseif moveType != MOVETYPE_LADDER && plyTable.InLadder && !validwep && !plyTable.Holstering then
                SimpleHolster()
    
                -- plyTable.InLadder = false
            end
        elseif plyTable.InLadder then
            plyTable.InLadder = false
        end
    end)
end

if SERVER then
    util.AddNetworkString("holstering")
    util.AddNetworkString("sendholster")

    local function SendHolster(data)
        net.Start("sendholster", false)
        net.WriteString(holster)
        net.Send(Player(data.userid))
    end

    local function SetupHolsterWeapon()
        local oldwep = holster
        if engine.ActiveGamemode() == "terrortown" then
            holster = "weapon_ttt_unarmed"
        else
            holster = (list.HasEntry("Weapon",WeaponCVar:GetString()) && WeaponCVar:GetString()) || (list.HasEntry("Weapon","apexswep") && "apexswep") || "weaponholster"
        end
        if oldwep == holster then return end
        for num, ply in ipairs(player.GetAll()) do
            ply:Give(holster)
            if ply:GetActiveWeapon():GetClass() == oldwep && ply:GetWeapon(holster):IsWeapon() then
                ply:SetActiveWeapon(NULL)
                ply:SelectWeapon(holster)
            end
            ply:StripWeapon(oldwep)
        end
        net.Start("sendholster", false)
        net.WriteString(holster)
        net.Broadcast()
    end

    hook.Add("InitPostEntity", "SetHolsterWeapon", SetupHolsterWeapon)
    cvars.AddChangeCallback("holsterweapon_weapon", SetupHolsterWeapon)
    gameevent.Listen("player_activate")
    hook.Add("player_activate", "SetHolsterWeapon", SendHolster)

    if engine.ActiveGamemode() != "terrortown" then
        hook.Add("PlayerLoadout", "GiveHolster", function(ply)
            timer.Simple(0, function()
                ply:Give(holster)
            end)
        end)
    end
    -- || (mdl:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW) != -1 && mdl:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW)) 

    local lastHolster = {}

    function DoWeaponHolstering(ply, exc)
        if !IsValid(ply) then return end

        local ct = CurTime()

        if !IsValid(ply) || (lastHolster[ply] || 0) + 0.5 >= ct then
            return
        end
    
        lastHolster[ply] = ct

        local weapon, vm = ply:GetActiveWeapon(), ply:GetViewModel()
        if !ply:HasWeapon(holster) then
            ply:Give(holster)
            ply:SelectWeapon(holster)
        end
        local str = "holstertimer" .. ply:EntIndex()
        local t = 0
        -- if LadderCVar:GetInt() == 2 then
        -- if IsValid(ply:GetEntityInUse()) && ply:GetEntityInUse():GetClass() == "player_pickup" then return end
        -- print(ply:GetInternalVariable("m_vecLadderNormal"))
        local hasanim = IsValid(weapon) && IsValid(vm) && (vm:SelectWeightedSequence(ACT_VM_HOLSTER) != -1 || vm:LookupSequence("holster") != -1)
        if ply:GetMoveType() == MOVETYPE_LADDER && ply:GetActiveWeapon() != NULL && ply:GetInternalVariable("m_vecLadderNormal").z < 0.9 then
            local model = vm:GetModel()
            -- local hasanim = vm:SelectWeightedSequence(ACT_VM_HOLSTER) != -1 || vm:LookupSequence("holster") != -1
            local anim = GetAnimation(vm)
            -- print(vm:GetSequence(), vm:GetSequenceName(vm:GetSequence()), vm:SelectWeightedSequence(ACT_VM_HOLSTER), vm:LookupSequence("holster"), anim, hasanim)
            ply:SelectWeapon(holster)
            if anim == -1 then
                ply:SetActiveWeapon(NULL)
                ply:DrawViewModel(true)
            else
                ply:SetActiveWeapon(NULL)
                ply:DrawViewModel(true)
                if vm:GetSequence() != 0 then
                    vm:SendViewModelMatchingSequence(0)
                end
                vm:SetModel(model)
                vm:SendViewModelMatchingSequence(anim)
                vm:SetPlaybackRate(hasanim && 1 || -2)
            end
            if game.SinglePlayer() && IsValid(ply) then
                net.Start("holstering")
                net.WriteNormal(ply:GetInternalVariable("m_vecLadderNormal"))
                net.Send(ply)
            end
            -- if ply:GetActiveWeapon() == ply:GetWeapon(holster) then
            --     vm:SetModel(model)
            -- end
            t = vm:SequenceDuration() * (hasanim && 1 || 0.5)
            ply:SetSaveValue("m_hLastWeapon", weapon)
            timer.Create(str, t, 1, function()
                if ply:GetActiveWeapon() == NULL then
                    ply:DrawViewModel(false)
                end
            end)
            -- end -- multiplayer holster animations, needed in current implementation
        elseif ply:GetActiveWeapon() == NULL then
            timer.Remove(str)
            ply:DrawViewModel(true)
            if IsValid(ply:GetPreviousWeapon()) then ply:SelectWeapon(ply:GetPreviousWeapon():GetClass()) end
            ply:SetSaveValue("m_hLastWeapon", NULL)
        elseif exc || hasanim then
            local anim = vm:LookupSequence("holster") != -1 && vm:LookupSequence("holster") || (vm:SelectWeightedSequence(ACT_VM_HOLSTER) != -1 && vm:SelectWeightedSequence(ACT_VM_HOLSTER) || (vm:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW) != -1 && vm:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW)) || vm:LookupSequence("draw") != -1 && vm:LookupSequence("draw") || vm:SelectWeightedSequence(ACT_VM_DRAW) != -1 && vm:SelectWeightedSequence(ACT_VM_DRAW) || vm:GetSequence())
            -- if vm:SelectWeightedSequence(ACT_VM_HOLSTER) != -1 then
            --     weapon:SendWeaponAnim(ACT_VM_HOLSTER)
            --     vm:SetPlaybackRate(1)
            -- else
            --     if weapon:GetClass() == "weapon_slam" then
            --         weapon:SendWeaponAnim(ACT_SLAM_DETONATOR_THROW_DRAW)
            --     else
            --         weapon:SendWeaponAnim(ACT_VM_DRAW)
            --     end
            --     vm:SetPlaybackRate(-2)
            -- end
            vm:SendViewModelMatchingSequence(anim)
            vm:SetPlaybackRate(hasanim && 1 || -2)
            t = vm:SequenceDuration()
            -- print(hasanim, anim, t)
            ply:SetSaveValue("m_flNextAttack", t)
            -- weapon:SetNextPrimaryFire(math.max(weapon:GetNextPrimaryFire(), ct+t))
        end -- multiplayer holster animations, needed in current implementation
    end

    net.Receive("holstering", function(len, ply)
        DoWeaponHolstering(ply, net.ReadBool())
    end)
end

if vt && (xd || db) then

    hook.Add("CalcMainActivity", "HolsterWeaponAnimHook", function(ply, vel)
        if ply:GetMoveType() != MOVETYPE_LADDER then return end
        if ply:GetActiveWeapon() == NULL then
            if vel.z > 0 then
                return ACT_SHIPLADDER_UP, -1
            elseif vel.z < 0 then
                return ACT_SHIPLADDER_DOWN, -1
            end
            return ACT_VM_IDLE_DEPLOYED_1, -1
        end
    end)


    hook.Add("UpdateAnimation", "HolsterWeaponAnimHook", function(ply, vel, spd)
        if ply:GetMoveType() != MOVETYPE_LADDER then return end
        if ply:GetActiveWeapon() == NULL then
            local vec = -ply:GetInternalVariable("m_vecLadderNormal")
            if vec.z < 0.9 then return end
            ply:SetRenderAngles(vec:Angle())
        end
    end)
end

hook.Add("PlayerSwitchWeapon", "HolsterWeaponSwitchHook", function(ply, oldwep, newwep)
    -- if newwep:GetClass() == holster then
    --     if CLIENT && !ply.Holstering then
    --         SimpleHolster()
    --         return true
    --     elseif ply:GetInternalVariable("m_flNextAttack") < 0 then
    --         return true
    --     end
    -- end
    if IsValid(oldwep) && oldwep:GetClass() == holster || oldwep == NULL then
        if ply:GetMoveType() == MOVETYPE_LADDER && LadderCVar:GetBool() then
            return true
        end
        if SERVER && game.SinglePlayer() && IsValid(ply) then
            net.Start("holstering")
            net.WriteNormal(ply:GetInternalVariable("m_vecLadderNormal"))
            net.Send(ply)
        end
    end
end)

local pAlive = PLAYER.Alive

hook.Add("StartCommand", "SimpleHolsterActionStop", function(ply, ucmd)
    if pAlive(ply) && ply.Holstering then
        ucmd:SetButtons(bit.band(ucmd:GetButtons(), bit.bnot(10241)))
    end
end)