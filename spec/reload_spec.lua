describe("module reloading", function()

	-- test based on https://github.com/tomasguisasola/luaexpat/issues/2
	it("reloads module if dropped", function()
		package.loaded.lxp = nil
		local first_lxp = require "lxp"
		assert.is_table(first_lxp)
		assert.is_function(first_lxp.new)

		package.loaded.lxp = nil
		local second_lxp = require "lxp"
		assert.is_table(second_lxp)
		assert.is_function(second_lxp.new)

		assert.not_equal(first_lxp, second_lxp)
	end)

end)
