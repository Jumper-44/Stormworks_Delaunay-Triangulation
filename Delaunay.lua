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





--#region readme
--[[
Recieves cameraTransform_world and laserPos from "CameraTransform.lua" script

This does the delaunay triangulation and 3d render

The triangulation is O(n*n) time complexity
See the delaunay triangulation in browser with touchscreen https://lua.flaffipony.rocks/?id=IDyvZ6wC8P
--]]
--#endregion readme

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

WorldToScreen = function(vertex_buffer, vertices, triangles, cameraTransform)
    local tri = {}

    for i=1, #vertices do
        local x,y,z = vertices[i].x, vertices[i].y, vertices[i].z

        local X,Y,Z,W =
            cameraTransform[1]*x + cameraTransform[5]*y + cameraTransform[9]*z + cameraTransform[13],
            cameraTransform[2]*x + cameraTransform[6]*y + cameraTransform[10]*z + cameraTransform[14],
            cameraTransform[3]*x + cameraTransform[7]*y + cameraTransform[11]*z + cameraTransform[15],
            cameraTransform[4]*x + cameraTransform[8]*y + cameraTransform[12]*z + cameraTransform[16]

        if (0<=Z and Z<=W) then --clip and discard points       -- (-W<=X and X<=W) and (-W<=Y and Y<=W) and (0<=Z and Z<=W)
            local w = 1/W
            vertex_buffer[i] = {
                x = X*w*cx+SCREEN.centerX, y = Y*w*cy+SCREEN.centerY, z = Z*w,
                isIn = (-W<=X and X<=W) and (-W<=Y and Y<=W)
            }
        else -- x & y are screen coordinates, z is depth
            vertex_buffer[i] = false
        end
    end

    for i=1, #triangles do
        local triangle = triangles[i]
        local v1,v2,v3 = vertex_buffer[triangle[1].id], vertex_buffer[triangle[2].id], vertex_buffer[triangle[3].id]

        if v1 and v2 and v3 then -- if all vertices are within the near and far plane
            if v1.isIn or v2.isIn or v3.isIn then -- if atleast 1 visible vertex
                if (v1.x*v2.y - v2.x*v1.y + v2.x*v3.y - v3.x*v2.y + v3.x*v1.y - v1.x*v3.y) > 0 then -- if the triangle is facing the camera, checks for CCW
                    tri[#tri + 1] = {
                        v1=v1, v2=v2, v3=v3;
                        color = triangle.color;
                        depth = (1/3)*(v1.z + v2.z + v3.z)
                    }
                end
            end
        end
    end

    -- painter's algorithm
    table.sort(tri,
        function(triangle1,triangle2)
            return triangle1.depth > triangle2.depth
        end
    )

    return tri
end
--#endregion Rendering

--#region QuadTree
local Quad = function(centerX, centerY, size) return {
        centerX = centerX,
        centerY = centerY,
        size = size,
        quadrant = {}
} end

--[[
local isPointInTriangle = function(s, a, b, c)
    local as_x, as_y, s_ab =
        s.x - a.x,
        s.y - a.x,
        nil

    s_ab = (b.x - a.x) * as_y - (b.y - a.y) * as_x > 0

    if ((c.x - a.x) * as_y - (c.y - a.y) * as_x > 0 == s_ab) then return false end
    if ((c.x - b.x) * (s.y - b.y) - (c.y - b.y)*(s.x - b.x) > 0 ~= s_ab) then return false end

    return true
end
--]]

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
    end
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

local Color = function(normal, vertices)
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


local Point, Triangle =
-- Point Class
    function(x,y,z,id) return {
        x=x; y=y; z=z or 0; id=id or 0
    } end,

-- Triangle Class
    function(p1,p2,p3, ...)
        local normal = Normalize( Cross(Sub(p1,p2), Sub(p2,p3)) )
        local CCW = normal.z < 0

    return {
        p1;
        CCW and p2 or p3;
        CCW and p3 or p2;
        circle = GetCircumCircle(p1,p2,p3);
        color = Color(normal, {p1,p2,p3});
        neighbor = {...};
    --  root = nil;
    } end

Delaunay = function(centerX, centerY, size)
    local vertices, quadTree =
        {},
        QuadTree(centerX, centerY, size)

    quadTree:insert(quadTree.tree, Triangle(Point(-9E5,-9E5), Point(9E5,-9E5), Point(0,9E5), false,false,false))

    return {
    vertices = vertices;
    n_vertices = 0;
    quadTree = quadTree;

    triangulate = function(self)
        local end_pos = #vertices

        for i = end_pos-(end_pos - self.n_vertices) + 1, end_pos do
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

                            for k = 1, 3 do
                                if currentTriangle == currentNeighbor.neighbor[k] then
                                    currentNeighbor.neighbor[k] = new_triangle
                                    break
                                end
                            end
                        end
                    elseif currentNeighbor == false then
                        new_triangles[#new_triangles + 1] = Triangle(
                            currentVertex,
                            currentTriangle[j],
                            currentTriangle[j%3 + 1],

                            nil, false
                        )
                    end

                    -- Removes reference to other tables/triangles, so garbagecollection can collect
                    -- Also currently the same triangle can be added to the queue more than one time, so it only process its neighbor once.
                    currentTriangle.neighbor[j] = nil
                end

                -- Remove triangle from quadTree and queue and update 'id'
                quadTree.remove(currentTriangle.root, currentTriangle)
                table.remove(triangle_check_queue, id)
                id = #triangle_check_queue
            end


            -- Added references to new neighboring triangles
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

        self.n_vertices = end_pos
    end
} end
--#endregion Delaunay


--#region init
local delaunay, cameraTransform_world, point, alpha, vertex_buffer =
    Delaunay(), -- delaunay
    {}, -- cameraTransform_world
    {}, -- point
    0, -- alpha
    {} -- vertex_buffer
--#endregion init

function onTick()
    renderOn = input.getBool(1)
    if input.getBool(2) then -- Clear scan
        delaunay = Delaunay()
    end

    if renderOn then
        -- Get cameraTransform
        for i = 1, 16 do
            cameraTransform_world[i] = input.getNumber(i)
        end

        alpha = input.getNumber(32)


        point = {input.getNumber(17), input.getNumber(18), input.getNumber(19)}

        if point[1] ~= 0 and point[2] ~= 0 then
            delaunay.vertices[#delaunay.vertices + 1] = Point( table.unpack(point) )
            delaunay:triangulate()
        end

    end
end

function onDraw()

    if renderOn then

        local setColor, drawTriangleF, drawTriangle, currentDrawnTriangles =
            screen.setColor,
            screen.drawTriangleF,
            screen.drawTriangle,
            0

        --#region drawTriangle
        if #delaunay.triangles > 0 then
            local triangles = WorldToScreen(vertex_buffer, delaunay.vertices, delaunay.triangles, cameraTransform_world)

            for i = 1, #triangles do
                local triangle = triangles[i]

                setColor(triangle.color.x, triangle.color.y, triangle.color.z)

                drawTriangleF(triangle.v1.x, triangle.v1.y, triangle.v2.x, triangle.v2.y, triangle.v3.x, triangle.v3.y)

                currentDrawnTriangles = currentDrawnTriangles + 1
            end

            setColor(0,0,0,255-alpha)
            screen.drawRectF(0,0,w,h)
        end
        --#endregion drawTriangle

        setColor(255,255,255,125)
        screen.drawText(0,130,"Alpha: "..alpha)
        screen.drawText(0,140,"#Triangles: "..#delaunay.triangles)
        screen.drawText(0,150,"#DrawTriangles: "..currentDrawnTriangles)
    end
end