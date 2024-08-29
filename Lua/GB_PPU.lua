require("GB_CPU")
require("GB")

local band, bor, bxor, lshift, rshift, rol, ror = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift, bit.rol, bit.ror

GB_PPU = {}

function GB_PPU:init()
    self.Mode = 0
    self.ModeCycles = 0
    self.Scanline = 0

    self.ScrollX = 0x00 --background
    self.ScrollY = 0x00 --background

    self.UseBG0 = true
    self.UseSet0 = true
    self.DisplayOn = false
    self.BackgroundOn = false
    self.SpritesOn = false
    self.Use88Size = true
    self.WindowOn = false
    self.WindowUseBG0 = true

    self.WindowX = 0x00
    self.WindowY = 0x00

    self.PPU_CTRL = 0x00 --control the lcd and ppu
    self.LCD_STAT = 0x00

    self.BGPallete = 0xE4

    self.SP0Pallete = 0xE4
    self.SP1Pallete = 0xE4

    self.Colors = {}
    for i = 0, 3 do
        self.Colors[i] = band(rshift(self.BGPallete,lshift(i,1)), 0x3)
    end

    self.SP0C = {}
    for i = 0, 3 do
        self.SP0C[i] = band(rshift(self.SP0Pallete,lshift(i,1)), 0x3)
    end

    self.SP1C = {}
    for i = 0, 3 do
        self.SP1C[i] = band(rshift(self.SP1Pallete,lshift(i,1)), 0x3)
    end

    self.Image = {}
    for x=0, 159 do
        self.Image[x] = {}
        for y=0, 143 do
            self.Image[x][y] = math.random(0,3)
        end
    end

    self.OAM = {}
    for i=0, 160 do
        self.OAM[i] = 0x00
    end

    self.DMA_Addr = 0x00 --for DMA Transfer

    self.LYC = 0x00 --lcd y compare

    self.COINC_INT = false
    self.MODE2_INT = false
    self.MODE1_INT = false
    self.MODE0_INT = false

    self.Tileset = {}
    self.VRAM = {}
    self.BG0 = {}
    self.BG1 = {}
    for i=0x0000, 0x1FFF do
        self.VRAM[i] = 0x00
        self.BG0[i] = 0x00
        self.BG1[i] = 0x00
    end
    for ind = 0, 383 do
        self.Tileset[ind] = {}
        for x = 0, 7 do
            self.Tileset[ind][x] = {}
            for y = 0, 7 do
                self.Tileset[ind][x][y] = 0x0
            end
        end
    end
end

function GB_PPU:InitDMA()
    for i = 0, 0x9F do
        self.OAM[i] = GB_CPU:Read(lshift(self.DMA_Addr,8) + i)
    end
end

function GB_PPU:UpdateTileset(Addr,Val)
    local a=band(Addr,0x1FFE)
    --print(hex(a)..", "..hex(Val))
    self.VRAM[band(Addr, 0x1FFF)] = Val
    local tile = band(rshift(a,4), 0x1FF)
    local y = band(rshift(a,1), 0x7)
    local sx
    local str = ""
    local tbll = {[0]="0",[1]="1",[2]="2",[3]="3"}
    for x = 0, 7 do
        sx = lshift(0x1, 7-x)
        local one = rshift(band(self.VRAM[a],sx), 7-x)
        local two = rshift(band(self.VRAM[a+1],sx), 7-x)
        self.Tileset[tile][x][y] = one + (2*two)
        str = str .. tbll[self.Tileset[tile][x][y]]
    end
   -- print(str)
end

function GB_PPU:Step(C)
    --print("Scanline = "..hex(self.Scanline))
    self.ModeCycles = self.ModeCycles + C
    GB_CPU.IFR = band(GB_CPU.IFR, 0xFE)
    if Debug then
    print("PPU: mode = "..self.Mode..", Cycles = "..self.ModeCycles..", Scanline = "..self.Scanline)
    end
    if self.Mode == 2 then --oam read, scanline active
        if self.ModeCycles >= 80 then
            --goto mode 3
            self.Mode = 3
            self.ModeCycles = self.ModeCycles % 80
        end
    elseif self.Mode == 3 then --vram read, scanline active
        if self.ModeCycles >= 172 then
            --goto hblank
            self.Mode = 0
            self.ModeCycles = self.ModeCycles % 172
            if self.MODE0_INT then
                GB_CPU.IFR = bor(GB_CPU.IFR, 0x2) --raise stat interrupt
            end
            --print("rend")
            self:RenderScanline() --render the scanline we just finished
        end
    elseif self.Mode == 0 then --hblank
        if self.ModeCycles >= 204 then
            self.ModeCycles = self.ModeCycles % 204
            self.Scanline = self.Scanline + 1
            if self.Scanline == self.LYC then
                GB_CPU.IFR = bor(GB_CPU.IFR, 0x2)
            end
            if self.Scanline == 144 then
                --goto vblank
                self.Mode = 1
                if self.MODE1_INT then
                    GB_CPU.IFR = bor(GB_CPU.IFR, 0x2)
                end
                GB_CPU.IFR = bor(GB_CPU.IFR, 0x1)
                --setimage
            else
            self.Mode = 2
            if self.MODE2_INT then
                GB_CPU.IFR = bor(GB_CPU.IFR, 0x2)
            end
            end
        end
    elseif self.Mode == 1 then --vblank
        if self.ModeCycles >= 456 then
            self.ModeCycles = 0
            self.Scanline = self.Scanline + 1
            if self.Scanline == self.LYC then
                GB_CPU.IFR = bor(GB_CPU.IFR, 0x2)
            end
            if self.Scanline > 153 then
                self.Mode = 2
                if self.MODE2_INT then
                    GB_CPU.IFR = bor(GB_CPU.IFR, 0x2)
                end
                self.Scanline = 0
            end
        end
    end
end

function s(O) --returns signed value from unsigned 8-bit value
    if O>0x7F then
        return O-0x100
    else
        return O
    end
end

function GB_PPU:RenderScanline()
    if self.DisplayOn == false then for i=0, 159 do self.Image[i][self.Scanline] = 0 end return end --if display is off then render a blank scanline then return
    if self.BackgroundOn then
        self:RenderBackground()
    end

    if self.WindowOn then
        self:RenderWindow()
    end
    
    if self.SpritesOn then
        self:RenderSprites()
    end
end

function GB_PPU:RenderWindow()
    local map_offset = lshift(rshift(self.Scanline+self.WindowY,3),5)
    local line_offset = band(rshift(self.WindowX-7, 3), 0xFF)
    local y = band(self.Scanline+self.WindowY,0x7)
    local x = band(self.WindowX-7, 0x7)
    local tile
    --print(","..hex(map_offset + line_offset))
    if self.WindowUseBG0 then
     tile = self.BG0[map_offset + line_offset]
    else
        tile = self.BG1[map_offset + line_offset]
    end

    if not self.UseSet0 then
        tile = s(tile)
        if tile < 0 then tile = tile + 256 end
    end


    for i = 0, 159 do --render the scanline to the image buffer
        --self.Image[i][self.Scanline] = self.Tileset[tile][x][y]
        local color = self.Colors[self.Tileset[tile][x][y]]
        if color ~= 0 then
        self.Image[i][self.Scanline] = color
        end
        x = x + 1
        if x == 8 then
            x = 0
            line_offset = line_offset + 1
            if self.WindowUseBG0 then
                tile = self.BG0[map_offset + line_offset]
               else
                   tile = self.BG1[map_offset + line_offset]
               end
           
               if not self.UseSet0 then
                   tile = s(tile)
                   if tile < 0 then tile = tile + 256 end
               end
        end
    end
end

function GB_PPU:RenderSprites()
    for sprite = 0, 39 do
        --init all atributes
        local oam_ind = sprite*4
        local SpriteX = self.OAM[oam_ind + 1] - 8
        local SpriteY = self.OAM[oam_ind] - 16
        local tile = self.OAM[oam_ind + 2]
        local attr = self.OAM[oam_ind + 3]

        local FlipX = (band(attr, 0x20) > 0x0)
        local FlipY = (band(attr, 0x40) > 0x0)
        local UsePallete0 = (band(attr, 0x10) == 0x0)
        local PriorityOverBack = (band(attr, 0x80) == 0x0)
        local YSize = 16
        if self.Use88Size then
            YSize = 8
        end


        if self.Scanline >= SpriteY and self.Scanline < SpriteY + YSize then --render the sprite
            if Debug_PPU == true then
                print("rendering sprite "..sprite)
                print("spritex: "..SpriteX)
                print("spritey: "..SpriteY)
                print("tile used: "..tile)
                print("Attributes: "..attr)
                print("pallete: "..(1-i(UsePallete0)))
                print("priority: "..i(PriorityOverBack))
                print("ysize: "..YSize)
                print("flipx,y: "..i(FlipX)..", "..i(FlipY))
                end
            for x = SpriteX, SpriteX + 7 do
                if x < 0 or x > 143 then break end
                if (YSize == 16 and self.Scanline-SpriteY >= 8) then
                    tile = tile + 1
                    SpriteY = SpriteY + 8
                end
                local currX, currY
                if FlipX then
                    currX = 7 - (x - SpriteX)
                else
                    currX = (x - SpriteX)
                end
                if FlipY then
                    currY = 7 - (self.Scanline - SpriteY)
                else
                    currY = (self.Scanline - SpriteY)
                end
                local color = self.SP1C[self.Tileset[tile][currX][currY]]
                if UsePallete0 then
                    color = self.SP0C[self.Tileset[tile][currX][currY]]
                end
                if (self.Image[x][self.Scanline] == 0 and not PriorityOverBack) or (PriorityOverBack and color ~= 0) then
                    --if color == nil then error("Scanline = "..self.Scanline..", tile = "..hex(tile)..", x = "..x..", y = "..self.Scanline-SpriteY..", tileset = "..self.Tileset[tile][x-SpriteX][self.Scanline - SpriteY]) end
                    self.Image[x][self.Scanline] = color
                end
            end
        end
    end
end

function GB_PPU:RenderBackground()
    --print("render sncsa")
    --print(self.ScrollY)
    local map_offset = lshift(rshift(self.Scanline+self.ScrollY,3),5)
    local line_offset = rshift(self.ScrollX, 3)
    local y = band(self.Scanline+self.ScrollY,0x7)
    local x = band(self.ScrollX, 0x7)
    local tile
    --print(","..hex(map_offset + line_offset))
    if self.UseBG0 then
     tile = self.BG0[map_offset + line_offset]
    else
        tile = self.BG1[map_offset + line_offset]
    end

    if not self.UseSet0 then
        tile = s(tile)
        if tile < 0 then tile = tile + 256 end
    end


    for i = 0, 159 do --render the scanline to the image buffer
        --self.Image[i][self.Scanline] = self.Tileset[tile][x][y]
        self.Image[i][self.Scanline] = self.Colors[self.Tileset[tile][x][y]]
        x = x + 1
        if x == 8 then
            x = 0
            line_offset = band(line_offset + 1, 31)
            if self.UseBG0 then
                tile = self.BG0[map_offset + line_offset]
               else
                   tile = self.BG1[map_offset + line_offset]
               end
           
               if not self.UseSet0 then
                   tile = s(tile)
                   if tile < 0 then tile = tile + 256 end
               end
        end
    end
end