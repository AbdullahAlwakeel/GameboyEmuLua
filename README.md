# GameboyEmuLua

Note: This project is incomplete, and work has stopped. I am uploading the code for anyone who is interested in the implementation or details.

Project start/stop date: 2018

A gameboy emulator written entirely using Lua. Uses LuaJIT and SDL Lua port for displaying graphics.

Lua (+JIT) is used for all operations including emulation, displaying graphics, taking user input.
All CPU instructions and user input operations are implemented, majority of PPU functions are implemented. Sound is not implemented, and the only supported cartridge types are (MBC1 type) as well as regular cartridge.

The program supports (.gb) files, which are binaries that contain the ROM files of the game to run. If you want, you can test the emulator using the files found in the Testing ROMs folder.