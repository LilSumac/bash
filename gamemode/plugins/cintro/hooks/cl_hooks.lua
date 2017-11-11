--[[
    CIntro client hooks.
]]

hook.Add("GatherPrelimData_Base", "CIntro_AddTasks", function()
    local ctask = bash.Util.GetPlugin("CTask");
    ctask:AddTask("CIntro_PreResponse");
    ctask:AddTask("CIntro_GameIntro");
    ctask:AddNextTask("CIntro_PreResponse", "CIntro_GameIntro");

    -- PreResponse
    ctask:AddTaskCondition("CIntro_PreResponse", "WaitForResponse", TASK_NUMERIC, 0, 1);
    ctask:AddTaskOnBorn("CIntro_PreResponse", function(task)
        LocalPlayer().PreResponseTask = task;
    end);
    ctask:AddTaskOnFinish("CIntro_PreResponse", function(status, task)
        LocalPlayer().PreResponseTask = nil;
    end);

    -- PostResponse
    ctask:AddTaskCondition("CIntro_GameIntro", "WaitForGameIntro", TASK_NUMERIC, 0, 1);
    ctask:AddTaskOnBorn("CIntro_GameIntro", function(task)
        LocalPlayer().GameIntroTask = task;
    end);
    ctask:AddTaskOnFinish("CIntro_GameIntro", function(status, task)
        LocalPlayer().GameIntroTask = nil;
        LocalPlayer().IntroFinished = true;
    end);
end);

hook.Add("InitPostEntity", "CIntro_StartProcess", function()
    if LocalPlayer().IntroFinished then return; end

    if !LocalPlayer().IntroFrame then
        local introFrame = vgui.Create("bash.Frame");
        introFrame:SetTitleText("Intr0");
        introFrame:SetScreenLock(true);

        --[[
        local introFrame = vgui.Create("DFrame");
        introFrame:SetSize(400, 300);
        introFrame:MakePopup();
        local form = vgui.Create("DForm", introFrame);
        form:Dock(FILL);

        local but = vgui.Create("DButton", form);
        but:SetText("Heyo!");
        form:AddItem(but);
        ]]

        LocalPlayer().IntroFrame = introFrame;
    end

    local ctask = bash.Util.GetPlugin("CTask");
    local preresp = ctask:NewTask("CIntro_PreResponse");
    preresp:Start();
end);

hook.Add("ServerResponded", "CIntro_ServerRespond", function()
    local preresp = LocalPlayer().PreResponseTask;
    preresp:Update("WaitForResponse", 1);
end);
