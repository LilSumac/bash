local Player = FindMetaTable("Player");

function Player:Initialize()
    if self.Initialized then return; end

    self.Initialized = true;
    hook.Run("PlayerOnInit", self);
end

function Player:PostInitialize()
    if self.PostInitialized then return; end

    self.PostInitialized = true;
    hook.Run("PlayerPostInit", self);
end
