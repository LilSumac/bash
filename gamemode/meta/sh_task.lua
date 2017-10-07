defineMeta_start("Task");

function META:Start()
    self.Conditions = {};

end

function META:Pause()
    // if not time-based, ignore
end

function META:Update()

end

function META:Fail()

end

function META:GetProgress()
    // return number, table of progress(?)
end

function META:AddListener(plys)

end

defineMeta_end();
