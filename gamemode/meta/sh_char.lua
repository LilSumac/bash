defineMeta_start("Character");

META.Data = {};

function META:SetData(data)
    for key, val in pairs(data) do
        self.Data[key] = val;
    end
end

function META:Save()

end

defineMeta_end();
