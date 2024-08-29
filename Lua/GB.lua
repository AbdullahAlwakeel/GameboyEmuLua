GB = {}

local band, bor, bxor, lshift, rshift, rol, ror = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift, bit.rol, bit.ror

--currently implemented cartridge types
C_ROMONLY = 0x00
C_MBC1 = 0x01

BIOS_Active = true --Set to false to skip BIOS sequence all-together, useful if you don't have

BIOS = {...} --Add in BIOS here as an array of bytes, removed for copyright reasons

function GB:init(ROMNAME,SKIPBIOS)
    local RomIO=io.open(ROMNAME, "rb")
local RomT=RomIO:read("*all")
print("Read ROM file.")
io.close(RomIO)
print("Finished Reading")
print("ROM SIZE: "..#RomT.." bytes")

ROM={}
for i=1, #RomT do
    ROM[i-1] = string.byte(RomT, i, i)
end
self.CartType = ROM[0x0147]
if ROM[0x0147] == C_ROMONLY then
    print("Cartridge Type: ROM ONLY")
elseif ROM[0x0147] == C_MBC1 then
    print("Cartridge Type: MBC1")
    self.CurrROMBank = 0x01
    self.CurrRAMBank = 0x0
    self.RAM_Enabled = false
    self.Use_RAM_Banking = false
else
    print("Unknown/Unimplemented Cartridge Type "..hex(self.CartType))
    self.CartType = C_MBC1
end


    GB_CPU:init(ReadMem, WriteMem)
    GB_PPU:init()
    GB_SND:init()
    self.WRAM = {}
    self.ZRAM = {}
    for i = 0xC000, 0xE000 do
        self.WRAM[i] = 0x00
    end
    for i = 0xFF80, 0xFFFF do
        self.ZRAM[i] = 0x00
    end
    self.Joy = 0xFF --Joypad matrix register

    --timers:
    self.DIV = 0x00
    self.TIMA = 0x00
    self.TMA = 0x00
    self.TAC = 0x00

    self.ModuloCyclesT = 0
    self.ModuloCyclesD = 0

    self.TimerOn = false
    self.TimerCLK = 1024
    self.TimerCLKS = {[0]=1024, [1]=16, [2]=64, [3]=256} --cycles per timer count

    if SKIPBIOS then
        GB_CPU.PC = 0x0100
        BIOS_Active = false
    end

    self.A_J = false
    self.B_J = false
    self.START_J = false
    self.SELECT_J = false

    self.UP_J = false
    self.DOWN_J = false
    self.LEFT_J = false
    self.RIGHT_J = false
end

function GB:ReadROM(Addr)
    if self.CartType == C_ROMONLY then return ROM[Addr]
    elseif self.CartType == C_MBC1 then
        if Addr < 0x4000 then
            return ROM[Addr]
        else
            return ROM[(Addr-0x4000) + (self.CurrROMBank*0x4000)]
        end
    end
end

function GB:WriteROM(Addr,Data)
    if self.CartType == C_MBC1 then
        if Addr < 0x2000 then
            self.RAM_Enabled = (band(Data,0xF) == 0xA)
        elseif Addr >= 0x2000 and Addr < 0x4000 then
            self.CurrROMBank = band(Data,0x1F)
            if band(self.CurrROMBank,0x1F) == 0x00 then self.CurrROMBank = self.CurrROMBank + 1 end
        elseif Addr >= 0x4000 and Addr < 0x6000 then
            if self.Use_RAM_Banking then
                self.CurrRAMBank = band(Data,0x3)
            else
                self.CurrROMBank = lshift(band(Data,0x3), 5) + self.CurrROMBank
            end
        elseif Addr >= 0x6000 then
            self.Use_RAM_Banking = (band(Data,0x1) > 0x0)
        end
    end
end

clock_speed = 4194304
cycles_per_frame = math.floor(clock_speed / 60)
--cycles_per_frame = 100
function GB:Update()
    local cycles = 0
    local locked_up = false
    while cycles < cycles_per_frame do
        if Debug then
            cycles_per_frame = 1
        end
        local Prev_PC = GB_CPU.PC
        local n_cycles = GB_CPU:RunOnce()
        self:TimerUpdate(n_cycles)
        if (GB_CPU.PC == 0x00FA or GB_CPU.PC == 0x00E9) and BIOS_Active then --locked up
            if locked_up then
            error("BIOS FAIL, LOCKED UP")
            else
            locked_up = true
            end
        else
            locked_up = false
        end

        --if GB_CPU.PC >= 0x0034 and GB_CPU.PC < 0x0040 then Debug = true end
        --if GB_CPU.PC >= 0x0040 and Debug then error("end of debug") end

        if GB_CPU.PC >= 0x100 and BIOS_Active then
            BIOS_Active = false
            print("PASSED BIOS")
        end
        GB_PPU:Step(n_cycles)
        cycles = cycles + n_cycles

        --Joypad updating
        self.Joy = band(self.Joy, 0xF0)
        if band(self.Joy, 0x20) == 0x0 then --A, B, SELECT, START
            if not self.A_J then self.Joy = bor(self.Joy, 0x1) end
            if not self.B_J then self.Joy = bor(self.Joy, 0x2) end
            if not self.SELECT_J then self.Joy = bor(self.Joy, 0x4) end
            if not self.START_J then self.Joy = bor(self.Joy, 0x8) end
        elseif band(self.Joy, 0x10) == 0x0 then --RIGHT, LEFT, UP, DOWN
            if not self.RIGHT_J then self.Joy = bor(self.Joy, 0x1) end
            if not self.LEFT_J then self.Joy = bor(self.Joy, 0x2) end
            if not self.UP_J then self.Joy = bor(self.Joy, 0x4) end
            if not self.DOWN_J then self.Joy = bor(self.Joy, 0x8) end
        end
    end
end


function GB:TimerUpdate(cycles)
    if self.TimerOn then
    self.ModuloCyclesT = self.ModuloCyclesT + cycles
    if self.ModuloCyclesT >= self.TimerCLK then
        self.TIMA = self.TIMA + 1
        if self.TIMA > 0xFF then
            self.TIMA = self.TMA
            --raise interrupt
            GB_CPU.IFR = bor(GB_CPU.IFR, 0x4)
        end
        self.ModuloCyclesT = self.ModuloCyclesT % self.TimerCLK
    end
end
    self.ModuloCyclesD = self.ModuloCyclesD + cycles
    if self.ModuloCyclesD > 0xFF then
        self.DIV = band(self.DIV+1, 0xFF)
        self.ModuloCyclesD = band(self.ModuloCyclesD, 0xFF)
    end
end




function ReadMem(self, Addr)
    if Addr < 0x8000 then
        if BIOS_Active == true and Addr < 0x100 then return BIOS[Addr] end
        return GB:ReadROM(Addr)
    elseif Addr >= 0x8000 and Addr < 0x9800 then
        return GB_PPU.VRAM[band(Addr, 0x1FFF)]
    elseif Addr >= 0x9800 and Addr < 0x9C00 then
        return GB_PPU.BG0[band(Addr, 0xFFF)]
    elseif Addr >= 0x9C00 and Addr < 0xA000 then
        return GB_PPU.BG1[band(Addr, 0xFFF)]
    elseif Addr >= 0xA000 and Addr < 0xBFFF then
        --TODO: external cartridge ram
        return 0x00
    elseif Addr >= 0xC000 and Addr < 0xE000 then
        return GB.WRAM[Addr]
    elseif Addr >= 0xE000 and Addr < 0xFE00 then
        return GB.WRAM[Addr-0x2000]
    elseif Addr >= 0xFE00 and Addr < 0xFEA0 then
        return GB_PPU.OAM[Addr - 0xFE00]
    --0xFEA0 to 0xFEFF is unused
    elseif Addr >= 0xFF00 and Addr < 0xFF80 then
        --TODO: hardware io
        if Addr == 0xFF00 then
            return GB.Joy
        elseif Addr == 0xFF04 then
            return GB.DIV
        elseif Addr == 0xFF05 then
            return GB.TIMA
        elseif Addr == 0xFF06 then
            return GB.TMA
        elseif Addr == 0xFF07 then
            return GB.TAC
        elseif Addr == 0xFF0F then
            return self.IFR
        elseif Addr == 0xFF40 then
            return GB_PPU.PPU_CTRL
        elseif Addr == 0xFF41 then
            GB_PPU.LCD_STAT = band(GB_PPU.LCD_STAT, 0x78) + GB_PPU.Mode + (lshift(i(GB_PPU.Scanline == GB_PPU.LYC), 2))
            return GB_PPU.LCD_STAT
        elseif Addr == 0xFF42 then
            return GB_PPU.ScrollY
        elseif Addr == 0xFF43 then
            return GB_PPU.ScrollX
        elseif Addr == 0xFF44 then
            --print("get scanline")
            return GB_PPU.Scanline
        elseif Addr == 0xFF45 then
            return GB_PPU.LYC
        elseif Addr == 0xFF48 then
            return GB_PPU.SP0Pallete
        elseif Addr == 0xFF49 then
            return GB_PPU.SP1Pallete
        end
    elseif Addr >= 0xFF80 and Addr < 0xFFFF then
        return GB.ZRAM[Addr]
    elseif Addr == 0xFFFF then
        return self.IME
    end
    print(hex(Addr))
    return 0x00
end

function WriteMem(self, Addr, Data)
    if Data > 0xFF then error(hex(Addr).." -> "..hex(Data)) end
    if Addr < 0x8000 then
        GB:WriteROM(Addr,Data)
    elseif Addr >= 0x8000 and Addr < 0x9800 then
        GB_PPU:UpdateTileset(Addr, Data)
    elseif Addr >= 0x9800 and Addr < 0x9C00 then
        GB_PPU.BG0[Addr - 0x9800] = Data
        --if Data > 0 then print(hex(Addr-0x9800) .. "----> " .. hex(Data)) end
    elseif Addr >= 0x9C00 and Addr < 0xA000 then
        GB_PPU.BG1[Addr - 0x9C00] = Data
    elseif Addr >= 0xA000 and Addr < 0xBFFF then
        --TODO: external cartridge ram
    elseif Addr >= 0xC000 and Addr < 0xE000 then
        GB.WRAM[Addr] = Data
    elseif Addr >= 0xE000 and Addr < 0xFE00 then
        GB.WRAM[Addr-0x2000] = Data
    elseif Addr >= 0xFE00 and Addr < 0xFEA0 then
        GB_PPU.OAM[Addr - 0xFE00] = Data
    --0xFEA0 to 0xFEFF is unused
    elseif Addr >= 0xFF00 and Addr < 0xFF80 then
        if Addr == 0xFF00 then
            GB.Joy = band(Data,0x30)
        elseif Addr == 0xFF01 then
            io.write(string.char(Data))
        elseif Addr == 0xFF04 then
            GB.DIV = 0x00
        elseif Addr == 0xFF05 then
            GB.TIMA = Data
        elseif Addr == 0xFF06 then
            GB.TMA = Data
        elseif Addr == 0xFF07 then
            GB.TAC = Data
            GB.TimerOn = (band(Data, 0x4) > 0x0)
            GB.TimerCLK = GB.TimerCLKS[band(Data, 0x3)]
        elseif Addr == 0xFF0F then
            self.IFR = Data
        elseif Addr == 0xFF40 then
            GB_PPU.PPU_CTRL = Data
            --print(hex(Data))
            GB_PPU.UseBG0 = (band(Data,0x8) == 0x0)
            GB_PPU.UseSet0 = (band(Data, 0x10) == 0x0)
            GB_PPU.DisplayOn = (band(Data,0x80) > 0x0)
            GB_PPU.BackgroundOn = (band(Data,0x1) > 0x0)
            GB_PPU.SpritesOn = (band(Data,0x2) > 0x0)
            GB_PPU.Use88Size = (band(Data,0x4) == 0x0)
            GB_PPU.WindowOn = (band(Data,0x20) > 0x0)
            GB_PPU.WindowUseBG0 = (band(Data,0x40) > 0x0)
        elseif Addr == 0xFF41 then
            GB_PPU.LCD_STAT = band(Data,0x78) + GB_PPU.Mode
            GB_PPU.COINC_INT = (band(Data,0x40)>0x00)
            GB_PPU.MODE2_INT = (band(Data,0x20)>0x00)
            GB_PPU.MODE1_INT = (band(Data,0x10)>0x00)
            GB_PPU.MODE0_INT = (band(Data,0x8)>0x00)

        elseif Addr == 0xFF42 then
            --print("scrolly ---> "..hex(Data))
            GB_PPU.ScrollY = Data
        elseif Addr == 0xFF43 then
            GB_PPU.ScrollX = Data
        elseif Addr == 0xFF45 then
            GB_PPU.LYC = Data
        elseif Addr == 0xFF46 then
            GB_PPU.DMA_Addr = Data
            GB_PPU:InitDMA()
        elseif Addr == 0xFF47 then
            GB_PPU.BGPallete = Data
            for i = 0, 3 do
                GB_PPU.Colors[i] = band(rshift(GB_PPU.BGPallete,lshift(i,1)), 0x3)
            end
        elseif Addr == 0xFF48 then
            GB_PPU.SP0Pallete = Data
            for i = 0, 3 do
                GB_PPU.SP0C[i] = band(rshift(Data,lshift(i,1)), 0x3)
            end
        elseif Addr == 0xFF49 then
            GB_PPU.SP1Pallete = Data
            for i = 0, 3 do
                GB_PPU.SP1C[i] = band(rshift(Data,lshift(i,1)), 0x3)
            end
        elseif Addr == 0xFF4A then
            GB_PPU.WindowY = Data
        elseif Addr == 0xFF4B then
            GB_PPU.WindowX = Data
        end
    elseif Addr >= 0xFF80 and Addr < 0xFFFF then
        GB.ZRAM[Addr] = Data
    elseif Addr == 0xFFFF then
        self.IME = Data
    end
end