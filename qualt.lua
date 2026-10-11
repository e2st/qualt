--[[==

	// .qualt Luau Framework { [2025] - [202x] }
  	// Written by normal - [ ._.normal ] 
	
	// .-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-. //

		Initial file 16-Dec-25

	// .-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-. //
	
==]]

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 
--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  -- 

local RunService = game:GetService("RunService")

local Qualt = {
	Directories = { },
	Namespaces = { },
	     
	Modules = { },
	Cached = { },

	Libraries = { pre = { }, post = { } },
	
	Loaded = false,
	Identity = "qualt",
	
	Mode = "nocheck",
}

local QualtKeys = {
	["INJECT"] = "inject",
	["SERVICES"] = "services",
	["USING"] = "using",
	["SCOPE"] = "scope",
}

local Settings = {
	["RESERVED_NAMESPACES"] = {
		["Services"] = { "srvc", "ctrl" },
	},
	["LIBRARY_ROOT"] = game:GetService("ReplicatedStorage"):WaitForChild("Libraries"),
	["DEFAULT_NAMESPACE"] = "g",
	["NAMESPACE_FORMAT"] = "::",
	["EXTENSION_FORMAT"] = "$",
	["DEFAULT_SCOPE"] = "shared"
}

local Exceptions = {
	["INVALID_CANONICAL_FORMAT"] = "invalid canonical format: '%s' (expected format: 'namespace::module')",
	["UNABLE_TO_PARSE_CANONICAL"] = "canonical %s couldn't be parsed",
	["MISSING_MODULE_INJECTED"] = "module '%s' injects missing module '%s'",
	["CIRCULAR_DEPENDENCY"] = "circular dependency detected in inject graph",
	["REQUIRE_FAIL"] = "Failed to require '%s'", 
	["INVALID_RETURN_TYPE"] = "module '%s' did not return a table",
	["IMPORT_NAMESPACE"] = "couldnt find namespace '%s' for module '%s'",
	["INVALID_INJECT_TYPE"] = "couldnt inject '%s' into '%s': module is not a table",
	["NO_LOAD_ORDER"] = "nonexistent loadorder",
	["INVALID_EXPORT"] = "callback function exception for module '%s': %s",
	["UNHANDLED_EXCEPTION"] = ""
}

local Callbacks = {
	["EXCEPTIONS"] = { },
}

--[[

debug + error handlers

]]

function Qualt:ThrowException(Exception, MessageOrArgs)
	local Context = RunService:IsServer() and "serversided |" or "clientsided |"

	if (typeof(MessageOrArgs) == "string") then
		local Formatted = string.format(
			".qualt | %s %s",
			Context, MessageOrArgs
		)

		if (self.Mode == "debug") then
			print(Formatted)
		end
	end

	local ExceptionHandlers = Callbacks.EXCEPTIONS[Exception] 

	if (ExceptionHandlers) then
		for _, Handler in ipairs(ExceptionHandlers) do
			Handler(MessageOrArgs)
		end
	end
end

--[[

formatting, how do you format <NAMESPACE> std and
<NAME> iostream?

]]

function Qualt:FormatCanonical(Namespace, Module)
	local FormatKey = Settings.NAMESPACE_FORMAT

	return Namespace .. FormatKey .. Module
end

--[[

Figure out what std::iostream gives

]]

function Qualt:ParseCanonical(Canonical)
	local FormatKey = Settings.NAMESPACE_FORMAT
	local ExtensionKey = Settings.EXTENSION_FORMAT
	local InvalidFormat = Exceptions.INVALID_CANONICAL_FORMAT

	local Parts = string.split(
		Canonical,
		FormatKey
	) 

	if (#Parts ~= 2) then
		self:ThrowException(
			"INVALID_CANONICAL_FORMAT",
			string.format(InvalidFormat, Canonical)
		)

		return nil
	end

	local NamespacePart = Parts[1]
	local ModuleName = Parts[2]

	local Extensions = string.split(
		NamespacePart, 
		ExtensionKey
	)
	
	local Scope = table.remove(Extensions, 1)

	return {
		scope = Scope,
		extensions = Extensions,
		module = ModuleName,
		full = Canonical,
		namespace = NamespacePart,
	}
end

--[[

This traverses down a path

]]

function Qualt:GetPath(Root, Parts)
	local Current = Root

	for _, Key in ipairs(Parts) do
		Current = Current and Current[Key]
	end

	return Current
end

--[[

Goes down the path, if the table doesn't exist,
then create it

]]

function Qualt:EstablishPath(Root, Parts)
	local Current = Root

	for _, Key in ipairs(Parts) do
		Current[Key] = Current[Key] or {}
		Current = Current[Key]
	end

	return Current
end

--[[

Where should std::iostream go? 
Establish the tree, put it there so we can use it later.

]]

function Qualt:EstablishNamespace(Canonical)
	local InvalidParse = Exceptions.UNABLE_TO_PARSE_CANONICAL

	local Parsed = self:ParseCanonical(Canonical)

	if (not Parsed) then
		self:ThrowException(
			"UNABLE_TO_PARSE_CANONICAL",
			string.format(InvalidParse, Canonical)

		)
		return { }
	end

	local PathParts = { Parsed.scope }

	for _, Extension in ipairs(Parsed.extensions) do
		table.insert(PathParts, Extension)
	end

	table.insert( PathParts, Parsed.module )

	local Namespace = self:EstablishPath(self.Namespaces, PathParts)

	return Namespace
end

--[[

Figure out everything that a module wants

]]

function Qualt:GetDependencies(Module)
	local InjectKey = QualtKeys.INJECT

	local Inject = Module[InjectKey]

	if (not Inject) then
		return { }
	end

	local Dependencies = { }
	
	for _, Value in pairs(Inject) do
		if (typeof(Value) == "string") then
			table.insert(
				Dependencies, 
				Value
			)
		elseif (typeof(Value) == "table") then
			for _, Canonical in ipairs(Value) do
				table.insert(
					Dependencies,
					Canonical
				)
			end
		end
	end

	return Dependencies
end

--[[

Needed for GetLoadOrder() (obviously...)

]]

function Qualt:BuildDependencyGraph()
	local InvalidFormat = Exceptions.MISSING_MODULE_INJECTED

	local Graph, Degree = { }, { }

	for Canonical in pairs(self.Modules) do
		Graph[Canonical] = {}
		Degree[Canonical] = 0
	end

	for Canonical, ModuleData in pairs(self.Modules) do
		local Dependencies = self:GetDependencies(ModuleData.data)

		for _, Dependency in ipairs(Dependencies) do
			if (not self.Modules[Dependency]) then
				self:ThrowException(
					"MISSING_MODULE_INJECTED",
					string.format(InvalidFormat, Canonical, Dependency)
				)
			else
				table.insert(Graph[Dependency], Canonical)

				Degree[Canonical] += 1
			end
		end
	end

	return Graph, Degree
end

--[[

Sort all the modules based on their injects and stuff like that

]]

function Qualt:GetLoadOrder()
	local CircularFormat = Exceptions.CIRCULAR_DEPENDENCY

	local Graph, InDegree = self:BuildDependencyGraph()
	local Queue, Order = { }, { }

	for Canonical, Degree in pairs(InDegree) do
		if (Degree == 0) then
			table.insert(Queue, Canonical)
		end
	end

	table.sort(Queue)

	while (#Queue > 0) do
		local Current = table.remove(Queue, 1)
		
		table.insert(Order, Current)

		for _, Neighbor in ipairs(Graph[Current]) do
			InDegree[Neighbor] -= 1

			if (InDegree[Neighbor] == 0) then
				table.insert(Queue, Neighbor)
			end
		end

		table.sort(Queue)
	end

	local Nodes = 0

	for _ in pairs(InDegree) do
		Nodes += 1
	end

	if (#Order ~= Nodes) then
		self:ThrowException("CIRCULAR_DEPENDENCY", CircularFormat)
		return nil
	else
		return Order
	end
end

function Qualt:CacheModule(Module)
	local DefaultNamespace = Settings.DEFAULT_NAMESPACE
	local InvalidFormat = Exceptions.INVALID_RETURN_TYPE
	local RequireFail = Exceptions.REQUIRE_FAIL

	local ModuleName = Module.Name

	local Success, Required = pcall(require, Module)

	if (not Success) then
		self:ThrowException(
			"REQUIRE_FAIL",
			string.format(RequireFail, ModuleName)
		)

		return
	end

	if (typeof(Required) ~= "table") then
		self:ThrowException(
			"INVALID_RETURN_TYPE",
			string.format(InvalidFormat, ModuleName)
		)

		return
	end

	local Namespace = Required.namespace or DefaultNamespace

	table.insert(self.Cached, {
		Parent = Module.Parent,
		Name = Module.Name,
		Required = Required,
		Namespace = Namespace
	})
end

function Qualt:Cache(Folder)
	if (not Folder) then
		return
	end

	for _, Module in ipairs(Folder:GetChildren()) do
		if (Module:IsA("ModuleScript")) then
			self:CacheModule(Module)
		elseif (Module:IsA("Folder")) then
			self:Cache(Module)
		end
	end
end

--[[

load in dependencies, whatever

]]

function Qualt:Link()
	local ImportFail = Exceptions.IMPORT_NAMESPACE
	local MissingInjection = Exceptions.MISSING_MODULE_INJECTED
	local InvalidInjection = Exceptions.INVALID_INJECT_TYPE

	local InjectKey = QualtKeys.INJECT
	local ServicesKey = QualtKeys.SERVICES
	local UsingKey = QualtKeys.USING

	for Canonical, ModuleData in pairs(self.Modules) do	
		local Module = ModuleData.data
		
		if (table.isfrozen(Module)) then
			continue
		end
		
		local Using = Module[UsingKey]
		local Inject = Module[InjectKey]
		local Services = Module[ServicesKey]
		
		--[[
		
		what namespace do you want to import?

		same as like using namespace std
		
		]]

		if (Using) then
			for _, Asked in ipairs(Using) do
				local Namespace = self:EstablishNamespace(Asked)

				if (not Namespace) then
					self:ThrowException(
						"IMPORT_NAMESPACE",
						string.format(ImportFail, Asked, Canonical)
					)

					continue
				end

				Module[Asked] = Namespace
			end
		end

		--[[
		
		what do you want to include (DI) ?

		same as #include <whatever>
		
		]]

		if (Inject) then
			for Key, Value in pairs(Inject) do
				if (typeof(Value) ~= "table") then
					Value = { Value }
				end

				for _, RequiredCanonical in ipairs(Value) do
					local AskingFor = self:GetModule(RequiredCanonical)

					if (not AskingFor) then
						self:ThrowException(
							"MISSING_MODULE_INJECTED",
							string.format(MissingInjection, Canonical, RequiredCanonical)

						)

						continue
					end

					if (typeof(AskingFor) ~= "table") then
						self:ThrowException(
							"INVALID_INJECT_TYPE",
							string.format(InvalidInjection, RequiredCanonical, Canonical)
						)

						continue
					end

					Module[Key] = AskingFor.public or { }
				end
			end
		end
		
		--[[
		
		any roblox services?
		
		]]

		if (Services) then
			for Key, Value in pairs(Services) do
				if (typeof(Value) ~= "string") then
					continue
				end

				Module[ServicesKey][Key] = game:GetService(Value)
			end
		end
	end

	self:Export()
end

--[[

run the stuff, since we're done.

]]

function Qualt:Export()
	local NoLoadOrder = Exceptions.NO_LOAD_ORDER
	local InvalidExport = Exceptions.INVALID_EXPORT

	local LoadOrder = self:GetLoadOrder()
	
	if (not LoadOrder) then
		self:ThrowException("NO_LOAD_ORDER", NoLoadOrder)

		return
	end
	
	for _, Canonical in ipairs(LoadOrder) do
		local ModuleData = self.Modules[Canonical]

		local Module = ModuleData.data
		local Export = Module.export
		
		local function LoadTable(Table)
			for Key, Callback in pairs(Table) do
				local Success, Error = pcall(Callback, Module)

				if (not Success) then
					self:ThrowException(
						"INVALID_EXPORT",
						string.format(InvalidExport, Canonical, tostring(Error))
					)
				end
			end
		end
		
		if (Export) then
			task.spawn(LoadTable, Export)
		end 
	end
end

function Qualt:LoadModule(Parent, Name, Module)
	local ScopeKey = QualtKeys.SCOPE
	local DefaultScope = Settings.DEFAULT_SCOPE
	local DefaultNamespace = Settings.DEFAULT_NAMESPACE
	local ReservedNamespaces = Settings.RESERVED_NAMESPACES

	if (typeof(Module) ~= "table") then
		return
	end

	local Scope = Module[ScopeKey] or DefaultScope

	if (Scope == "server" and RunService:IsClient()) then
		return
	elseif (Scope == "client" and RunService:IsServer()) then
		return
	end

	local Namespace = DefaultNamespace

	if (Module.namespace) then
		Namespace = Module.namespace
	end

	if (table.find(ReservedNamespaces.Services, Namespace)) then
		Name = Parent.Name
	end

	local Canonical = self:FormatCanonical(Namespace, Name)
	
	local Path = self:EstablishNamespace(Canonical)
	local Public = Module.public

	if (Public) then
		for Key, Value in pairs(Public) do
			Path[Key] = Value
		end
	end

	self.Modules[Canonical] = { data = Module, namespace = Namespace, scope = Scope }

	return Module
end

function Qualt:GetModule(Canonical)
	local Module = self.Modules[Canonical]

	if (Module) then	
		return Module.data
	end

	for _, Cached in ipairs(self.Cached) do
		local NameCache = self:FormatCanonical(Cached.Namespace, Cached.Name)

		if (NameCache == Canonical) then
			return self:LoadModule(
				Cached.Parent,
				Cached.Name,
				Cached.Required
			)
		end
	end

	return nil
end

function Qualt:GetPublic(Canonical)
	local Module = self:GetModule(Canonical)

	if (not Module) then
		return nil
	end

	local Public = Module.public

	if (Public) then
		return Public
	end

	return nil
end

-- cool

function Qualt:_g(Canonical)
	return Qualt:GetPublic(Canonical)
end

-- port from origin framework 

function Qualt:LoadLibraries()
	local Libraries = Settings.LIBRARY_ROOT
	
	for _, Library in ipairs(Libraries:GetChildren()) do
		if (Library:IsA("ModuleScript")) then
			local Success, Data = pcall(require, Library)

			if (not Success) then 
				continue
			end

			local Behavior = Data.Behavior
			local Logic = Data.Logic
			local Boot = Data.Boot

			local Identity = self.Identity

			local When = Behavior[Identity] -- when to load

			if (not When) then
				continue -- we do not have a behavior for this framework
			end

			local Holder = self.Libraries[When]

			if (not Holder) then
				continue -- no specified logic for this behavior
			end

			Holder[Library.Name] = {
				Boot = Boot,
				Logic = Logic
			}
		end
	end
end

function Qualt:HandleLibraries(Phase)
	local Holder = self.Libraries[Phase]

	if (not Holder) then
		return
	end

	for Name, Library in pairs(Holder) do
		if (Library.Boot) then
			Library.Boot(self.Identity, self)
		end
	end
end

--[[

New thing, cool!

qualt.onUnhandledException("THIS_IS_DUMB", "This is dumb!", function()
	Player:Kick("You are dumb!")
end)

qualt:ThrowException("THIS_IS_DUMB", "Bye)

]]

function Qualt.onUnhandledException(Exception, Message, Callback)
	Exceptions[Exception] = Message

	Callbacks.EXCEPTIONS[Exception] = Callbacks.EXCEPTIONS[Exception] or { }

	table.insert(Callbacks.EXCEPTIONS[Exception], Callback)
end

-- Validate

function Qualt.toException(Given)
	if (Exceptions[Given]) then -- This is a proper exception
		return Given
	end

	return "UNHANDLED_EXCEPTION" -- You can choose how you handle this!
end

function Qualt:setMode(Mode)
	self.Mode = Mode
end

--[[

Does not check for wrong settings. Make sure you don't pass in garbage.

]]

function Qualt:Settings(List)
	for Key, Value in pairs(List) do
		if (Settings[Key]) then
			Settings[Key] = Value
		end
	end
end

function Qualt:Load(Directory)
	if (self.Loaded) then
		return
	end

	self:LoadLibraries()
	
	self:HandleLibraries("pre")

	for Context, Folder in pairs(Directory) do
		self.Directories[Context] = Folder
		
		self:Cache(Folder)
	end

	for _, Data in ipairs(self.Cached) do
		local Parent = Data.Parent
		local Name = Data.Name
		local Required = Data.Required

		self:LoadModule(Parent, Name, Required)
	end

	self:Link()

	self.Loaded = true

	self:HandleLibraries("post")
end

function Qualt.Yield()
	while (not Qualt.Loaded) do
		task.wait()
	end

	return Qualt
end

return Qualt