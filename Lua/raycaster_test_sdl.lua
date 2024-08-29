--a test code to become more familiar with SDL+LuaJIT

local ffi = require( "ffi" )
ffi.cdef [[
    void *malloc(size_t size);
    void free(void *ptr);
]]
local sdl = require( "ffi/sdl" )
local wm = require( "lib/wm/sdl" )
local uint32ptr = ffi.typeof( "uint32_t*" )

local band, bor, bxor, shl, shr, rol, ror = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift, bit.rol, bit.ror

Draw = {}
RenderW = 300
RenderH = 300
for x = 0, RenderW-1 do
    Draw[x] = {}
    for y = 0, RenderH-1 do
        if y < RenderH/2 then
            Draw[x][y] = 0x0
        else
            Draw[x][y] = 0x888888
        end
    end
end

function getpixel(x,y)
return Draw[math.floor(x*RenderW)][math.floor(y*RenderH)]
end

local function render( screen, tick )
local pixels_u32 = ffi.cast( uint32ptr, screen.pixels )
local width, height, pitch = screen.w, screen.h, screen.pitch / 4
for i = 0, height-1 do
   for j = 0, width-1 do
  pixels_u32[ j + i*pitch ] = getpixel(j/width,i/height)
   end
end
end

Map = {
    {1,1,1,1,1,1,1,1,1,1},
    {1,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,3,0,1,0,1},
    {1,0,0,0,0,4,0,0,0,1},
    {1,0,0,3,0,0,0,2,0,1},
    {1,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,1},
    {1,0,0,4,0,0,0,2,0,1},
    {1,0,0,0,0,2,0,0,0,1},
    {1,1,1,1,1,1,1,1,1,1},
}

ColorTbl = {0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00, 0xFF00FF, 0x00FFFF, 0xFFFFFF}

PlayerX = 3.5
PlayerY = 3.5

PlayerAngle = 0
FOV = 70

MoveSpeed = 0.01
LookSpeed = 1

Delta = 0.01
function Calc()
    for x = 0, RenderW-1 do
        for y = 0, RenderH-1 do
            if y < RenderH/2 then
                Draw[x][y] = 0x0
            else
                Draw[x][y] = 0x888888
            end
        end
    end
    for x = 0, RenderW-1 do
        local Angle = ((x/RenderW)*FOV) + PlayerAngle - (FOV/2)
        local currX, currY = PlayerX, PlayerY
        local DeltaX = math.cos(math.rad(Angle))*Delta
        local DeltaY = math.sin(math.rad(Angle))*Delta
        local Color = -1
        for iter = 1, (10/Delta) do
            currX = currX + DeltaX
            currY = currY + DeltaY
            if currX < 0 or currY < 0 or currX > RenderW-1 or currY > RenderH-1 then
                break
            end
            Color = Map[math.floor(currY)][math.floor(currX)]
            if Color == nil then
                break
            end
            if Color > 0 then
                local Dist = (currX-PlayerX)*math.cos(math.rad(PlayerAngle)) + (currY-PlayerY)*math.sin(math.rad(PlayerAngle))
                local Size = math.min(math.floor(RenderH / Dist), RenderH-1)
                local StartY = math.floor((RenderH - Size)/2)
                for y = StartY, StartY+Size do
                    if currX % 1.0 < currY % 1.0 then
                        Draw[x][y] = ColorTbl[Color]
                    else
                        Draw[x][y] = band(ColorTbl[Color], 0x888888)
                    end
                end
                break
            end
        end
    end
end

do
    local prev_time, curr_time, fps = nil, 0, 0, 0, 0
 
    local ticks_base, ticks = 256 * 128, 0, 0
    local bounce_mode, bounce_range, bounce_delta, bounce_step = false, 1024, 0, 1
 
    while wm:update() do
       local event = wm.event
       local sym, mod = event.key.keysym.sym, event.key.keysym.mod
       if wm.kb == 13 then
      sdl.SDL_WM_ToggleFullScreen( wm.window )
       end
 
       if wm.kb == 27 then
      wm:exit()
      break
       end
       print(sym)
       if sym > 255 then
       if wm.kb == ("w"):byte() then
        PlayerX = PlayerX + (MoveSpeed*math.cos(math.rad(PlayerAngle)))
        PlayerY = PlayerY + (MoveSpeed*math.sin(math.rad(PlayerAngle)))
       end
       if wm.kb == ("s"):byte() then
        PlayerX = PlayerX - (MoveSpeed*math.cos(math.rad(PlayerAngle)))
        PlayerY = PlayerY - (MoveSpeed*math.sin(math.rad(PlayerAngle)))
       end

       if wm.kb == ("d"):byte() then
        PlayerAngle = PlayerAngle + LookSpeed
    end
    if wm.kb == ("a"):byte() then
            PlayerAngle = PlayerAngle - LookSpeed
        end
    end

 

      ticks = sdl.SDL_GetTicks()
 
       -- Render the screen, and flip it
       Calc()
       render( wm.window, ticks )
 
       -- Calculate the frame rate
       prev_time, curr_time = curr_time, os.clock()
       local diff = curr_time - prev_time + 0.00001
       local real_fps = 1/diff
       if math.abs( fps - real_fps ) * 10 > real_fps then
      fps = real_fps
       end
       fps = fps*0.99 + 0.01*real_fps
      
       -- Update the window caption with statistics
       sdl.SDL_WM_SetCaption( string.format("Raycaster V1 %d %dx%d | %.2f fps | %.2f mps", ticks_base, wm.window.w, wm.window.h, fps, fps * (wm.window.w * wm.window.h) / (1024*1024)), nil )
    end
    sdl.SDL_Quit()
 end