# About these data tables
These tables allow you to have recursive ID referenced tables of objects, meant for saving/loading object oriented data structures to disk.  
Your main data table should be local to your program, something like  
```lua
local data = {}  
```

except that alone won't be very good, so you should add some base tables  
```lua
local data = {someObjects={},someOtherObjects={}}  
```

The objects that you make should be a table with no functions directly in it, however it may have a metatable set  
```lua
local anObject = {  
  id = "this is a unique identifier", -- id is a mandatory index, this is what this object will be referenced by  
  someOtherObjects = { -- The name of this table does not matter, ALL tables in your object will be searched for the ref tag, any without it will be unmodified  
    ref="someOtherObjects", -- This is where the magic happens, this table is what I'll refer to as a reference table.  
    -- the ref tag signals that this table is an integer indexed ordered array of objects, which reference the index of the base table in the main table  
  }  
  meta = "someObjects" -- the meta key is used as an index into a main metaTable that holds object type metatables  
  -- All other keys are free to use for any purpose  
}  
```

An example of a MetaTable for `anObject` would be:  
```lua
local metaTable = {someObjects={}}  
function metaTable.someObjects:printId()  
  print(self.id)  
end  
metaTable.someObjects.__index = metaTable.someObjects
setmetatable(metaTable.someObjects, metaTable.someObjects)  
```

The functions in `db.lua` have luadoc style documentation, and `example.lua` has some basic examples on object oriented programming in lua, and modifying relationships between objects.