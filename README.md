# NeoGeo-Aseprite-Scripting-Tools

`to_fix.lua`:
  rearranges each cell of the sprite into a 1d spritesheet (The cel's width and height must be a multiple of 8), then it converts that spritesheet into the FIX graphics format. It also converts the palette to the neogeo's color format.

`to_neogeo_sprite.lua`:
also rearranges each cell of the sprite into a 1d spritesheet (the cel's width and height must be a multiple of 16), then it converts it into the neogeo's sprite format. It also converts the palette to the neogeo's color format.

## TODO
* Rearrange animated sprites to support autoanim
