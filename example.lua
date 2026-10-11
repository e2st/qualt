local main = {
	inject = { },
	using = { },

	public = { },
	private = { },

	export = { },
	services = { },

	namespace = "std",
	scope = "client",
}

function main.public.doSomething(message)
	print(message)
end

function main.export.load()
	print("Hello from the client!")
end

return main