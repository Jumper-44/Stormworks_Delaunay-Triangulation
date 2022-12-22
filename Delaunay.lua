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
    simulator:setScreen(1, "9x5")
    simulator:setProperty("ExampleNumberProperty", 123)

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
        else
            simulator:setInputNumber(11, 0)
            simulator:setInputNumber(12, 0)
        end
        _isTouched = screenConnection.isTouched

        -- NEW! button/slider options from the UI
        simulator:setInputBool(31, simulator:getIsClicked(1))       -- if button 1 is clicked, provide an ON pulse for input.getBool(31)
        simulator:setInputNumber(31, simulator:getSlider(1))        -- set input 31 to the value of slider 1

        simulator:setInputBool(32, simulator:getIsToggled(2))       -- make button 2 a toggle, for input.getBool(32)
        simulator:setInputNumber(32, simulator:getSlider(2) * 50)   -- set input 32 to the value from slider 2 * 50
    end;
end
---@endsection


--[====[ IN-GAME CODE ]====]





--#region readme
--[[
Recieves laserPos from "CameraTransform.lua" script

This does the delaunay triangulation
--]]
--#endregion readme

--#region Conversion
-- Bitwise operations can only be done to integers, but also need to send the numbers as float when sending from script to script as Stormworks likes it that way.
local function int32_to_uint16(a, b) -- Takes 2 int32 and converts them to uint16 residing in a single number
	return (('f'):unpack(('I'):pack( ((a&0xffff)<<16) | (b&0xffff)) ))
end

--[[
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

--#region QuadTree
local Quad = function(centerX, centerY, size) return {
        centerX = centerX,
        centerY = centerY,
        size = size,
        quadrant = {}
} end

-- Specifically for triangles(3 point AABB) in which none overlaps(2.5d triangle mesh). No duplicates in tree.
local QuadTree = function(centerX, centerY, size) return {
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
            triangle.root = root
            root[#root + 1] = triangle
        end
    end;

    -- Finds the first triangle in which the point lies within the circumcircle and returns reference to triangle
    search = function(self, root, point)
        for i = 1, #root do
            local dx, dy =
                root[i].circle.x - point.x,
                root[i].circle.y - point.y

            if dx * dx + dy * dy <= root[i].circle.r then
                return root[i]
            end
        end

        local quadrant = (point.y>=root.centerY and 1 or 3) + ((point.x>=root.centerX)==(point.y>=root.centerY) and 0 or 1)

        if root.quadrant[quadrant] then
           return self:search(root.quadrant[quadrant], point)
        end
    end;

    -- The root the triangle lies in and the triangle itself
    remove = function(root, triangle)
        for i = 1, #root do
            if root[i] == triangle then
                table.remove(root, i)
                break
            end
        end
    end;
} end
--#endregion QuadTree

--#region Delaunay
local GetCircumCircle = function(a,b,c)
    local dx_ab, dy_ab, dx_ac, dy_ac =
        b.x - a.x,
        b.y - a.y,
        c.x - a.x,
        c.y - a.y

    local b_len_squared, c_len_squared, d =
        dx_ab * dx_ab + dy_ab * dy_ab,
        dx_ac * dx_ac + dy_ac * dy_ac,
        0.5 / (dx_ab * dy_ac - dy_ab * dx_ac)

    local dx,dy =
        (dy_ac * b_len_squared - dy_ab * c_len_squared) * d,
        (dx_ab * c_len_squared - dx_ac * b_len_squared) * d

    return {
        x = a.x + dx,
        y = a.y + dy,
        r = dx*dx + dy*dy -- r squared
    }
end

-- Point Class
local Point = function(x,y,z,id) return {
    x=x; y=y; z=z or 0; id=id or 0
} end

-- Triangle Class
local Triangle = function(p1,p2,p3, n1,n2,n3)
    local normal = Normalize( Cross(Sub(p1,p2), Sub(p2,p3)) )
    local CCW = normal.z < 0

return {
    p1;
    CCW and p2 or p3;
    CCW and p3 or p2;
    circle = GetCircumCircle(p1,p2,p3);
    neighbor = {n1,n2,n3};
--  root = nil;
} end

local Delaunay = function(centerX, centerY, size)
    local vertices, actions_log, quadTree =
        {n_vertices = 0},
        {},
        QuadTree(centerX, centerY, size)

    quadTree:insert(quadTree.tree, Triangle(Point(-9E5,-9E5), Point(9E5,-9E5), Point(0,9E5), false,false,false))

    return {
    vertices = vertices;
    actions_log = actions_log; -- Don't care about triangles if any of the vertices is from the super triangle
    quadTree = quadTree;

    triangulate = function()
        local end_pos = #vertices

        for i = end_pos-(end_pos - vertices.n_vertices) + 1, end_pos do
            local currentVertex = vertices[i]
            local new_triangles, triangle_check_queue, id = {}, {quadTree:search(quadTree.tree, currentVertex)}, 1

            currentVertex.id = i

            -- Depends on CCW winding order for the triangles.
            while id > 0 do
                local currentTriangle = triangle_check_queue[id]

                for j = 1, 3 do
                    local currentNeighbor = currentTriangle.neighbor[j]

                    if currentNeighbor then
                        local dx,dy =
                            currentNeighbor.circle.x - currentVertex.x,
                            currentNeighbor.circle.y - currentVertex.y

                        if dx * dx + dy * dy <= currentNeighbor.circle.r then
                            for k = 1, 3 do
                                -- If neighboring triangle don't have a reference to current, then the neigboring triangle has already been checked, and won't be added to queue again
                                if currentTriangle == currentNeighbor.neighbor[k] then
                                    triangle_check_queue[#triangle_check_queue + 1] = currentNeighbor
                                    currentNeighbor.neighbor[k] = nil
                                    break
                                end
                            end
                        else
                            local new_triangle = Triangle(
                                currentVertex,
                                currentTriangle[j],
                                currentTriangle[j%3 + 1],

                                nil, currentNeighbor
                            )

                            new_triangles[#new_triangles + 1] = new_triangle
                            if new_triangle[1].id ~= 0 and new_triangle[2].id ~= 0 and new_triangle[3].id ~= 0 then
                                table.insert(actions_log, 1, {new_triangle, true})
                            end

                            for k = 1, 3 do
                                if currentTriangle == currentNeighbor.neighbor[k] then
                                    currentNeighbor.neighbor[k] = new_triangle
                                    break
                                end
                            end
                        end
                    elseif currentNeighbor == false then
                        local new_triangle = Triangle(
                            currentVertex,
                            currentTriangle[j],
                            currentTriangle[j%3 + 1],

                            nil, false
                        )

                        new_triangles[#new_triangles + 1] = new_triangle
                        if new_triangle[1].id ~= 0 and new_triangle[2].id ~= 0 and new_triangle[3].id ~= 0 then
                            table.insert(actions_log, 1, {new_triangle, true})
                        end
                    end

                    -- Removes reference to other tables/triangles, so garbagecollection can collect (Not sure if neccecary for GB)
                    -- Also currently the same triangle can be added to the queue more than one time, so it only process its neighbor once.
                    currentTriangle.neighbor[j] = nil
                end

                -- Remove triangle from quadTree and queue and update 'id'
                quadTree.remove(currentTriangle.root, currentTriangle)

                if currentTriangle[1].id ~= 0 and currentTriangle[2].id ~= 0 and currentTriangle[3].id ~= 0 then
                    table.insert(actions_log, 1, {currentTriangle, false})
                end

                table.remove(triangle_check_queue, id)
                id = #triangle_check_queue
            end


            -- Adding references to new neighboring triangles
            -- Comparing every triangle to every other triangle in 'new_triangles',
            -- in which to only compare a to b, and not a to b && b to a, then a for loop is arranged that does so,
            -- but the way it is structured then the last index of 'new_triangles' will not be added to the quadtree, so adding the last index right here.
            quadTree:insert(quadTree.tree, new_triangles[#new_triangles])

            for j = 1, #new_triangles - 1 do
                local currentTri = new_triangles[j]
                quadTree:insert(quadTree.tree, currentTri)

                for k = j + 1, #new_triangles do
                    local otherTri = new_triangles[k]

                    if currentTri[2] == otherTri[3] then
                        currentTri.neighbor[1] = otherTri
                        otherTri.neighbor[3] = currentTri
                    elseif currentTri[3] == otherTri[2] then
                        currentTri.neighbor[3] = otherTri
                        otherTri.neighbor[1] = currentTri
                    end
                end
            end

        end

        vertices.n_vertices = end_pos
    end
} end
--#endregion Delaunay


--#region init
local delaunay, point =
    Delaunay(0,0, 1E5),
    {}
--#endregion init

function onTick()
    --#region Get & pass though

    -- Get & Pass through renderOn & clear
    renderOn = input.getBool(1)
    clear = input.getBool(2)
    output.setBool(1, renderOn)
    output.setBool(2, clear)

    -- Get & Pass through laserPos
    point = {input.getNumber(17), input.getNumber(18), input.getNumber(19)}
    for i = 1, 3 do output.setNumber(i+16, point[i]) end

    -- Pass though cameratransform
    for i = 1, 16 do output.setNumber(i, input.getNumber(i)) end

    -- Pass though color alpha
    output.setNumber(20, input.getNumber(20))

    --#endregion Get & pass though


    if clear then
        -- Probably memory leak, can't garbagecollect tables that references each other(?)
        delaunay = Delaunay(0,0, 1E5)
    end


    if renderOn then

        if point[1] ~= 0 and point[2] ~= 0 then
            delaunay.vertices[#delaunay.vertices + 1] = Point( point[1], point[2], point[3] )
            delaunay.triangulate()
        end

        for i = 0, 3 do
            local id = #delaunay.actions_log

            if id > 0 then
                if id == 1 then
                    for j = 1, 3 do
                        output.setNumber(20 + i*3 + j, int32_to_uint16(delaunay.actions_log[id][1][j].id, 0))
                    end
                    output.setBool(i*2 + 3, delaunay.actions_log[id][2])
                    delaunay.actions_log[id] = nil
                else
                    for j = 1, 3 do
                        output.setNumber(20 + i*3 + j, int32_to_uint16(delaunay.actions_log[id][1][j].id, delaunay.actions_log[id-1][1][j].id))
                    end
                    output.setBool(i*2 + 3, delaunay.actions_log[id][2])
                    output.setBool(i*2 + 4, delaunay.actions_log[id-1][2])
                    delaunay.actions_log[id] = nil
                    delaunay.actions_log[id-1] = nil
                end
            else
                -- Clear the rest of the triangle output when #delaunay.actions_log is 0
                for j = 21 + i*3, 32 do output.setNumber(j, 0) end
                break
            end
        end
    end
end
