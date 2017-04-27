require "behaviours/decide"

local WalterBrain = Class(Brain, function(self, inst, server)
    Brain._ctor(self, inst)
    self.inst = inst

    self.FAtiMAServer = (server and server .. "percept") or "http://localhost:8080/percept"

    self.callbackfn = function(result, isSuccessful , http_code)
        self:HandleCallback(result, isSuccessful, http_code)
    end

    self.onkilledfn = function (inst, data)
        self:OnEvent(inst.name, "Killed", data.victim, "actionend")
    end

    self.onattackfn = function (inst, data)
        self:OnEvent(inst.name, "Attacked", data.target, "actionend")
    end

    self.needtodecidefn = function()
        return self.inst.components.deliberator and (self.inst.components.deliberator:HasNextAction() == nil)
    end

    self.doactionfn = function()
        return self.inst.components.deliberator and (self.inst.components.deliberator:GetNextAction() == "Wander")
    end
end)

function WalterBrain:OnStart()
    self.inst:ListenForEvent("killed", self.onkilledfn)
    self.inst:ListenForEvent("onattackother", self.onattackfn)
    self.inst:ListenForEvent("onmissother", self.onattackfn)

	self.inst:AddComponent("deliberator")
    
    local root = 
        PriorityNode(
        {
            WhileNode(self.needtodecidefn, "Decide?", Decide(self.inst)),
            WhileNode(self.doactionfn, "Wander?", Wander(self.inst, nil, 1))
        }, 0)

    self.bt = BT(self.inst, root)
end

function WalterBrain:OnStop()
    self.inst:RemoveComponent("deliberator")
    self.inst:RemoveEventCallback("killed", self.onkilledfn)
    self.inst:RemoveEventCallback("onattackother", self.onattackfn)
    self.inst:RemoveEventCallback("onmissother", self.onattackfn)
end

function WalterBrain:HandleCallback(result, isSuccessful, http_code)
    -- if isSuccessful and http_code == 200 then
    --  print(result)
    -- else
    --  print("Couldn't Appraise Perceptions")
    -- end
end

function WalterBrain:QueryFAtiMA(data)
    print(data)
    TheSim:QueryServer(
        self.FAtiMAServer,
        self.callbackfn,
        "POST",
        data)
end

function WalterBrain:OnEvent(actor, event, target, type)
    local data = {}
    data["subject"] = actor
    data["actionName"] = event
    data["target"] = target.name
    data["type"] = type

    self:QueryFAtiMA(json.encode(data))
end

return WalterBrain