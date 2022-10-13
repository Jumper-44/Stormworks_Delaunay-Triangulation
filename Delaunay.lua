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
See the delaunay triangulation in browser with touchscreen https://lua.flaffipony.rocks/?id=IDyvZ6wC8P
--]]
--#endregion readme

--#region math
local Add, Sub, Scale, Dot, Cross =
    function(a,b) return {x = a.x+b.x, y = a.y+b.y, z = a.z+b.z} end,
    function(a,b) return {x = a.x-b.x, y = a.y-b.y, z = a.z-b.z} end,
    function(a,b) return {x = a.x*b, y = a.y*b, z = a.z*b} end,
    function(a,b) return a.x*b.x + a.y*b.y + a.z*b.z end,
    function(a,b) return {x = a.y*b.z-a.z*b.y, y = a.z*b.x-a.x*b.z, z = a.x*b.y-a.y*b.x} end

local Len = function(a) return Dot(a,a)^.5 end
local Normalize = function(a) return Scale(a, 1/Len(a)) end
--#endregion math

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

local Normal = function(a,b,c)
    local normal = Normalize( Cross(Sub(a,b), Sub(a,c)) )
    if normal.z < 0 then normal = Scale(normal, -1) end -- Making sure the normal is upwards, as triangle vertices aren't ordered

    return normal
end

-- Point Class
local Point = function(x,y,z,id) return {
    x=x; y=y, z=z or 0; id=id or 0
} end

-- Triangle Class
local Triangle = function(p1,p2,p3) return {
    v1=p1; v2=p2; v3=p3;

    circle = GetCircumCircle(p1,p2,p3);

    normal = Normal(p1,p2,p3)
} end

local Delaunay = function() return {
    trianglesMesh = {}; -- calcMesh() will populate this

    vertices = {};
    n_vertices = 0;

    triangles = { Triangle(Point(-9E5,-9E5), Point(9E5,-9E5), Point(0,9E5)) }; -- Supertriangle

    triangulate = function(self)
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

    calcMesh = function(self) -- The step to remove the triangles which shares a vertex with the Supertriangle
        self.trianglesMesh = {}

        for i = 2, #self.triangles do
            if not (
                self.triangles[i].v1.id == 0 or
                self.triangles[i].v2.id == 0 or
                self.triangles[i].v3.id == 0 )
            then
                self.trianglesMesh[#self.trianglesMesh + 1] = self.triangles[i]
            end
        end
    end

} end
--#endregion Delaunay

--#region Rendering
w,h = 160,160 -- Screen Pixels
cx,cy = w/2,h/2
SCREEN = {centerX = cx, centerY = cy}

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
            result[#result + 1] = {X*W*cx+SCREEN.centerX, Y*W*cy+SCREEN.centerY, Z*W}
        else -- x & y are screen coordinates, z is depth
            result[#result + 1] = false
        end
    end

    return result
end
--#endregion Rendering


-- init
local delaunay, colorPalette, cameraTransform_world, cameraDirection, point, triangles =
    Delaunay(), -- delaunay
    {{0,0,255,75},{0,100,0,75}}, -- colorPalette : {water, ground}
    {}, -- cameraTransform_world
    {}, -- cameraDirection
    {}, -- point
    nil -- triangles


function onTick()
    renderOn = input.getBool(1)
    if input.getBool(2) then -- Clear scan
        delaunay = Delaunay()
        triangles = nil
    end

    --Get point
    point = {input.getNumber(20), input.getNumber(21), input.getNumber(22)}

    if point[1] ~= 0 and point[2] ~= 0 then
        delaunay.vertices[#delaunay.vertices + 1] = Point( table.unpack(point) )
        delaunay:triangulate()
        delaunay:calcMesh()

        triangles = {{},{}}

        for i = 1, #delaunay.trianglesMesh do
            local triangle = delaunay.trianglesMesh[i]
            local verticesUnderWater, set = 0, {triangle.v1.z, triangle.v2.z, triangle.v3.z}

            for j = 1, 3 do
                verticesUnderWater = verticesUnderWater + (set[j] < 0 and 1 or 0)
            end

            if verticesUnderWater > 1 then
                triangles[1][#triangles[1] + 1] = triangle
            else
                triangles[2][#triangles[2] + 1] = triangle
            end
        end
    end

    if renderOn then
        -- Get cameraTransform
        for i = 1, 16 do
            cameraTransform_world[i] = input.getNumber(i)
        end

        -- Get camera direction vector
        cameraDirection.x = input.getNumber(17)
        cameraDirection.y = input.getNumber(18)
        cameraDirection.z = input.getNumber(19)

        -- Update colorPalette alhpa value
        alpha = input.getNumber(32)
        for i = 1, #colorPalette do
            colorPalette[i][4] = alpha
        end
    end

end

function onDraw()

    if renderOn and triangles then

        local transformed_vertices, currentDrawnTriangles, drawTriangle =
            WorldToScreen_Point(delaunay.vertices, cameraTransform_world),
            0,
            screen.drawTriangle

        for i = 1, #colorPalette do
            screen.setColor( table.unpack(colorPalette[i]) )

            for j = 1, #triangles[i] do
                local triangle = triangles[i][j]
                local v1, v2, v3 =
                    transformed_vertices[triangle.v1.id],
                    transformed_vertices[triangle.v2.id],
                    transformed_vertices[triangle.v3.id]

                if v1 and v2 and v3 then -- Only draws triangle if all vertices are in view
                    drawTriangle(v1[1],v1[2], v2[1],v2[2], v3[1],v3[2])
                    currentDrawnTriangles = currentDrawnTriangles + 1
                end
            end
        end

        screen.setColor(255,255,255,125)
        screen.drawText(0,130,"Alpha: "..alpha)
        screen.drawText(0,140,"#Triangles: "..#delaunay.trianglesMesh)
        screen.drawText(0,150,"#DrawTriangles: "..currentDrawnTriangles)
    end
end