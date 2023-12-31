require "ISUI/ISPanelJoypad"

zxMarkChunk = ISPanelJoypad:derive("zxMarkChunk")

function zxMarkChunk:new(x, y, width, height)
    width, height = 200, 94
    local o = ISPanelJoypad.new(self,x, y, width, height)
    o.textWidth = 80
    o.boxWidth = 50
    o.font = UIFont.Small
    return o
end

function zxMarkChunk:createChildren()
    local lineHeight = getTextManager():getFontHeight(self.font) + 7
    local pad = 5
    local x1 = self.textWidth + pad * 2
    local y1 = pad+lineHeight
    local x2 = x1 + self.boxWidth + pad
    local y2 = y1+lineHeight

    local function onCommandEntered(self)
        return self.parent:OnMarkChunk()
    end
    local function addEntryBox(self,id,x,y)
        local newBox = ISTextEntryBox:new("",x,y,self.boxWidth,0)
        newBox:initialise()
        newBox:instantiate()
        newBox:setOnlyNumbers(true)
        newBox.onCommandEntered = onCommandEntered
        self[id] = newBox
        self:addChild(newBox)
    end
    addEntryBox(self,"xOffset",x1,y1)
    addEntryBox(self,"yOffset",x2,y1)
    addEntryBox(self,"xInput",x1,y2)
    addEntryBox(self,"yInput",x2,y2)

    self.markButton = ISButton:new(pad, y2+lineHeight, self.width-2*pad, lineHeight, "Mark Chunk", self, self.OnMarkChunk)
    self:addChild(self.markButton)
end

function zxMarkChunk:render()
    local pad = 5
    local font = UIFont.Small
    local lineHeight = getTextManager():getFontHeight(self.font) + 7
    local x1 = self.textWidth + pad * 2 + 1
    local x2 = x1 + self.boxWidth + pad
    local y = pad

    local square = getPlayer():getSquare()
    if square:getChunk() ~= self.IsoChunk then --possible follow player option
        self.IsoChunk = square:getChunk()
        self.xCurrent = tostring(math.floor(square:getX()/10))
        self.yCurrent = tostring(math.floor(square:getY()/10))
    end
    self:drawText("Current Chunk", pad, y, 1, 1, 1, 1, font)
    self:drawText(self.xCurrent, x1+3, y, 1, 1, 1, 1, font)
    self:drawText(self.yCurrent, x2+3, y, 1, 1, 1, 1, font)
    y=y+lineHeight
    self:drawText("Chunk Offset", pad, y, 1, 1, 1, 1, font)
    y=y+lineHeight
    self:drawText("Set Chunk Var ", pad, y, 1, 1, 1, 1, font)

    if zxMarkChunk.toCheck then self.markButton.tooltip = "Unloaded chunk queued" else self.markButton.tooltip = nil end --possible improve
end

function zxMarkChunk:markChunk(IsoChunk, x, y)
    local markers = {}
    local z = getPlayer():getZ()
    for i=0,9 do
        for v=0,9 do
            local square = IsoChunk:getGridSquare(i,v,z)

            --if not squares[square] then
            --    squares[square] = IsoSprite.new()
            --    squares[square]:LoadFramesNoDirPageSimple('media/ui/FloorTileCursor.png')
            --end
            --squares[square]:RenderGhostTileColor(x+i, y+v, z, 1, 1, 1, 0)
            --squares[square]:RenderGhostTileColor(200, 200, 0, 1, 1, 1, 0)

            if square then
                local floor = square:getFloor()
                if floor then
                    floor:setHighlighted(true,false)
                    floor:setHighlightColor(1,0.7,0,0.4)
                end
                if i == 0 or i == 9 or v ==0 or v == 9 or i == v or i+v == 9 then
                    table.insert(markers,getWorldMarkers():addGridSquareMarker("circle_center", "circle_shadow", square, 1, 0.7, 0, true, 0.5, 0.001, 0.3, 0.7)) --low visibility in vegitation
                    --chunk.markers[index]:setDoBlink(true)
                end
            end
        end
    end
    self.marked = { x = x, y = y, z = z, markers = markers }
end

function zxMarkChunk:unmarkChunk()
    if not self.marked then return end
    local x,y,z,markers = self.marked.x*10, self.marked.y*10, self.marked.z, self.marked.markers
    local index = 0
    for i=0,9 do
        for v=0,9 do
            index = index+1
            local square = getSquare(x+i,y+v,z)
            if square then
                local floor = square:getFloor()
                if floor then floor:setHighlighted(false) end
            end
        end
    end
    for _,marker in ipairs(markers) do
        getWorldMarkers():removeGridSquareMarker(marker)
    end
    self.marked = nil
end

function zxMarkChunk:OnMarkChunk()
    self:unmarkChunk()
    zxMarkChunk.toCheck = nil

    local x = tonumber(self.xInput:getText())
    if type(x) ~= "number" then x = tonumber(self.xCurrent) end
    local xOff = tonumber(self.xOffset:getText())
    if type(xOff) == "number" then x = x + xOff end
    x = math.floor(x)
    local y = tonumber(self.yInput:getText())
    if type(y) ~= "number" then y = tonumber(self.yCurrent) end
    local yOff = tonumber(self.yOffset:getText())
    if type(yOff) == "number" then y = y + yOff end
    y = math.floor(tonumber(y))

    if x < 0 or y < 0 then return print("Can't mark negative chunks") end --not yet
    local IsoChunk = getCell():getChunk(x,y)
    if not IsoChunk then
        return self:addToCheck(x,y)
    end
    return self:markChunk(IsoChunk,x,y)
end

function zxMarkChunk:onRemoveFromUIManager()
    self:unmarkChunk()
    zxMarkChunk.toCheck = nil
end

function zxMarkChunk:addToCheck(x,y)
    zxMarkChunk.toCheck = { x = x, y = y, instance = self }
    return Events.LoadGridsquare.Add(zxMarkChunk.checkToMark)
end

function zxMarkChunk.checkToMark(square)
    if not zxMarkChunk.toCheck then return Events.LoadGridsquare.Remove(zxMarkChunk.checkToMark) end
    local x, y = math.floor(square:getX()/10), math.floor(square:getY()/10)
    if x == zxMarkChunk.toCheck.x and y == zxMarkChunk.toCheck.y then
        Events.LoadGridsquare.Remove(zxMarkChunk.checkToMark)
        zxMarkChunk.toCheck.instance:markChunk(square:getChunk(),x,y)
        zxMarkChunk.toCheck = nil
    end
end

require "ISUI/ISCollapsableWindow"
zxMarkChunkWindow = ISCollapsableWindow:derive("zxMarkChunkWindow")

function zxMarkChunkWindow:new(x,y,w,h)
    local o = ISCollapsableWindow.new(self,x,y,w,h)
    o:setResizable(false)
    o.title = "Mark Chunk"
    return o
end

function zxMarkChunkWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()

    self.markChunk = zxMarkChunk:new(0,th,0,0)
    self.markChunk:initialise()
    self:addChild(self.markChunk);

end

function zxMarkChunkWindow:setVisible(visible)
    self.reallyvisible = visible
    return ISCollapsableWindow.setVisible(self,visible)
end

function zxMarkChunkWindow:removeFromUIManager()
    self.markChunk:onRemoveFromUIManager()
    return ISCollapsableWindow.removeFromUIManager(self)
end

function zxMarkChunkWindow.toggleWindow()
    local instance = zxMarkChunkWindow.instance
    if instance then
        if instance.reallyvisible then
            instance.reallyvisible = nil
            instance:removeFromUIManager()
        else
            --instance.reallyvisible = true
            instance:addToUIManager()
            instance:setVisible(true)
        end
    else
        instance = zxMarkChunkWindow:new(200,200,200,110)
        instance.reallyvisible = true
        zxMarkChunkWindow.instance = instance
        instance:addToUIManager()
        ISLayoutManager.RegisterWindow('zxmarkchunkwindow', zxMarkChunkWindow, instance)
    end
end

local function checkIsInGame()
    if MainScreen.instance:isVisible() then return false end
    local player = getPlayer()
    if not player or player:isDead() then return false end
    return true
end

local function OnKeyPressed(key)
    if key == Keyboard.KEY_6 and isShiftKeyDown() then
        return checkIsInGame() and zxMarkChunkWindow.toggleWindow()
    end
end

Events.OnKeyPressed.Add(OnKeyPressed)
