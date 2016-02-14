AddCSLuaFile('cl_init.lua')
AddCSLuaFile('shared.lua')
include('shared.lua')

util.AddNetworkString( "starfall_hud_set_enabled" )

local vehiclelinks = setmetatable({}, {__mode="k"})

function ENT:Initialize ()
	self.BaseClass.Initialize( self )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetUseType( SIMPLE_USE )
end

function ENT:Use( activator )
	net.Start( "starfall_hud_set_enabled" )
		net.WriteEntity( self )
		net.WriteInt(-1, 8)
	net.Send( activator )
end

function ENT:LinkEnt ( ent, ply )
	self.link = ent
	net.Start("starfall_processor_link")
		net.WriteEntity(self)
		net.WriteEntity(ent)
	if ply then net.Send(ply) else net.Broadcast() end
end

function ENT:LinkVehicle( ent )
	if ent then
		vehiclelinks[ent] = self
	else
		--Clear links
		for k,v in pairs( vehiclelinks ) do
			if self == v then
				vehiclelinks[k] = nil
			end
		end
	end
end

hook.Add("PlayerEnteredVehicle","Starfall_HUD_PlayerEnteredVehicle",function( ply, vehicle )
	for k,v in pairs( vehiclelinks ) do
		if vehicle == k and v:IsValid() then
			vehicle:CallOnRemove("remove_sf_hud", function()
				if not IsValid( v ) then return end
				net.Start( "starfall_hud_set_enabled" )
					net.WriteEntity( v )
					net.WriteInt(0, 8)
				net.Send( ply )
			end)
			
			net.Start( "starfall_hud_set_enabled" )
				net.WriteEntity( v )
				net.WriteInt(1, 8)
			net.Send( ply )
		end
	end
end)

hook.Add("PlayerLeaveVehicle","Starfall_HUD_PlayerLeaveVehicle",function( ply, vehicle )
	for k,v in pairs( vehiclelinks ) do
		if vehicle == k and v:IsValid() then
			net.Start( "starfall_hud_set_enabled" )
				net.WriteEntity( v )
				net.WriteInt(0, 8)
			net.Send( ply )
		end
	end
end)

function ENT:PreEntityCopy ()
	if self.EntityMods then self.EntityMods.SFLink = nil end
	local info = {}
	if IsValid(self.link) then
		info.link = self.link:EntIndex()
	end
	local linkedvehicles = {}
	for k, v in pairs( vehiclelinks ) do
		if v == self and k:IsValid() then
			linkedvehicles[#linkedvehicles + 1] = k:EntIndex()
		end
	end
	if #linkedvehicles > 0 then
		info.linkedvehicles = linkedvehicles
	end
	if info.link or info.linkedvehicles then
		duplicator.StoreEntityModifier( self, "SFLink", info )
	end
end

function ENT:PostEntityPaste ( ply, ent, CreatedEntities )
	if ent.EntityMods and ent.EntityMods.SFLink then
		local info = ent.EntityMods.SFLink
		if info.link then
			local e = CreatedEntities[ info.link ]
			if IsValid( e ) then
				self:LinkEnt( e )
			end
		end
		
		if info.linkedvehicles then
			for k, v in pairs(info.linkedvehicles) do
				local e = CreatedEntities[ v ]
				if IsValid( e ) then
					self:LinkVehicle( e )
				end
			end
		end
	end
end
