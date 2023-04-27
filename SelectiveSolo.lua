---
--- Created by geroh.
--- DateTime: 26.04.2023 21:29
---
---
---Description:
--- This plugin was made to provide an alternative to the solo function. Instead of affecting all fixtures 
--- it only touches the current selection. 
--- The user can define a lowlight preset in the all preset pool otherwise lowlight is definded as dimmer at 0.
--- Three Macros "Previous", "Set" and "Next" are generated and must be used instead of the 
--- buttons on the console to work with the selective solo function. 
---
---
---Usage: 
---     -Select a group of fixtures
---     -Step through the selection unsing the generated macros and make the changes you want
---     -Reselect all fixtures using the generated "Set" macro
---     -Store the new values 
---
---
---Notes: 
---     -Update can not be used to update presets while working with this plugin!
---     -Store the lowlight preset at a position in the preset pool that won't be touched, as the plugin writes presets 
---      to store values and will overwrite any presets near the lowlight preset

-----------------------------------------------------
----EDIT HERE TO SET LOWLIGHTPRESET----
-----------------------------------------------------

---User Variables---
local lowlightPreset = nil --replace "nil" with the number of your lowlight preset

-----------------------------------------------------
----API----------------------------------------------
-----------------------------------------------------



MA = {}
local report = {}



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
    --returns the handle of an object (The internal pointer)
    handle = gma.show.getobj.handle
,
    --returns the "class of the object
    class = function(obj)
        return gma.show.getobj.class(MA.get.handle(obj))
    end
,
    --returns the label of the object
    label = function (obj)
        return gma.show.getobj.label(MA.get.handle(obj))
    end,

    exists = function(obj)
        local handle = MA.get.handle(obj)
        if(not handle) then
           return false 
        end
        return gma.show.getobj.verify(handle)
    end,

    var = gma.show.getvar
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
    }
}



--------------------------------
-----PLUGIN CODE STARTS HERE----
--------------------------------


---Program Variables---
local MAtricksON = false
local highlightPreset
local bufferPreset
local deactivationPreset

function setup()
    --create lowlightPreset if none is set
    if(lowlightPreset == nil) then
        lowlightPreset = 1
        while(MA.get.exists('Preset 0.'..lowlightPreset))do
            lowlightPreset = lowlightPreset+1
        end
        cmdF('BlindEdit On')
        cmdF('Fixture 1 thru')
        cmdF('At 0')
        cmdF('Store Preset 0.%d /u',lowlightPreset)
        cmdF('Label Preset 0.%d "Lowlight',lowlightPreset)
        cmdF('ClearAll')
        cmdF('BlindEdit Off')
    end

    --create highightPreset if none is set
    highlightPreset = lowlightPreset+1
    while(MA.get.exists('Preset 0.'..highlightPreset))do
        highlightPreset = highlightPreset+1
    end

    deactivationPreset = 1+highlightPreset
    while(MA.get.exists('Preset 0.'..deactivationPreset))do
        deactivationPreset = deactivationPreset+10
    end

    bufferPreset = 1+deactivationPreset
    while(MA.get.exists('Preset 0.'..bufferPreset))do
        bufferPreset = bufferPreset+1
    end

    --create macros 
    local prevMacroNum = 1
    while(MA.get.exists('Macro '..prevMacroNum) or MA.get.exists('Macro '..prevMacroNum+1) or MA.get.exists('Macro '..prevMacroNum+2))do
       prevMacroNum = prevMacroNum+1 
    end
    local setMacroNum = prevMacroNum+1
    local nextMacroNum = prevMacroNum+2

    local prevMacro = MA.class.Macro:new(prevMacroNum,'Previous')
    prevMacro:append(string.format('Lua \'previous(%d,%d,%d)\'',bufferPreset,lowlightPreset,highlightPreset))

    local setMacro = MA.class.Macro:new(setMacroNum,'Set')
    setMacro:append(string.format('Lua \'set(%d,%d,%d,%d)\'',bufferPreset,lowlightPreset,highlightPreset,deactivationPreset))

    local nextMacro = MA.class.Macro:new(nextMacroNum,'Next')
    nextMacro:append(string.format('Lua \'next(%d,%d,%d)\'',bufferPreset,lowlightPreset,highlightPreset))

    gma.gui.msgbox('Selection Solo',string.format('Tree plugins created \nPrev:  %d\nSet:   %d\nNext:  %d',prevMacroNum,setMacroNum,nextMacroNum))
end

function previous(bufferPreset_p,lowlightPreset_p,highlightPreset_p)
    MAtricksON = true
    gma.echo('prev')
    saveChanges(bufferPreset_p,lowlightPreset_p,highlightPreset_p)
    cmdF('previous')
    activateNextFixture(bufferPreset_p,highlightPreset_p)
end

function set(bufferPreset_p,lowlightPreset_p,highlightPreset_p,deactivationPreset_p)
    saveChanges(bufferPreset_p,lowlightPreset_p,highlightPreset_p)
    cmdF('MAtricks Toggle')
    activateNextFixture(bufferPreset_p,highlightPreset_p)
    if(MAtricksON) then
        cmdF('Store Preset 0.%d /o',deactivationPreset_p)
        cmdF('At Preset 0.%d',deactivationPreset_p)
        cmdF('Store Preset 0.%d /r',bufferPreset_p)
        cmdF('At Preset 0.%d',deactivationPreset_p)
        cmdF('Delete Preset 0.%d',deactivationPreset_p)
    end
    MAtricksON = not MAtricksON
end

function next(bufferPreset_p,lowlightPreset_p,highlightPreset_p)
    MAtricksON =true
    saveChanges(bufferPreset_p,lowlightPreset_p,highlightPreset_p)
    cmdF('Next')
    activateNextFixture(bufferPreset_p,highlightPreset_p)
end


function saveChanges(bufferPreset_p,lowlightPreset_p,highlightPreset_p)
    cmdF('Store Preset 0.%d /m /s',bufferPreset_p)
    cmdF('Store Preset 0.%d /use="allforselected" /m /e="true"',highlightPreset_p)
    cmdF('At Preset 0.%d',lowlightPreset_p)
    cmdF('ClearActive')
end

function activateNextFixture(bufferPreset_p,highlightPreset_p)
    cmdF('At Preset 0.%d',highlightPreset_p)
    cmdF('ClearActive')
    cmdF('At Preset 0.%d', bufferPreset_p)
end

return setup
