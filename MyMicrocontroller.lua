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

-- try require("Folder.Filename") to include code from another file in this, so you can store code in libraries
-- the "LifeBoatAPI" is included by default in /_build/libs/ - you can use require("LifeBoatAPI") to get this, and use all the LifeBoatAPI.<functions>!
--require("JumperLib.Delaunay")


--[[ Delaunay start ]]--
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
--[[ Delaunay end ]]--

--[[ k-d tree start ]]--
Dist2 = function(a,b)
    local sum = 0
    for i = 1, #a do
        local vec = a[i]-b[i]
        sum = sum + vec*vec
    end
    return sum
end

insertRecursive = function(root, point, depth, k)
    if root.point == nil then
        root.point = point
        root.left = {}
        root.right = {}
        return
    end

    local cd = depth % k + 1

    if point[cd] < root.point[cd] then
        insertRecursive(root.left, point, depth + 1, k)
    else
        insertRecursive(root.right, point, depth + 1, k)
    end
end

KDTree = function(k) return { --https://www.geeksforgeeks.org/k-dimensional-tree/
    k = k;
    tree = {};

    insert = function(self, point)
        insertRecursive(self.tree, point, 0, self.k)
    end;

    nearestNeighbor = function(self)

    end;
} end
--[[ k-d trees end ]]--


tree = KDTree(2)
tree:insert({50,50})
tree:insert({40,40})
tree:insert({70,20})


delaunayController = Delaunay()
local triangles = {}

_press = false

function onTick()
    x,y = input.getNumber(3),input.getNumber(4)
    press = input.getBool(1)

    if press and press ~= _press then
        delaunayController.vertices[#delaunayController.vertices + 1] = Point(x, y)
        delaunayController:Triangulate()
        delaunayController:CalcMesh()

        triangles = delaunayController.trianglesMesh
    end
    _press = press
end


function onDraw()
    for i=1, #triangles do
        screen.drawTriangle(triangles[i].v1.x,triangles[i].v1.y, triangles[i].v2.x,triangles[i].v2.y, triangles[i].v3.x,triangles[i].v3.y)
    end

    screen.setColor(255,255,255)

    for i = 1, #delaunayController.vertices do
        screen.drawText(delaunayController.vertices[i].x-1, delaunayController.vertices[i].y-4, '.')
    end

    screen.drawText(0,0,#triangles)
end