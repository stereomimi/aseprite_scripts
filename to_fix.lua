-------------------------------------------------------------------------
------------------ Aseprite Neogeo Fix Image Converter ------------------
------------------         Made by GbaCretin           ------------------
-------------------------------------------------------------------------

-------------------------------| Constants |------------------------------
local TITLE         = "Aseprite Neogeo Fix Image Converter"
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

function to_pal_idx_matrix(img, tile_x, tile_y)
    local ofs_x = tile_x*8
    local ofs_y = tile_y*8
    local pal_idx_array = {} -- pal_idx_array[y][x]
    
    for y=0,7 do
        pal_idx_array[y] = {}
        
        for x=0,7 do
            pal_idx_array[y][x] = math.min(15, img:getPixel(x+ofs_x, y+ofs_y))
        end
    end
    
    return pal_idx_array
end

-------------------------------| Main code |------------------------------
if app.activeSprite.colorMode ~= ColorMode.INDEXED then
    app.alert{
        title=TITLE,
        text="ERROR! The sprite's color mode must be indexed."
    }
    return
end

local layer = app.activeLayer

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

if app.activeSprite.width % 8 ~= 0 then
    app.alert{
        title=TITLE,
        text="ERROR! The tiles' width must be a multiple of 8.",
    }
    return
end

if app.activeSprite.height % 8 ~= 0 then
    app.alert{
        title=TITLE,
        text="ERROR! The tiles' height must be a multiple of 8.",
    }
    return
end

--[[local alert_res = app.alert{
    title=TITLE,
    text="WARNING! This tool only converts the currently selected layer.",
    buttons={"Ok", "Cancel"}
}

if alert_res ~= 1 then
    return
end]]--

--------| Convert palette |--------
local palette = {}

for i=0,15 do
    local color = layer.sprite.palettes[PALETTE_INDEX]:getColor(0)
    
    if i <= #layer.sprite.palettes[PALETTE_INDEX] then
        color = layer.sprite.palettes[PALETTE_INDEX]:getColor(i)
    end
    
    palette[i] = to_neogeo_color(color)
    --print(i, " ", string.format("%04x", palette[i]))
end

--------| Convert cels into 8x8 tiles |--------
local tiles = {}

for cel_idx, cel in ipairs(layer.cels) do
    local img = cel.image:clone()
    local tile_columns = math.ceil(img.width / 8)
    local tile_rows = math.ceil(img.height / 8)
    
    for row=0, tile_rows-1 do
        for col=0, tile_columns-1 do
            tiles[#tiles+1] = to_pal_idx_matrix(img, col, row)
        end
    end
end

--------| Convert each tile to the FIX graphic format |--------
local fix_data = {}
local fix_col_order = {2, 3, 0, 1}

for tile_idx, tile in ipairs(tiles) do
    for _, col in ipairs(fix_col_order) do
        local x = col*2
        
        for y=0,7 do
            local left_color  = tile[y][x]
            local right_color = tile[y][x+1]
            local hex = left_color | (right_color << 4)
            
            fix_data[#fix_data+1] = hex
        end
    end
end

--------| Save FIX graphics |--------
local sprite_parent_dir = app.fs.filePath(app.activeSprite.filename)
local fix_output_path = app.fs.joinPath(sprite_parent_dir, "s1.bin")
local fix_out = io.open(fix_output_path, "wb")
local fix_data_string = ""

for _, byte in ipairs(fix_data) do
    fix_data_string = fix_data_string..string.char(byte)
end

fix_out:write(fix_data_string)
fix_out:close()

--------| Save converted palette |--------
local pal_output_path= app.fs.joinPath(sprite_parent_dir, "pal.txt")
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
