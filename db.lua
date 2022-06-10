local expect = require("cc.expect")
local api = {}
-- Written by ShreksHellraiser 2022
-- You're free to redistribute with credit.

--- Get a UUID string, this is recommended for use in your complex data structures
-- @return string
-- https://gist.github.com/jrus/3197011
function api.generateUUID()
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)
end

local function isValueInTable(value, T)
  for k, v in pairs(T) do
    if v == value then
      return true
    end
  end
  return false
end

--- Change ID String references to direct links to tables
-- ID String -> Reference to table
-- @param dataT base table to reference by
-- @param T nil, table; table to modify used for recursion
-- @param refStack nil, table; used for recursion
local function recurseFlatTable(dataT, T, refStack)
  expect(1, dataT, "table")
  refStack = refStack or {}
  T = T or dataT

  for key, value in pairs(T) do
    if T.ref and key ~= "ref" then
      assert(type(value) == "string", "Attempt to dereference non-string ID.")
      assert(type(dataT[T.ref][value]) ~= "nil", string.format("Attempt to de-reference non-existant ID %s of type %s", value, T.ref))
      T[key] = dataT[T.ref][value]

    elseif key ~= "ref" and type(value) == "table" then
      if not isValueInTable(key, refStack) then
        -- Ensure we're not iterating over duplicate items
        refStack[#refStack + 1] = key
        recurseFlatTable(T[key], refStack)
        refStack[#refStack] = nil
      end
    end
  end
end

--- Reference to table -> ID String
-- ID String -> Reference to table
-- @param T table to modify
-- @param refStack nil, table; used for recursion
local function flattenRecursiveTable(T, refStack)
  expect(1, T, "table")
  refStack = refStack or {}
  for key, value in pairs(T) do
    if T.ref and key ~= "ref" then
      assert(type(value) == "table", "Attempt to reference non-table.")
      assert(type(value.id) ~= "nil", "Attempt to reference object with no ID")
      T[key] = value.id

    elseif key ~= "ref" and type(value) == "table" then
      if not isValueInTable(key, refStack) then
        -- Ensure we're not iterating over duplicate items
        refStack[#refStack + 1] = key
        flattenRecursiveTable(T[key], refStack)
        refStack[#refStack] = nil
      end
    end
  end
end

-- ID String -> Reference to table
-- @param T table to modify
-- @param metaT table table of metatables to apply
-- @param refStack nil, table; used for recursion
local function applyMetatables(T, metaT, refStack)
  expect(1, T, "table")
  refStack = refStack or {}
  if type(T.meta) == "string" then
    setmetatable(T, api[T.meta])
  end
  for key, value in pairs(T) do
    if type(value) == "table" and not isValueInTable(key, refStack) then
      refStack[#refStack + 1] = key
      applyMetatables(T[key], refStack)
      refStack[#refStack] = nil
    end
  end
end

--- Reference to table -> ID String
-- ID String -> Reference to table
-- @param T table to clone and dereference
-- @param refStack nil, table; used for recursion
-- @return table
local function flattenRecursiveTableClone(T, refStack)
  expect(1, T, "table")
  refStack = refStack or {}
  local tmpT = {}
  for key, value in pairs(T) do
    if T.ref and key ~= "ref" then
      assert(type(value) == "table", "Attempt to reference non-table.")
      assert(type(value.id) ~= "nil", "Attempt to reference object with no ID")
      tmpT[key] = value.id

    elseif key ~= "ref" and type(value) == "table" then
      if not isValueInTable(key, refStack) then
        -- Ensure we're not iterating over duplicate items
        refStack[#refStack + 1] = key
        tmpT[key] = flattenRecursiveTableClone(T[key], refStack)
        refStack[#refStack] = nil
      end
    else
      tmpT[key] = value
    end
  end
  return tmpT
end

--- Serialize a recursive/reference filled table
-- @param T table to serialize
-- @param compact optional boolean to compact string; default true
-- @return string serialized table
function api.serializeRecursiveTable(T, compact)
  expect(1, T, "table")
  if type(compact) ~= "boolean" then compact = true end
  local tmpT = flattenRecursiveTableClone(T)
  return textutils.serialize(tmpT, { compact = compact })
end

--- Save a recursive table to file
-- @param T table to save
-- @param filename string
-- @param compact boolean, default true
-- @return boolean success
function api.saveRecursiveTable(T, filename, compact)
  expect(1, T, "table")
  expect(2, filename, "string")
  local f = fs.open(filename, "w")
  if f then
    f.write(api.serializeRecursiveTable(T,compact))
    f.close()
    return true
  end
  return false
end

--- Load recursive table from file
-- @param filename: string
-- @param metaT table, nil: metatables to apply
-- @return boolean: success, table: loaded table
function api.loadRecursiveTable(filename, metaT)
  expect(1, filename, "string")
  local f = fs.open(filename, "r")
  if f then
    local T = textutils.unserialise(f.readAll())
    recurseFlatTable(T)
    if (metaT) then
      applyMetatables(T, metaT)
    end
    f.close()
    return true, T
  end
  return false
end

function api.tableContainsTableWithValueAtKey(T, k, value)
  for index,v in ipairs(T) do
    if v[k] == value then
      return true, index
    end
  end
  return false
end

--- Attempt to return an object from a reference table by ID
-- Should also work for a base table
-- @param T reference table
-- @param id any ID of object to search for
-- @return object or nil
function api.indexReferenceByID(T, id)
  local state, index = api.tableContainsTableWithValueAtKey(T, "id", id)
  if state then
    return T[index]
  end
  return nil
end

--- Intended to search through a ref table for an object with id
-- @param T Table reference table i.e. {{id="A"},{id="B"},ref="object"}
-- @param obj Table object to search for
-- @return boolean contains object, int index of object
function api.tableContainsObject(T, obj)
  expect(1, T, "table")
  expect(2, obj, "table")
  return api.tableContainsTableWithValueAtKey(T, "id", obj.id)
end

--- Attempts to remove an object from a reference table
-- @param T Table reference table i.e. {{id="A"},{id="B"},ref="object"}
-- @param obj Table object to remove
-- @return boolean object was removed
function api.removeObject(T, obj)
  expect(1, T, "table")
  expect(2, T, "table")
  local hasObject, objectIndex = api.tableContainsObject(T, obj)
  if hasObject then
    table.remove(T, objectIndex)
    return true
  end
  return false -- table doesn't contain object
end

--- Attempts to add an object to a reference table
-- @param T Table reference table i.e. {{id="A"},{id="B"},ref="object"}
-- @param obj Table object to add
-- @return boolean object was added
function api.addObject(T, obj)
  expect(1, T, "table")
  expect(2, T, "table")
  local hasObject, objectIndex = api.tableContainsObject(T, obj)
  if not hasObject then
    T[#T+1] = obj
    return true
  end
  return false -- table contains object already
end

--- Attempts to add a linked reference to each object, referencing the other object
-- These references are added at the key provided
-- @param obj1 table, object 1
-- @param obj2 table, object 2
-- @param k1 Any, key into array where the reference table is
-- i.e. k="objs" for {id="obj1",objs={ref="obj"}}
-- @param k2 Any, key into array where the reference table is, defaults to k1
-- @return boolean success
function api.addLinkedReference(obj1, obj2, k1, k2)
  expect(2, obj1, "table")
  expect(4, obj2, "table")
  k2 = k2 or k1
  return api.addObject(obj1[k1], obj2) and api.addObject(obj2[k2], obj1)
end

--- Attempts to remove a linked reference to each object, referencing the other object
-- These references are removed from the key provided
-- @param obj1 table, object 1
-- @param obj2 table, object 2
-- @param k1 Any, key into array where the reference table is
-- i.e. k="objs" for {id="obj1",objs={ref="obj"}}
-- @param k2 Any, key into array where the reference table is, defaults to k1
-- @return boolean success
function api.removeLinkedReference(obj1, obj2, k1, k2)
  expect(2, obj1, "table")
  expect(4, obj2, "table")
  k2 = k2 or k1
  return api.removeObject(obj1[k1], obj2) and api.removeObject(obj2[k2], obj1)
end

--- Validates that each object in obj[k] has a link back to obj in obj[k][i][lk] where i is the index of the linked object
-- @param obj table object
-- @param k any index to reference table in obj
-- @param lk any index to reference table that should contain obj in each object in obj[k]
-- @return boolean success
-- @return int first index of obj in obj[k][index] that does not contain a link back
function api.validateLinkedReference(obj, k, lk)
  expect(1, obj, "table")
  for index,v in ipairs(obj[k]) do
    if not api.tableContainsObject(v[lk], obj) then
      return false, index
    end
  end
  return true
end

return api