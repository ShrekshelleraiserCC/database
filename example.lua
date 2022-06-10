-- example program
-- register some people
-- then make them friends!
-- maybe add some enemies!
-- and some checks to make sure that friends aren't enemies..
-- give them a city, that city has other people in it
-- okay that's enough for a sample program
local db = require("db")
local data = {cities={},people={}}

local person = {}
person.__index = person
function person.new(name, age)
  local p = {
    id = name, -- id is what this object will be referenced by
    age = age,
    friends = {ref="people"}, -- The ref key is used as the index into the recursive table to search
    enemies = {ref="people"}, -- for these examples it will check data["people"] to reference IDs
    city = {ref="cities"},
    meta = "person", -- Meta refers to the key into a metatable table. In this example it will assign metaT["person"] as the metatable when loading
  }
  setmetatable(p, person)
  data.people[#data.people+1] = p
end

function person:addFriend(friend)
  if (db.tableContainsObject(self.enemies, friend)) then
    print(string.format("%s is already enemies with %s", self.id, friend.id))
    return false -- Exclusive references
  elseif (db.tableContainsObject(self.friends, friend)) then
    print(string.format("%s is already friends with %s", self.id, friend.id))
    return false -- Ensure we don't reference twice
  end
  db.addLinkedReference(self, friend, "friends")
  return true
end

function person:addEnemy(enemy)
  if (db.tableContainsObject(self.friends, enemy)) then
    print(string.format("%s is already friends with %s", self.id, enemy.id))
    return false
  elseif (db.tableContainsObject(self.enemies, enemy)) then
    print(string.format("%s is already enemies with %s", self.id, enemy.id))
    return false
  end
  db.addLinkedReference(self, enemy, "enemies")
  return true
end

function person:move(c)
  self.city[1]:removePerson(self) -- example of going a copule references in and then referencing the original object you came from
  c:addPerson(self)
end

local city = {}
city.__index = city
function city.new(name)
  local c = {
    id = name,
    population = 0,
    citizens = {ref="people"},
    neighboringCities = {ref="cities"},
    meta = "city"
  }
  setmetatable(c, city)
  data.cities[c.id] = c
end

function city:addPerson(p)
  db.addObject(self.citizens, p)
  p.city[1] = self -- Example of an enforced single reference
  self.population = #self.citizens
end

function city:removePerson(p)
  db.removeObject(self.citizens, p)
  p.city[1] = nil
  self.population = #self.citizens
end

local metaT = {person=person, city=city} -- metatable table used for loading

-- Stuff below here is to get the user input / handle running this example program
-- It's very poorly written.. I suggest looking at everything above this for reference, and pretending this doesn't exist
--- Function to get a valid reference
-- @return false | table reference
local function getValidSelection(type, friendlyString)
  while true do
    io.write(string.format("Enter a %s or 'q': ",friendlyString))
    local input = io.read()
    if (input == "q") then return false end -- user decided to quit
    local status, index = db.tableContainsTableWithValueAtKey(data[type], "id", input)
    if (status) then
      -- input references an object!
      return data[type][index]
    end
    local preColor = term.getTextColor()
    term.setTextColor(colors.red)
    print("That doesn't exist!")
    term.setTextColor(preColor)
  end
end

local function exploreTable(T, depth, path)
  depth = depth or 0
  path = path or "data"
  local preColor = term.getTextColor()
  while true do
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.red)
    print("Enter '..' to go up a layer, or the key of a table to explore deeper")
    print("Path: "..path)
    print(string.format("Current depth: %u", depth))
    term.setTextColor(colors.white)
    for k, v in pairs(T) do
      if type(v) == "table" then
        print(string.format("[%s] { ... }", k))
      else
        print(string.format("[%s] %s", k, v))
      end
    end
    io.write("Enter .. or key: ")
    local k = io.read()
    if (k == "..") then term.setTextColor(preColor) return end
    if tonumber(k) then
      k = tonumber(k)
    end
    if type(T[k]) == "table" then
      exploreTable(T[k], depth + 1, string.format("%s[%s]",path,k))
    else
      print("That is not a table!")
    end
  end
end

local function doEventLoop()
  print("Welcome to this sample program.")
  print("This will hopefully demonstrate the capabilities of my library.")
  while true do
    term.setTextColor(colors.blue)
    print("Please choose an option:")
    print("(0) Add a person")
    print("(1) Add a city")
    print("(2) Modify a person")
    print("(3) Modify a city")
    print("(4) Explore the recursive structure")
    print("(5) Save")
    print("(6) Load")
    print("(q) Quit")
    term.setTextColor(colors.white)
    term.write("> ")
    local input = io.read()
    if (input == "0") then -- Add person
      term.write("Name: ")
      local name = io.read()
      term.write("Age: ")
      local age = io.read() -- I'm leaving the ages as strings. Yes you'll probably notice you can type in whatever you want for age
      person.new(name, age)

    elseif (input == "1") then -- Add city
      term.write("City name: ")
      local name = io.read()
      city.new(name)

    elseif (input == "2") then -- Modify person
      local p = getValidSelection("people", "person")
      if p then
        print("Select an option")
        print("(0) Add a friend")
        print("(1) Add an enemy")
        print("(2) Move to a different city")
        local choice = io.read()
        if (choice == "0" or choice == "1") then
          newPerson = getValidSelection("people", "person")
          if (choice == "0") and newPerson then
            p:addFriend(newPerson)
          elseif newPerson then
            p:addEnemy(newPerson)
          end
        elseif (choice == "2") then
          newCity = getValidSelection("cities", "city")
          if newCity then
            p:move(newCity)
          end
        end
      end

    elseif (input == "3") then -- Modify city
      local c = getValidSelection("cities", "city")
      if c then
        print("Enter person to move to city")
        local p = getValidSelection("people", "person")
        if p then
          c:addPerson(p)
        end
      end

    elseif (input == "4") then -- explore
      exploreTable(data)
    elseif (input == "5") then -- save
      io.write("Enter filename or q: ")
      local filename = io.read()
      if filename ~= "q" then
        io.write("Compact? 'yes'/?: ")
        local compact = io.read()
        db.saveRecursiveTable(data, filename, compact == "yes")
      end
    elseif (input == "6") then -- load
      print("Enter filename or q: ")
      local filename = io.read()
      if filename ~= "q" then
        _, data = db.loadRecursiveTable(filename, metaT)
        data = data or {cities={}, people={}}
      end
      
    elseif (input == "q") then
      return
    end
  end
end

doEventLoop()