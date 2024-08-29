GB_CPU = {}

local band, bor, bxor, lshift, rshift, rol, ror = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift, bit.rol, bit.ror

function s(O) --returns signed value from unsigned 8-bit value
    if O>0x7F then
        return O-0x100
    else
        return O
    end
end

function hex(n)
    if n < 0x100 then
        local h={[0]="0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"}
    return h[math.floor(n/16)]..h[(n%16)]
    else
        --local h={[0]="0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"}
        --return h[(math.floor(n/1024)%16)]..h[(math.floor(n/256)%16)]..h[(math.floor(n/16)%16)]..h[(n%16)]
        return hex(rshift(n,8))..hex(band(n,0xFF))
    end
end

function i(b)
    if b then return 1 else return 0 end
end

function t16(O1,O2) --fuses 2 8-bit values to 1 16-bit value
    return bor(lshift(band(O1,0xFF),8), band(O2,0xFF))
end

B=0
C=1
D=2
E=3
H=4
L=5
HL=6
A = 7

function DAA(self)
    local correction = 0
    if (self.HF or (band(self.A,0xF)>0x9)) then
        correction = bor(correction,0x6)
    end
    if (self.CF or (rshift(self.A,4)>0x9)) then
        correction = bor(correction,0x60)
        self.CF = true
    else
        self.CF = false
    end
    if self.NF then
        correction = -correction
    end
    self.A = band(self.A + correction,0xFF)
    self.ZF = (self.A==0x00)
    self.HF = false
    return 1,8
end

--CB PREFIX INSTRUCTIONS
function SWAP(self,ind)
    self.RegTbl[ind] = bor(lshift(band(self.RegTbl[ind],0xF),4), rshift(self.RegTbl[ind],4))
    self.NF = false
    self.HF = false
    self.CF = false
    self.ZF = (self.RegTbl[ind] == 0x00)
    if ind == HL then return 16 else return 8 end
end

function RLC(self, ind)
    self.CF = (self.RegTbl[ind] > 0x7F)
    self.RegTbl[ind] = band(lshift(self.RegTbl[ind],1), 0xFF) + i(self.CF)
    self.ZF = (self.RegTbl[ind] == 0x00)
    self.NF = false
    self.HF = false
    if ind == HL then return 16 else return 8 end
end

function RRC(self, ind)
    self.CF = band(self.RegTbl[ind],0x1) == 0x1
    self.RegTbl[ind] = rshift(self.RegTbl[ind],1) + lshift(i(self.CF),7)
    self.ZF = (self.RegTbl[ind] == 0x00)
    self.NF = false
    self.HF = false
    if ind == HL then return 16 else return 8 end
end

function RL(self, ind)
    local t = i(self.CF)
    self.HF = false
    self.NF = false
    self.CF = (self.RegTbl[ind] > 0x7F)
    self.RegTbl[ind] = band(lshift(self.RegTbl[ind], 1),0xFF) + t
    self.ZF = (self.RegTbl[ind] == 0x00)
    if ind == HL then return 16 else return 8 end
end

function RR(self, ind)
    local t = i(self.CF)
    self.CF = band(self.RegTbl[ind], 0x1)
    self.RegTbl[ind] = rshift(self.RegTbl[ind], 1) + lshift(t,7)
    self.ZF = (self.RegTbl[ind] == 0x00)
    self.NF = false
    self.HF = false
    if ind == HL then return 16 else return 8 end
end

function SLA(self, ind)
    self.CF = (self.RegTbl[ind] > 0x7F)
    self.RegTbl[ind] = band(lshift(self.RegTbl[ind], 1),0xFF)
    self.ZF = (self.RegTbl[ind] == 0x00)
    self.NF = false
    self.HF = false
    if ind == HL then return 16 else return 8 end
end

function SRA(self, ind)
    self.CF = band(self.RegTbl[ind], 0x1)
    self.RegTbl[ind] = rshift(self.RegTbl[ind], 1) + band(self.RegTbl[ind], 0x80)
    self.ZF = (self.RegTbl[ind] == 0x00)
    self.NF = false
    self.HF = false
    if ind == HL then return 16 else return 8 end
end

function SRL(self, ind)
    self.CF = band(self.RegTbl[ind], 0x1)
    self.RegTbl[ind] = rshift(self.RegTbl[ind], 1)
    self.ZF = (self.RegTbl[ind] == 0x00)
    self.NF = false
    self.HF = false
    if ind == HL then return 16 else return 8 end
end

function BIT(self, ind, bit)
    self.ZF = (band(self.RegTbl[ind], lshift(0x1, bit)) == 0x0)
    self.NF = false
    self.HF = true
    if ind == HL then return 12 else return 8 end
end

function RES(self, ind, bit)
    self.RegTbl[ind] = band(self.RegTbl[ind], bxor(0xFF,lshift(0x1,bit)))
    if ind == HL then return 16 else return 8 end
end

function SET(self, ind, bit)
    self.RegTbl[ind] = bor(self.RegTbl[ind], lshift(0x1,bit))
    if ind == HL then return 16 else return 8 end
end

--END CB PREFIX INSTRUCTIONS

function GB_CPU:init(ReadF, WriteF)
    self.A = 0x00
    self.B = 0x00
    self.C = 0x00
    self.D = 0x00
    self.E = 0x00
    self.F = 0x00 --Flag register
    self.H = 0x00
    self.L = 0x00

    self.HALTED = false

    self.IE = true

    --self.RegTbl = {self.A, self.B, self.C, self.D, self.E, self.F, self.H, self.L, self:Read(t16(self.H, self.L))}


    self.SP = 0xFFFE
    self.PC = 0x0000

    self.ZF = false
    self.NF = false
    self.HF = false
    self.CF = false

    self.IME = 0x00
    self.IFR = 0x00

    self.Read = ReadF --format: function ReadF(Mem)
    self.Write = WriteF --format: function WriteF(Mem,Data)

    self.Instructions = {
        --format: [OPCODE] = function(self,O1,O2) ###### return Size,Cycles end

        --row 0x0# start ---------------------------------------------
        [0x00] = function(self) return 1,4 end, --NOP
        [0x01] = function(self,O1,O2) self.B = O2 self.C = O1 return 3, 12 end, --LD BC, d16
        [0x02] = function(self) self:Write(t16(self.B,self.C), self.A) return 1,8 end, --LD (BC), A
        [0x03] = function(self) local t=band(t16(self.B,self.C)+1,0xFFFF) self.B = rshift(t,8) self.C = band(t,0xFF) return 1,8 end, --INC BC
        [0x04] = function(self) self.HF = (band(self.B, 0xF) == 0xF) self.NF = false self.B = band(self.B+1, 0xFF) self.ZF = (self.B == 0x00) return 1,4 end, --INC B
        [0x05] = function(self) self.HF = (band(self.B, 0xF) == 0x0) self.NF = true self.B = band(self.B-1, 0xFF) self.ZF = (self.B == 0x00) return 1,4 end, --DEC B
        [0x06] = function(self,O1) self.B = O1 return 2,8 end, --LD B, d8
        [0x07] = function(self) self.CF = (self.A > 0x7F) self.A = band(lshift(self.A,1)+i(self.CF),0xFF) self.ZF = (self.A == 0x00) self.NF = false self.HF = false return 1,4 end, --RLCA
        [0x08] = function(self,O1,O2) self:Write(t16(O2,O1), band(self.SP,0xFF)) self:Write(t16(O2,O1)+1, rshift(self.SP,8)) return 3,20 end, --LD (a16), SP
        [0x09] = function(self) local t = band(t16(self.H,self.L) + t16(self.B,self.C), 0xFFFF) self.H = rshift(t,8) self.L = band(t,0xFF) return 1,8 end, --ADD HL,BC
        [0x0A] = function(self) self.A = self:Read(t16(self.B,self.C)) return 1,8 end, --LD A, (BC)
        [0x0B] = function(self) local t=band((t16(self.B, self.C)-1),0xFFFF) self.B = rshift(t,8) self.C = band(t,0xFF) return 1,8 end, --DEC BC
        [0x0C] = function(self) self.HF = (band(self.C, 0xF) == 0xF) self.NF = false self.C = band(self.C+1, 0xFF) self.ZF = (self.C == 0x00) return 1,4 end, --INC C
        [0x0D] = function(self) self.HF = (band(self.C, 0xF) == 0x0) self.NF = true self.C = band(self.C-1, 0xFF) self.ZF = (self.C == 0x00) return 1,4 end, --DEC C
        [0x0E] = function(self,O1) self.C = O1 return 2,8 end, --LD C,d8
        [0x0F] = function(self) self.CF = (band(self.A,0x1)==0x1) self.A = rshift(self.A,1)+lshift(i(self.CF),7) self.ZF = (self.A == 0x00) self.NF = false self.HF = false return 1,4 end, --RRCA


        --row 0x1# start --------------------------------------------------
        [0x10] = function(self) self.HALTED = true self.IE = true return 1,4 end, --stop
        [0x11] = function(self,O1,O2) self.D = O2 self.E = O1 return 3, 12 end, --LD DE,d16
        [0x12] = function(self) self:Write(t16(self.D,self.E), self.A) return 1,8 end, --LD (DE),A
        [0x13] = function(self) local t=band(t16(self.D,self.E)+1,0xFFFF) self.D = rshift(t,8) self.E = band(t,0xFF) return 1,8 end, --INC DE
        [0x14] = function(self) self.HF = (band(self.D, 0xF) == 0xF) self.NF = false self.D = band(self.D+1, 0xFF) self.ZF = (self.D == 0x00) return 1,4 end, --INC D
        [0x15] = function(self) self.HF = (band(self.D, 0xF) == 0x0) self.NF = true self.D = band(self.D-1, 0xFF) self.ZF = (self.D == 0x00) return 1,4 end, --DEC D
        [0x16] = function(self,O1) self.D = O1 return 2,8 end, --LD D, d8
        [0x17] = function(self) local t if self.CF then t=1 else t=0 end self.CF = (self.A > 0x7F) self.A = band(lshift(self.A,1)+t,0xFF) self.ZF = (self.A == 0x00) self.NF = false self.HF = false return 1,4 end, --RLA
        [0x18] = function(self,O1) self.PC = self.PC + s(O1) return 2,12 end, --JR n 
        [0x19] = function(self) local t = band(t16(self.H,self.L) + t16(self.D,self.E), 0xFFFF) self.H = rshift(t,8) self.L = band(t,0xFF) return 1,8 end, --ADD HL,DE
        [0x1A] = function(self) self.A = self:Read(t16(self.D,self.E)) return 1,8 end, --LD A, (DE)
        [0x1B] = function(self) local t=band((t16(self.D, self.E)-1),0xFFFF) self.D = rshift(t,8) self.E = band(t,0xFF) return 1,8 end, --DEC DE
        [0x1C] = function(self) self.HF = (band(self.E, 0xF) == 0xF) self.NF = false self.E = band(self.E+1, 0xFF) self.ZF = (self.E == 0x00) return 1,4 end, --INC E
        [0x1D] = function(self) self.HF = (band(self.E, 0xF) == 0x0) self.NF = true self.E = band(self.E-1, 0xFF) self.ZF = (self.E == 0x00) return 1,4 end, --DEC E
        [0x1E] = function(self,O1) self.E = O1 return 2,8 end, --LD E,d8
        [0x1F] = function(self) local t if self.CF then t=1 else t=0 end self.CF = (band(self.A,0x1)==0x1) self.A = bor(rshift(self.A,1), lshift(t,7)) self.ZF = (self.A == 0x00) self.NF = false self.HF = false return 1,4 end, --RRA


        --row 0x2# start ---------------------------------------------------
        [0x20] = function(self,O1) if not self.ZF then self.PC = self.PC + s(O1) return 2, 12 else return 2,8 end end, --JR NZ,r8
        [0x21] = function(self,O1,O2) self.H = O2 self.L = O1 return 3, 12 end, --LD HL, d16
        [0x22] = function(self) self:Write(t16(self.H, self.L), self.A) local t = band(t16(self.H, self.L)+1, 0xFFFF) self.H = rshift(t,8) self.L = band(t,0xFF) return 1,8 end, --LD (HL+),A
        [0x23] = function(self) local t=band(t16(self.H,self.L)+1,0xFFFF) self.H = rshift(t,8) self.L = band(t,0xFF) return 1,8 end, --INC HL
        [0x24] = function(self) self.HF = (band(self.H, 0xF) == 0xF) self.NF = false self.H = band(self.H+1, 0xFF) self.ZF = (self.H == 0x00) return 1,4 end, --INC H
        [0x25] = function(self) self.HF = (band(self.H, 0xF) == 0x0) self.NF = true self.H = band(self.H-1, 0xFF) self.ZF = (self.H == 0x00) return 1,4 end, --DEC H
        [0x26] = function(self,O1) self.H = O1 return 2,8 end, --LD H, d8
        [0x27] = function(self) return DAA(self) end, --DAA
        [0x28] = function(self,O1) if self.ZF then self.PC = self.PC + s(O1) return 2, 12 else return 2,8 end end, --JR Z,r8
        [0x29] = function(self) local t = band(t16(self.H,self.L) + t16(self.H,self.L), 0xFFFF) self.H = rshift(t,8) self.L = band(t,0xFF) return 1,8 end, --ADD HL,HL
        [0x2A] = function(self) self.A = self:Read(t16(self.H, self.L)) local t = band(t16(self.H, self.L)+1, 0xFFFF) self.H = rshift(t,8) self.L = band(t,0xFF) return 1,8 end, --LD A,(HL+)
        [0x2B] = function(self) local t=band((t16(self.H, self.L)-1),0xFFFF) self.H = rshift(t,8) self.L = band(t,0xFF) return 1,8 end, --DEC HL
        [0x2C] = function(self) self.HF = (band(self.L, 0xF) == 0xF) self.NF = false self.L = band(self.L+1, 0xFF) self.ZF = (self.L == 0x00) return 1,4 end, --INC L
        [0x2D] = function(self) self.HF = (band(self.L, 0xF) == 0x0) self.NF = true self.L = band(self.L-1, 0xFF) self.ZF = (self.L == 0x00) return 1,4 end, --DEC L
        [0x2E] = function(self,O1) self.L = O1 return 2,8 end, --LD L,d8
        [0x2F] = function(self) self.A = bxor(self.A, 0xFF) self.NF = true self.HF = true return 1,4 end, --CPL


        --row 0x3# start ------------------------------------------------------------
        [0x30] = function(self,O1) if not self.CF then self.PC = self.PC + s(O1) return 2, 12 else return 2,8 end end, --JR NC,r8
        [0x31] = function(self,O1,O2) self.SP = t16(O2,O1) return 3, 12 end, --LD SP, d16
        [0x32] = function(self) self:Write(t16(self.H, self.L), self.A) local t = band(t16(self.H, self.L)-1, 0xFFFF) self.H = rshift(t,8) self.L = band(t,0xFF) return 1,8 end, --LD (HL-),A
        [0x33] = function(self) self.SP = band(self.SP+1, 0xFFFF) return 1,8 end, --INC SP
        [0x34] = function(self) local t=band(self:Read(t16(self.H, self.L))+1, 0xFF) self:Write(t16(self.H, self.L), t) self.HF = (band(t,0xF)==0x0) self.ZF = (t == 0x00) self.NF = false return 1,12 end, --INC (HL)
        [0x35] = function(self) local t=band(self:Read(t16(self.H, self.L))-1, 0xFF) self:Write(t16(self.H, self.L), t) self.HF = (band(t,0xF)==0x0) self.ZF = (t == 0x00) self.NF = false return 1,12 end, --DEC (HL)
        [0x36] = function(self,O1) self:Write(t16(self.H, self.L), O1) return 2,12 end, --LD (HL),d8
        [0x37] = function(self) self.CF = true self.NF = false self.HF = false return 1,4 end, --SCF
        [0x38] = function(self,O1) if self.CF then self.PC = self.PC + s(O1) return 2, 12 else return 2,8 end end, --JR C,r8
        [0x39] = function(self) local t = band(t16(self.H,self.L) + self.SP, 0xFFFF) self.H = rshift(t,8) self.L = band(t,0xFF) return 1,8 end, --ADD HL,SP
        [0x3A] = function(self) self.A = self:Read(t16(self.H, self.L)) local t = band(t16(self.H, self.L)-1, 0xFFFF) self.H = rshift(t,8) self.L = band(t,0xFF) return 1,8 end, --LD A,(HL-)
        [0x3B] = function(self) self.SP = band(self.SP - 1, 0xFFFF) return 1, 8 end, --DEC SP
        [0x3C] = function(self) self.HF = (band(self.A, 0xF) == 0xF) self.NF = false self.A = band(self.A+1, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --INC A
        [0x3D] = function(self) self.HF = (band(self.A, 0xF) == 0x0) self.NF = true self.A = band(self.A-1, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --DEC A
        [0x3E] = function(self,O1) self.A = O1 return 2,8 end, --LD A,d8
        [0x3F] = function(self) self.CF = not self.CF self.NF = false self.HF = false return 1,4 end, --CCF


        --row 0x4# start ---------------------------------------------------------------
        [0x40] = function(self) return 1,4 end, --LD B,B
        [0x41] = function(self) self.B = self.C return 1,4 end, --LD B,C
        [0x42] = function(self) self.B = self.D return 1,4 end, --LD B,D
        [0x43] = function(self) self.B = self.E return 1,4 end, --LD B,E
        [0x44] = function(self) self.B = self.H return 1,4 end, --LD B,H
        [0x45] = function(self) self.B = self.L return 1,4 end, --LD B,L
        [0x46] = function(self) self.B = self:Read(t16(self.H, self.L)) return 1,8 end, --LD B,(HL)
        [0x47] = function(self) self.B = self.A return 1,4 end, --LD B,A
        [0x48] = function(self) self.C = self.B return 1,4 end, --LD C,B
        [0x49] = function(self) return 1,4 end, --LD C,C
        [0x4A] = function(self) self.C = self.D return 1,4 end, --LD C,D
        [0x4B] = function(self) self.C = self.E return 1,4 end, --LD C,E
        [0x4C] = function(self) self.C = self.H return 1,4 end, --LD C,H
        [0x4D] = function(self) self.C = self.L return 1,4 end, --LD C,L
        [0x4E] = function(self) self.C = self:Read(t16(self.H, self.L)) return 1,8 end, --LD C,(HL)
        [0x4F] = function(self) self.C = self.A return 1,4 end, --LD C,A


        --row 0x5# start --------------------------------------------------------------
        [0x50] = function(self) self.D = self.B return 1,4 end, --LD D,B
        [0x51] = function(self) self.D = self.C return 1,4 end, --LD D,C
        [0x52] = function(self) return 1,4 end, --LD D,D
        [0x53] = function(self) self.D = self.E return 1,4 end, --LD D,E
        [0x54] = function(self) self.D = self.H return 1,4 end, --LD D,H
        [0x55] = function(self) self.D = self.L return 1,4 end, --LD D,L
        [0x56] = function(self) self.D = self:Read(t16(self.H, self.L)) return 1,8 end, --LD B,(HL)
        [0x57] = function(self) self.D = self.A return 1,4 end, --LD D,A
        [0x58] = function(self) self.E = self.B return 1,4 end, --LD E,B
        [0x59] = function(self) self.E = self.C return 1,4 end, --LD E,C
        [0x5A] = function(self) self.E = self.D return 1,4 end, --LD E,D
        [0x5B] = function(self) return 1,4 end, --LD E,E
        [0x5C] = function(self) self.E = self.H return 1,4 end, --LD E,H
        [0x5D] = function(self) self.E = self.L return 1,4 end, --LD E,L
        [0x5E] = function(self) self.E = self:Read(t16(self.H, self.L)) return 1,8 end, --LD E,(HL)
        [0x5F] = function(self) self.E = self.A return 1,4 end, --LD E,A


        --row 0x6# start ----------------------------------------------------------------
        [0x60] = function(self) self.H = self.B return 1,4 end, --LD H,B
        [0x61] = function(self) self.H = self.C return 1,4 end, --LD H,C
        [0x62] = function(self) self.H = self.D return 1,4 end, --LD H,D
        [0x63] = function(self) self.H = self.E return 1,4 end, --LD H,E
        [0x64] = function(self) return 1,4 end, --LD H,H
        [0x65] = function(self) self.H = self.L return 1,4 end, --LD H,L
        [0x66] = function(self) self.H = self:Read(t16(self.H, self.L)) return 1,8 end, --LD H,(HL)
        [0x67] = function(self) self.H = self.A return 1,4 end, --LD H,A
        [0x68] = function(self) self.L = self.B return 1,4 end, --LD L,B
        [0x69] = function(self) self.L = self.C return 1,4 end, --LD L,C
        [0x6A] = function(self) self.L = self.D return 1,4 end, --LD L,D
        [0x6B] = function(self) self.L = self.E return 1,4 end, --LD L,E
        [0x6C] = function(self) self.L = self.H return 1,4 end, --LD L,H
        [0x6D] = function(self) return 1,4 end, --LD L,L
        [0x6E] = function(self) self.L = self:Read(t16(self.H, self.L)) return 1,8 end, --LD L,(HL)
        [0x6F] = function(self) self.L = self.A return 1,4 end, --LD L,A


        --row 0x7# start --------------------------------------------------------------
        [0x70] = function(self) self:Write(t16(self.H, self.L), self.B) return 1,8 end, --LD (HL),B
        [0x71] = function(self) self:Write(t16(self.H, self.L), self.C) return 1,8 end, --LD (HL),C
        [0x72] = function(self) self:Write(t16(self.H, self.L), self.D) return 1,8 end, --LD (HL),D
        [0x73] = function(self) self:Write(t16(self.H, self.L), self.E) return 1,8 end, --LD (HL),E
        [0x74] = function(self) self:Write(t16(self.H, self.L), self.H) return 1,8 end, --LD (HL),H
        [0x75] = function(self) self:Write(t16(self.H, self.L), self.L) return 1,8 end, --LD (HL),L
        [0x76] = function(self) self.HALTED = true self.IE = true return 1,4 end, --HALT
        [0x77] = function(self) self:Write(t16(self.H, self.L), self.A) return 1,8 end, --LD (HL),A
        [0x78] = function(self) self.A = self.B return 1,4 end, --LD A,B
        [0x79] = function(self) self.A = self.C return 1,4 end, --LD A,C
        [0x7A] = function(self) self.A = self.D return 1,4 end, --LD A,D
        [0x7B] = function(self) self.A = self.E return 1,4 end, --LD A,E
        [0x7C] = function(self) self.A = self.H return 1,4 end, --LD A,H
        [0x7D] = function(self) self.A = self.L return 1,4 end, --LD A,L
        [0x7E] = function(self) self.A = self:Read(t16(self.H, self.L)) return 1,8 end, --LD A,(HL)
        [0x7F] = function(self) return 1,4 end, --LD A,A


        --row 0x8# start ------------------------------------------------------------
        [0x80] = function(self) local t = self.A self.A = self.A + self.B self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADD A,B
        [0x81] = function(self) local t = self.A self.A = self.A + self.C self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADD A,C
        [0x82] = function(self) local t = self.A self.A = self.A + self.D self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADD A,D
        [0x83] = function(self) local t = self.A self.A = self.A + self.E self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADD A,E
        [0x84] = function(self) local t = self.A self.A = self.A + self.H self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADD A,H
        [0x85] = function(self) local t = self.A self.A = self.A + self.L self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADD A,L
        [0x86] = function(self) local t = self.A self.A = self.A + self:Read(t16(self.H,self.L)) self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,8 end, --ADD A, (HL)
        [0x87] = function(self) local t = self.A self.A = self.A + self.A self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADD A,A
        [0x88] = function(self) local t = self.A self.A = self.A + self.B + i(self.CF) self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADC A,B
        [0x89] = function(self) local t = self.A self.A = self.A + self.C + i(self.CF) self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADC A,C
        [0x8A] = function(self) local t = self.A self.A = self.A + self.D + i(self.CF) self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADC A,D
        [0x8B] = function(self) local t = self.A self.A = self.A + self.E + i(self.CF) self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADC A,E
        [0x8C] = function(self) local t = self.A self.A = self.A + self.H + i(self.CF) self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADC A,H
        [0x8D] = function(self) local t = self.A self.A = self.A + self.L + i(self.CF) self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADC A,L
        [0x8E] = function(self) local t = self.A self.A = self.A + self:Read(t16(self.H,self.L))+ i(self.CF) self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,8 end, --ADC A, (HL)
        [0x8F] = function(self) local t = self.A self.A = self.A + self.A + i(self.CF) self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --ADC A,A

        
        --row 0x9# start ------------------------------------------------------------
        [0x90] = function(self) local t = self.A self.A = self.A - self.B self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SUB A,B
        [0x91] = function(self) local t = self.A self.A = self.A - self.C self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SUB A,C
        [0x92] = function(self) local t = self.A self.A = self.A - self.D self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SUB A,D
        [0x93] = function(self) local t = self.A self.A = self.A - self.E self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SUB A,E
        [0x94] = function(self) local t = self.A self.A = self.A - self.H self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SUB A,H
        [0x95] = function(self) local t = self.A self.A = self.A - self.L self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SUB A,L
        [0x96] = function(self) local t = self.A self.A = self.A - self:Read(t16(self.H,self.L)) self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,8 end, --SUB A, (HL)
        [0x97] = function(self) local t = self.A self.A = self.A - self.A self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SUB A,A
        [0x98] = function(self) local t = self.A self.A = self.A - (self.B + i(self.CF)) self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SBC A,B
        [0x99] = function(self) local t = self.A self.A = self.A - (self.C + i(self.CF)) self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SBC A,C
        [0x9A] = function(self) local t = self.A self.A = self.A - (self.D + i(self.CF)) self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SBC A,D
        [0x9B] = function(self) local t = self.A self.A = self.A - (self.E + i(self.CF)) self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SBC A,E
        [0x9C] = function(self) local t = self.A self.A = self.A - (self.H + i(self.CF)) self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SBC A,H
        [0x9D] = function(self) local t = self.A self.A = self.A - (self.L + i(self.CF)) self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SBC A,L
        [0x9E] = function(self) local t = self.A self.A = self.A - (self:Read(t16(self.H,self.L))+ i(self.CF)) self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,8 end, --SBC A, (HL)
        [0x9F] = function(self) local t = self.A self.A = self.A - (self.A + i(self.CF)) self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 1,4 end, --SBC A,A


        --row 0xA# start --------------------------------------------------------------
        [0xA0] = function(self) self.NF = false self.HF = true self.CF = false self.A = band(self.A, self.B) self.ZF = (self.A == 0x00) return 1,4 end, --AND A,B
        [0xA1] = function(self) self.NF = false self.HF = true self.CF = false self.A = band(self.A, self.C) self.ZF = (self.A == 0x00) return 1,4 end, --AND A,C
        [0xA2] = function(self) self.NF = false self.HF = true self.CF = false self.A = band(self.A, self.D) self.ZF = (self.A == 0x00) return 1,4 end, --AND A,D
        [0xA3] = function(self) self.NF = false self.HF = true self.CF = false self.A = band(self.A, self.E) self.ZF = (self.A == 0x00) return 1,4 end, --AND A,E
        [0xA4] = function(self) self.NF = false self.HF = true self.CF = false self.A = band(self.A, self.H) self.ZF = (self.A == 0x00) return 1,4 end, --AND A,H
        [0xA5] = function(self) self.NF = false self.HF = true self.CF = false self.A = band(self.A, self.L) self.ZF = (self.A == 0x00) return 1,4 end, --AND A,L
        [0xA6] = function(self) self.NF = false self.HF = true self.CF = false self.A = band(self.A, self:Read(t16(self.H,self.L))) self.ZF = (self.A == 0x00) return 1,8 end, --AND A,(HL)
        [0xA7] = function(self) self.NF = false self.HF = true self.CF = false self.ZF = (self.A == 0x00) return 1,4 end, --AND A,A
        [0xA8] = function(self) self.NF = false self.HF = false self.CF = false self.A = bxor(self.A, self.B) self.ZF = (self.A == 0x00) return 1,4 end, --XOR A,B
        [0xA9] = function(self) self.NF = false self.HF = false self.CF = false self.A = bxor(self.A, self.C) self.ZF = (self.A == 0x00) return 1,4 end, --XOR A,C
        [0xAA] = function(self) self.NF = false self.HF = false self.CF = false self.A = bxor(self.A, self.D) self.ZF = (self.A == 0x00) return 1,4 end, --XOR A,D
        [0xAB] = function(self) self.NF = false self.HF = false self.CF = false self.A = bxor(self.A, self.E) self.ZF = (self.A == 0x00) return 1,4 end, --XOR A,E
        [0xAC] = function(self) self.NF = false self.HF = false self.CF = false self.A = bxor(self.A, self.H) self.ZF = (self.A == 0x00) return 1,4 end, --XOR A,H
        [0xAD] = function(self) self.NF = false self.HF = false self.CF = false self.A = bxor(self.A, self.L) self.ZF = (self.A == 0x00) return 1,4 end, --XOR A,L
        [0xAE] = function(self) self.NF = false self.HF = false self.CF = false self.A = bxor(self.A, self:Read(t16(self.H,self.L))) self.ZF = (self.A == 0x00) return 1,8 end, --XOR A,(HL)
        [0xAF] = function(self) self.NF = false self.HF = false self.CF = false self.ZF = true self.A = 0x00 return 1,4 end, --XOR A,A


        --row 0xB# start ---------------------------------------------------------------
        [0xB0] = function(self) self.NF = false self.HF = false self.CF = false self.A = bor(self.A, self.B) self.ZF = (self.A == 0x00) return 1,4 end, --OR A,B
        [0xB1] = function(self) self.NF = false self.HF = false self.CF = false self.A = bor(self.A, self.C) self.ZF = (self.A == 0x00) return 1,4 end, --OR A,C
        [0xB2] = function(self) self.NF = false self.HF = false self.CF = false self.A = bor(self.A, self.D) self.ZF = (self.A == 0x00) return 1,4 end, --OR A,D
        [0xB3] = function(self) self.NF = false self.HF = false self.CF = false self.A = bor(self.A, self.E) self.ZF = (self.A == 0x00) return 1,4 end, --OR A,E
        [0xB4] = function(self) self.NF = false self.HF = false self.CF = false self.A = bor(self.A, self.H) self.ZF = (self.A == 0x00) return 1,4 end, --OR A,H
        [0xB5] = function(self) self.NF = false self.HF = false self.CF = false self.A = bor(self.A, self.L) self.ZF = (self.A == 0x00) return 1,4 end, --OR A,L
        [0xB6] = function(self) self.NF = false self.HF = false self.CF = false self.A = bor(self.A, self:Read(t16(self.H,self.L))) self.ZF = (self.A == 0x00) return 1,8 end, --OR A,(HL)
        [0xB7] = function(self) self.NF = false self.HF = false self.CF = false self.ZF = (self.A == 0x00) return 1,4 end, --OR A,A
        [0xB8] = function(self) local res = self.A - self.B self.CF = (res < 0x00) self.HF = (band(res,0xF)>band(self.A,0xF)) self.NF = true self.ZF = (band(res,0xFF) == 0x00) return 1,4 end, --CP A,B
        [0xB9] = function(self) local res = self.A - self.C self.CF = (res < 0x00) self.HF = (band(res,0xF)>band(self.A,0xF)) self.NF = true self.ZF = (band(res,0xFF) == 0x00) return 1,4 end, --CP A,C
        [0xBA] = function(self) local res = self.A - self.D self.CF = (res < 0x00) self.HF = (band(res,0xF)>band(self.A,0xF)) self.NF = true self.ZF = (band(res,0xFF) == 0x00) return 1,4 end, --CP A,D
        [0xBB] = function(self) local res = self.A - self.E self.CF = (res < 0x00) self.HF = (band(res,0xF)>band(self.A,0xF)) self.NF = true self.ZF = (band(res,0xFF) == 0x00) return 1,4 end, --CP A,E
        [0xBC] = function(self) local res = self.A - self.H self.CF = (res < 0x00) self.HF = (band(res,0xF)>band(self.A,0xF)) self.NF = true self.ZF = (band(res,0xFF) == 0x00) return 1,4 end, --CP A,H
        [0xBD] = function(self) local res = self.A - self.L self.CF = (res < 0x00) self.HF = (band(res,0xF)>band(self.A,0xF)) self.NF = true self.ZF = (band(res,0xFF) == 0x00) return 1,4 end, --CP A,L
        [0xBE] = function(self) local res = self.A - self:Read(t16(self.H,self.L)) self.CF = (res < 0x00) self.HF = (band(res,0xF)>band(self.A,0xF)) self.NF = true self.ZF = (res == 0x00) return 1,8 end, --CP A, (HL)
        [0xBF] = function(self) local res = self.A - self.A self.CF = (res < 0x00) self.HF = (band(res,0xF)>band(self.A,0xF)) self.NF = true self.ZF = (band(self.A,0xFF) == 0x00) return 1,4 end, --CP A,A


        --row 0xC# start -----------------------------------------------------------------
        [0xC0] = function(self) if not self.ZF then local addr = self:Pop(true) self.PC = addr return 0,20 else return 1,8 end end, --RET NZ
        [0xC1] = function(self) local word = self:Pop(true) self.B = rshift(word, 8) self.C = band(word, 0xFF) return 1,12 end, --POP BC
        [0xC2] = function(self,O1,O2) if not self.ZF then self.PC = t16(O2,O1) return 0,16 else return 3,12 end end, --JP NZ, a16
        [0xC3] = function(self,O1,O2) self.PC = t16(O2,O1) return 0,16 end, --JP a16
        [0xC4] = function(self,O1,O2) if not self.ZF then self:Push(band(self.PC+3,0xFFFF),true) self.PC = t16(O2,O1) return 0,24 else return 3,12 end end, --CALL NZ,a16
        [0xC5] = function(self) self:Push(t16(self.B,self.C), true) return 1, 16 end, --PUSH BC
        [0xC6] = function(self,O1) local t = self.A self.A = self.A + O1 self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 2,8 end, --ADD A,d8
        [0xC7] = function(self) self:Push(band(self.PC+1,0xFFFF),true) self.PC = 0x0000 return 0,16 end, --RST 00H
        [0xC8] = function(self) if self.ZF then local addr = self:Pop(true) self.PC = addr return 0,20 else return 1,8 end end, --RET Z
        [0xC9] = function(self) local addr = self:Pop(true) self.PC = addr return 0,20 end, --RET
        [0xCA] = function(self,O1,O2) if self.ZF then self.PC = t16(O2,O1) return 0,16 else return 3,12 end end, --JP Z, a16
        --[0xCB] = PREFIX CB
        [0xCC] = function(self,O1,O2) if self.ZF then self:Push(band(self.PC+3,0xFFFF),true) self.PC = t16(O2,O1) return 0,24 else return 3,12 end end, --CALL Z,a16
        [0xCD] = function(self,O1,O2) self:Push(band(self.PC+3,0xFFFF),true) self.PC = t16(O2,O1) return 0,24 end, --CALL a16
        [0xCE] = function(self,O1) local t = self.A self.A = self.A + O1 + i(self.CF) self.CF = (self.A > 0xFF) self.HF = (band(t,0xF)>band(self.A,0xF)) self.NF = false self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 2,8 end, --ADC A,d8
        [0xCF] = function(self) self:Push(band(self.PC+1,0xFFFF),true) self.PC = 0x0008 return 0,16 end, --RST 08H


        --row 0xD# start --------------------------------------------------------------------
        [0xD0] = function(self) if not self.CF then local addr = self:Pop(true) self.PC = addr return 0,20 else return 1,8 end end, --RET NC
        [0xD1] = function(self) local word = self:Pop(true) self.D = rshift(word, 8) self.E = band(word, 0xFF) return 1,12 end, --POP DE
        [0xD2] = function(self,O1,O2) if not self.CF then self.PC = t16(O2,O1) return 0,16 else return 3,12 end end, --JP NC, a16
        --[0xD3] = nothing
        [0xD4] = function(self,O1,O2) if not self.CF then self:Push(band(self.PC+3,0xFFFF),true) self.PC = t16(O2,O1) return 0,24 else return 3,12 end end, --CALL NC,a16
        [0xD5] = function(self) self:Push(t16(self.D,self.E), true) return 1, 16 end, --PUSH DE
        [0xD6] = function(self,O1) local t = self.A self.A = self.A - O1 self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 2,8 end, --SUB A, d8
        [0xD7] = function(self) self:Push(band(self.PC+1,0xFFFF),true) self.PC = 0x0010 return 0,16 end, --RST 10H
        [0xD8] = function(self) if self.CF then local addr = self:Pop(true) self.PC = addr return 0,20 else return 1,8 end end, --RET C
        [0xD9] = function(self) local addr = self:Pop(true) self.PC = addr self.IE = true return 0,20 end, --RETI
        [0xDA] = function(self,O1,O2) if self.CF then self.PC = t16(O2,O1) return 0,16 else return 3,12 end end, --JP C, a16
        --[0xDB] = nothing
        [0xDC] = function(self,O1,O2) if self.CF then self:Push(band(self.PC+3,0xFFFF),true) self.PC = t16(O2,O1) return 0,24 else return 3,12 end end, --CALL C,a16
        --[0xDD] = nothing
        [0xDE] = function(self,O1) local t = self.A self.A = self.A - (O1 + i(self.CF)) self.CF = (self.A < 0x00) self.HF = (band(t,0xF)<band(self.A,0xF)) self.NF = true self.A = band(self.A, 0xFF) self.ZF = (self.A == 0x00) return 2,8 end, --SBC A,d8
        [0xDF] = function(self) self:Push(band(self.PC+1,0xFFFF),true) self.PC = 0x0018 return 0,16 end, --RST 18H


        --row 0xE# start -----------------------------------------------------------------------
        [0xE0] = function(self,O1) self:Write(bor(0xFF00,O1), self.A) return 2, 12 end, --LDH (a8), A
        [0xE1] = function(self) local word = self:Pop(true) self.H = rshift(word, 8) self.L = band(word, 0xFF) return 1,12 end, --POP HL
        [0xE2] = function(self) self:Write(bor(0xFF00,self.C), self.A) return 1,8 end, --LDH (C), A
        --no E3
        --no E4
        [0xE5] = function(self) self:Push(t16(self.H,self.L), true) return 1, 16 end, --PUSH HL
        [0xE6] = function(self,O1) self.NF = false self.HF = true self.CF = false self.A = band(self.A, O1) self.ZF = (self.A == 0x00) return 2,8 end, --AND A,d8
        [0xE7] = function(self) self:Push(band(self.PC+1,0xFFFF),true) self.PC = 0x0020 return 0,16 end, --RST 20H
        [0xE8] = function(self,O1) local res = self.SP + s(O1) self.HF = (band(res,0xF) < band(self.SP,0xF)) self.CF = (res > 0xFFFF) self.NF = false self.ZF = false self.SP = res return 2,16 end, --ADD SP,r8
        [0xE9] = function(self) self.PC = t16(self.H, self.L) return 0, 4 end, --JP (HL)
        [0xEA] = function(self,O1,O2) self:Write(t16(O2,O1), self.A) return 3,16 end, --LD (a16), A
        --no EB
        --no EC
        --no ED
        [0xEE] = function(self,O1) self.NF = false self.HF = false self.CF = false self.A = bxor(self.A, O1) self.ZF = (self.A == 0x00) return 2,8 end, --XOR A,d8
        [0xEF] = function(self) self:Push(band(self.PC+1,0xFFFF),true) self.PC = 0x0028 return 0,16 end, --RST 28H


        --row 0xF# start ------------------------------------------------------------------------
        [0xF0] = function(self,O1) self.A = self:Read(bor(0xFF00,O1)) return 2, 12 end, --LDH A, (a8)
        [0xF1] = function(self) local word = self:Pop(true) self.A = rshift(word, 8) self.F = band(word, 0xFF) self.ZF = band(self.F, 0x80)>0x0 self.NF = band(self.F, 0x40)>0x0 self.HF = band(self.F, 0x20)>0x0 self.CF = band(self.F, 0x10)>0x0 return 1,12 end, --POP AF
        [0xF2] = function(self) self.A = self:Read(bor(0xFF00,self.C)) return 1,8 end, --LDH A, (C)
        [0xF3] = function(self) self.IE = false return 1, 4 end, --DI
        --no F4
        [0xF5] = function(self) self.F = 0x00 if self.ZF then self.F = bor(self.F,0x80) end if self.NF then self.F = bor(self.F, 0x40) end if self.HF then self.F = bor(self.F, 0x20) end if self.CF then self.F = bor(self.F, 0x10) end self:Push(t16(self.A, self.F),true) return 1, 16 end, --PUSH AF
        [0xF6] = function(self, O1) self.NF = false self.HF = false self.CF = false self.A = bor(self.A, O1) self.ZF = (self.A == 0x00) return 2,8 end, --OR A,d8
        [0xF7] = function(self) self:Push(band(self.PC+1,0xFFFF),true) self.PC = 0x0030 return 0,16 end, --RST 30H
        [0xF8] = function(self, O1) local t = self.SP + s(O1) self.H = band(rshift(t,8),0xFF) self.L = band(t,0xFF) self.ZF = false self.NF = false self.HF = (band(t,0xF) < band(self.SP,0xF)) self.CF = (t > 0xFFFF) return 2,12 end, --LD HL, SP+r8
        [0xF9] = function(self) self.SP = t16(self.H, self.L) return 1, 8 end, --LD SP, HL
        [0xFA] = function(self,O1,O2) self.A = self:Read(t16(O2,O1)) return 3,16 end, --LD A, (a16)
        [0xFB] = function(self) self.IE = true return 1,4 end, --EI
        --no FC
        --no FD
        [0xFE] = function(self,O1) local res = self.A - O1 self.CF = (res < 0x00) self.HF = (band(res,0xF)>band(self.A,0xF)) self.NF = true self.ZF = (band(res,0xFF) == 0x00) return 2,8 end, --CP A,d8
        [0xFF] = function(self) self:Push(band(self.PC+1,0xFFFF),true) self.PC = 0x0038 return 0,16 end --RST 38H
    }
end

function GB_CPU:Push(Val, word)
    if word then
        self:Push(rshift(Val, 8),false)
        self:Push(band(Val, 0xFF),false)
    else
        self.SP = band(self.SP-1, 0xFFFF)
        self:Write(self.SP, Val)
        --print("got value $"..hex(Val).." into SP $"..hex(self.SP))
    end
end

function GB_CPU:Pop(word)
    if word then
        local O2 = self:Pop(false)
        local O1 = self:Pop(false)
        return t16(O1,O2)
    else
        local v= self:Read(self.SP)
        --print("got value $"..hex(v).." from SP $"..hex(self.SP))
        self.SP = band(self.SP+1, 0xFFFF)
        return v
    end
end

function GB_CPU:RunOnce()
    self.PC = band(self.PC, 0xFFFF)
    local size, cycles
    cycles = 4
    if not self.HALTED then
    local CI = self:Read(self.PC)
    if Debug then
    print("---------------------")
    print("A=$"..hex(self.A)..", B=$"..hex(self.B)..", C=$"..hex(self.C)..", D=$"..hex(self.D)..", E=$"..hex(self.E)..", H=$"..hex(self.H)..", L=$"..hex(self.L)..", SP=$"..hex(self.SP))
    print(({[0]="-","Z"})[i(self.ZF)]..({[0]="-","N"})[i(self.NF)]..({[0]="-","H"})[i(self.HF)]..({[0]="-","C"})[i(self.CF)])
    print("IME = $"..hex(self.IME))
    print("IFR = $"..hex(self.IFR))
    --print(hex(self.A))
    --print(hex(self.B))
    --print(hex(self.C))
    --print(hex(self.D))
    --print(hex(self.E))
    --print(hex(self.F))
    --print(hex(self.H))
    --print(hex(self.L))
    print("PC = $"..hex(self.PC))
    print("CI = $"..hex(CI))
    end
    local inst
    if CI == 0xCB then --CB PREFIX, BITWISE / SHIFT INSTRUCTIONS / instruction set
        local O1 = self:Read(self.PC+1)
        if Debug then
        print("CB SUFFIX = $"..hex(O1))
        end
        size = 2
        local inst = 0x00
        local offset = 0x00
        local func
        self.RegTbl = {[B] = self.B, [C] = self.C, [D] = self.D, [E] = self.E, [H] = self.H, [L] = self.L, [HL] = self:Read(t16(self.H, self.L)), [A] = self.A} --init regtable
        if O1 >= 0xF8 then
            inst = 0xF8
            func = function(self, ind) return SET(self,ind,7) end
        elseif O1 >= 0xF0 then
            inst = 0xF0
            func = function(self, ind) return SET(self, ind, 6) end
        elseif O1 >= 0xE8 then
            inst = 0xE8
            func = function(self, ind) return SET(self, ind, 5) end
        elseif O1 >= 0xE0 then
            inst = 0xE0
            func = function(self, ind) return SET(self, ind, 4) end
        elseif O1 >= 0xD8 then
            inst = 0xD8
            func = function(self, ind) return SET(self, ind, 3) end
        elseif O1 >= 0xD0 then
            inst = 0xD0
            func = function(self, ind) return SET(self, ind, 2) end
        elseif O1 >= 0xC8 then
            inst = 0xC8
            func = function(self, ind) return SET(self, ind, 1) end
        elseif O1 >= 0xC0 then
            inst = 0xC0
            func = function(self, ind) return SET(self, ind, 0) end
        --END SET
        elseif O1 >= 0xB8 then
            inst = 0xB8
            func = function(self, ind) return RES(self,ind,7) end
        elseif O1 >= 0xB0 then
            inst = 0xB0
            func = function(self, ind) return RES(self, ind, 6) end
        elseif O1 >= 0xA8 then
            inst = 0xA8
            func = function(self, ind) return RES(self, ind, 5) end
        elseif O1 >= 0xA0 then
            inst = 0xA0
            func = function(self, ind) return RES(self, ind, 4) end
        elseif O1 >= 0x98 then
            inst = 0x98
            func = function(self, ind) return RES(self, ind, 3) end
        elseif O1 >= 0x90 then
            inst = 0x90
            func = function(self, ind) return RES(self, ind, 2) end
        elseif O1 >= 0x88 then
            inst = 0x88
            func = function(self, ind) return RES(self, ind, 1) end
        elseif O1 >= 0x80 then
            inst = 0x80
            func = function(self, ind) return RES(self, ind, 0) end
        --END RES
        elseif O1 >= 0x78 then
            inst = 0x78
            func = function(self, ind) return BIT(self,ind,7) end
        elseif O1 >= 0x70 then
            inst = 0x70
            func = function(self, ind) return BIT(self, ind, 6) end
        elseif O1 >= 0x68 then
            inst = 0x68
            func = function(self, ind) return BIT(self, ind, 5) end
        elseif O1 >= 0x60 then
            inst = 0x60
            func = function(self, ind) return BIT(self, ind, 4) end
        elseif O1 >= 0x58 then
            inst = 0x58
            func = function(self, ind) return BIT(self, ind, 3) end
        elseif O1 >= 0x50 then
            inst = 0x50
            func = function(self, ind) return BIT(self, ind, 2) end
        elseif O1 >= 0x48 then
            inst = 0x48
            func = function(self, ind) return BIT(self, ind, 1) end
        elseif O1 >= 0x40 then
            inst = 0x40
            func = function(self, ind) return BIT(self, ind, 0) end
        --END BIT
        elseif O1 >= 0x38 then
            inst = 0x38
            func = SRL
        elseif O1 >= 0x30 then
            inst = 0x30
            func = SWAP
        elseif O1 >= 0x28 then
            inst = 0x28
            func = SRA
        elseif O1 >= 0x20 then
            inst = 0x20
            func = SLA
        elseif O1 >= 0x18 then
            inst = 0x18
            func = RR
        elseif O1 >= 0x10 then
            inst = 0x10
            func = RL
        elseif O1 >= 0x08 then
            inst = 0x08
            func = RRC
        elseif O1 >= 0x00 then
            inst = 0x00
            func = RLC
        end

        offset = O1 - inst

        cycles = func(self, offset)
        --cycles = inst(self) --all cb instructions have size 2 (CB,xx)
        if cycles < 12 then
        self.A = self.RegTbl[A]
        self.B = self.RegTbl[B]
        self.C = self.RegTbl[C]
        self.D = self.RegTbl[D]
        self.E = self.RegTbl[E]
        self.H = self.RegTbl[H]
        self.L = self.RegTbl[L]
        elseif cycles >= 16 then
            self:Write(t16(self.H, self.L), self.RegTbl[HL])
        end
        
    else --regular instructions / instruction set
    inst = self.Instructions[CI]
    local O1 = self:Read(self.PC+1)
    local O2 = self:Read(self.PC+2)
    if Debug then
    print("O1 = $"..hex(O1))
    print("O2 = $"..hex(O2))
    end
     size, cycles = inst(self, O1, O2)
    end
    self.PC = self.PC + size

end
    local maskedIFR = band(band(self.IFR, self.IME),0x1F)
    if maskedIFR > 0x00 and self.IE then --interrupt found
        if Debug then print("found interrupt") print(self.IME) end
        self.HALTED = false
        self:Push(self.PC, true)
        if band(maskedIFR, 0x1) == 0x1 then --vblank
            self.PC = 0x0040
            self.IFR = bxor(self.IFR, 0x1)
            if Debug then print("found vblank") end
        elseif band(maskedIFR, 0x2) > 0x0 then --lcd stat
            self.PC = 0x0048
            if Debug then print("found lcd stat") end
            self.IFR = bxor(self.IFR, 0x2)
        elseif band(maskedIFR, 0x4) > 0x0 then --timer overflow
            self.PC = 0x0050
            if Debug then print("found timer overflow") end
            self.IFR = bxor(self.IFR, 0x4)
        elseif band(maskedIFR, 0x8) > 0x0 then --serial transfer complete
            self.PC = 0x0058
            if Debug then print("found serial transfer complete") end
            self.IFR = bxor(self.IFR, 0x8)
        elseif band(maskedIFR, 0x10) > 0x0 then --joypad
            self.PC = 0x0060
            if Debug then print("found joypad") end
            self.IFR = bxor(self.IFR, 0x10)
        end
        cycles = cycles + 12
        self.IE = false
    end
    return cycles
end