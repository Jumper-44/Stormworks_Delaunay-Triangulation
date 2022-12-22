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
    simulator:setScreen(1, "5x5")
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

-- try require("Folder.Filename") to include code from another file in this, so you can store code in libraries
-- the "LifeBoatAPI" is included by default in /_build/libs/ - you can use require("LifeBoatAPI") to get this, and use all the LifeBoatAPI.<functions>!





--#region readme
--[[
Recieves cameraTransform_world and laserPos from "CameraTransform.lua" script

This recieves triangle data from "Delaunay.lua" and renders
--]]
--#endregion readme


--#region Conversion
-- Bitwise operations can only be done to integers, but also need to send the numbers as float when sending from script to script as Stormworks likes it that way.
--[[
local function int32_to_uint16(a, b) -- Takes 2 int32 and converts them to uint16 residing in a single number
	return (('f'):unpack(('I'):pack( ((a&0xffff)<<16) | (b&0xffff)) ))
end
--]]

--[[ Using uint16_to_int32(), but it is inlined to save chars
local function uint16_to_int32(x) -- Takes a single number containing 2 uint16 and unpacks them.
	x = ('I'):unpack(('f'):pack(x))
	return x>>16, x&0xffff
end
--]]
--#endregion Conversion



--#region vec3
local Vec3 = function(x,y,z) return {x=x, y=y, z=z} end

local Add, Sub, Scale, Dot, Cross =
    function(a,b) return Vec3(a.x+b.x, a.y+b.y, a.z+b.z) end,
    function(a,b) return Vec3(a.x-b.x, a.y-b.y, a.z-b.z) end,
    function(a,b) return Vec3(a.x*b, a.y*b, a.z*b) end,
    function(a,b) return a.x*b.x + a.y*b.y + a.z*b.z end,
    function(a,b) return Vec3(a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x) end

Len = function(a) return Dot(a,a)^.5 end
Normalize = function(a) return Scale(a, 1/Len(a)) end
--#endregion vec3



--#region Rendering
w, h, max_drawn_triangles =
    property.getNumber("w"),
    property.getNumber("h"),
    property.getNumber("MDT")

local cx,cy, SCREEN_centerX, SCREEN_centerY, triangle_buffer_refreshrate, triangle_buffer, frameCount =
    w/2, h/2,
    w/2 + property.getNumber("pxOffsetX"),
    h/2 + property.getNumber("pxOffsetY"),
    property.getNumber("TBR"),
    {}, 1


WorldToScreen = function(vertices, quadTree, cameraTransform, gps)
    local screen_triangles, vertex_buffer = {}, {}

    if frameCount >= triangle_buffer_refreshrate then
        triangle_buffer = {}
        quadTree.frustumCull(quadTree.tree, cameraTransform, gps, triangle_buffer)
        frameCount = 1
    else
        frameCount = frameCount+1
    end

    for i = #triangle_buffer, 1, -1 do -- Reverse iteration, so indexes can be removed from triangle_buffer
        local v, id, w = {}, 0, 0
        for j = 1, 3 do
            id = triangle_buffer[i][j].id
            if vertex_buffer[id] == nil then

                local X, Y, Z, W =
                    vertices[id].x - gps.x,
                    vertices[id].y - gps.y,
                    vertices[id].z - gps.z,
                    {} -- W was 0, but now used as a temp local var

                --[[ Reduced due to char limit
                X,Y,Z,W =
                    cameraTransform[1]*X + cameraTransform[5]*Y + cameraTransform[9]*Z,             -- + cameraTransform[13],
                    cameraTransform[2]*X + cameraTransform[6]*Y + cameraTransform[10]*Z,            -- + cameraTransform[14],
                    cameraTransform[3]*X + cameraTransform[7]*Y + cameraTransform[11]*Z + cameraTransform[15],
                    cameraTransform[4]*X + cameraTransform[8]*Y + cameraTransform[12]*Z             -- + cameraTransform[16]
                --]]

                for k = 1, 4 do
                    W[k] = cameraTransform[k]*X + cameraTransform[k+4]*Y + cameraTransform[k+8]*Z
                end
                X, Y, Z, W =
                    W[1],
                    W[2],
                    W[3] + cameraTransform[15],
                    W[4]


                if (0<=Z and Z<=W) then --clip and discard points       -- (-W<=X and X<=W) and (-W<=Y and Y<=W) and (0<=Z and Z<=W)
                    w = 1/W
                    v[j] = {
                        x = X*w*cx + SCREEN_centerX,
                        y = Y*w*cy + SCREEN_centerY,
                        z = Z*w,
                        isIn = (-W<=X and X<=W) and (-W<=Y and Y<=W)
                    }
                    vertex_buffer[id] = v[j]
                else -- x & y are screen coordinates, z is depth
                    vertex_buffer[id] = false
                    v[j] = false
                end
            else
                v[j] = vertex_buffer[id]
            end
        end

        if v[1] and v[2] and v[3] then -- if all vertices are within the near and far plane
            if v[1].isIn or v[2].isIn or v[3].isIn then -- if atleast 1 visible vertex
                if (v[1].x*v[2].y - v[2].x*v[1].y + v[2].x*v[3].y - v[3].x*v[2].y + v[3].x*v[1].y - v[1].x*v[3].y) > 0 then -- if the triangle is facing the camera, checks for CCW
                    screen_triangles[#screen_triangles + 1] = {
                        v1=v[1], v2=v[2], v3=v[3];
                        color = triangle_buffer[i].color;
                        depth = (1/3)*(v[1].z + v[2].z + v[3].z)
                    }

                    goto continue
                end
            end
        end

        -- Remove the triangle from 'triangle_buffer' if it's not in frustum.
        table.remove(triangle_buffer, i)
        ::continue::
    end

    -- painter's algorithm
    table.sort(screen_triangles,
        function(triangle1,triangle2)
            return triangle1.depth > triangle2.depth
        end
    )

    return screen_triangles
end

--#endregion Rendering



--#region QuadTree
Quad = function(centerX, centerY, size) return {
    centerX = centerX,
    centerY = centerY,
    size = size,
    quadrant = {}
} end

BoundaryCheck = function(root, table)
    local x_positive, y_positive = 0, 0
    for i = 1, 3 do
        x_positive = x_positive + (table[i].x >= root.centerX and 1 or 0)
        y_positive = y_positive + (table[i].y >= root.centerY and 1 or 0)
    end
    -- Returns: quadrant, x_positive, y_positive
    return (y_positive==3 and 1 or 3) + (x_positive==y_positive and 0 or 1), x_positive, y_positive
end


-- Specifically for triangles(3 point AABB). No duplicates in tree.
QuadTree = function(centerX, centerY, size) return {
    tree = Quad(centerX, centerY, size);

    -- Example: quadTree:insertTriangle(quadTree.tree, triangle)
    insertTriangle = function(self, root, triangle)
        local rootSize, quadrant, x_positive, y_positive = root.size, BoundaryCheck(root, triangle)

        -- if x|y_positive%3 is not 0 then the triangle is overlapping with other quadrants
        if x_positive%3 == 0 and y_positive%3 == 0 and rootSize > 20 then

            if root.quadrant[quadrant] then
                self:insertTriangle(root.quadrant[quadrant], triangle)
            else
                root.quadrant[quadrant] = Quad(
                    root.centerX + (x_positive==3 and rootSize or -rootSize),
                    root.centerY + (y_positive==3 and rootSize or -rootSize),
                    rootSize*0.5
                )
                self:insertTriangle(root.quadrant[quadrant], triangle)
            end

        else
            -- Triangle get a reference to the root it lies in and adds it to said root
            -- triangle.root = root     -- Only for "delaunay"
            root[#root + 1] = triangle
        end
    end;

    -- Bruteforce search the tree for matching triangle to remove.
    -- Example: quadTree:remove(quadTree.tree, {p1, p2, p3})
    searchAndRemove = function(self, root, vertices)
        for i = 1, #root do
            if root[i][1] == vertices[1] and root[i][2] == vertices[2] and root[i][3] == vertices[3] then
                return table.remove(root, i)
            end
        end

        -- Assuming child quad node exist.
        return self:searchAndRemove(root.quadrant[(BoundaryCheck(root, vertices))], vertices)
    end;

    -- Frustum cull the quadTree and add the triangles in visible quads to the 'triangle_buffer'.
    -- Later the 'WorldToScreen' function will remove triangles in 'triangle_buffer' which are not visible in frustum.
    -- https://web.archive.org/web/20030810032130/http://www.markmorley.com:80/opengl/frustumculling.html
    frustumCull = function(startRoot, cameraTransform, gps, triangle_buffer)
        local check_queue, full_in_view_queue, z, addToTraversalQueue = {startRoot}, {}, {},
            function(root, traversalQueue)
                -- If the distance from the camera to the center of a quad node is greater than 500^2 m
                -- and triangle_buffer is greater than the max_drawn_triangles amount then it will only add every third triangle of a quad node to the triangle_buffer,
                -- which is to get better performance while still able to slightly see in the distance when the amount triangles in view are high.
                for i = 1, #root, ((root.centerX-gps.x)^2 + (root.centerY-gps.y)^2<25E4 or #triangle_buffer<max_drawn_triangles) and 1 or 3 do
                    triangle_buffer[#triangle_buffer+1] = root[i]
                end

                -- If a quad child exist then add it to queue.
                for i = 1, 4 do
                    if root.quadrant[i] then
                        traversalQueue[#traversalQueue+1] = root.quadrant[i]
                    end
                end
            end

        for i = 1, 4 do
            z[i] = gps.z*cameraTransform[i+8]
        end

        while #check_queue > 0 do
            local root = table.remove(check_queue)
            local x, y, size = root.centerX, root.centerY, root.size*2

            -- If the camera is within the boundary of the quad XY then just add it as partially inside, else frustum check each corner of the quad node
            if math.abs(x-gps.x)<size and math.abs(y-gps.y)<size then
                addToTraversalQueue(root, check_queue)
            else

                local quadCorners, points_in_frustum, fully_inside, partially_inside = {
                    x + size, y + size,
                    x - size, y + size,
                    x - size, y - size,
                    x + size, y - size
                }, {}, true, true

                for i = 1, 7, 2 do
                    -- Reusing local variables 'x' & 'y'
                    x, y =
                        quadCorners[i]   - gps.x,
                        quadCorners[i+1] - gps.y

                    -- Reusing local var 'size' to hold a table.
                    -- Calculate transformed quadCorners coordinates to clip space.
                    -- All quad nodes has a height(z) of 0 and therefore precomputed by z[1-4].
                    size = {}
                    for j = 1, 4 do
                        size[j] = cameraTransform[j]*x + cameraTransform[j+4]*y - z[j]
                    end

                    -- Reusing local variables 'x' & 'y'
                    x, y = size[3] + cameraTransform[15], size[4]
                    x = {
                        -y<=size[1], size[1]<=y,    -- -W<=X, X<=W,
                        -y<=size[2], size[2]<=y,    -- -W<=Y, Y<=W,
                        0<=x, x<=y                  -- 0<=Z, Z<=W
                    }


                    for j = 1, 6 do
                        points_in_frustum[j] = (points_in_frustum[j] or 0) + (x[j] and 1 or 0)
                    end
                end

                for i = 1, 6 do
                    if points_in_frustum[i] == 0 then
                        -- If all the points are on the wrong side of one of the frustum planes, then it is fully out of view.
                        fully_inside, partially_inside = false, false
                        break
                    elseif points_in_frustum[i] ~= 4 then
                        -- For the quad node to be fully inside the frustum, then every point need to be on the right side of the frustum planes.
                        fully_inside = false
                    end
                end

                if fully_inside then
                    full_in_view_queue[#full_in_view_queue+1] = root
                elseif partially_inside then
                    addToTraversalQueue(root, check_queue)
                end

            end
        end

        while #full_in_view_queue > 0 do
            addToTraversalQueue( table.remove(full_in_view_queue), full_in_view_queue )
        end
    end;
} end
--#endregion QuadTree



--#region init
local point, cameraTransform_world, gps, vertices, quadTree, alpha = {}, {}, Vec3(), {}, QuadTree(0,0,1E5), 0
--#endregion init


--#region Triangle Handling
LIGHT_DIRECTION = Normalize(Vec3(0, 0.1, -1))

--[[ inlined 'color' to 'Triangle_add_remove'
Color = function(normal, triangle_vertices)
    local dot, verticesUnderWater, color =
        Dot(normal, LIGHT_DIRECTION),
        0, nil

    for i = 1, 3 do if triangle_vertices[i].z <= 0 then verticesUnderWater = verticesUnderWater + 1 end end

    if verticesUnderWater > 1 then
        color = {flat = Vec3(0,0,255), steep = Vec3(0,150,255)} -- water
    else
        color = {flat = Vec3(0,255,0), steep = Vec3(255,200,0)} -- ground
    end

    -- Squaring to get absolute value and better curve
    dot = dot*dot
    return Scale( Add(Scale(color.flat, dot), Scale(color.steep, 1-dot)), dot*dot*0.9 + 0.1 )
end
--]]

Triangle_add_remove = function(tri, bool_index)
    -- 'tri' parameter == {v1_id, v2_id, v3_id}
    tri = {vertices[tri[1]], vertices[tri[2]], vertices[tri[3]]}
    -- Triangles have a CCW winding order.

    if input.getBool(bool_index) then
        --#region triangle.color
        local dot, verticesUnderWater, color =
            Dot(Normalize( Cross(Sub(tri[1],tri[2]), Sub(tri[2],tri[3])) ), LIGHT_DIRECTION)^2, -- dot is squared to get absolute value and better curve
            0, nil

        for i = 1, 3 do if tri[i].z <= 0 then verticesUnderWater = verticesUnderWater + 1 end end

        if verticesUnderWater > 1 then
            color = {flat = Vec3(0,0,255), steep = Vec3(0,150,255)} -- water
        else
            color = {flat = Vec3(0,255,0), steep = Vec3(255,200,0)} -- ground
        end

        tri.color = Scale( Add(Scale(color.flat, dot), Scale(color.steep, 1-dot)), dot*dot*0.9 + 0.1 )
        --#endregion triangle.color

        quadTree:insertTriangle(quadTree.tree, tri)
    else
        quadTree:searchAndRemove(quadTree.tree, tri)
    end
end
--#endregion Triangle Handling



function onTick()
    renderOn = input.getBool(1)
    clear = input.getBool(2)

    if clear then
        vertices, quadTree = {}, QuadTree(gps.x, gps.y, 5E4)
        triangle_buffer, frameCount = {}, 1
    end


    if renderOn then
        for i = 1, 12 do
            cameraTransform_world[i] = input.getNumber(i)
        end
        cameraTransform_world[15] = input.getNumber(13)
        gps = Vec3(input.getNumber(14), input.getNumber(15), input.getNumber(16))


        -- Get and try add point
        point = Vec3(input.getNumber(17), input.getNumber(18), input.getNumber(19))
        if point.x ~= 0 and point.y ~= 0 then
            local id = #vertices+1
            vertices[id] = point
            point.id = id
        end

        -- Get color alpha
        alpha = input.getNumber(20)

        -- Get triangles
        for i = 0, 3 do
            local t1, t2, temp = {}, {}, 0

            for j = 1, 3 do
                -- Inlined uint16_to_int32()
                -- t1[j], t2[j] = uint16_to_int32(input.getNumber(20 + i*3 + j))
                temp = ('I'):unpack(('f'):pack(input.getNumber(20 + i*3 + j)))
	            t1[j], t2[j] = temp>>16, temp&0xffff
            end

            temp = i*2 + 3

            if t1[1] == 0 then
                break
            elseif t2[1] == 0 then
                Triangle_add_remove(t1, temp)
                break
            end

            Triangle_add_remove(t1, temp)
            Triangle_add_remove(t2, temp+1)
        end

    end
end


function onDraw()

    if renderOn then
        local setColor, drawTriangleF, triangles =
            screen.setColor,
            screen.drawTriangleF,
            WorldToScreen(vertices, quadTree, cameraTransform_world, gps)

        triangles_drawStartIndex = math.max(#triangles+1-max_drawn_triangles, 1)

        for i = triangles_drawStartIndex, #triangles do
            local triangle = triangles[i]

            setColor(triangle.color.x, triangle.color.y, triangle.color.z)

            drawTriangleF(triangle.v1.x, triangle.v1.y, triangle.v2.x, triangle.v2.y, triangle.v3.x, triangle.v3.y)
        end

        setColor(0,0,0,255-alpha)
        screen.drawRectF(0,0,w,h)


        -- [[ debug
        setColor(255,255,255,125)
        screen.drawText(0,140, "A "..alpha)
        screen.drawText(0,150, "Tri "..#triangles+1-triangles_drawStartIndex)
        -- ]]
    end
end

