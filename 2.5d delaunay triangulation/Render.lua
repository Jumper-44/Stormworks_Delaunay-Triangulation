-- Author: Jumper
-- GitHub: https://github.com/Jumper-44
-- Workshop: https://steamcommunity.com/profiles/76561198084249280/myworkshopfiles/
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey


--[====[ HOTKEYS ]====]
-- Press F6 to simulate this file
-- Press F7 to build the project, copy the output from /_build/out/ into the game to use
-- Remember to set your Author name etc. in the settings: CTRL+COMMA


--[====[ EDITABLE SIMULATOR CONFIG - *automatically removed from the F7 build output ]====]
---@section __LB_SIMULATOR_ONLY__
do
    ---@type Simulator -- Set properties and screen sizes here - will run once when the script is loaded
    simulator = simulator
    simulator:setScreen(1, "3x3")
    simulator:setProperty("ExampleNumberProperty", 123)

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)

        -- touchscreen defaults
        local screenConnection = simulator:getTouchScreen(1)
        simulator:setInputBool(1, screenConnection.isTouched)
        simulator:setInputNumber(1, screenConnection.width)
        simulator:setInputNumber(2, screenConnection.height)
        simulator:setInputNumber(3, screenConnection.touchX)
        simulator:setInputNumber(4, screenConnection.touchY)

        -- NEW! button/slider options from the UI
        simulator:setInputBool(31, simulator:getIsClicked(1))       -- if button 1 is clicked, provide an ON pulse for input.getBool(31)
        simulator:setInputNumber(31, simulator:getSlider(1))        -- set input 31 to the value of slider 1

        simulator:setInputBool(32, simulator:getIsToggled(2))       -- make button 2 a toggle, for input.getBool(32)
        simulator:setInputNumber(32, simulator:getSlider(2) * 50)   -- set input 32 to the value from slider 2 * 50
    end;
end
---@endsection


--[====[ IN-GAME CODE ]====]



require("JumperLib.DataStructures.JL_list")

local v_x, v_y, v_z, v_sx, v_sy, v_sz, v_inNearAndFar, v_isVisible, v_frame,
    t_v1, t_v2, t_v3, t_colorR, t_colorG, t_colorB, t_centroidDepth,
    vertices, triangles, frameCount,
    batch_sequence, batch_sequence_prev, batch_add_ran, triangle_data1, triangle_data2,
    px_cx, px_cy, px_cx_pos, px_cy_pos,
    temp, adx, ady, adz, bdx, bdy, bdz, cdx, cdy, cdz, t, inv_t, lightDirX, lightDirY, lightDirZ,
    initialize, uint16_to_int32, point_sub, normalize, add_triangle, WorldToScreen_triangles_sortFunction, WorldToScreen_triangles

local vertex_buffer_list, triangle_buffer_list, cameraTransform, vertex3_buffer, width, height, colors =
    {0, 0, 0, 0, 0, 0, false, false, 0}, -- vertex_buffer_list
    {0, 0, 0, 0, 0, 0, 0},               -- triangle_buffer_list
    {}, -- cameraTransform
    {}, -- vertex3_buffer
    property.getNumber("w"), property.getNumber("h"), -- width, height
    {{flat = {0,0,255}, steep = {0,150,255}}, {flat = {0,255,0}, steep = {255,200,0}}} -- colors = {color_water, color_ground}

px_cx, px_cy = width/2, height/2
px_cx_pos, px_cy_pos = px_cx + property.getNumber("pxOffsetX"), px_cy + property.getNumber("pxOffsetY")

function initialize()
    v_x, v_y, v_z, v_sx, v_sy, v_sz, v_inNearAndFar, v_isVisible, v_frame,  t_v1, t_v2, t_v3, t_colorR, t_colorG, t_colorB, t_centroidDepth = {},{},{},{},{},{},{},{},{}, {},{},{},{},{},{},{}
    vertices = list({v_x, v_y, v_z, v_sx, v_sy, v_sz, v_inNearAndFar, v_isVisible, v_frame})
    triangles = list({t_v1, t_v2, t_v3, t_colorR, t_colorG, t_colorB, t_centroidDepth})
    frameCount = 0

    for i = 1, 3 do
        vertices.list_insert(vertex_buffer_list) -- super-triangle vertices
    end
end
initialize()
---@cast vertices list
---@cast triangles list

function uint16_to_int32(x) -- Takes a single number containing 2 uint16 and unpacks them.
	x = ('I'):unpack(('f'):pack(x))
	return x>>16, x&0xffff
end

---@param a integer
---@param b integer
---@return number, number, number
function point_sub(a, b)
    return v_x[a]-v_x[b], v_y[a]-v_y[b], v_z[a]-v_z[b]
end

function normalize(x,y,z)
    temp = 1 / (x*x + y*y + z*z)^0.5
    return x*temp, y*temp, z*temp
end

lightDirX, lightDirY, lightDirZ = normalize(0.1, -1, 0.1)

---@return integer
function add_triangle()
    -- calculate color
    adx, ady, adz = point_sub(triangle_buffer_list[1], triangle_buffer_list[2])
    bdx, bdy, bdz = point_sub(triangle_buffer_list[2], triangle_buffer_list[3])
    cdx, cdy, cdz = normalize( -- normalize(cross(a, b))
        ady*bdz - adz*bdy,
        adz*bdx - adx*bdz,
        adx*bdy - ady*bdx
    )

    t = cdx*lightDirX + cdy*lightDirY + cdz*lightDirZ
    t = t*t -- absoloute value and better curve
    inv_t = 1-t

    temp = 0
    for i = 1, 3 do -- amount of vertices under 0 height, i.e. underwater
        temp = temp + (v_y[triangle_buffer_list[i]] < 0 and 1 or 0)
    end
    temp = temp > 1 and colors[1] or colors[2]

    for i = 1, 3 do -- rgb
        triangle_buffer_list[i+3] = (temp.flat[i]*t + temp.steep[i]*inv_t) * t*t*0.9 + 0.1
    end

    return triangles.list_insert(triangle_buffer_list)
end


WorldToScreen_triangles_sortFunction = function(t1,t2)
    return t_centroidDepth[t1] > t_centroidDepth[t2]
end

---@param triangle_buffer table
---@param frameCount number
---@return table
WorldToScreen_triangles = function(triangle_buffer, frameCount)
    local new_triangle_buffer, currentTriangle, vertex_id, X, Y, Z, W, v1, v2, v3
    new_triangle_buffer = {}

    --for i = 1, #triangle_buffer do
    for i in pairs(triangle_buffer) do --temp

        --currentTriangle = triangle_buffer[i]
        currentTriangle = i -- temp
        for j = 1, 3 do
            vertex_id = triangles[j][currentTriangle]

            if v_frame[vertex_id] ~= frameCount then -- is the transformed vertex NOT already calculated
                X, Y, Z, W =
                    v_x[vertex_id],
                    v_y[vertex_id],
                    v_z[vertex_id],
                    1

                X,Y,Z,W =
                    cameraTransform[1]*X + cameraTransform[5]*Y + cameraTransform[9]*Z + cameraTransform[13],
                    cameraTransform[2]*X + cameraTransform[6]*Y + cameraTransform[10]*Z + cameraTransform[14],
                    cameraTransform[3]*X + cameraTransform[7]*Y + cameraTransform[11]*Z + cameraTransform[15],
                    cameraTransform[4]*X + cameraTransform[8]*Y + cameraTransform[12]*Z + cameraTransform[16]

                v_inNearAndFar[vertex_id] = 0<=Z and Z<=W
                if v_inNearAndFar[vertex_id] then -- Is vertex between near and far plane
                    v_isVisible[vertex_id] = -W<=X and X<=W  and  -W<=Y and Y<=W -- Is vertex in frustum (excluded near and far plane test)

                    W = 1/W
                    v_sx[vertex_id] = X*W*px_cx + px_cx_pos
                    v_sy[vertex_id] = Y*W*px_cy + px_cy_pos
                    v_sz[vertex_id] = Z*W
                end
            end
        end

        v1, v2, v3 = t_v1[currentTriangle], t_v2[currentTriangle], t_v3[currentTriangle]
        if -- (Most average cases) determining if triangle is visible / should be rendered
            v_inNearAndFar[v1] and v_inNearAndFar[v2] and v_inNearAndFar[v3]                                           -- Are all vertices within near and far plane
            and (v_isVisible[v1] or v_isVisible[v2] or v_isVisible[v3])                                                -- and atleast 1 visible in frustum
            and (v_sx[v1]*v_sy[v2] - v_sx[v2]*v_sy[v1] + v_sx[v2]*v_sy[v3] - v_sx[v3]*v_sy[v2] + v_sx[v3]*v_sy[v1] - v_sx[v1]*v_sy[v3] > 0) -- and is the triangle facing the camera (backface culling CCW. Flip '>' for CW. Can be removed if triangles aren't consistently ordered CCW/CW)
        then
            t_centroidDepth[currentTriangle] = v_sz[v1] + v_sz[v2] + v_sz[v3] -- centroid depth for sort
            new_triangle_buffer[#new_triangle_buffer+1] = currentTriangle
        end
    end

    table.sort(new_triangle_buffer, WorldToScreen_triangles_sortFunction) -- painter's algorithm | triangle centroid depth sort
    return new_triangle_buffer
end



local temp_triangle_buffer = {}

function onTick()
    renderOn = input.getBool(1)
    if input.getBool(3) then -- reset/clear data
        initialize()
        temp_triangle_buffer = {} -- temp
    end

    if renderOn then
        for i = 1, 16 do
            cameraTransform[i] = input.getNumber(i)
        end

        color_alpha = 0
        for i = 25, 32 do
            color_alpha = color_alpha << 1 | (input.getBool(i) and 1 or 0)
        end
    end

    temp = input.getBool(21) and (input.getBool(22) and 0 or 3) or 6
    for i = 16, 21-temp, 3 do -- get point(s)
        for j = 1, 3 do
            vertex_buffer_list[j] = input.getNumber(i + j)
        end
        vertices.list_insert(vertex_buffer_list)
    end

    -- get triangle data
    batch_sequence, batch_sequence_prev = false, false
    vertex3_buffer[1], vertex3_buffer[2] = uint16_to_int32(input.getNumber(32))
    batch_add_ran = 0
    for i = 7-temp, 15 do
        batch_sequence = input.getBool(3 + i)
        if batch_sequence and not batch_sequence_prev then
            batch_add_ran = batch_add_ran + 1
            triangle_buffer_list[3] = vertex3_buffer[batch_add_ran]
        end
        batch_sequence_prev = batch_sequence

        triangle_data1, triangle_data2 = uint16_to_int32(input.getNumber(i + 16))
        if triangle_data1 > 0 then
            if batch_sequence then -- triangle_data2 is assumed not 0
                triangle_buffer_list[1] = triangle_data1
                triangle_buffer_list[2] = triangle_data2
                --add_triangle()
                temp_triangle_buffer[add_triangle()] = true -- temp
            else
                triangles.list_remove(triangle_data1)
                temp_triangle_buffer[triangle_data1] = nil -- temp
                if triangle_data2 > 0 then
                    triangles.list_remove(triangle_data2)
                    temp_triangle_buffer[triangle_data2] = nil -- temp
                end
            end
        end
    end
end

function onDraw()
    if renderOn then
        triangle_buffer = WorldToScreen_triangles(temp_triangle_buffer, frameCount)
        for i = 1, #triangle_buffer do
            local tri = triangle_buffer[i]
            local v1, v2, v3 = t_v1[tri], t_v2[tri], t_v3[tri]

            screen.setColor(t_colorR[tri], t_colorG[tri], t_colorB[tri])
            screen.drawTriangleF(v_sx[v1], v_sy[v1], v_sx[v2], v_sy[v2], v_sx[v3], v_sy[v3])
        end
        screen.setColor(0, 0, 0, color_alpha)
        screen.drawRectF(0, 0, width, height)

        screen.setColor(255,255,0)
        screen.drawText(0,5, "#T "..#triangle_buffer)

        frameCount = frameCount + 1
    end
end
