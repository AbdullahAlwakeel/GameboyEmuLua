local ffi = require("ffi")
local sdl = require("ffi/sdl")

GB_SND = {}

local a = ffi.load("audio_callback")
ffi.cdef[[
    struct Sound {
        unsigned char *Data;
        int length;
    };
    void audio_callback(void *userdata, unsigned char *stream, int len);
]]

function GB_SND:init()
    Sound_Struct = ffi.new("struct Sound")

    local desired = ffi.new("SDL_AudioSpec")
    local obtained = ffi.new('SDL_AudioSpec')
    desired.freq = 44100
    desired.channels = 4 --4 channels for the gameboy
    desired.format = 0x0008
    desired.samples = 512
    desired.callback = a.audio_callback

    self.NR10 = 0x00
    self.NR11 = 0x00
    self.NR12 = 0x00
    self.NR13 = 0x00
    self.NR14 = 0x00
    self.Ch1Freq = 0x00

    if sdl.SDL_OpenAudio(desired, obtained) ~= 0 then
        error(string.format('could not open audio device: %s', ffi.string(sdl.getError())))
    end

    print("SDL: Opened Audio: freq="..obtained.freq..", channels="..obtained.channels..", samples="..obtained.samples)
    --sdl.SDL_PauseAudio(0)
end

function GB_SND:Update()
end

function GB_SND:UpdateBuffer()
    local buff = {0,0,0,0,255,255,255,255}
end