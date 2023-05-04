MA = {}
local report = {}

function echo(...)
    gma.echo(string.format(...))
end

function feedback(...)
    gma.feedback(string.format(...))
end

function labelObj(obj,number,name)
    cmdF('Label %s %s "%s"',obj,number,name)
end


function setApperanceObj(obj,color)
    color.r = color.r or 0
    color.g = color.g or 0
    color.b = color.b or 0
    cmdF('Appearance %s /r = %d /g = %d /b = %d',obj,color.r,color.g,color.b)
end

function cmdF(...)
    local command = string.format(...)
    gma.cmd(command)
end



MA.get = {
    --TODO add check for cancel action
    textinput = function(title, default)
        return gma.textinput(title,default)
    end,

    --returns the handle of an object (The internal pointer)
    handle = function(obj)
        return gma.show.getobj.handle(obj)
    end
,
    --returns the "class of the object
    class = function(obj)
        return gma.show.getobj.class(MA.get.handle(obj))
    end
,
    --returns the label of the object
    label = function (obj)
        return gma.show.getobj.label(MA.get.handle(obj))--TODO catch nil return on no name set
    end,

    exists = function(obj)
        return gma.show.getobj.verify(MA.get.handle(obj))
    end,

    childCount = function(handle)
        return gma.show.getobj.amount(handle)
    end,

    child = function(obj, index)
        return gma.show.getobj.child(MA.get.handle(obj),index)
    end,

    var = gma.show.getvar,

    ---returns the amount of property fields for that object
    ---@param handle number - see get.handle
    ---@return string - amount of propertys specified for this object
    propertyAmount = function(handle)
        return gma.show.property.amount(handle)
    end,

    ---returns the name of a property from the specified object
    ---@param handle number - see get.handle
    ---@param index number - the index of the specific property
    ---@return string - Name of the property field 
    propertyName = function(handle, index)
        return gma.show.property.name(handle,index)
    end,

    ---returns the value of a property from the specified object
    ---@param handle number - see get.handle
    ---@param index number - the index of the specific property
    ---@return string - Value of the property field
    propertyValue = function(handle, index)
        return gma.show.property.get(handle,index)
    end
,


    ----Object specific functions----
    --[[
    determines the size of the group
        param: group:num
        return: number of fixtures in the Group
    --]]
    groupSize = function(group)
        cmdF('ClearSelection')
        cmdF('Group '..group)
        local size = MA.get.var('SELECTEDFIXTURESCOUNT')
        cmdF('ClearSelection')
        return size
    end,
}


MA.set = {

    ---sets the property of the object to the specified value if the property is editable
    ---@param obj table - gma2 name for the object (e.g. Effect 1.1.1 -> line 1 of effect 1)
    ---@param index number - the index of the specific property (e.g. 17 for wings of an effect)
    ---@param value string - the value the property should take
    ---@param handle number - (optional) if obj specifies multiple objects handle can give the handle to one of the data tables to read out property names
    property = function(obj, index, value, handle)
        handle = handle or MA.get.handle(obj)

        local propertyName = string.gsub(MA.get.propertyName(handle,index),"|","")
        if(string.match( value,"^%-?%d+$")) then
            cmdF('Assign %s /%s=%f',obj,propertyName,tonumber(value))
        else
            cmdF('Assign %s /%s="%s"',obj,propertyName,value)
        end
    end
}

MA.class = {
    Macro = {
        --[[
        creates a new Macro object and stores the macro in the console
        param:
            number:num  --Number in console
            name:str    --Name for the macro (optional)
        --]]
        new = function (self, number, name)
            gma.echo('NEW MAC')
            local o = {}
            o.number = number
            o.line = 1

            setmetatable(o,self)
            self.__index = self
            gma.echo(number)
            gma.echo(name)

            cmdF('Store Macro %d',number)
            if(name) then labelObj('Macro',number, name) end

            return o
        end,

        setLine = function(self, line,command,wait,info)
            if(line>self.line+1)then--check if the given line is within the macro
                errors:append(string.format('Macro.setLine: Macro:%d    Line:%d    Command:%s;      Line out of bounds: %d',self.number,line,command,self.line))
                return
            end

            if(not MA.get.verify(string.format('Macro 1.%d.%d',self.number,line))) then --check if line already exists
                cmdF('Store Macro 1.%d.%d',self.number,line) -- create line
                self.line = line --update line variable
            end
            cmdF('Assign Macro 1.%d.%d /cmd = "%s"', self.number,line,command) --assign the command
            if(wait)then cmdF('Assign Macro 1.%d.%d /wait = %s',self.number,line,wait) end
            if(info)then cmdF('Assign Macro 1.%d.%d /wait = "%s"',self.number,line,info) end

        end,

        append = function(self, command, wait, info)
            cmdF('Store Macro 1.%d.%d',self.number,self.line) -- create line
            cmdF('Assign Macro 1.%d.%d /cmd = "%s"', self.number,self.line,command) --assign the command
            if(wait)then cmdF('Assign Macro 1.%d.%d /wait = %s',self.number,self.line,wait) end
            if(info)then cmdF('Assign Macro 1.%d.%d /wait = "%s"',self.number,self.line,info) end
            self.line = self.line+1
        end,

        label = function(self,name)
            labelObj('Macro '..self.number, name)
        end,

        setAppearance = function(self,color)
            --make sure all values are given
            color.r = color.r or 0
            color.g = color.g or 0
            color.b = color.b or 0

            --set appearance
            setApperanceObj('Macro '..self.number, color)
        end,

        appearanceAt = function(self,obj)
            cmdF('Appearance Macro %d At %s',self.number,obj)
        end,

        assignExec = function(self,exec)
            cmdF('Assign Macro %d Exec %s',self.number,exec)
        end
    },

    Effect = {
        new = function (self, number)
            local o = {}
            o.number = number
            feedback('Created effect object for effect %d',number)

            setmetatable(o,self)
            self.__index = self

            return o
        end,

        copySettingsTo = function(self, other, boolTable) --FIXME children of effect object represent single lines in the effect change approach to work with that
            if(MA.get.exists('Effect '..self.number) and MA.get.exists('Effect '..other.number)) then
                local amountSelf = MA.get.childCount(MA.get.handle('Effect '..self.number))
                local amountOther = MA.get.childCount(MA.get.handle('Effect '..other.number))

                boolTable = boolTable or {
                    true, -- (1) Interleave
                    false, -- (2) Attribute         -> special assign syntax
                    false, -- (3) Mode (abs/rel)
                    false, -- (4) Form              -> special assign syntax
                    false, -- (5) Rate
                    false, -- (6) Speed
                    false, -- (7) Speed Group
                    false, -- (8) Dir (</>/Bounce</Bounce>)
                    false, -- (9) Low value
                    false, -- (10) High value
                    false, -- (11) Phase
                    false, -- (12) Width
                    false, -- (13) Attack
                    false, -- (14) Decay
                    true, -- (15) Groups
                    true, -- (16) Blocks
                    true, -- (17) Wings
                    false,} -- (18) Singel Shot 

                for destinationLine = 0, amountOther-1 do
                    local sourceLine = destinationLine%amountSelf
                    local sourceTabel = MA.get.child('Effect '..self.number,sourceLine)

                    local destinationTable = MA.get.child('Effect '..other.number,destinationLine)
                    for i = 1, 18 do
                        if(boolTable[i] and not i == 2) then
                            --Attribute copying is disabled because due to the mapping from the propertys from source to destination
                            -- there could be more than one line with the same attribute created in the destination thereby breaking that line.

                            echo('Copying %d.%d %s',sourceLine, i, gma.show.property.name(sourceTabel,i))
                            local value = MA.get.propertyValue(sourceTabel,i)
                            
                            if i == 4 then --handle form property
                                local splitTable = {}
                                for str in string.gmatch(value,"([^%s]+)") do
                                    splitTable[#splitTable+1] = str
                                end
                                value = tonumber(splitTable[#splitTable])
                                cmdF('Assign Form %d at Effect 1.%d.%d',value,other.number,destinationLine+1)
                            else
                                MA.set.property(string.format('Effect 1.%d.%d',other.number,destinationLine+1),i,value,destinationTable) 
                            end
                        end
                    end
                end
            else
                feedback('Effect source (%d) or destination (%d) does not exists',self.number,other.number)
            end
        end
    }
}

local get = MA.get
local class = MA.class
local Effect = class.Effect

local tIn = get.textinput

function test()
    local source = Effect:new(1)
    local dest = Effect:new(2)

    source:copySettingsTo(dest)
end

return test