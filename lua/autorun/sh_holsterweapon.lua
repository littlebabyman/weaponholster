local CVarFlags = {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}
local LadderCVar = CreateConVar("holsterweapon_ladders", 1, CVarFlags, "Enable holstering your weapon on ladders.", 0, 2)
local UndrawCVar = CreateConVar("holsterweapon_undraw", 1, CVarFlags, "Allow playing weapon draw animation backwards, as a fallback.", 0, 1)
local WeaponCVar = CreateConVar("holsterweapon_weapon", "", CVarFlags, "Weapon to holster to. Invalid weapon returns default holster. Will remove previous holster-weapon on change.")
local BindCVar = CreateClientConVar("holsterweapon_key", 18, true)
local MemoryCVar = CreateClientConVar("holsterweapon_rememberlast", 1, true, true, "Remember the previous weapon you changed from before holstering.", 0, 1)
local holster = "weaponholster"


if CLIENT then
    hook.Add("PopulateToolMenu", "AddHolsterOptions", function()
        spawnmenu.AddToolMenuOption("Utilities", "Admin", "SimpleHolsterOptions", "Simple Holster", "", "", function(panel)
            local ladders = panel:ComboBox("Holstering in ladders", "holsterweapon_ladders")
            ladders:SetSortItems(false)
            ladders:AddChoice("Disabled", 0)
            ladders:AddChoice("Holster normally", 1)
            ladders:AddChoice("Holster instantly", 2)
            panel:TextEntry("Holstering weapon", "holsterweapon_weapon")
            panel:Help("Weapon class name to have as the ''the holster'', or leave blank for default (recommended).")
            panel:ControlHelp("Right click a weapon in the spawnmenu and click ''copy to clipboard'' to get its class name.")
            panel:CheckBox("Remember last weapons", "holsterweapon_rememberlast")
            panel:CheckBox("Enable ''backwards weapon draw''", "holsterweapon_undraw")
        end)
    end)

    local HLAZCvar = GetConVar("hlaz_sv_holster")
    local SSCVar = GetConVar("ss_enableholsterdelay")

    function SimpleHolster()
        local ply = LocalPlayer()
        if !ply:Alive() || ply.Holstering then return end
        local weapon, lastweapon, holsterweapon = ply:GetActiveWeapon(), ply:GetPreviousWeapon(), ply:GetWeapon(holster)
        local vm = ply:GetViewModel()

        HLAZCvar = HLAZCvar || GetConVar("hlaz_sv_holster")
        SSCVar = SSCVar || GetConVar("ss_enableholsterdelay")

        local based = IsValid(weapon) && !(weapon.ArcCW || weapon.ARC9 || weapon.ArcticTacRP || weapon.IsTFAWeapon || weapon.CW20Weapon || weapon.IsFAS2Weapon || weapon.IsUT99Weapon || weapons.IsBasedOn(weapon:GetClass(), "weapon_ss2_base") || weapons.IsBasedOn(weapon:GetClass(), "weapon_ut2004_base") || (weapons.IsBasedOn(weapon:GetClass(), "weapon_hlaz_base") && SSCVar:GetBool()) || (weapons.IsBasedOn(weapon:GetClass(), "weapon_ss_base") && SSCvar:GetBool()))
        local t = 0

        ply.Holstering = true

        if based then
            local hasanim = vm:SelectWeightedSequence(ACT_VM_HOLSTER) != -1 && true
            local anim = hasanim && vm:SelectWeightedSequence(ACT_VM_HOLSTER) || (weapon:GetClass() == "weapon_slam" && vm:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW) || vm:SelectWeightedSequence(ACT_VM_DRAW))
                t = vm:SequenceDuration(anim) * (hasanim && 1 || 0.5)
                -- print(hasanim, anim, t)
                -- vm:SendViewModelMatchingSequence(anim)
                -- vm:SetPlaybackRate(hasanim && 1 || -2)
                -- ply:SetSaveValue("m_flNextAttack", CurTime()+t)
                -- we're assuming the player's ping is stable here, so.
            -- else
            --     if vm:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW) != -1 then
            --         t = (ply:Ping() * 0.001) + vm:SequenceDuration(vm:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW)) * 0.5
            --     else
            --         t = (ply:Ping() * 0.001) + vm:SequenceDuration(vm:SelectWeightedSequence(ACT_VM_DRAW)) * 0.5
            --     end
            -- end
        end

        ply.HolsterWep = (weapon != holsterweapon && lastweapon || ply.HolsterWep)

        timer.Simple(t, function()
            if weapon == holsterweapon && (ply:Alive() && IsValid(lastweapon)) then
                input.SelectWeapon(lastweapon)
            elseif (ply:Alive() && IsValid(holsterweapon)) then
                input.SelectWeapon(holsterweapon)
            end
            ply.Holstering = false
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
        if MemoryCVar:GetBool() then lp:SetSaveValue("m_hLastWeapon", lp.HolsterWep || lp:GetPreviousWeapon()) end
    end)

    concommand.Add("holsterweapon", SimpleHolster, nil, "Holster You're Weapon.")

    hook.Add("PlayerBindPress", "SimpleHolsterSlot0", function(ply, bind, pressed, code)
        if bind == "slot0" && !input.LookupBinding("holsterweapon") && !IsFirstTimePredicted() then SimpleHolster() end
    end)

    hook.Add("CreateMove", "HolsterThink", function()
        local ply = LocalPlayer()
        if !IsValid(ply) then return end
        if (ply:Alive() && IsValid(ply:GetActiveWeapon()) && LadderCVar:GetBool()) then
            local weapon = ply:GetActiveWeapon()
            local holstered = weapon:GetClass() == holster
            local based = weapons.IsBasedOn(weapon:GetClass(), "mg_base") || weapons.IsBasedOn(weapon:GetClass(), "kf_zed_pill")
            if (!ply.InLadder && holstered) || based then return end
            if ply:GetMoveType() == MOVETYPE_LADDER && !ply.InLadder && !holstered && ply:GetVelocity().z != 0 then
                SimpleHolster()
                ply.InLadder = true
            elseif ply:GetMoveType() != MOVETYPE_LADDER && ply.InLadder && holstered then
                SimpleHolster()
                ply.InLadder = false
            end
        elseif ply.InLadder then
            ply.InLadder = false
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
                ply:SelectWeapon(ply:GetWeapon(holster))
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

    function DoWeaponHolstering(ply, exc)
        if !IsValid(ply) then return end
        local weapon, vm, ct = ply:GetActiveWeapon(), ply:GetViewModel(), CurTime()
        if !ply:HasWeapon(holster) then
            -- print("holster is invalid, giving new one to " .. ply:Nick())
            ply:Give(holster)
            -- timer.Simple(t, function() ply:SelectWeapon(holster) end)
        end
        if LadderCVar:GetInt() == 2 && ply:GetMoveType() == MOVETYPE_LADDER then
            ply:SetActiveWeapon(NULL)
            ply:SelectWeapon(holster)
        elseif exc then
            local hasanim = vm:SelectWeightedSequence(ACT_VM_HOLSTER) != -1 && true
            local anim = hasanim && vm:SelectWeightedSequence(ACT_VM_HOLSTER) || (weapon:GetClass() == "weapon_slam" && vm:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW) || vm:SelectWeightedSequence(ACT_VM_DRAW))
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
            local t = (vm:SequenceDuration() / math.abs(vm:GetPlaybackRate())) + 0.1
            -- print(hasanim, anim, t)
            ply:SetSaveValue("m_flNextAttack", t)
            weapon:SetNextPrimaryFire(math.max(weapon:GetNextPrimaryFire(), ct+t))
        end -- multiplayer holster animations, needed in current implementation
    end

    net.Receive("holstering", function(len, ply)
        DoWeaponHolstering(ply, net.ReadBool())
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
    if IsValid(oldwep) && oldwep:GetClass() == holster then
        if ply:GetMoveType() == MOVETYPE_LADDER && LadderCVar:GetBool() then
            return true
        end
        if SERVER && game.SinglePlayer() then
            net.Start("holstering")
            net.Send(ply)
        elseif CLIENT && MemoryCVar:GetBool() then
            ply:SetSaveValue("m_hLastWeapon", ply.HolsterWep || ply:GetPreviousWeapon())
        end
    end
end)

hook.Add("StartCommand", "SimpleHolsterActionStop", function(ply, ucmd)
    if ply:Alive() && ply.Holstering then
        ucmd:SetButtons(bit.band(ucmd:GetButtons(), bit.bnot(10241)))
    end
end)
