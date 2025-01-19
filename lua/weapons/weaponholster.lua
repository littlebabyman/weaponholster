AddCSLuaFile()
SWEP.Slot = 5
SWEP.SlotPos = 127
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = ""
SWEP.PrintName = "Holster"
SWEP.Spawnable = true
SWEP.Weight = 0
SWEP.UseHands = true
SWEP.ViewModelFOV = 68
SWEP.AutoSwitchFrom = false
SWEP.AutoSwitchTo = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic = false
SWEP.DrawCrosshair = false
SWEP.DisableDuplicator = true
SWEP.BounceWeaponIcon = false
SWEP.m_bPlayPickupSound = false
if CLIENT then SWEP.WepSelectIcon = surface.GetTextureID( "vgui/null" ) end
SWEP.Instructions = "Press Reload to toggle the crosshair."

function SWEP:Initialize()
    self:SetHoldType("normal")
end

function SWEP:Deploy()
    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence(vm:LookupSequence("seq_deploy"))
    vm:SetPlaybackRate(0)
    vm:SetCycle(0)
    return true
end

function SWEP:Think()
end

function SWEP:PrimaryAttack()
    -- local owner = self:GetOwner()
end

function SWEP:SecondaryAttack()
    -- local owner = self:GetOwner()
end

function SWEP:Reload()
    local owner = self:GetOwner()
    if !owner or !owner:IsPlayer() then return end
    if IsFirstTimePredicted() and owner:KeyPressed(IN_RELOAD) or CLIENT and game.SinglePlayer() then
        if game.SinglePlayer() and SERVER then self:CallOnClient("Reload") end
        if CLIENT then
            self.DrawCrosshair = !self.DrawCrosshair
        end
    end
end

-- function SWEP:DrawWeaponSelection()
-- end

-- function SWEP:PrintWeaponInfo()
--     return false
-- end

function SWEP:Holster(wep)
    return true
end

function SWEP:CanBePickedUpByNPCs()
    return false
end

function SWEP:OnRemove()
end

function SWEP:OnDrop()
    self:Remove()
end