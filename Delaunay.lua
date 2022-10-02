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





--#region readme
--[[
Recieves cameraTransform_world and laserPos from "CameraTransform.lua" script

This does the delaunay triangulation and 3d render

The triangulation is O(n*n) time complexity
See the triangulation in browser with touchscreen https://lua.flaffipony.rocks/?id=IDyvZ6wC8P
--]]
--#endregion readme

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
Point = function(x,y,z,id) return {
    x=x; y=y, z=z or 0; id=id or 0
} end

-- Triangle Class
Triangle = function(p1,p2,p3) return {
    v1=p1; v2=p2; v3=p3;

    circle = GetCircumCircle(p1,p2,p3)
} end

local Delaunay = function() return {
    trianglesMesh = {}; --CalcMesh() will populate this

    vertices = {};
    n_vertices = 0;

    triangles = { Triangle(Point(-9E5,-9E5), Point(9E5,-9E5), Point(0,9E5)) }; -- Supertriangle

    Triangulate = function(self)
        local end_pos = #self.vertices

        for i = end_pos-(end_pos - self.n_vertices) + 1, end_pos do
            local edges, currentVertex = {}, self.vertices[i]
            currentVertex.id = i

            for j = #self.triangles, 1, -1 do
                local currentTriangle = self.triangles[j]

                local dx,dy =
                    currentTriangle.circle.x - currentVertex.x,
                    currentTriangle.circle.y - currentVertex.y

                if dx * dx + dy * dy <= currentTriangle.circle.r then
                    edges[#edges + 1] = {p1=currentTriangle.v1, p2=currentTriangle.v2}
                    edges[#edges + 1] = {p1=currentTriangle.v2, p2=currentTriangle.v3}
                    edges[#edges + 1] = {p1=currentTriangle.v3, p2=currentTriangle.v1}
                    table.remove(self.triangles, j)
                end
            end

            for j = #edges - 1, 1, -1 do
                for k = #edges, j + 1, -1 do

                    if edges[j] and edges[k] and
                    ((edges[j].p1 == edges[k].p1 and edges[j].p2 == edges[k].p2)
                    or (edges[j].p1 == edges[k].p2 and edges[j].p2 == edges[k].p1))
                    then
                        table.remove(edges, j)
                        table.remove(edges, k-1)
                    end

                end
            end

            for j = 1, #edges do
                local n = #self.triangles
                self.triangles[n + 1] = Triangle(edges[j].p1, edges[j].p2, self.vertices[i])
            end
        end

        self.n_vertices = end_pos
    end;

    CalcMesh = function(self) -- The step to remove the triangles which shares a vertex with the Supertriangle
        self.trianglesMesh = {}

        for i = 2, #self.triangles do
            if not (
                self.triangles[i].v1.id == 0 or
                self.triangles[i].v2.id == 0 or
                self.triangles[i].v3.id == 0 )
            then
                self.trianglesMesh[#self.trianglesMesh+1] =  self.triangles[i]
            end
        end
    end

} end
--#endregion Delaunay

--#region kdtree
dist2 = function(a,b)
    local sum, dis = 0, 0
    for i = 1, #a do
        dis = a[i]-b[i]
        sum = sum + dis*dis
    end
    return sum
end

closest = function(left, right, point)
    if left == nil then return right end
    if right == nil then return left end

    local d1,d2 =
        dist2(left.point, point),
        dist2(right.point, point)

    if (d1 < d2) then
        return left, d1
    else
        return right, d2
    end
end

--https://youtu.be/Glp7THUpGow || https://bitbucket.org/StableSort/play/src/master/src/com/stablesort/kdtree/KDTree.java
--https://www.geeksforgeeks.org/k-dimensional-tree/
New_KDTree = function(k) return {
    k = k;
    tree = {};

    insert = function(self, point)
        self:insertRecursive(self.tree, point, 0)
    end;
    insertRecursive = function(self, root, point, depth)
        if root.point == nil then --Create node if nil
            root.point = point
            root.left = {}
            root.right = {}
            return
        end

        local cd = depth % self.k + 1

        if point[cd] < root.point[cd] then
            self:insertRecursive(root.left, point, depth + 1)
        else
            self:insertRecursive(root.right, point, depth + 1)
        end
    end;

    nearestNeighbor = function(self, point) -- Returns nearest node to point and distance squared
        return self:nearestNeighborRecursive(self.tree, point, 0)
    end;
    nearestNeighborRecursive = function(self, root, point, depth)
        if root.point == nil then return nil end

        local cd = depth % self.k + 1
        if point[cd] < root.point[cd] then
            nextBranch, ortherBranch = root.left, root.right
        else
            nextBranch, ortherBranch = root.right, root.left
        end

        local temp = self:nearestNeighborRecursive(nextBranch, point, depth+1)
        local best = closest(temp, root, point)

        local r2, dist, r2_ =
            dist2(point, best.point),
            point[cd] - root.point[cd],
            nil

        if r2 >= dist*dist then
            temp = self:nearestNeighborRecursive(ortherBranch, point, depth+1)
            best, r2_ = closest(temp, best, point)
        end

        return best, r2_ or r2
    end
} end
--#endregion kdtree

--#region Rendering
WorldToScreen_Point = function(vertices, cameraTransform)
    local result = {}

    for i=1, #vertices do
        local x,y,z = vertices[i].x, vertices[i].y, vertices[i].z

        local X,Y,Z,W =
            cameraTransform[1]*x + cameraTransform[5]*y + cameraTransform[9]*z + cameraTransform[13],
            cameraTransform[2]*x + cameraTransform[6]*y + cameraTransform[10]*z + cameraTransform[14],
            cameraTransform[3]*x + cameraTransform[7]*y + cameraTransform[11]*z + cameraTransform[15],
            cameraTransform[4]*x + cameraTransform[8]*y + cameraTransform[12]*z + cameraTransform[16]

        if (-W<=X and X<=W) and (-W<=Y and Y<=W) and (0<=Z and Z<=W) then --clip and discard points
            W=1/W
            result[#result+1] = {X*W*cx+SCREEN.centerX, Y*W*cy+SCREEN.centerY, Z*W, i}
        else -- x & y are screen coordinates, z is depth, the 4th is the index of the point
            result[#result+1] = false
        end
    end

    return result
end
--#endregion Rendering


cameraTransform_world = {}
delaunay = Delaunay()
kdtree = New_KDTree(2)

minDist_squared = 20^2 -- How dense can the point cloud be


function onTick()
    renderOn = input.getBool(1)

    if renderOn then
        --Get cameraTransform
        for i = 1, 16 do
            cameraTransform_world[i] = input.getNumber(i)
        end

        --Get point
        p = {input.getNumber(17), input.getNumber(18), input.getNumber(19)}

        --Try add point
        if p[1] ~= 0 and p[2] ~= 0 then
            node, dist_squared = kdtree:nearestNeighbor(p)

            if node == nil or dist_squared > minDist_squared then
                kdtree:insert(p)

                delaunay.vertices[#delaunay.vertices + 1] = Point( table.unpack(p) )
                delaunay:Triangulate()
                delaunay:CalcMesh()
            end
        end
    end

end


function onDraw()

    if renderOn then

        local transformed_vertices = WorldToScreen_Point(delaunay.vertices, cameraTransform_world)
        local triangles = delaunay.trianglesMesh

        for i = 1, #triangles do
            local triangle = triangles[i]
            local v1, v2, v3 =
                transformed_vertices[triangle.v1.id],
                transformed_vertices[triangle.v2.id],
                transformed_vertices[triangle.v3.id]

            if v1 and v2 and v3 then -- Only draws triangle if all vertices are in view
                screen.drawTriangle(v1[1],v1[2], v2[1],v2[2], v3[1],v3[2])
            end
        end

    end
end