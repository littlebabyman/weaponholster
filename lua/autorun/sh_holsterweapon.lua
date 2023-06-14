local CVarFlags = {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}
local LadderCVar = CreateConVar("holsterweapon_ladders", 1, CVarFlags, "Enable holstering your weapon on ladders.", 0, 2)
local UndrawCVar = CreateConVar("holsterweapon_undraw", 1, CVarFlags, "Allow playing weapon draw animation backwards, as a fallback.", 0, 1)
local WeaponCVar = CreateConVar("holsterweapon_weapon", "", CVarFlags, "Weapon to holster to. Invalid weapon returns default holster. Will remove previous holster-weapon on change.")
local BindCVar = CreateClientConVar("holsterweapon_key", 18, true)
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
            panel:CheckBox("Enable ''backwards weapon draw''", "holsterweapon_undraw")
        end)
    end)

    local HLAZCvar = GetConVar("hlaz_sv_holster")
    local SSCVar = GetConVar("ss_enableholsterdelay")

    function SimpleHolster()
        local ply = LocalPlayer()
        if !ply:Alive() || ply.Holstering then return end
        local weapon = ply:GetActiveWeapon()
        local vm = ply:GetViewModel()
        local holsterweapon = ply:GetWeapon(holster)

        HLAZCvar = HLAZCvar || GetConVar("hlaz_sv_holster")
        SSCVar = SSCVar || GetConVar("ss_enableholsterdelay")

        local based = IsValid(weapon) && !(weapon.ArcCW || weapon.ARC9 || weapon.ArcticTacRP || weapon.IsTFAWeapon || weapon.CW20Weapon || weapon.IsFAS2Weapon || weapon.IsUT99Weapon || weapons.IsBasedOn(weapon:GetClass(), "weapon_ss2_base") || weapons.IsBasedOn(weapon:GetClass(), "weapon_ut2004_base") || (weapons.IsBasedOn(weapon:GetClass(), "weapon_hlaz_base") && SSCVar:GetBool()) || (weapons.IsBasedOn(weapon:GetClass(), "weapon_ss_base") && SSCvar:GetBool()))
        local t = 0

        ply.Holstering = true

        if based then
            if vm:SelectWeightedSequence(ACT_VM_HOLSTER) != -1 then
                t = (ply:Ping() * 0.001) + vm:SequenceDuration(vm:SelectWeightedSequence(ACT_VM_HOLSTER))
                -- we're assuming the player's ping is stable here, so.
            else
                if vm:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW) != -1 then
                    t = (ply:Ping() * 0.001) + vm:SequenceDuration(vm:SelectWeightedSequence(ACT_SLAM_DETONATOR_THROW_DRAW)) * 0.5
                else
                    t = (ply:Ping() * 0.001) + vm:SequenceDuration(vm:SelectWeightedSequence(ACT_VM_DRAW)) * 0.5
                end
            end
        end

        timer.Simple(t, function()
            if weapon == holsterweapon && (ply:Alive() && IsValid(ply.HolsterWep)) then
                input.SelectWeapon(ply.HolsterWep)
            else
                ply.HolsterWep = weapon
                if (ply:Alive() && IsValid(holsterweapon)) then
                    input.SelectWeapon(holsterweapon)
                end
            end
            ply.Holstering = false
        end)

        net.Start("holstering", false)
        net.WriteFloat(t)
        net.SendToServer()
    end

    net.Receive("sendholster", function()
        holster = net.ReadString()
    end)

    concommand.Add("holsterweapon", SimpleHolster, nil, "Holster You're Weapon.")

    hook.Add("PlayerBindPress", "SimpleHolsterSlot0", function(ply, bind, pressed, code)
        if bind == "slot0" && !input.LookupBinding("holsterweapon") then SimpleHolster() end
    end)

    hook.Add("Think", "HolsterThink", function()
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
                ply:Give(holster, true)
            end)
        end)
    end

    function DoWeaponHolstering(ply, t)
        if !IsValid(ply) then return end
        local weapon = ply:GetActiveWeapon()
        if !ply:HasWeapon(holster) then
            -- print("holster is invalid, giving new one to " .. ply:Nick())
            ply:Give(holster, true)
            timer.Simple(t, function() ply:SelectWeapon(holster) end)
        end
        if LadderCVar:GetInt() == 2 && ply:GetMoveType() == MOVETYPE_LADDER then
            ply:SetActiveWeapon(NULL)
            ply:SelectWeapon(holster)
        elseif t != 0 then
            if weapon:SelectWeightedSequence(ACT_VM_HOLSTER) != -1 then
                weapon:SendWeaponAnim(ACT_VM_HOLSTER)
                ply:GetViewModel():SetPlaybackRate(1)
            else
                if weapon:GetClass() == "weapon_slam" then
                    weapon:SendWeaponAnim(ACT_SLAM_DETONATOR_THROW_DRAW)
                else
                    weapon:SendWeaponAnim(ACT_VM_DRAW)
                end
                ply:GetViewModel():SetPlaybackRate(-2)
            end
        end -- multiplayer holster animations, needed in current implementation
    end

    net.Receive("holstering", function(len, ply)
        DoWeaponHolstering(ply, net.ReadFloat())
    end)
end

if game.SinglePlayer() || CLIENT then
    hook.Add("PlayerSwitchWeapon", "HolsterWeaponSwitchHook", function(ply, oldwep, newwep)
        if IsValid(oldwep) && LadderCVar:GetBool() && ply:GetMoveType() == MOVETYPE_LADDER && ply:GetActiveWeapon():GetClass() == holster then
            return true
        end
    end)
end

hook.Add("StartCommand", "SimpleHolsterActionStop", function(ply, ucmd)
    if ply:Alive() && ply.Holstering then
        ucmd:SetButtons(bit.band(ucmd:GetButtons(), bit.bnot(10241)))
    end
end)
