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
    textinput = function(title, default)
        return gma.textinput(title,default)
    end,

    handle = function(obj)
        return gma.show.getobj.handle(obj)
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
        propertyName = string.gsub(propertyName," ","")
        if(not string.match( value,"[a-zA-Z]") and not string.match(value,"%.%.")) then
            cmdF('Assign %s /%s=%s',obj,propertyName,value)
        else
            value = string.gsub(value,"|"," ")
            cmdF('Assign %s /%s="%s"',obj,propertyName,value)
        end
    end
}

MA.class = {
    Effect = {
        new = function (self, number)
            local o = {}
            o.number = number
            feedback('Created effect object for effect %d',number)

            setmetatable(o,self)
            self.__index = self

            return o
        end,

        copySettingsTo = function(self, other, boolTable)
            if(MA.get.exists('Effect '..self.number) and MA.get.exists('Effect '..other.number)) then
                local amountSelf = MA.get.childCount(MA.get.handle('Effect '..self.number))
                local amountOther = MA.get.childCount(MA.get.handle('Effect '..other.number))

                boolTable = boolTable or {  --default settings
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


                boolTable[6] = boolTable[6] and not boolTable[7] and not boolTable[5] --disable speed copy if speedmaster or rate are copied as well (the properties overwrite each other)

                for destinationLine = 0, amountOther-1 do
                    local sourceLine = destinationLine%amountSelf
                    local sourceTabel = MA.get.child('Effect '..self.number,sourceLine)

                    local destinationTable = MA.get.child('Effect '..other.number,destinationLine)
                    for i = 1, 18 do
                        if(boolTable[i] and i ~= 2) then
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


--------------------------------------
----PLUGIN CODE-----------------------
----EDIT HERE-------------------------
--------------------------------------

----Set all properties that should be copied to true---

local copySettings = {
                    true, -- (1) Interleave
                    false, -- (2) Attribute       >>>>THE ATTRIBUTE PROPERTY OF AN EFFECT CAN NOT BE COPIED USING THIS PLUGIN!<<<<<
                    false, -- (3) Mode (abs/rel)
                    false, -- (4) Form              
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


-------------------------------------- 
----DO NOT EDIT BEYOND THIS POINT-----
--------------------------------------                    

function copyEffectSettings()
    local userSource = tonumber(tIn('Copy from (Effect number)',''))
    local userDest = tIn('Copy to','') --TODO add support for range of effects

    local effectSoure = class.Effect:new(userSource)
    if(not get.exists('Effect '..effectSoure.number)) then
        feedback("Copy source (Effect %d) does not exist",effectSoure.number)
        return
    end

    local effectDest = class.Effect:new(userDest)
    if(not get.exists('Effect '..effectDest.number)) then
        feedback("Copy destination (Effect %d) does not exist",effectDest.number)
        return
    end

    effectSoure:copySettingsTo(effectDest,copySettings)
end