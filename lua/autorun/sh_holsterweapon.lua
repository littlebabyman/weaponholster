CreateConVar("holsterweapon_ladders", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Enable holstering your weapon on ladders.", 0, 1)
CreateConVar("holsterweapon_weapon", "", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED}, "Weapon to holster to. Invalid weapon returns default holster. Requires restart to change.")
/*local basedtable = {"arccw_base",
"tfa_gun_base",
"cw_base"}*/
local holster = GetConVar("holsterweapon_weapon"):GetString()
timer.Simple(0, function()
    if engine.ActiveGamemode() == "terrortown" then
        holster = "weapon_ttt_unarmed"
    elseif !list.HasEntry("Weapon",holster) then
        holster = "weaponholster"
    end
end)

if CLIENT then
    hook.Add("PopulateToolMenu", "AddHolsterOptions", function()
        spawnmenu.AddToolMenuOption("Utilities", "Admin", "SimpleHolsterOptions", "Simple Holster", "", "", function(DForm)
            DForm:CheckBox("Enable ladder holstering", "holsterweapon_ladders")
            DForm:TextEntry("Holstering weapon", "holsterweapon_weapon")
            DForm:Help("Weapon classname to have as the ''the holster'', or leave blank for default (recommended). Requires map restart.")
            DForm:ControlHelp("Right click a weapon and click ''copy to clipboard'' to get its classname.")
        end)
    end)

    local function SimpleHolster()
        local ply = LocalPlayer()
        if (!ply:Alive() || ply.Holstering) then return end
        local weapon = ply:GetActiveWeapon()
        local vm = ply:GetViewModel()
        -- local lastweapon = ply:GetPreviousWeapon() -- who knows, maybe i'll need this later
        local holsterweapon = ply:GetWeapon(holster)
        local based = (IsValid(weapon) && !(weapon.ArcCW || weapon.IsTFAWeapon || weapon.CW20Weapon || weapon.IsFAS2Weapon || (weapons.IsBasedOn(weapon:GetClass(), "weapon_hlaz_base") && GetConVar("hlaz_sv_holster"):GetBool())))
        curtime = CurTime()
        local t = 0
        ply.Holstering = true
        net.Start("holstering", false)
        net.SendToServer()
        if IsValid(holsterweapon) then
            if based then
                if vm:SelectWeightedSequence(ACT_VM_HOLSTER) != -1 then
                    t = (ply:Ping() / 1000) + vm:SequenceDuration(vm:SelectWeightedSequence(ACT_VM_HOLSTER))
                    vm:SetCycle(0)
                    vm:SetPlaybackRate(1)
                    -- we're assuming the player's ping is stable here, so.
                end
            end
            timer.Simple(t, function()
                if weapon == holsterweapon then
                    if (ply:Alive() && IsValid(ply.HolsterWep)) then
                        input.SelectWeapon(ply.HolsterWep)
                    end
                else
            --ply:PrintMessage(HUD_PRINTTALK, "holstering")
                ply.HolsterWep = weapon
                    if (ply:Alive() && IsValid(holsterweapon)) then
                        input.SelectWeapon(holsterweapon)
                    end
                end
                ply.Holstering = false
            end)
            -- print(t)
            -- print("Check success")
        else
            ply.Holstering = false
            --print("Check failure, holster given!")
            return
        end
    end

    concommand.Add("holsterweapon", SimpleHolster, nil, "Holster You're Weapon.")

    hook.Add("Think", "HolsterThink", function()
        local ply = LocalPlayer()
        if !IsValid(ply) then return end
        if (ply:Alive() && IsValid(ply:GetActiveWeapon()) && GetConVar("holsterweapon_ladders"):GetBool()) then
            local weapon = ply:GetActiveWeapon()
            local holstered = weapon:GetClass() == holster
            local based = weapons.IsBasedOn(weapon:GetClass(), "mg_base") || weapons.IsBasedOn(weapon:GetClass(), "kf_zed_pill")
            if (!ply.InLadder && holstered) || based then return end
            -- check if player is both holding holster and not in ladder state or holstering or holding based weapon
            timer.Simple(0, function()
                if ply:GetMoveType() == MOVETYPE_LADDER && !ply.InLadder && !holstered then
                -- check if player is on a ladder and is not in ladder state and not holding holster
                    ply.InLadder = true
                    SimpleHolster()
                    if !IsValid(ply:GetWeapon(holster)) then
                        SimpleHolster()
                    end
                elseif ply:GetMoveType() != MOVETYPE_LADDER && ply.InLadder && holstered then
                    -- check if player is not on a ladder and is in ladder state and holding holster
                    ply.InLadder = false
                    SimpleHolster()
                end
            end)
        else
            return
        end
        -- print(ply.InLadder)
    end)

end

if SERVER then
    util.AddNetworkString("holstering")

    if engine.ActiveGamemode() != "terrortown" then
        hook.Add("PlayerLoadout", "GiveHolster", function(ply)
            ply:Give(holster, true)
        end)
    end

    net.Receive("holstering", function(len, ply)
        if IsValid(ply) then
            local weapon = ply:GetActiveWeapon()
            local based = (IsValid(weapon) && !(weapon.ArcCW || weapon.IsTFAWeapon || weapon.CW20Weapon || weapon.IsFAS2Weapon || (weapons.IsBasedOn(weapon:GetClass(), "weapon_hlaz_base") && GetConVar("hlaz_sv_holster"):GetBool())))
            if ply:HasWeapon(holster) then
                if (based) then
                    if ply:GetActiveWeapon():SelectWeightedSequence(ACT_VM_HOLSTER) != -1 then
                    ply:GetActiveWeapon():SendWeaponAnim(ACT_VM_HOLSTER)
                    end
                end -- multiplayer holster animations, needed in current implementation
            else
                print("holster is invalid, giving new one to " .. ply:Nick())
                ply:Give(holster, true)
                --else
                --print("holster is valid")
            end
        end
    end)
end

hook.Add("PlayerSwitchWeapon", "HolsterWeaponSwitchHook", function(ply, oldwep, newwep)
    if GetConVar("holsterweapon_ladders"):GetBool() && ply:GetMoveType() == MOVETYPE_LADDER && ply:GetActiveWeapon():GetClass() == holster then return true end
end)

hook.Add("StartCommand", "SimpleHolsterActionStop", function(ply, ucmd)
    if CLIENT && ply:Alive() && ply.Holstering then
        ucmd:RemoveKey(10241)
    end
end)
