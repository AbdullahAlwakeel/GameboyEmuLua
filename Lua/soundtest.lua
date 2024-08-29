local sdl = require 'ffi/sdl'
local ffi = require 'ffi'
local wm = require("lib/wm/sdl")

ffi.cdef(
[[
void *malloc(size_t size);
void free(void *ptr);
void *memset(void *ptr, int value, size_t size);
]])

local desired = ffi.new('SDL_AudioSpec')
local obtained = ffi.new('SDL_AudioSpec')

desired.freq = 44100
desired.format = 0x0008
desired.channels = 2
desired.samples = 512
desired.callback = function(userdata, stream, size) for i = 0, size-1 do stream[i] = i end end
desired.userdata = nil

if sdl.SDL_OpenAudio(desired, obtained) ~= 0 then
   error(string.format('could not open audio device: %s', ffi.string(sdl.getError())))
end

print(string.format('obtained parameters: format=%s, channels=%s freq=%s size=%s bytes',
                    bit.band(obtained.format, 0xff), obtained.channels, obtained.freq, obtained.samples))

jit.off()
sdl.SDL_PauseAudio(0)
c_ = 0
while true do
   c_ = c_ + 1
end
jit.on()
