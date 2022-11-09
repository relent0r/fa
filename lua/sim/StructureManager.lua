local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend

local TableGetn = table.getn
local TableInsert = table.insert
local TableRemove = table.remove
local TableSort = table.sort

StructureManager = Class {
    Create = function(self, brain)
        LOG('Creating Structure Manager')
        self.Brain = brain
        self.Initialized = false
        self.Debug = false
        self.ExtractorData = {
            EconomyUpgradeSpendDefault = 0.35,
            CurrentEconomyUpgradeSpend = 0.35,
            ExtractorsUpgrading = { TECH1 = 0, TECH2 = 0 },
            EcoMassUpgradeTimeout = 180
        }
        if brain.CheatEnabled then
            self.EcoMultiplier = tonumber(ScenarioInfo.Options.CheatMult) or 1.0
        else
            self.EcoMultiplier = 1.0
        end
    end,

    Run = function(self)
       LOG('AI : StructureManager Starting')
        self:ForkThread(self.EcoExtractorUpgradeCheck, self.Brain)
        if self.Debug then
            self:ForkThread(self.StructureDebugThread)
        end
        self.Initialized = true
       --LOG('AI : StructureManager Started')
    end,

    ForkThread = function(self, fn, ...)
        if fn then
            local thread = ForkThread(fn, self, unpack(arg))
            self.Brain.Trash:Add(thread)
            return thread
        else
            return nil
        end
    end,

    EcoExtractorUpgradeCheck = function(self, aiBrain)
    -- Keep track of how many extractors are currently upgrading
    -- Right now this is less about making the best decision to upgrade and more about managing the economy while that upgrade is happening.
        WaitTicks(Random(5,20))
        local ALLBPS = __blueprints
        while true do
            local upgradeTrigger = false
            local upgradeSpend = (aiBrain.EconomyOverTimeCurrent.MassIncome*10)*self.ExtractorData.CurrentEconomyUpgradeSpend
            if upgradeSpend > 4 or GetGameTimeSeconds() > (420 / self.EcoMultiplier) then
                upgradeTrigger = true
            end
            local extractorsDetail, extractorTable, totalSpend = self.ExtractorsBeingUpgraded(self, aiBrain)
            self.ExtractorData.ExtractorsUpgrading.TECH1 = extractorsDetail.TECH1Upgrading
            self.ExtractorData.ExtractorsUpgrading.TECH2 = extractorsDetail.TECH2Upgrading
            --LOG('Core Extractor T3 Count needs to be less than 3 '..aiBrain.EcoManager.CoreExtractorT3Count)
            --LOG('Total Core Extractors needs to be greater than 2 '..aiBrain.EcoManager.TotalCoreExtractors)
            --LOG('Mex Income '..aiBrain.cmanager.income.r.m..' needs to be greater than '..(140 * self.EcoMultiplier))
            --LOG('T3 Land Factory Count needs to be greater than 1 '..aiBrain.smanager.fact.Land.T3)
            --LOG('or T3 Air Factory Count needs to be greater than 1 '..aiBrain.smanager.fact.Air.T3)
            --LOG('Efficiency over time needs to be greater than 1.0 '..aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime)
            --LOG('upgradespend - totalSpend '..(upgradeSpend - totalSpend))
            if self.T3ExtractorSpend then
                --RLOG('self.T3ExtractorSpend '..self.T3ExtractorSpend)
                --RLOG('Is upgradeSpend minus total spend greater than T3ExtractorSpend?')
            end

            LOG('Total Spend is '..totalSpend..' income with ratio is '..upgradeSpend)
            --LOG('Current number of T1 mexes upgrading '..extractorsDetail.TECH1Upgrading)
            --LOG('Current number of T2 mexes upgrading '..extractorsDetail.TECH2Upgrading)
            local massStorage = GetEconomyStored( aiBrain, 'MASS')
            local energyStorage = GetEconomyStored( aiBrain, 'ENERGY')
            if aiBrain.EcoManager.CoreExtractorT3Count then
                --LOG('CoreExtractorT3Count '..aiBrain.EcoManager.CoreExtractorT3Count)
            end
            if massStorage > 2500 and energyStorage > 8000 and extractorsDetail.TECH2Upgrading < 1 then
                self:ValidateExtractorUpgrade(aiBrain, extractorTable, true)
                WaitTicks(60)
                continue
            end
            if extractorsDetail.TECH1Upgrading < 2 and extractorsDetail.TECH2Upgrading < 1 and upgradeTrigger then
                if totalSpend < upgradeSpend and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 0.8 then
                    --LOG('We Could upgrade an extractor now with over time')
                        --LOG('We Could upgrade an extractor now with instant energyefficiency and mass efficiency')
                        if (extractorsDetail.TECH1 / extractorsDetail.TECH2 >= 1.2) and upgradeSpend - totalSpend > self.T3ExtractorSpend then
                            --LOG('Extractor Ratio of T1 to T2 is >= 1.1 and and upgradeSpend - totalSpend > self.T3ExtractorSpend')
                            self:ValidateExtractorUpgrade(aiBrain, extractorTable, true)
                        elseif (extractorsDetail.TECH1 / extractorsDetail.TECH2 >= 1.7) or upgradeSpend < 15 then
                            --LOG('Extractor Ratio of T1 to T2 is >= 1.5 or upgrade spend under 15')
                            self:ValidateExtractorUpgrade(aiBrain, extractorTable, false)
                        else
                            --LOG('Else all tiers upgrade')
                            self:ValidateExtractorUpgrade(aiBrain, extractorTable, true)
                        end
                        WaitTicks(30)
                    --end
                    WaitTicks(30)
                end
                WaitTicks(30)
            elseif extractorsDetail.TECH1Upgrading < 5 and massStorage > 150 and upgradeTrigger then
                if totalSpend < upgradeSpend and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 0.8 then
                    --LOG('We Could upgrade a non t2 extractor now with over time')
                    self:ValidateExtractorUpgrade(aiBrain, extractorTable, false)
                    WaitTicks(60)
                end
            elseif massStorage > 500 and energyStorage > 3000 and extractorsDetail.TECH2Upgrading < 2 then
                if aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= 1.05 and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 1.05 then
                    --LOG('We Could upgrade an extractor now with over time')
                    local massIncome = GetEconomyIncome(aiBrain, 'MASS')
                    local massRequested = GetEconomyRequested(aiBrain, 'MASS')
                    local energyIncome = GetEconomyIncome(aiBrain, 'ENERGY')
                    local energyRequested = GetEconomyRequested(aiBrain, 'ENERGY')
                    local massEfficiency = math.min(massIncome / massRequested, 2)
                    local energyEfficiency = math.min(energyIncome / energyRequested, 2)
                    if energyEfficiency >= 1.05 and massEfficiency >= 1.05 then
                        --LOG('We Could upgrade an extractor now with instant energyefficiency and mass efficiency')
                        if extractorsDetail.TECH1 / extractorsDetail.TECH2 >= 1.5 or upgradeSpend < 15 then
                            --LOG('Trigger all tiers false')
                            self:ValidateExtractorUpgrade(aiBrain, extractorTable, false)
                        else
                            --LOG('Trigger all tiers true')
                            self:ValidateExtractorUpgrade(aiBrain, extractorTable, true)
                        end
                        WaitTicks(30)
                    end
                    WaitTicks(30)
                end
            elseif massStorage > 2500 and energyStorage > 8000 then
                if aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime >= 0.8 and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime >= 0.8 then
                    -- We Could upgrade an extractor now with over time efficiency
                    local massIncome = GetEconomyIncome(aiBrain, 'MASS')
                    local massRequested = GetEconomyRequested(aiBrain, 'MASS')
                    local energyIncome = GetEconomyIncome(aiBrain, 'ENERGY')
                    local energyRequested = GetEconomyRequested(aiBrain, 'ENERGY')
                    local massEfficiency = math.min(massIncome / massRequested, 2)
                    local energyEfficiency = math.min(energyIncome / energyRequested, 2)
                    if energyEfficiency >= 0.8 and massEfficiency >= 0.8 then
                        -- We Could upgrade an extractor now with instant efficiency
                        -- Trigger all tiers true
                        self:ValidateExtractorUpgrade(aiBrain, extractorTable, true)
                        WaitTicks(30)
                    end
                    WaitTicks(30)
                end
            end
            WaitTicks(30)
        end
    end,
    
    ValidateExtractorUpgrade = function(self, aiBrain, extractorTable, allTiers)
        --LOG('ValidateExtractorUpgrade Stuff')
        local UnitPos
        local DistanceToBase
        local LowestDistanceToBase
        local lowestUnit = false
        local BasePosition = aiBrain.BuilderManagers['MAIN'].Position
        --LOG('BasePosition is '..repr(BasePosition))
        if extractorTable then
            --LOG('extractorTable present in upgrade validation')                
            if not allTiers then
                for _, c in extractorTable.TECH1 do
                    if c and not c.Dead then
                        if c.InitialDelayCompleted then
                            if not c:IsUnitState('Upgrading') then
                                UnitPos = c:GetPosition()
                                DistanceToBase = VDist2Sq(BasePosition[1] or 0, BasePosition[3] or 0, UnitPos[1] or 0, UnitPos[3] or 0)
                                if DistanceToBase < 6400 then
                                    c.MAINBASE = true
                                end
                                if not LowestDistanceToBase or DistanceToBase < LowestDistanceToBase then
                                    LowestDistanceToBase = DistanceToBase
                                    lowestUnit = c
                                    --LOG('T1 lowestUnit added alltiers false')
                                end
                            end
                        end
                    end
                end
            else
                for _, c in extractorTable.TECH1 do
                    if c and not c.Dead then
                        if c.InitialDelayCompleted then
                            if not c:IsUnitState('Upgrading') then
                                UnitPos = c:GetPosition()
                                DistanceToBase = VDist2Sq(BasePosition[1] or 0, BasePosition[3] or 0, UnitPos[1] or 0, UnitPos[3] or 0)
                                if DistanceToBase < 6400 then
                                    c.MAINBASE = true
                                end
                                if not LowestDistanceToBase or DistanceToBase < LowestDistanceToBase then
                                    LowestDistanceToBase = DistanceToBase
                                    lowestUnit = c
                                    --LOG('T1 lowestUnit added alltiers true')
                                end
                            end
                        end
                    end
                end
                for _, c in extractorTable.TECH2 do
                    if c and not c.Dead then
                        if c.InitialDelayCompleted then
                            if not c:IsUnitState('Upgrading') then
                                UnitPos = c:GetPosition()
                                DistanceToBase = VDist2Sq(BasePosition[1] or 0, BasePosition[3] or 0, UnitPos[1] or 0, UnitPos[3] or 0)
                                if DistanceToBase < 6400 then
                                    c.MAINBASE = true
                                end
                                if not LowestDistanceToBase or DistanceToBase < LowestDistanceToBase then
                                    LowestDistanceToBase = DistanceToBase
                                    lowestUnit = c
                                    --LOG('T2 lowestUnit added alltiers true')
                                end
                            end
                        end
                    end
                end
            end
            if lowestUnit then
                lowestUnit.CentralBrainExtractorUpgrade = true
                lowestUnit.DistanceToBase = LowestDistanceToBase
                if not self.CentralBrainExtractorUnitUpgradeClosest then
                    self.CentralBrainExtractorUnitUpgradeClosest = lowestUnit
                end
                --LOG('Closest Extractor')
                self:ForkThread(self.UpgradeExtractor, aiBrain, lowestUnit, LowestDistanceToBase)
            else
                --LOG('There is no lowestUnit')
            end
        end
    end,
    
    UpgradeExtractor = function(self, aiBrain, extractorUnit, distanceToBase)
        LOG('Upgrading Extractor from central brain thread')
        local upgradeID = extractorUnit.Blueprint.General.UpgradesTo or false
        if upgradeID then
            IssueUpgrade({extractorUnit}, upgradeID)
            WaitTicks(2)
            local fractionComplete
            local upgradeTimeStamp = GetGameTimeSeconds()
            local bypassEcoManager = false
            local extractorUpgradeTimeoutReached = false
            local upgradedExtractor = extractorUnit.UnitBeingBuilt
            if not upgradedExtractor.Dead then
                fractionComplete = upgradedExtractor:GetFractionComplete()
            end
            while extractorUnit and not extractorUnit.Dead and fractionComplete < 1 do
                --LOG('Upgrading Extractor Loop')
                --LOG('Unit is '..fractionComplete..' fraction complete')
                if not self.CentralBrainExtractorUnitUpgradeClosest or self.CentralBrainExtractorUnitUpgradeClosest.Dead then
                    self.CentralBrainExtractorUnitUpgradeClosest = extractorUnit
                elseif self.CentralBrainExtractorUnitUpgradeClosest.DistanceToBase > distanceToBase then
                    self.CentralBrainExtractorUnitUpgradeClosest = extractorUnit
                    --LOG('This is a new closest extractor upgrading at '..distanceToBase)
                end
                if not bypassEcoManager and fractionComplete < 0.65 then
                    if (GetEconomyTrend(aiBrain, 'MASS') <= 0.0 and GetEconomyStored(aiBrain, 'MASS') <= 150) or GetEconomyStored( aiBrain, 'ENERGY') < 200 then
                        if not extractorUnit:IsPaused() then
                            extractorUnit:SetPaused(true)
                            WaitTicks(10)
                        end
                    else
                        if extractorUnit:IsPaused() then
                            if self.ExtractorData.ExtractorsUpgrading.TECH1 > 1 or self.ExtractorData.ExtractorsUpgrading.TECH2 > 0 then
                                if self.CentralBrainExtractorUnitUpgradeClosest and not self.CentralBrainExtractorUnitUpgradeClosest.Dead 
                                and self.CentralBrainExtractorUnitUpgradeClosest.DistanceToBase == distanceToBase then
                                    extractorUnit:SetPaused(false)
                                    WaitTicks(30)
                                elseif self.ExtractorData.ExtractorsUpgrading.TECH2 > 0 and EntityCategoryContains(categories.TECH1, extractorUnit) then
                                    extractorUnit:SetPaused(false)
                                    if extractorUpgradeTimeoutReached then
                                        WaitTicks(30)
                                    end
                                    WaitTicks(30)
                                elseif GetEconomyStored(aiBrain, 'MASS') > 250 then
                                    extractorUnit:SetPaused(false)
                                    WaitTicks(30)
                                end
                            else
                                extractorUnit:SetPaused(false)
                                WaitTicks(20)
                            end
                        end
                    end
                end
                WaitTicks(30)
                if upgradedExtractor and not upgradedExtractor.Dead then
                    fractionComplete = upgradedExtractor:GetFractionComplete()
                end
                if not extractorUpgradeTimeoutReached then
                    if GetGameTimeSeconds() - upgradeTimeStamp > self.ExtractorData.EcoMassUpgradeTimeout then
                        extractorUpgradeTimeoutReached = true
                    end
                end
                if fractionComplete < 1 and extractorUpgradeTimeoutReached and (self.CentralBrainExtractorUnitUpgradeClosest.DistanceToBase == distanceToBase or extractorUnit.MAINBASE) then
                    bypassEcoManager = true
                    if extractorUnit:IsPaused() then
                        extractorUnit:SetPaused(false)
                    end
                end
            end
            if upgradedExtractor and not upgradedExtractor.Dead then
                if VDist3Sq(upgradedExtractor:GetPosition(), aiBrain.BuilderManagers['MAIN'].Position) < 6400 then
                    upgradedExtractor.MAINBASE = true
                end
            end
        else
            WARN('No upgrade id provided to UpgradeExtractor, unit id is '..extractorUnit.UnitId)
        end
        WaitTicks(80)
    end,

    ExtractorInitialDelay = function(self, aiBrain, unit)
        local initial_delay = 0
        local ecoStartTime = GetGameTimeSeconds()
        local ecoTimeOut = 300
        unit.InitialDelayCompleted = false
        unit.InitialDelayStarted = true
        --LOG('Initial Delay loop starting')
        while initial_delay < (50 / self.EcoMultiplier) do
            if not unit.Dead and GetEconomyStored( aiBrain, 'ENERGY') >= 150 and unit:GetFractionComplete() == 1 then
                initial_delay = initial_delay + 10
                if (GetGameTimeSeconds() - ecoStartTime) > ecoTimeOut then
                    initial_delay = 50
                end
            end
            --LOG('* AI : Initial Delay loop trigger for '..aiBrain.Nickname..' is : '..initial_delay..' out of 90')
            WaitTicks(100)
        end
        --LOG('Initial Delay loop completing')
        unit.InitialDelayCompleted = true
    end,

    ExtractorsBeingUpgraded = function(self, aiBrain)
        -- Returns number of extractors upgrading
        local ALLBPS = __blueprints
        local extractors = aiBrain:GetListOfUnits(categories.MASSEXTRACTION, true)
        local tech1ExtNumBuilding = 0
        local tech2ExtNumBuilding = 0
        local tech1Total = 0
        local tech2Total = 0
        local tech3Total = 0
        local totalSpend = 0
        local extractorTable = {
            TECH1 = {},
            TECH2 = {}
        }

        -- loop over all units and search for upgrading units
        for _, extractor in extractors do
            if not IsDestroyed(extractor) and extractor:GetFractionComplete() == 1 then
                if not extractor.InitialDelayStarted then
                    self:ForkThread(self.ExtractorInitialDelay, aiBrain, extractor)
                end
                if extractor.Blueprint.CategoriesHash.TECH1 then
                    tech1Total = tech1Total + 1
                    if not self.T2ExtractorSpend then
                        local upgradeId = extractor.Blueprint.General.UpgradesTo
                        self.T2ExtractorSpend = (ALLBPS[upgradeId].Economy.BuildCostMass / ALLBPS[upgradeId].Economy.BuildTime * (ALLBPS[extractor.UnitId].Economy.BuildRate * self.EcoMultiplier))
                    end
                    if extractor:IsUnitState('Upgrading') then
                        local upgradeId = extractor.Blueprint.General.UpgradesTo
                        totalSpend = totalSpend +  (ALLBPS[upgradeId].Economy.BuildCostMass / ALLBPS[upgradeId].Economy.BuildTime * (ALLBPS[extractor.UnitId].Economy.BuildRate * self.EcoMultiplier))
                        extractor.Upgrading = true
                        tech1ExtNumBuilding = tech1ExtNumBuilding + 1
                    else
                        extractor.Upgrading = false
                        TableInsert(extractorTable.TECH1, extractor)
                    end
                elseif extractor.Blueprint.CategoriesHash.TECH2 then
                    tech2Total = tech2Total + 1
                    if not self.T3ExtractorSpend then
                        local upgradeId = extractor.Blueprint.General.UpgradesTo
                        self.T3ExtractorSpend = (ALLBPS[upgradeId].Economy.BuildCostMass / ALLBPS[upgradeId].Economy.BuildTime * (ALLBPS[extractor.UnitId].Economy.BuildRate * self.EcoMultiplier))
                    end
                    if extractor:IsUnitState('Upgrading') then
                        local upgradeId = extractor.Blueprint.General.UpgradesTo
                        totalSpend = totalSpend + (ALLBPS[upgradeId].Economy.BuildCostMass / ALLBPS[upgradeId].Economy.BuildTime * (ALLBPS[extractor.UnitId].Economy.BuildRate * self.EcoMultiplier))
                        extractor.Upgrading = true
                        tech2ExtNumBuilding = tech2ExtNumBuilding + 1
                    else
                        extractor.Upgrading = false
                        TableInsert(extractorTable.TECH2, extractor)
                    end
                elseif extractor.Blueprint.CategoriesHash.TECH3 then
                    tech3Total = tech3Total + 1
                end
            end
        end
        self.TotalMexSpend = totalSpend
        return {TECH1 = tech1Total, TECH1Upgrading = tech1ExtNumBuilding, TECH2 = tech2Total, TECH2Upgrading = tech2ExtNumBuilding, TECH3 = tech3Total }, extractorTable, totalSpend
    end,
}

function CreateStructureManager(brain)
    local sm 
    sm = StructureManager()
    sm:Create(brain)
    return sm
end

function GetStructureManager(brain)
    return brain.StructureManager
end