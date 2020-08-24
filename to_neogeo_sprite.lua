-------------------------------------------------------------------------
------------------ Aseprite Neogeo Fix Image Converter ------------------
------------------         Made by GbaCretin           ------------------
-------------------------------------------------------------------------
-- WARNING! This only works with 8 MBs of sprite data;
-- it can be modified easily to save to more croms though.

-------------------------------| Constants |------------------------------
local TITLE         = "Aseprite Neogeo Sprite Image Converter"
local PALETTE_INDEX = 1

--------------------------| Conversion Functions |------------------------
function to_neogeo_color(color)
    local luma 
        = math.floor(
            (54.213*color.red) + (182.376*color.green) + (18.411*color.blue)) & 1
    local red   = math.floor(color.red/8)
    local green = math.floor(color.green/8)
    local blue  = math.floor(color.blue/8)
    local hex = 
            (((luma ~ 1) << 15) | ((red & 1) << 14) | ((green & 1) << 13) | 
             ((blue & 1) << 12) | ((red & 0x1E) << 7) | ((green & 0x1E) << 3) | (blue >> 1))
    
    --print(luma)
    
    return hex
end

function to_16x16_tile(img, col, row)
    local ofs_x = col*16
    local ofs_y = row*16
    local tile16x16 = {} -- tile16x16[y][x]
    
    for y=0,15 do
        tile16x16[y] = {}
        
        for x=0,15 do
            local px = img:getPixel(x+ofs_x, y+ofs_y)
            
            if px <= 15 then
                tile16x16[y][x] = px
            else
                tile16x16[y][x] = 0
            end
        end
    end
    
    return tile16x16
end

function to_8x8_tile(t16, col, row)
    local ofs_x = col*8
    local ofs_y = row*8
    local tile8x8 = {} -- tile8x8[y][x]
    
    for y=0,7 do
        tile8x8[y] = {}
        
        for x=0,7 do
            tile8x8[y][x] = t16[y+ofs_y][x+ofs_x]
        end
    end
    
    return tile8x8
end

-------------------------------| Main code |------------------------------
if app.activeSprite.colorMode ~= ColorMode.INDEXED then
    app.alert{
        title=TITLE,
        text="ERROR! The sprite's color mode must be indexed."
    }
    return
end

local sprite = Sprite(app.activeSprite)
sprite:flatten()
local layer = sprite.layers[1]
local sprite_name = app.fs.fileTitle(app.activeSprite.filename)

if layer.isGroup then
    app.alert{
        title=TITLE,
        text="ERROR! The selected layer cannot be a group."
    }
    return
end

if #layer.sprite.palettes[PALETTE_INDEX] > 16 then
    local res = app.alert{
        title=TITLE,
        buttons={"Ok", "Cancel"},
        text="WARNING! The FIX palette can only contain a maximum of 16 colors. Some of them won't show up.",
    }
    
    if res ~= 1 then
        return
    end
end

if app.activeSprite.width % 16 ~= 0 then
    app.alert{
        title=TITLE,
        text="ERROR! The sprites' width must be a multiple of 16.",
    }
    return
end

if app.activeSprite.height % 16 ~= 0 then
    app.alert{
        title=TITLE,
        text="ERROR! The sprites' height must be a multiple of 16.",
    }
    return
end

if app.activeSprite.height > 512 then
    app.alert{
        title=TITLE,
        text="ERROR! The sprites' height cannot be more then 512.",
    }
    return
end

--------| Convert palette |--------
local palette = {}
    
for i=0,15 do
    local color = layer.sprite.palettes[PALETTE_INDEX]:getColor(0)

    if i <= (#layer.sprite.palettes[PALETTE_INDEX]-1) then
        color = layer.sprite.palettes[PALETTE_INDEX]:getColor(i)
    end
    
    palette[i] = to_neogeo_color(color)
    --print(i, " ", string.format("%04x", palette[i]))
end

--------| Convert cels to 16x16 tiles |--------
local tiles16x16 = {} -- each element is a 16x16 matrix

for cel_idx, cel in ipairs(layer.cels) do
    local img = cel.image:clone()
    local tile_columns = math.ceil(img.width / 16)
    local tile_rows = math.ceil(img.height / 16)
    
    for col=0,tile_columns-1 do
        for row=0,tile_rows-1 do
            local img = cel.image:clone()
            tiles16x16[#tiles16x16+1] = to_16x16_tile(img, col, row)
        end
    end
end

--------| 16x16 tiles to 8x8 tiles |--------
local tiles8x8 = {} -- each element is an 8x8 matrix

for i, t16 in ipairs(tiles16x16) do
    for col=1,0,-1 do
        for row=0,1 do
            tiles8x8[#tiles8x8+1] = to_8x8_tile(t16, col, row)
        end
    end
end

--------| 8x8 tiles to backwards pixel strips |--------
local pixel_strips = {} -- each element is an array of 8 nibbles

for i, t8 in ipairs(tiles8x8) do
    for y=0,7 do
        pixel_strips[#pixel_strips+1] = {}
        
        for x=0,7 do
            local next_idx = #pixel_strips[#pixel_strips]+1
            pixel_strips[#pixel_strips][next_idx] = t8[y][x]
        end
    end
end

--------| convert pixel strips into odd and even croms |--------
local even_crom = {}
local odd_crom  = {}

for pxs_i, px_strip in ipairs(pixel_strips) do
    local bitplanes = {} -- each bitplane is a byte
    bitplanes[0] = 0
    bitplanes[1] = 0
    bitplanes[2] = 0
    bitplanes[3] = 0
    
    for px_i, px in ipairs(px_strip) do
        for bit_i=0,3 do
            local mask = 1 << bit_i
            local bit = (px & mask) >> bit_i
            bitplanes[bit_i] = bitplanes[bit_i] | (bit<<(px_i-1))
        end
    end
    
    odd_crom[#odd_crom+1] = bitplanes[0]
    odd_crom[#odd_crom+1] = bitplanes[1]
    even_crom[#even_crom+1] = bitplanes[2]
    even_crom[#even_crom+1] = bitplanes[3]
end

--------| Save the croms |--------
local sprite_parent_dir = app.fs.filePath(app.activeSprite.filename)
local c1_output_path = app.fs.joinPath(sprite_parent_dir, sprite_name..".c1")
local c2_output_path = app.fs.joinPath(sprite_parent_dir, sprite_name..".c2")
local c1_out = io.open(c1_output_path, "wb")
local c2_out = io.open(c2_output_path, "wb")
local c1_data_string = ""
local c2_data_string = ""

for i, _ in ipairs(odd_crom) do
    c1_data_string = c1_data_string..string.char(odd_crom[i])
    c2_data_string = c2_data_string..string.char(even_crom[i])
end

c1_out:write(c1_data_string)
c2_out:write(c2_data_string)
c1_out:close()
c2_out:close()

--------| Save converted palette |--------
local pal_output_path= app.fs.joinPath(sprite_parent_dir, sprite_name..".pal.txt")
local pal_out = io.open(pal_output_path, "w")
local pal_out_string = ""

for i, clr in ipairs(palette) do
    pal_out_string = 
            pal_out_string.."color "..i..": "..string.format("%04X", clr).."\n"
end

pal_out:write(pal_out_string)
pal_out:close()

--------| Success Alert |--------
app.alert{
    title=TITLE,
    text="The active layer and palette were succesfully converted and saved."}
