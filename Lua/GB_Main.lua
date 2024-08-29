local ffi = require( "ffi" )
local sdl = require( "ffi/sdl" )
local wm = require( "lib/wm/sdl" )
local uint32ptr = ffi.typeof( "uint32_t*" )
local cos, sin, abs, sqrt, band, bor, bxor, shl, shr, rol, ror = math.cos, math.sin, math.abs, math.sqrt, bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift, bit.rol, bit.ror

Debug = false
Debug_PPU = false

Colors_G = {[0] = 0xBDDE1F, [1] = 0x8bac0f, [2] = 0x306230, [3] = 0x0f380f}
Colors_W = {[0] = 0xFFFFFF, [1] = 0x888888, [2] = 0x444444, [3] = 0x000000}

Colors = Colors_G

function getpixel(x,y)
    --print(math.floor(x*160)..", "..math.floor(y*144))
    return Colors[GB_PPU.Image[math.floor(x*160)][math.floor(y*144)]]
end

package.path = "/Users/abdullahal-wakeel/Desktop/Emu/?.lua;" .. package.path

require("GB_CPU")
require("GB_PPU")
require("GB_SND")
require("GB")

function _2bin(h)
    local b = {[0] = "0", [1] = "1"}
    local s = ""
    local max = 7
    if h > 0xFF then max = 15 end
    for i = 0, max do
        s = s .. b[band(shr(h,i), 0x1)]
    end
    return s:reverse()
end

GB:init("tetris.gb", false)

local function render( screen, tick )
    local pixels_u32 = ffi.cast( uint32ptr, screen.pixels )
    local width, height, pitch = screen.w, screen.h, screen.pitch / 4
    for i = 0, height-1 do
       for j = 0, width-1 do
	  pixels_u32[ j + i*pitch ] = getpixel((j)/(width),(i)/(height))
       end
    end
end


do
   local prev_time, curr_time, fps = nil, 0, 0, 0, 0

   local ticks_base, ticks = 256 * 128, 0, 0
   local bounce_mode, bounce_range, bounce_delta, bounce_step = false, 1024, 0, 1

   while wm:update() do
    local time_since_prev_frame = os.clock()
      local event = wm.event
      local sym, mod = event.key.keysym.sym, event.key.keysym.mod
    --print("KB = "..wm.kb..", SYM = "..sym)
    --print(event.type .. " == ".. sdl.SDL_KEYDOWN)

      if wm.kb == 27 then
	 wm:exit()
	 break
      end

      --keyboard handler
      if event.type == 771 or event.type == 768 then --keydown
        if wm.kb == ("x"):byte() then
            GB.A_J = true
        elseif wm.kb == ("z"):byte() then
            GB.B_J = true
        elseif wm.kb == sdl.SDLK_UP then
            GB.UP_J = true
        elseif wm.kb == sdl.SDLK_DOWN then
            GB.DOWN_J = true
        elseif wm.kb == sdl.SDLK_LEFT then
            GB.LEFT_J = true
        elseif wm.kb == sdl.SDLK_RIGHT then
            GB.RIGHT_J = true
        elseif wm.kb == 13 then
            GB.START_J = true
        end
    else
        if wm.kb == ("x"):byte() then
            GB.A_J = false
        elseif wm.kb == ("z"):byte() then
            GB.B_J = false
        elseif wm.kb == sdl.SDLK_UP then
            GB.UP_J = false
        elseif wm.kb == sdl.SDLK_DOWN then
            GB.DOWN_J = false
        elseif wm.kb == sdl.SDLK_LEFT then
            GB.LEFT_J = false
        elseif wm.kb == sdl.SDLK_RIGHT then
            GB.RIGHT_J = false
        elseif wm.kb == 13 then
            GB.START_J = false
        elseif wm.kb == ("t"):byte() then
            Debug_PPU = true
        end
      end

      --print(i(GB.A_J)..i(GB.B_J)..i(GB.START_J)..i(GB.SELECT_J)..i(GB.UP_J)..i(GB.DOWN_J)..i(GB.LEFT_J)..i(GB.RIGHT_J))
      --print(hex(GB.Joy))

     ticks = sdl.SDL_GetTicks()
     GB:Update()

      -- Render the screen, and flip it
      render( wm.window, ticks + ticks_base )

      -- Calculate the frame rate
      prev_time, curr_time = curr_time, os.clock()
      local diff = curr_time - prev_time + 0.00001
      local real_fps = 1/diff
      if abs( fps - real_fps ) * 10 > real_fps then
	 fps = real_fps
      end
      fps = fps*0.99 + 0.01*real_fps
	 
      -- Update the window caption with statistics
      sdl.SDL_WM_SetCaption( string.format("%dx%d | %.2f fps | %.2f mps",wm.window.w, wm.window.h, fps, fps * (wm.window.w * wm.window.h) / (1024*1024)), nil )
      --while os.clock() - time_since_prev_frame < (1.0/60.0) do
        --
      --end
   end
   sdl.SDL_Quit()
end