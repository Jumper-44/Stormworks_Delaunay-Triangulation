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
    simulator:setProperty("w", 96)
    simulator:setProperty("h", 96)
    simulator:setProperty("pxOffsetX", 0)
    simulator:setProperty("pxOffsetY", 0)
    simulator:setProperty("TBR", 60)
    simulator:setProperty("MDT", 1000)

    local _isTouched = false

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)

        -- touchscreen defaults
        local screenConnection = simulator:getTouchScreen(1)
        --simulator:setInputBool(1, screenConnection.isTouched)
        --simulator:setInputNumber(1, screenConnection.width)
        --simulator:setInputNumber(2, screenConnection.height)
        --simulator:setInputNumber(3, screenConnection.touchX)
        --simulator:setInputNumber(4, screenConnection.touchY)

        if screenConnection.isTouched and screenConnection.isTouched ~= _isTouched then
            simulator:setInputNumber(11, screenConnection.touchX)
            simulator:setInputNumber(12, screenConnection.touchY)
            simulator:setInputBool(11, true)
        else
            simulator:setInputNumber(11, 0)
            simulator:setInputNumber(12, 0)
            simulator:setInputBool(11, false)
        end
        _isTouched = screenConnection.isTouched

        -- NEW! button/slider options from the UI
        simulator:setInputBool(32, simulator:getIsClicked(1))       -- if button 1 is clicked, provide an ON pulse for input.getBool(31)
        simulator:setInputNumber(32, math.floor(simulator:getSlider(1)*20))        -- set input 31 to the value of slider 1

        --simulator:setInputBool(32, simulator:getIsToggled(2))       -- make button 2 a toggle, for input.getBool(32)
        --simulator:setInputNumber(32, simulator:getSlider(2) * 50)   -- set input 32 to the value from slider 2 * 50
    end;
end
---@endsection


--[====[ IN-GAME CODE ]====]

-- try require("Folder.Filename") to include code from another file in this, so you can store code in libraries
-- the "LifeBoatAPI" is included by default in /_build/libs/ - you can use require("LifeBoatAPI") to get this, and use all the LifeBoatAPI.<functions>!


require("JumperLib.JL_general")
require("JumperLib.DataStructures.JL_list")


local v_x, v_y, v_z, v_sx, v_sy, v_sz, v_inNearAndFar, v_isVisible, v_frame,
    t_v1, t_v2, t_v3, t_colorR, t_colorG, t_colorB, t_centroidDepth, t_quadtree_id,
    vertices, triangles, quadTree, triangle_buffer,
    batch_sequence, batch_sequence_prev, batch_add_ran, v1, v2, v3,
    px_cx, px_cy, px_cx_pos, px_cy_pos,
    temp, adz, bdz, cdx, cdy, t, inv_t

local vertex_buffer_list, triangle_buffer_list, cameraTransform, vertex3_buffer, frameCount, width, height, triangle_buffer_refreshrate, max_drawn_triangles, colors =
    {0,0,0, 0,0,0, false, false, 0}, -- vertex_buffer_list
    {0,0,0, 0,0,0, 0, 0},            -- triangle_buffer_list
    {}, -- cameraTransform
    {}, 0, -- vertex3_buffer, frameCount
    property.getNumber("w"), property.getNumber("h"), property.getNumber("TBR"), property.getNumber("MDT"), -- width, height, triangle_buffer_refreshrate, max_drawn_triangles
    {{flat = {0,0,255}, steep = {0,150,255}}, {flat = {0,255,0}, steep = {255,200,0}}} -- colors = {color_water, color_ground}

px_cx, px_cy = width/2, height/2
px_cx_pos, px_cy_pos = px_cx + property.getNumber("pxOffsetX"), px_cy + property.getNumber("pxOffsetY")


WorldToScreen_triangles_sortFunction = function(t1, t2)
    return t_centroidDepth[t1] < t_centroidDepth[t2]
end

---@param triangle_buffer table
---@return table
WorldToScreen_triangles = function(triangle_buffer)
    local new_triangle_buffer, refreshCurrentFrame, currentTriangle, vertex_id, X, Y, Z, W
    new_triangle_buffer = {}
    refreshCurrentFrame = frameCount % triangle_buffer_refreshrate == 0

    if refreshCurrentFrame then
        triangle_buffer = {}
        quadTree.QuadTree_frustumcull(triangle_buffer)

        -- [[ only used in debug draw
        triangle_buffer_len_debug = #triangle_buffer
        --]]
    end

    for i = 1, #triangle_buffer do
        currentTriangle = triangle_buffer[i]

        for j = 1, 3 do
            vertex_id = triangles[j][currentTriangle]

            if v_frame[vertex_id] ~= frameCount then -- is the transformed vertex NOT already calculated
                v_frame[vertex_id] = frameCount

                X, Y, Z = v_x[vertex_id], v_y[vertex_id], v_z[vertex_id]
                X, Y, Z, W =
                    cameraTransform[1]*X + cameraTransform[5]*Y + cameraTransform[9 ]*Z + cameraTransform[13],
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
            v_inNearAndFar[v1] and v_inNearAndFar[v2] and v_inNearAndFar[v3]                                                                -- Are all vertices within near and far plane
            and (v_isVisible[v1] or v_isVisible[v2] or v_isVisible[v3])                                                                     -- and atleast 1 visible in frustum
            and (v_sx[v1]*v_sy[v2] - v_sx[v2]*v_sy[v1] + v_sx[v2]*v_sy[v3] - v_sx[v3]*v_sy[v2] + v_sx[v3]*v_sy[v1] - v_sx[v1]*v_sy[v3] > 0) -- and is the triangle facing the camera (backface culling CCW. Flip '>' for CW. Can be removed if triangles aren't consistently ordered CCW/CW)
        then
            t_centroidDepth[currentTriangle] = v_sz[v1] + v_sz[v2] + v_sz[v3] -- centroid depth for sort
            new_triangle_buffer[#new_triangle_buffer+1] = currentTriangle
        end
    end

    if refreshCurrentFrame then
        table.sort(new_triangle_buffer, WorldToScreen_triangles_sortFunction) -- painter's algorithm | triangle centroid depth sort

        for i = max_drawn_triangles, #new_triangle_buffer do
            new_triangle_buffer[i] = nil
        end
    end

    return new_triangle_buffer
end


---require "JumperLib.DataStructures.JL_list"
---@return table
QuadTree = function()
    local qt, nCenterX, nCenterZ, nSize, nItems, nQuadrant1, nQuadrant2, nQuadrant3, nQuadrant4, check_queue, full_in_view_queue, check_queue_ptr, full_in_view_queue_ptr, check_queue_size, full_in_view_queue_size, lookUpTable, frustumPlaneTest, currentNode, quadrant, partially_visible, fully_visible, cx, cz, nodeSize, X, Y, Z, W =
        {},{},{},{},{},{},{},{},{}, -- qt, nCenterX, nCenterZ, nSize, nItems, nQuadrant1, nQuadrant2, nQuadrant3, nQuadrant4
        {1}, {}, 0, 0, 0, 0, -- check_queue, full_in_view_queue, check_queue_ptr, full_in_view_queue_ptr, check_queue_size, full_in_view_queue_size
        {}, {} -- lookUpTable, frustumPlaneTest
        --, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil  -- currentNode, quadrant, partially_visible, fully_visible, cx, cz, nodeSize, X, Y, Z, W

    local nodes, newNodeBuffer, quadrants, bool2num =
        list({nCenterX, nCenterZ, nSize, nItems, nQuadrant1, nQuadrant2, nQuadrant3, nQuadrant4}),
        {0, 0, 3e5, false, false, false, false, false},
        {nQuadrant1, nQuadrant2, nQuadrant3, nQuadrant4},
        {[false] = 0, [true] = 1}

    nodes.list_insert(newNodeBuffer) -- init root node

    ---comment
    ---@param triangleID integer
    ---@return integer nodeID
    qt.QuadTree_insert = function(triangleID)
        currentNode = 1
        X = (v_x[t_v1[triangleID]] + v_x[t_v2[triangleID]] + v_x[t_v3[triangleID]])/3
        Z = (v_z[t_v1[triangleID]] + v_z[t_v2[triangleID]] + v_z[t_v3[triangleID]])/3

        repeat
            cx = nCenterX[currentNode] < X
            cz = nCenterZ[currentNode] < Z
            quadrant = quadrants[bool2num[cx]*2 + bool2num[cz] + 1]
            if quadrant[currentNode] then
                currentNode = quadrant[currentNode]
            else
                nodeSize = nSize[currentNode]
                newNodeBuffer[1] = nCenterX[currentNode] + (cx and nodeSize or -nodeSize)
                newNodeBuffer[2] = nCenterZ[currentNode] + (cz and nodeSize or -nodeSize)
                newNodeBuffer[3] = nodeSize * 0.5
                newNodeBuffer[4] = nodeSize < 32 and {} or false -- if nodeSize is less than 32 then create leaf node

                temp = nodes.list_insert(newNodeBuffer)
                quadrant[currentNode] = temp
                currentNode = temp
            end
        until nItems[currentNode]

        nItems[currentNode][#nItems[currentNode]+1] = triangleID
        t_quadtree_id[triangleID] = currentNode
        return currentNode
    end

    ---comment
    ---@param triangleID integer
    qt.QuadTree_remove = function(triangleID)
        temp = nItems[t_quadtree_id[triangleID]]
        for i = 1, #temp do
            if temp[i] == triangleID then
                temp[i] = temp[#temp]
                temp[#temp] = nil
                break
            end
        end
    end

    ---https://web.archive.org/web/20030810032130/http://www.markmorley.com:80/opengl/frustumculling.html  
    ---Frustum culling in clip space instead of extracting frustum planes.  
    ---A quad node height is implicitly 0.
    ---@param triangle_buffer table
    qt.QuadTree_frustumcull = function(triangle_buffer)
        check_queue_ptr = 1
        check_queue_size = 1 -- Has root node
        full_in_view_queue_ptr = 1
        full_in_view_queue_size = 0

        repeat
            currentNode = check_queue[check_queue_ptr]
            if nItems[currentNode] then -- is leaf node?
                for i = 1, #nItems[currentNode], bool2num[#triangle_buffer > max_drawn_triangles]+1 do
                    triangle_buffer[#triangle_buffer+1] = nItems[currentNode][i]
                end
            else
                for i = 1, 6 do
                    frustumPlaneTest[i] = 0
                end

                cx, cz, nodeSize = nCenterX[currentNode], nCenterZ[currentNode], nSize[currentNode]*2
                lookUpTable[0] = nodeSize
                lookUpTable[2] = -nodeSize

                for i = 1, 4 do
                    X, Z = cx + lookUpTable[i&2], cz + lookUpTable[-i&2] -- quad corner

                    X, Y, Z, W =
                        cameraTransform[1]*X + cameraTransform[9 ]*Z + cameraTransform[13],
                        cameraTransform[2]*X + cameraTransform[10]*Z + cameraTransform[14],
                        cameraTransform[3]*X + cameraTransform[11]*Z + cameraTransform[15],
                        cameraTransform[4]*X + cameraTransform[12]*Z + cameraTransform[16]

                    frustumPlaneTest[1] = frustumPlaneTest[1] + bool2num[-W<=X]
                    frustumPlaneTest[2] = frustumPlaneTest[2] + bool2num[X<=W]
                    frustumPlaneTest[3] = frustumPlaneTest[3] + bool2num[-W<=Y]
                    frustumPlaneTest[4] = frustumPlaneTest[4] + bool2num[Y<=W]
                    frustumPlaneTest[5] = frustumPlaneTest[5] + bool2num[0<=Z]
                    frustumPlaneTest[6] = frustumPlaneTest[6] + bool2num[Z<=W]
                end

                partially_visible = true
                fully_visible = true
                for i = 1, 6 do
                    if frustumPlaneTest[i] == 0 then
                        partially_visible = false
                        fully_visible = false
                        break
                    elseif frustumPlaneTest[i] ~= 4 then
                        fully_visible = false
                    end
                end

                if fully_visible then
                    full_in_view_queue_size = full_in_view_queue_size + 1
                    full_in_view_queue[full_in_view_queue_size] = currentNode
                elseif partially_visible then
                    for i = 1, 4 do
                        temp = quadrants[i][currentNode]
                        if temp then
                            check_queue_size = check_queue_size + 1
                            check_queue[check_queue_size] = temp
                        end
                    end
                end
            end

            check_queue_ptr = check_queue_ptr + 1
        until check_queue_ptr > #check_queue

        while full_in_view_queue_ptr <= full_in_view_queue_size do
            currentNode = full_in_view_queue[full_in_view_queue_ptr]
            if nItems[currentNode] then -- is leaf node?
                for i = 1, #nItems[currentNode], bool2num[#triangle_buffer > max_drawn_triangles]+1 do
                    triangle_buffer[#triangle_buffer+1] = nItems[currentNode][i]
                end
            else
                for i = 1, 4 do
                    temp = quadrants[i][currentNode]
                    if temp then
                        full_in_view_queue_size = full_in_view_queue_size + 1
                        full_in_view_queue[full_in_view_queue_size] = temp
                    end
                end
            end

            full_in_view_queue_ptr = full_in_view_queue_ptr + 1
        end
    end

    return qt
end


function initialize()
    v_x, v_y, v_z, v_sx, v_sy, v_sz, v_inNearAndFar, v_isVisible, v_frame,  t_v1, t_v2, t_v3, t_colorR, t_colorG, t_colorB, t_centroidDepth, t_quadtree_id = {},{},{},{},{},{},{},{},{}, {},{},{},{},{},{},{},{}
    vertices = list({v_x, v_y, v_z, v_sx, v_sy, v_sz, v_inNearAndFar, v_isVisible, v_frame})
    triangles = list({t_v1, t_v2, t_v3, t_colorR, t_colorG, t_colorB, t_centroidDepth, t_quadtree_id})
    triangle_buffer = {}
    quadTree = QuadTree()
end
initialize()


function onTick()
    renderOn = input.getBool(1)
    if input.getBool(3) then -- reset/clear data
        initialize()
    end
    drawWireframe = input.getBool(4)

    if renderOn then
        for i = 1, 16 do
            cameraTransform[i] = input.getNumber(i)
        end

        color_alpha = 0
        for i = 25, 32 do
            color_alpha = color_alpha << 1 | (input.getBool(i) and 1 or 0)
        end

        frameCount = frameCount + 1
    end

    temp = input.getBool(22) and (input.getBool(23) and 0 or 3) or 6
    for i = 16, 21-temp, 3 do -- get point(s)
        for j = 1, 3 do
            vertex_buffer_list[j] = input.getNumber(i + j)
        end
        vertices.list_insert(vertex_buffer_list)
    end

    -- get triangle data
    batch_sequence, batch_sequence_prev = false, false
    vertex3_buffer[1], vertex3_buffer[2] = unpack_float_to_uint16_pair(input.getNumber(32))
    batch_add_ran = 0
    for i = 7-temp, 15 do
        batch_sequence = input.getBool(4 + i)
        if batch_sequence and not batch_sequence_prev then
            batch_add_ran = batch_add_ran + 1

            v3 = vertex3_buffer[batch_add_ran]
            triangle_buffer_list[3] = v3
        end
        batch_sequence_prev = batch_sequence

        v1, v2 = unpack_float_to_uint16_pair(input.getNumber(i + 16))
        if v1 > 0 then
            if batch_sequence then -- triangle_data2 is assumed not 0
                triangle_buffer_list[1] = v1
                triangle_buffer_list[2] = v2

                -- add_triangle
                adz = v_z[v1]-v_z[v2]
                bdz = v_z[v2]-v_z[v3]
                cdx, cdy = -- crossproduct, but z-component is discarded
                    (v_y[v1]-v_y[v2])*bdz - adz*(v_y[v2]-v_y[v3]),
                    adz*(v_x[v2]-v_x[v3]) - (v_x[v1]-v_x[v2])*bdz

                                                                        -- lightDirX, lightDirY = 0.28, -0.96  -- 0.28² + 0.96² = 1
                t = (0.28*cdx - 0.96*cdy) / (cdx*cdx + cdy*cdy)^0.5     -- (lightDirX*cdx + lightDirY*cdy) / cd_length
                t = t*t -- absoloute value and better curve
                inv_t = 1-t

                temp = 0 > (v_y[v1] + v_y[v2] + v_y[v3]) and colors[1] or colors[2] -- is triangle centroid center less than 0, i.e. underwater

                for j = 1, 3 do
                    triangle_buffer_list[j+3] = (temp.flat[j]*t + temp.steep[j]*inv_t) * t*t*0.8 + 0.2 -- rgb
                end

                temp = triangles.list_insert(triangle_buffer_list)
                t_quadtree_id[temp] = quadTree.QuadTree_insert(temp)
            else
                triangles.list_remove(v1)
                quadTree.QuadTree_remove(v1)
                if v2 > 0 then
                    triangles.list_remove(v2)
                    quadTree.QuadTree_remove(v2)
                end
            end
        end
    end
end

triangle_buffer_len_debug = 0 -- debug

function onDraw()
    if renderOn then
        local setColor, drawTriangle =
            screen.setColor,
            drawWireframe and screen.drawTriangle or screen.drawTriangleF

        triangle_buffer = WorldToScreen_triangles(triangle_buffer)
        for i = #triangle_buffer, 1, -1 do
            temp = triangle_buffer[i]
            v1, v2, v3 = t_v1[temp], t_v2[temp], t_v3[temp]

            setColor(t_colorR[temp], t_colorG[temp], t_colorB[temp])
            drawTriangle(v_sx[v1], v_sy[v1], v_sx[v2], v_sy[v2], v_sx[v3], v_sy[v3])
        end
        setColor(0, 0, 0, color_alpha)
        screen.drawRectF(0, 0, width, height)

        -- [[ debug
        setColor(255,255,255,100)
        screen.drawText(0,height-15, "A "..color_alpha)
        screen.drawText(0,height-7, "T "..#triangle_buffer.."/"..triangle_buffer_len_debug)
        -- ]]
    end
end