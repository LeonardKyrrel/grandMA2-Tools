---
--- Created by geroh.
--- DateTime: 04.05.2023 10:00
---
---
---Description:
--- This plugin can be used to copy "settings" from one existing effect to other effects. (The effects have to already exists in the effect pool)
--- e.g. if there is a dimmer effect and a seperate color effect this plugin can be used to transfere settings like groups or wings from one to the other.
--- Currently all properties can be transfered except selection an attribute type.
--- The user can decide if the properties of one specific line should be copied to all lines of the destination effects or if the all lines in the source should be mapped to the destination effects.
--- For the destination the user can enter a range of effects as one would in the command line. (e.g. 1 Thru 20 - 5 + 42)  -> Accepted operators are: {Thru, thru, +, -}
---
---Usage: 
---     -Select the properties that should be transfered by editing the table below
---     -Choose if only a single line should be used as the source 
---     -Start the plugin and enter the number of the effec you want to copy to/from
---
---
---Notes: 
---     -Attribute type can not be copied
---     -Selection can currently not be transfered
---     -When copying high or low values there can be problems when copying from one fixturetype to another or across different attributes



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

local singleLineCopy = true     --if set to true the plugin asks for the line in the source effect from wich the data should be copied (given the effect has more than one line)
                                --otherwise it will cycle over all lines of the source effect until all lines in the destination have received new values



-------------------------------------- 
----DO NOT EDIT BEYOND THIS POINT-----
--------------------------------------   


    
-----------------------------------------------------
----API----------------------------------------------
-----------------------------------------------------



MA = {}
local report = {}
local sourceEffectLine

function echo(...)
    gma.echo(string.format(...))
end

function feedback(...)
    gma.feedback(string.format(...))
end

---Get the escape code to set the following text in the command line to the specified color
---@param color string - Set the color. Can be: BLACK; RED; YELLOW; GREEN; CYAN; BLUE; MAGENTA; WHITE.
---@return string - Escape code 
function colorEscape(color)
    local colorCodes = {BLACK = 30, RED = 31, GREEN = 32, YELLOW = 33, BLUE = 34, CYAN = 35, MAGENTA = 36, WHITE = 37}
    return string.char(27) .. "[" .. colorCodes[color] .. "m"
end

---Can be used to make debug prints. Output will be shown in cyan
---@param ... unknown -input for string.format( "formatstring",... )
function printTest(...)
    feedback(colorEscape("CYAN")..string.format(...))
end

---Can be used to print warnings/errors for the user while running a plugin
---@param ... unknown - input for string.format( "formatstring",... )
function printError(...)
    feedback(colorEscape("YELLOW")..">>>"..colorEscape("RED")..string.format(...)..colorEscape("YELLOW").."<<<")
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

            setmetatable(o,self)
            self.__index = self

            return o
        end,

        ---Copy properties from one effect to another
        ---boolTable is used to define which properties to copy. 
        ---If no settings are provided Interleave, Groups, Blocks and Wings are used as default settings
        ---@param self table, object of the source effect
        ---@param other table, object of the copy destination
        ---@param boolTable table, boolean table to define which properties to cop
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

                local sourceLine = sourceEffectLine
                local sourceTabel = MA.get.child('Effect '..self.number,sourceLine)

                for destinationLine = 0, amountOther-1 do
                    if(not singleLineCopy) then
                        sourceLine = destinationLine%amountSelf
                        sourceTabel = MA.get.child('Effect '..self.number,sourceLine)
                    end

                    local destinationTable = MA.get.child('Effect '..other.number,destinationLine)
                    for i = 1, 18 do
                        if(boolTable[i] and i ~= 2) then
                            --Attribute copying is disabled because due to the mapping from the propertys from source to destination
                            -- there could be more than one line with the same attribute created in the destination thereby breaking that line.
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


function copyEffectSettings()
    local userSource = tonumber(tIn('Copy from (Effect number)',''))

    local effectSoure = class.Effect:new(userSource)
    if(not get.exists('Effect '..effectSoure.number)) then
        printError("Copy source (Effect %d) does not exist",effectSoure.number)
        return
    end
    if(singleLineCopy) then 
        local lineCount = get.childCount(get.handle("Effect "..effectSoure.number))
        sourceEffectLine = tonumber(tIn("Choose Source Line (1-".. lineCount ..")",''))-1 --TODO add input verification
    end



    local userDest = tIn('Copy to','') --TODO change to use one assign statement per effect
    if(string.match(userDest,"thru") or string.match(userDest,"Thru") or string.match(userDest,"+") or string.match(userDest,"-")) then --process range string pattern

        local destTable = {}
        local lastNumber
        local lastOperator
        local expectingNumber = true

        for str in string.gmatch(userDest,"%S+") do --split by spaces and itterate over all resulting strings

            if(expectingNumber and str:match("[0-9]")) then
                local currentNumber = tonumber(str)

                if(not lastNumber or lastOperator == "+") then --if this is the first number read
                    lastNumber = currentNumber
                    destTable[#destTable+1] = currentNumber
                elseif(lastOperator == 'Thru' or lastOperator == 'thru') then
                    for i = lastNumber+1, currentNumber do
                        destTable[#destTable+1] = i
                    end
                    lastNumber = currentNumber
                elseif(lastOperator == "-") then
                    lastNumber = currentNumber
                    for i = 1, #destTable do
                        if(destTable[i] == currentNumber) then
                            table.remove(destTable,i)
                        end
                    end
                else
                    return
                end
                expectingNumber = false
                lastOperator = nil
            elseif((not expectingNumber) and (str=="thru" or str == "Thru" or str == "+" or str == "-")) then
                lastOperator = str
                expectingNumber = true
            else
                return
            end
        end

        for i = 1, #destTable do

            local currentDest = destTable[i]
            local effectDest = class.Effect:new(currentDest)
            if(tonumber(userSource) == tonumber(currentDest))then
                printError('Source and destination are equal (Source: %d; Dest: %d)',userSource,currentDest)
            elseif(not get.exists('Effect '.. effectDest.number)) then
                printError("Copy destination (Effect %d) does not exist",effectDest.number)
            end

            effectSoure:copySettingsTo(effectDest,copySettings)
        end
    else

        local effectDest = class.Effect:new(userDest)
        if(tonumber(userSource) == tonumber(userDest))then
            printError('Source and destination are equal')
            return
        elseif(not get.exists('Effect '..effectDest.number)) then
            printError("Copy destination (Effect %d) does not exist",effectDest.number)
            return
        end

        effectSoure:copySettingsTo(effectDest,copySettings)
    end
end

return copyEffectSettings