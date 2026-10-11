--[[
	
	// .qualt Luau Framework { [2025] - [202x] }
  	// Written by normal - [ ._.normal ] / east - [ e2st ]

]]

A Luau framework with Dependency Injection, Namespaces, and a boot lifecycle. Basically, me wanting to make it look a bit like
C++, and with assistance in mitigating circular injection which causes errors.

This covers:

Modules, Namespaces, Settings, Exceptions, Libraries.

## //------------------------------------------ Modules: ------------------------------------------//

Once a module is loaded from Cache into .Loaded, you can get it.

### To get the Module table from .Loaded (not Public functions):

qualt:GetModule("MODULE_NAME")

This will return the ENTIRE module required. Everything that comes along with it.

### To get the public functions of the module:

These are functions that are available for other scripts to use.

You can do qualt:GetPublic("MODULE_NAME")

This will return the .public table of the module.

An alias for this function is qualt:_g("MODULE_NAME")

### Creating Modules:

These are quite strict. But this is a valid module, which will be loaded by qualt once :Load() is ran validly.

```

local Module = {
	inject = { ... },
	using = { },

	public = { },
	private = { },

	export = { },
	services = { ... },

	namespace = "NAMESPACE",
	scope = "SCOPE",
}

function Module.export.Load()

end

return Module

```

### Inject:

To inject a module, you can provide a Key for it, and the full path of the module.

Example: 

inject = { iostream = "std::iostream" }

This will add a new field in Module, named "iostream" with ALL the public functions of std::iostream.

Like this:

{
	iostream = { print = <fn>, etc }
}

So you can use it: Module.iostream.print(...), and it will work

### Using:

You can import ENTIRE namespaces.

e.g., using = { "std" } will create a NEW field in Module, with the key of "std". 
That key will be equal to the ENTIRE std namespace.

Check Namespace Layouts (below) on how its structured to use the namespace.

### Public:

Anything here, is going to be exported as [Key] = [Value].
This will be available in the namespace. A function in this case. Check Namespace Layouts on how its going to look like

### Private: 

This is optional, but can be used for organization. Private functions, that shouldn't be checked at all.

### Export:

Once qualt loads, EVERY single function in this table is ran. 

Example:

export = { some_fn = function() end }

Once qualt loads, some_fn is loaded. No arguments passed, though.

### Services:

Not required. You can just use game:GetService("") at the top.

Example if you do use it:

services = { some_service = "name_of_service" }

"name_of_service" must be available, that means it needs to return a valid object from :GetService().

some_service will be replaced with the :GetService() object.

So you can use it like:

Module.services.some_service.doSomething().

A bit long, so just use :GetService()

### Namespace:

Must be a string. Check Namespace Layouts (below) on what is a valid namespace.

### Scope:

must be either "client", "server" or "shared". Self-explanatory.


## //------------------------------------------ Namespace Layouts: ------------------------------------------//

For a namespace, each Module belonging to that namespace will have their Public functions in there. Key of the public function, and value of it.

{
	std = {
		print,
		something_else
	}
}

All of them are just dumped there.

### Valid namespaces:

From the Settings part, a namespace is typically a string. Like "abc" is a valid namespace. You can extend onto this to make it fancier, by doing "abc$something".

This creates a NEW table in the abc namespace. So it looks like this:

{
	abc = {
		something = {
			something_functions, etc...
		},
		abc_functions, ...
	}
}

Useful if you use "using = { ... }"

## //------------------------------------------ Framework Settings: ------------------------------------------//

### Debug mode:

qualt:setMode("NEW_MODE")

"debug" will print all errors to the output. Anything other than "debug" will NOT print

### Boot settings:

You can update the settings of how qualt will boot.

** THIS DOES NOT OVERWRITE THE TABLE FULLY. INSTEAD, IF THE SETTING KEY EXISTS
THEN IT WILL OVERWRITE IT. YOU DO NOT NEED THE ENTIRE TABLE FILLED

Use qualt:Settings({ ... })

These are the fields: 

```
{
	["RESERVED_NAMESPACES"] = {
		["Services"] = { "srvc", "ctrl" },
	},
	["LIBRARY_ROOT"] = game:GetService("ReplicatedStorage"):WaitForChild("Libraries"),
	["DEFAULT_NAMESPACE"] = "g",
	["NAMESPACE_FORMAT"] = "::",
	["EXTENSION_FORMAT"] = "$",
	["DEFAULT_SCOPE"] = "shared"
}
```

"RESERVED_NAMESPACES" are for internal handling, and should be ignored. Unless you modify the framework, that is.

"LIBRARY_ROOT" is where qualt checks for new libraries to load them. 
Make this the directory of the libraries.

"DEFAULT_NAMESPACE" is the default namespace modules will be assigned with, if they do not have a namespace.

"NAMESPACE_FORMAT" is how the namespace will be formatted with the modules name. If namespace is "g" and module name is "module", then it will be

"g" .. FORMAT .. "module"
With a format of "::", you get "g::module"

"EXTENSION_FORMAT" is extending the namespace, more depth.

This allows for nested namespace.s

Example:

"g$utils::module" 
"std$utils::print"
"a$b$c::d"

Useful if you want to break it into multiple nested categories.
Like:

Standard > Utils, Math, Etc 

"DEFAULT_SCOPE" should be left alone.

// Booting & Usage:

### To boot qualt, run qualt:Load(DIRECTORIES)

The directories table looks like this:

```
{
	["shared"] = Path.to.object,
	["client"] = Path.to.object,
	["server"] = Path.to.object,

}

```

The keys MUST be "shared", "client", OR "server".

Obviously, do not include all of them. You will need two
scripts to run the framework. Have client & shared on one, 
and server & shared on the other. The Path.to.object does NOT need :GetChildren() ran on it. Just a valid object in the Datamodel.
It is the place where qualt looks for valid modules to load.

Example of Booting qualt:

```
qualt:setMode("debug")
qualt:Settings({
	["DEFAULT_NAMESPACE"] = "std",
})

qualt:Load({
	["shared"] = game.ReplicatedStorage.Modules.qualt,
	["server"] = game.ServerScriptService.Server.qualt
})

```

### Waiting for it to load:

use qualt.Yield(). You can do:

local q = require("path.to.qualt").Yield(), as it returns the framework as a return value. 

## //------------------------------------------ Libraries: ------------------------------------------//

A library is a module made specifically to work with other frameworks. 
Usually, these are for generic utils, made for multiple frameworks. Currently, qualt supports them
but they are intended for my other frameworks. 

### How to make a Library:

```

local Module = { }

function Boot()
	-- You can put ANYTHING you want here, to run once the framework runs.
end

--[[

Version is just for style.

Behavior acts in this way. For each framework key (e.g., "qualt"), you can indicate a status.
This means the framework will load THIS LIBRARY at THAT status. "pre" states that qualt is going to be
in the "pre" loading status.

All the loading states: 

"pre" -- Before it has loaded
"post" -- After it has loaded.

In that case, "it" refers to qualt.

]]

return {
	Version = "1.0.0",
	Behavior = {
		["qualt"] = "pre"
	},

	Boot = function(Who, Running)
        Boot()
	end,

	--[[

		The "Boot" function gives TWO arguments.

		Who is the IDENTITY of the framework running this.
		Like: "qualt". 

		Running is the ENTIRE framework given there. For example, qualt would give ALL of its code. All the functions, etc.

	]]

	Logic = Module

	--[[

		"Logic" is useful if you want to require this
		without it being a framework. Just requiring in general.

	]]
}

```

## //------------------------------------------ Exceptions: ------------------------------------------//

An exception is a sort of error. You can provide error handling for this.

### To throw one:

qualt:ThrowException("EXCEPTION_KEY", MESSAGE_OR_ARGS)

If MESSAGE_OR_ARGS is a String type, it will be printed out. If there a fail handler,
then the MESSAGE_OR_ARGS is passed into that error handler.

### To register Callbacks (unhandled exceptions):

qualt.onUnhandledException("EXCEPTION_KEY", "DEFAULT_MESSAGE", ERROR_HANDLER)

"EXCEPTION_KEY" is a string, on how the exception is keyed.
"DEFAULT_MESSAGE" is for debugging. Just a default message, not important.

ERROR_HANDLER is a callback. This is the error handler, which was talked about in ThrowException. If you throw one and it is the same key, then ERROR_HANDLER is called.

### To check if the exception is valid:

qualt.toException("EXCEPTION_KEY").

Returns "EXCEPTION_KEY" or "UNHANDLED_EXCEPTION".
