local tests = {
	{
		input = [[<abc a1="A1" a2="A2">inside tag `abc'</abc>]],
		totable = {
			[0] = "abc",
			a1 = "A1",
			a2 = "A2",
			"inside tag `abc'",
		},
		clean = { -- no whitesapce, no changes
			[0] = "abc",
			a1 = "A1",
			a2 = "A2",
			"inside tag `abc'",
		},
		torecord = { -- no single entries, no changes
			[0] = "abc",
			a1 = "A1",
			a2 = "A2",
			"inside tag `abc'",
		},
	},
	{
		input = [[<qwerty q1="q1" q2="q2">
	<q2>some text</q2>
	<asdf>some text</asdf>
</qwerty>]],
		totable = {
			[0] = "qwerty",
			q1 = "q1",
			q2 = "q2",
			"\n\t",
			{
				[0] = "q2",
				"some text",
			},
			"\n\t",
			{
				[0] = "asdf",
				"some text",
			},
			"\n",
		},
		clean = {
			[0] = "qwerty",
			q1 = "q1",
			q2 = "q2",
			{
				[0] = "q2",
				"some text",
			},
			{
				[0] = "asdf",
				"some text",
			},
		},
		torecord = {
			[0] = "qwerty",
			q1 = "q1",
			q2 = "q2",
			{
				[0] = "q2", -- does not overwrite the existing q2 entry
				"some text",
			},
			asdf = "some text", -- entry moved to a field
		},
	},
	{
		input = [[
<!-- http://www.w3schools.com/xml/simple.xml -->
<breakfast_menu>
	<food>
		<name>Belgian Waffles</name>
		<price>$5.95</price>
		<description>Two of our famous Belgian Waffles with plenty of real maple syrup</description>
		<calories>650</calories>
	</food>
	<food>
		<name>Strawberry Belgian Waffles</name>
		<price>$7.95</price>
		<description>Light Belgian waffles covered with strawberries and whipped cream</description>
		<calories>900</calories>
	</food>
	<food>
		<name>Berry-Berry Belgian Waffles</name>
		<price>$8.95</price>
		<description>Light Belgian waffles covered with an assortment of fresh berries and whipped cream</description>
		<calories>900</calories>
	</food>
	<food>
		<name>French Toast</name>
		<price>$4.50</price>
		<description>Thick slices made from our homemade sourdough bread</description>
		<calories>600</calories>
	</food>
	<food>
		<name>Homestyle Breakfast</name>
		<price>$6.95</price>
		<description>Two eggs, bacon or sausage, toast, and our ever-popular hash browns</description>
		<calories>950</calories>
	</food>
</breakfast_menu>]],
		totable = {
			[0] = "breakfast_menu",
			[1] = "\n\t",
			[2] = {
				[0] = "food",
				[1] = "\n\t\t",
				[2] = { [0] = "name", [1] = "Belgian Waffles", },
				[3] = "\n\t\t",
				[4] = { [0] = "price", [1] = "$5.95", },
				[5] = "\n\t\t",
				[6] = {
					[0] = "description",
					[1] = "Two of our famous Belgian Waffles with plenty of real maple syrup",
				},
				[7] = "\n\t\t",
				[8] = { [0] = "calories", [1] = "650", },
				[9] = "\n\t",
			},
			[3] = "\n\t",
			[4] = {
				[0] = "food",
				[1] = "\n\t\t",
				[2] = { [0] = "name", [1] = "Strawberry Belgian Waffles", },
				[3] = "\n\t\t",
				[4] = { [0] = "price", [1] = "$7.95", },
				[5] = "\n\t\t",
				[6] = {
					[0] = "description",
					[1] = "Light Belgian waffles covered with strawberries and whipped cream",
				},
				[7] = "\n\t\t",
				[8] = { [0] = "calories", [1] = "900", },
				[9] = "\n\t",
			},
			[5] = "\n\t",
			[6] = {
				[0] = "food",
				[1] = "\n\t\t",
				[2] = { [0] = "name", [1] = "Berry-Berry Belgian Waffles", },
				[3] = "\n\t\t",
				[4] = { [0] = "price", [1] = "$8.95", },
				[5] = "\n\t\t",
				[6] = {
					[0] = "description",
					[1] = "Light Belgian waffles covered with an assortment of fresh berries and whipped cream",
				},
				[7] = "\n\t\t",
				[8] = { [0] = "calories", [1] = "900", },
				[9] = "\n\t",
			},
			[7] = "\n\t",
			[8] = {
				[0] = "food",
				[1] = "\n\t\t",
				[2] = { [0] = "name", [1] = "French Toast", },
				[3] = "\n\t\t",
				[4] = { [0] = "price", [1] = "$4.50", },
				[5] = "\n\t\t",
				[6] = {
					[0] = "description",
					[1] = "Thick slices made from our homemade sourdough bread",
				},
				[7] = "\n\t\t",
				[8] = { [0] = "calories", [1] = "600", },
				[9] = "\n\t",
			},
			[9] = "\n\t",
			[10] = {
				[0] = "food",
				[1] = "\n\t\t",
				[2] = { [0] = "name", [1] = "Homestyle Breakfast", },
				[3] = "\n\t\t",
				[4] = { [0] = "price", [1] = "$6.95", },
				[5] = "\n\t\t",
				[6] = {
					[0] = "description",
					[1] = "Two eggs, bacon or sausage, toast, and our ever-popular hash browns",
				},
				[7] = "\n\t\t",
				[8] = { [0] = "calories", [1] = "950", },
				[9] = "\n\t",
			},
			[11] = "\n",
		},
		clean = {
			[0] = "breakfast_menu",
			[1] = {
				[0] = "food",
				[1] = { [0] = "name", [1] = "Belgian Waffles", },
				[2] = { [0] = "price", [1] = "$5.95", },
				[3] = {
					[0] = "description",
					[1] = "Two of our famous Belgian Waffles with plenty of real maple syrup",
				},
				[4] = { [0] = "calories", [1] = "650", },
			},
			[2] = {
				[0] = "food",
				[1] = { [0] = "name", [1] = "Strawberry Belgian Waffles", },
				[2] = { [0] = "price", [1] = "$7.95", },
				[3] = {
					[0] = "description",
					[1] = "Light Belgian waffles covered with strawberries and whipped cream",
				},
				[4] = { [0] = "calories", [1] = "900", },
			},
			[3] = {
				[0] = "food",
				[1] = { [0] = "name", [1] = "Berry-Berry Belgian Waffles", },
				[2] = { [0] = "price", [1] = "$8.95", },
				[3] = {
					[0] = "description",
					[1] = "Light Belgian waffles covered with an assortment of fresh berries and whipped cream",
				},
				[4] = { [0] = "calories", [1] = "900", },
			},
			[4] = {
				[0] = "food",
				[1] = { [0] = "name", [1] = "French Toast", },
				[2] = { [0] = "price", [1] = "$4.50", },
				[3] = {
					[0] = "description",
					[1] = "Thick slices made from our homemade sourdough bread",
				},
				[4] = { [0] = "calories", [1] = "600", },
			},
			[5] = {
				[0] = "food",
				[1] = { [0] = "name", [1] = "Homestyle Breakfast", },
				[2] = { [0] = "price", [1] = "$6.95", },
				[3] = {
					[0] = "description",
					[1] = "Two eggs, bacon or sausage, toast, and our ever-popular hash browns",
				},
				[4] = { [0] = "calories", [1] = "950", },
			},
		},
		torecord = {
			[0] = "breakfast_menu",
			[1] = {
				[0] = "food",
				name = "Belgian Waffles",
				price = "$5.95",
				description = "Two of our famous Belgian Waffles with plenty of real maple syrup",
				calories = "650",
			},
			[2] = {
				[0] = "food",
				name = "Strawberry Belgian Waffles",
				price = "$7.95",
				description = "Light Belgian waffles covered with strawberries and whipped cream",
				calories = "900",
			},
			[3] = {
				[0] = "food",
				name = "Berry-Berry Belgian Waffles",
				price = "$8.95",
				description = "Light Belgian waffles covered with an assortment of fresh berries and whipped cream",
				calories = "900",
			},
			[4] = {
				[0] = "food",
				name = "French Toast",
				price = "$4.50",
				description = "Thick slices made from our homemade sourdough bread",
				calories = "600",
			},
			[5] = {
				[0] = "food",
				name = "Homestyle Breakfast",
				price = "$6.95",
				description = "Two eggs, bacon or sausage, toast, and our ever-popular hash browns",
				calories = "950",
			},
		},
	},
}


describe("totable:", function()

	local totable
	before_each(function()
		totable = require "lxp.totable"
	end)


	for i, test in ipairs(tests) do

		describe("case " .. i .. ":", function()

			local preamble = [[<?xml version="1.0" encoding="ISO-8859-1"?>]]
			local input = preamble .. test.input

			it("totable", function()
				local result = assert(totable.parse(input))
				assert.same(test.totable, result)
			end)


			it("clean", function()
				local result = assert(totable.parse(input))
				totable.clean(result)
				assert.same(test.clean, result)
			end)


			it("torecord", function()
				local result = assert(totable.parse(input))
				totable.torecord(totable.clean(result))
				assert.same(test.torecord, result)
			end)

		end)

	end

end)
