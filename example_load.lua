local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local qualt = require(ReplicatedStorage:WaitForChild("qualt"))

qualt:setMode("debug")
qualt:Settings({
	["LIBRARY_ROOT"] = ReplicatedStorage:WaitForChild("Libraries"), -- Make this YOUR library root! 
})

qualt:Load({
	["shared"] = Modules.qualt,
	["client"] = Modules.qualt,
})

qualt.Yield()

qualt:_g("std::example").doSomething("Hello!")

-- Note, dependent on structure