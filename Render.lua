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
local function S_H_fp(a, b) -- 2 Single Float Conversion To Half Float residing in a float.
    local function convert(f)
        local epsilon = .000031
        if f<epsilon and f>-epsilon then return 0 end

        f = ('I'):unpack(('f'):pack(f))

        return ((f>>16)&0x8000)|((((f&0x7f800000)-0x38000000)>>13)&0x7c00)|((f>>13)&0x03ff)
    end

    return (('f'):unpack(('I'):pack( convert(a)<<16 | convert(b) )))
end
--]]

--[[ Using H_S_fp, but have it inlined to reduce chars - only used once
local function H_S_fp(x) -- Half Float Conversion To Single Float.
    local function convert(h)
        return ('f'):unpack(('I'):pack(((h&0x8000)<<16) | (((h&0x7c00)+0x1C000)<<13) | ((h&0x03FF)<<13)))
    end
    x = ('I'):unpack(('f'):pack(x))
    return convert(x>>16), convert(x)
end
--]]

-- Visualizer for the usable size range of 16bit floats.
-- https://observablehq.com/@rreusser/half-precision-floating-point-visualized

--[[
local function int32_to_uint16(a, b) -- Takes 2 int32 and converts them to uint16 residing in a single number
	return (('f'):unpack(('I'):pack( ((a&0xffff)<<16) | (b&0xffff)) ))
end
--]]

--[[ Using uint16_to_int32, but have it inlined to reduce chars - only used once
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

local Len = function(a) return Dot(a,a)^.5 end
local Normalize = function(a) return Scale(a, 1/Len(a)) end
--#endregion vec3

--#region Rendering
w,h = 160,160 -- Screen Pixels
local cx,cy = w/2,h/2
local SCREEN, LIGHT_DIRECTION =
    {centerX = cx, centerY = cy},
    Normalize(Vec3(0, 0.1, -1))

WorldToScreen = function(vertices, quadTree, cameraTransform)
    local triangles_in_frustum, screen_triangles, vertex_buffer = {}, {}, {}
    quadTree.frustumCull(quadTree.tree, cameraTransform, triangles_in_frustum)

    for i = 1, #triangles_in_frustum do
        local currentTriangle, v = triangles_in_frustum[i], {}
        for j = 1, 3 do
            local id = currentTriangle[j].id
            if vertex_buffer[id] == nil then

                local x,y,z = vertices[id].x, vertices[id].y, vertices[id].z

                local X,Y,Z,W =
                    cameraTransform[1]*x + cameraTransform[5]*y + cameraTransform[9]*z + cameraTransform[13],
                    cameraTransform[2]*x + cameraTransform[6]*y + cameraTransform[10]*z + cameraTransform[14],
                    cameraTransform[3]*x + cameraTransform[7]*y + cameraTransform[11]*z + cameraTransform[15],
                    cameraTransform[4]*x + cameraTransform[8]*y + cameraTransform[12]*z + cameraTransform[16]

                if (0<=Z and Z<=W) then --clip and discard points       -- (-W<=X and X<=W) and (-W<=Y and Y<=W) and (0<=Z and Z<=W)
                    local w = 1/W
                    v[j] = {
                        x = X*w*cx+SCREEN.centerX, y = Y*w*cy+SCREEN.centerY, z = Z*w,
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
                        color = currentTriangle.color;
                        depth = (1/3)*(v[1].z + v[2].z + v[3].z)
                    }
                end
            end
        end
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
local Quad = function(centerX, centerY, size) return {
    centerX = centerX,
    centerY = centerY,
    size = size,
    quadrant = {}
} end

-- Specifically for triangles in which none overlaps. No duplicates in tree. Not normal quad boundary checking.
QuadTree = function(centerX, centerY, size) return {
    tree = Quad(centerX, centerY, size);

    -- Example: quadTree:insert(quadTree.tree, triangle)
    insert = function(self, root, triangle)
        local x_positive, y_positive, rootSize = 0, 0, root.size

        -- Checking boundary for each vertex
        for i = 1, 3 do
            if triangle[i].x >= root.centerX then x_positive = x_positive + 1 end
            if triangle[i].y >= root.centerY then y_positive = y_positive + 1 end
        end

        -- if x|y_positive%3 is not 0 then the triangle is overlapping with other quadrants
        if x_positive%3 == 0 and y_positive%3 == 0 and rootSize > 20 then
            local quadrant = (y_positive==3 and 1 or 3) + (x_positive==y_positive and 0 or 1)

            if root.quadrant[quadrant] then
                self:insert(root.quadrant[quadrant], triangle)
            else
                root.quadrant[quadrant] = Quad(
                    root.centerX + (x_positive==3 and rootSize or -rootSize),
                    root.centerY + (y_positive==3 and rootSize or -rootSize),
                    rootSize*0.5
                )
                self:insert(root.quadrant[quadrant], triangle)
            end

        else
            -- Triangle get a reference to the root it lies in and adds it to said root
            --triangle.root = root
            root[#root + 1] = triangle
        end
    end;

    -- Example: quadTree:remove(quadTree.tree, {p1, p2, p3})
    searchAndRemove = function(self, root, vertices)
        for i = 1, #root do
            if root[i][1] == vertices[1] then
                if root[i][2] == vertices[2] then
                    if root[i][3] == vertices[3] then
                        table.remove(root, i)
                        return
                    end
                end
            end
        end

        local x_positive, y_positive = 0, 0

        -- Checking boundary for each vertex
        for i = 1, 3 do
            if vertices[i].x >= root.centerX then x_positive = x_positive + 1 end
            if vertices[i].y >= root.centerY then y_positive = y_positive + 1 end
        end

        return self:searchAndRemove(root.quadrant((y_positive==3 and 1 or 3) + (x_positive==y_positive and 0 or 1)), vertices)
    end;

    frustumCull = function(startRoot, cameraTransform, triangle_buffer)
        local check_queue, full_in_view, id = {startRoot}, {}, 1

        while id > 0 do
            local root = check_queue[id]
            local x, y, size, points_in = root.centerX, root.centerY, root.size, 0
            local quadCorners = {
                {x + size, y + size},
                {x - size, y + size},
                {x - size, y - size},
                {x + size, y - size},
            }

            for i = 1, 4 do
                local X,Z,W =
                    cameraTransform[1]*quadCorners[i][1] + cameraTransform[5]*quadCorners[i][2] + cameraTransform[13],
                --  cameraTransform[2]*quadCorners[i][1] + cameraTransform[6]*quadCorners[i][2] + cameraTransform[14],
                    cameraTransform[3]*quadCorners[i][1] + cameraTransform[7]*quadCorners[i][2] + cameraTransform[15],
                    cameraTransform[4]*quadCorners[i][1] + cameraTransform[8]*quadCorners[i][2] + cameraTransform[16]

                if -W<=X and X<=W and 0<=Z and Z<=W then
                    points_in = points_in + 1
                end
            end

            if points_in == 4 then
                full_in_view[#full_in_view+1] = root
            elseif points_in > 0 then
                for i = 1, #root do
                    triangle_buffer[#triangle_buffer+1] = root[i]
                end
                for i = 1, 4 do
                    if root.quadrant[i] then
                        check_queue[#check_queue+1] = root.quadrant[i]
                    end
                end
            end

            table.remove(check_queue, id)
            id = #check_queue
        end

        id = #full_in_view
        while id > 0 do
            local root = full_in_view[id]
            for i = 1, #root do
                triangle_buffer[#triangle_buffer+1] = root[i]
            end
            for i = 1, 4 do
                if root.quadrant[i] then
                    full_in_view[#full_in_view+1] = root.quadrant[i]
                end
            end
            table.remove(full_in_view, id)
            id = #full_in_view
        end
    end
} end
--#endregion QuadTree

--#region Triangle Handling
Color = function(normal, vertices)
    local dot, verticesUnderWater, color =
        Dot(normal, LIGHT_DIRECTION),
        0, nil

    for i = 1, 3 do if vertices[i].z <= 0 then verticesUnderWater = verticesUnderWater + 1 end end

    if verticesUnderWater > 1 then
        color = {flat = Vec3(0,0,255), steep = Vec3(0,150,255)} -- water
    else
        color = {flat = Vec3(0,255,0), steep = Vec3(255,200,0)} -- ground
    end

    dot = dot*dot
    return Scale( Add(Scale(color.flat, dot), Scale(color.steep, 1-dot)), dot*dot*0.9 + 0.1 )
end

--[[ Point Class is substituted by Vec3()
local Point = function(x,y,z) return {
    x=x; y=y; z=z or 0; --id=id or 0
} end
]]

-- Triangle Class
Triangle = function(p1,p2,p3) return {
    p1;
    p2; -- Triangle should be CCW winding order
    p3;
    color = Color(Normalize( Cross(Sub(p1,p2), Sub(p2,p3)) ), {p1,p2,p3});
--  root = nil;
} end

Triangle_add_rem = function(vertices, quadTree, t, i)
    if input.getBool(i) then
        quadTree:insert(quadTree.tree, Triangle(vertices[t[1]], vertices[t[2]], vertices[t[3]]))
    else
        quadTree:searchAndRemove(quadTree.tree, {vertices[t[1]], vertices[t[2]], vertices[t[3]]})
    end
end
--#endregion Triangle Handling


--#region init
local point, cameraTransform_world, vertices, quadTree, alpha = {}, {}, {}, QuadTree(0,0,1E5), 0
--#endregion init


function onTick()
    renderOn = input.getBool(1)
    clear = input.getBool(2)

    if clear then
        vertices, quadTree = {}, QuadTree(0,0,1E5)
    end


    if renderOn then
        -- Get cameratransform
        for i = 1, 6 do
            -- inlined H_S_fp()
            -- cameraTransform_world[(i-1)*2 + 1], cameraTransform_world[(i-1)*2 + 2] = H_S_fp(input.getNumber(i))
            local convert, temp = function(h)
                return ('f'):unpack(('I'):pack(((h&0x8000)<<16) | (((h&0x7c00)+0x1C000)<<13) | ((h&0x03FF)<<13)))
            end, ('I'):unpack(('f'):pack(input.getNumber(i)))
            cameraTransform_world[(i-1)*2 + 1], cameraTransform_world[(i-1)*2 + 2] = convert(temp>>16), convert(temp)
        end
        for i = 1, 4 do
            cameraTransform_world[i+12] = input.getNumber(i+6)
        end


        -- Get and try add point
        point = Vec3(input.getNumber(11), input.getNumber(12), input.getNumber(13))
        if point.x ~= 0 and point.y ~= 0 then
            local id = #vertices + 1
            vertices[id] = point
            point.id = id
        end

        alpha = input.getNumber(14)

        -- Get triangles
        local t1, t2, temp = {}, {}, 0
        for i = 0, 5 do
            for j = 1, 3 do
                -- inlined uint16_to_int32()
                -- t1[j], t2[j] = uint16_to_int32(input.getNumber(14 + i*3 + j))
                temp = ('I'):unpack(('f'):pack(input.getNumber(14 + i*3 + j)))
                t1[j], t2[j] = temp>>16, temp&0xffff
            end

            if t1[1] == 0 then
                break
            elseif t2[1] == 0 then
                Triangle_add_rem(vertices, quadTree, t1, i*2 + 3)
                break
            end

            Triangle_add_rem(vertices, quadTree, t1, i*2 + 3)
            Triangle_add_rem(vertices, quadTree, t2, i*2 + 4)
        end



    end
end


function onDraw()

    if renderOn then

        local setColor, drawTriangleF, currentDrawnTriangles =
            screen.setColor,
            screen.drawTriangleF,
            0

        --#region drawTriangle
        local triangles = WorldToScreen(vertices, quadTree, cameraTransform_world)

        for i = 1, #triangles do
            local triangle = triangles[i]

            setColor(triangle.color.x, triangle.color.y, triangle.color.z)

            drawTriangleF(triangle.v1.x, triangle.v1.y, triangle.v2.x, triangle.v2.y, triangle.v3.x, triangle.v3.y)

            currentDrawnTriangles = currentDrawnTriangles + 1
        end

        setColor(0,0,0,255-alpha)
        screen.drawRectF(0,0,w,h)
        --#endregion drawTriangle

        setColor(255,255,255,125)
        screen.drawText(0,130,"Alpha: "..alpha)
        screen.drawText(0,150,"#DrawTriangles: "..currentDrawnTriangles)
    end
end

