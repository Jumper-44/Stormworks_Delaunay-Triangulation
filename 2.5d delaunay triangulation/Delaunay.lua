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
    simulator:setScreen(1, "10x10")
    simulator:setProperty("Max_T", 1000^2)
    simulator:setProperty("Min_D", 0.1)

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
        simulator:setInputBool(31, simulator:getIsClicked(1))       -- if button 1 is clicked, provide an ON pulse for input.getBool(31)
        simulator:setInputNumber(31, simulator:getSlider(1))        -- set input 31 to the value of slider 1

        simulator:setInputBool(32, simulator:getIsToggled(2))       -- make button 2 a toggle, for input.getBool(32)
        simulator:setInputNumber(32, simulator:getSlider(2) * 50)   -- set input 32 to the value from slider 2 * 50
    end;
end
---@endsection


--[====[ IN-GAME CODE ]====]





require("JumperLib.DataStructures.JL_kdtree")
require("JumperLib.DataStructures.JL_queue")

-- Bitwise operations can only be done to integers, but also need to send the numbers as float when sending from script to script as Stormworks likes it that way.
--function int32_to_uint16(a, b) -- Takes 2 int32 and converts them to uint16 residing in a single number
--	return (('f'):unpack(('I'):pack( ((a&0xffff)<<16) | (b&0xffff)) ))
--end
--
--local function uint16_to_int32(x) -- Takes a single number containing 2 uint16 and unpacks them.
--	x = ('I'):unpack(('f'):pack(x))
--	return x>>16, x&0xffff
--end


---comment
---@class triangulation2_5d
---@field DT_vertices list
---@field DT_vertices_kdtree IKDTree
---@field DT_triangles list
---@field DT_delta_final_mesh_id queue
---@field DT_delta_final_mesh_operation queue
---@field DT_insert fun(point: table)
---@param max_triangle_size_squared number
---@return triangulation2_5d
function triangulation2_5d(max_triangle_size_squared)
    local delta_final_mesh_id, delta_final_mesh_operation, v_x, v_y, v_near_triangle, t_v1, t_v2, t_v3, t_neighbor1, t_neighbor2, t_neighbor3, t_isChecked, t_isInvalid, t_isSurface, vertex_buffer, triangle_buffer, temp = queue(),queue(), {},{},{}, {},{},{},{},{},{},{},{},{}, {0,0,0,1}, {0,0,0,false,false,false,false,false,false}, {}
    local vertices, vertices_kdtree, triangles, triangles_vertices, triangles_neighbors,  triangle_check_queue, triangle_check_queue_pointer, triangle_check_queue_size,  invalid_triangles, invalid_triangles_size,  edge_boundary_neighbor, edge_boundary_v1, edge_boundary_v2, edge_boundary_size, edge_shared =
        list({v_x, v_y, {}, v_near_triangle}), -- x,y,z, near_triangle_reference                                -- vertices
        IKDTree(v_x, v_y),                                                                                      -- vertices_kdtree
        list({t_v1, t_v2, t_v3, t_neighbor1, t_neighbor2, t_neighbor3, t_isChecked, t_isInvalid, t_isSurface}), -- triangles
        {t_v1, t_v2, t_v3},                                                                                     -- triangles_vertices
        {t_neighbor1, t_neighbor2, t_neighbor3},                                                                -- triangles_neighbors
        {}, 0, 0,           -- triangle_check_queue, triangle_check_queue_pointer, triangle_check_queue_size
        {}, 0,              -- invalid_triangles, invalid_triangles_size
        {}, {}, {}, 0, {}   -- edge_boundary_neighbor, edge_boundary_v1, edge_boundary_v2, edge_boundary_size, edge_shared

    local add_vertex, add_triangle, in_circle, min_enclosing_circleradius_of_triangle,  pointID, new_triangle, ccw, current_boundary_neighbor, hash_index, shared_triangle, current_triangle, current_neighbor,  adx, ady, bdx, bdy, cdx, cdy,  abx, aby, bcx, bcy, cax, cay, ab, bc, ca, maxVal

    ---@param x number
    ---@param y number
    ---@param z number
    function add_vertex(x, y, z) -- Insert new point in kd-tree and list
        vertex_buffer[1] = x
        vertex_buffer[2] = y
        vertex_buffer[3] = z
        pointID = vertices.list_insert(vertex_buffer)
        vertices_kdtree.IKDTree_insert(pointID)
    end

    ---@param v1 integer
    ---@param v2 integer
    ---@param v3 integer
    function add_triangle(v1, v2, v3) -- checking sign of 2d determinant to set triangle orientation and inserts triangle in list
        ccw = (v_x[v1] - v_x[v3]) * (v_y[v2] - v_y[v3]) - (v_y[v1] - v_y[v3]) * (v_x[v2] - v_x[v3]) < 0 -- ac_x * bc_y - ac_y * bc_x < 0
        triangle_buffer[1] = ccw and v1 or v2
        triangle_buffer[2] = ccw and v2 or v1
        triangle_buffer[3] = v3
        new_triangle = triangles.list_insert(triangle_buffer) -- returns given integer id to 'triangles'
    end

    ---@param t integer
    ---@param p table {x, y}
    ---@return number
    function in_circle(t, p) -- https://www.cs.cmu.edu/afs/cs/project/quake/public/code/predicates.c     incirclefast
        -- local adx, ady, bdx, bdy, cdx, cdy  --, abdet, bcdet, cadet, alift, blift, clift

        adx = v_x[t_v1[t]] - p[1]
        ady = v_y[t_v1[t]] - p[2]
        bdx = v_x[t_v2[t]] - p[1]
        bdy = v_y[t_v2[t]] - p[2]
        cdx = v_x[t_v3[t]] - p[1]
        cdy = v_y[t_v3[t]] - p[2]

        --abdet = adx * bdy - bdx * ady
        --bcdet = bdx * cdy - cdx * bdy
        --cadet = cdx * ady - adx * cdy
        --alift = adx * adx + ady * ady
        --blift = bdx * bdx + bdy * bdy
        --clift = cdx * cdx + cdy * cdy
        --return alift * bcdet + blift * cadet + clift * abdet

        return (adx * adx + ady * ady) * (bdx * cdy - cdx * bdy) + (bdx * bdx + bdy * bdy) * (cdx * ady - adx * cdy) + (cdx * cdx + cdy * cdy) * (adx * bdy - bdx * ady)
    end

    ---If the triangle is acute then the circumscribed circle is the smallest circle,
    ---else if the triangle is obtuse, then it is the circle enclosing the 2 opposite vertices of the obtuse angle,
    ---in which the obtuse angled vertex is enclosed too.
    ---@param tri integer
    ---@return number radius_squared
    function min_enclosing_circleradius_of_triangle(tri)
        -- local abx, aby, bcx, bcy, cax, cay, ab, bc, ca, maxVal
        abx = v_x[t_v2[tri]] - v_x[t_v1[tri]]
        aby = v_y[t_v2[tri]] - v_y[t_v1[tri]]
        bcx = v_x[t_v3[tri]] - v_x[t_v2[tri]]
        bcy = v_y[t_v3[tri]] - v_y[t_v2[tri]]
        cax = v_x[t_v1[tri]] - v_x[t_v3[tri]]
        cay = v_y[t_v1[tri]] - v_y[t_v3[tri]]

        -- triangle side lengths squared
        ab = abx*abx + aby*aby
        bc = bcx*bcx + bcy*bcy
        ca = cax*cax + cay*cay

        temp[1] = ab
        temp[2] = bc
        temp[3] = ca
        maxVal = (ab >= bc and ab >= ca) and 1 or (bc >= ab and bc >= ca) and 2 or 3

        return (temp[maxVal] > temp[maxVal%3+1] + temp[(maxVal+1)%3+1]) and (temp[maxVal] / 4)  -- if triangle is obtuse (c² > a² + b²), in which 'c' is the longest side, then r² = c²/4
            or (ab*bc*ca / (2*(ab*(bc + ca) + bc*ca) -ab*ab -bc*bc -ca*ca))                     -- Circumradius:  r = a*b*c / sqrt((a+b+c) * (-a+b+c) * (a-b+c) * (a+b-c))    ->    r² = a²b²c² / (2(a²(b² + c²) + b²c²) -a^4 -b^4 -c^4)
    end

    -- init super-triangle
    add_vertex(-9E5, -9E5, 0)
    add_vertex(9E5,  -9E5, 0)
    add_vertex(0,     9E5, 0)
    add_triangle(1, 2, 3)


    return {
    DT_vertices = vertices;
    DT_vertices_kdtree = vertices_kdtree;
    DT_triangles = triangles;
    DT_delta_final_mesh_id = delta_final_mesh_id;
    DT_delta_final_mesh_operation = delta_final_mesh_operation;

    ---@param point table {x, y, z}
    DT_insert = function(point)
        triangle_check_queue[1] = v_near_triangle[vertices_kdtree.IKDTree_nearestNeighbors(point, 1)[1]]
        t_isChecked[triangle_check_queue[1]] = true
        triangle_check_queue_pointer = 1
        triangle_check_queue_size = 1

        invalid_triangles_size = 0

        -- Do Bowyer-Watson Algorithm
        repeat -- Find all invalid triangles
            current_triangle = triangle_check_queue[triangle_check_queue_pointer]

            if in_circle(current_triangle, point) < 1e-9 then -- Is current_triangle invalid? || Is point inside circumcircle of current_triangle?
                t_isInvalid[current_triangle] = true
                invalid_triangles_size = invalid_triangles_size + 1
                invalid_triangles[invalid_triangles_size] = current_triangle
            end

            if t_isInvalid[current_triangle] or invalid_triangles_size == 0 then -- If current_triangle is invalid OR no invalid triangles has been found yet then try add neighboring triangles of current_triangle to check queue
                for i = 1, 3 do
                    current_neighbor = triangles_neighbors[i][current_triangle]
                    if current_neighbor and not t_isChecked[current_neighbor] then -- if neighbor exist and has not been checked yet then add to queue
                        triangle_check_queue_size = triangle_check_queue_size + 1
                        triangle_check_queue[triangle_check_queue_size] = current_neighbor
                        t_isChecked[current_neighbor] = true
                    end
                end
            end

            triangle_check_queue_pointer = triangle_check_queue_pointer + 1
        until triangle_check_queue_size < triangle_check_queue_pointer

        for i = 1, triangle_check_queue_size do -- reset isChecked state for checked triangles
            t_isChecked[triangle_check_queue[i]] = false
        end

        -- Now the invalid_triangles makes up a polygon (new point is assumed to be within super-triangle. No check for it, which would just be if invalid_triangles_size == 0)
        -- Find the boundary edge of invalid_triangles
        edge_boundary_size = 0
        for i = 1, invalid_triangles_size do
            current_triangle = invalid_triangles[i]
            for j = 1, 3 do
                current_neighbor = triangles_neighbors[j][current_triangle]
                if not current_neighbor or not t_isInvalid[current_neighbor] then -- If edge doesn't have neighbor OR if neighbor exist and it is not invalid then add as edge_boundary, else then the edge neighbor is an invalid triangle
                    edge_boundary_size = edge_boundary_size + 1
                    edge_boundary_neighbor[edge_boundary_size] = current_neighbor
                    edge_boundary_v1[edge_boundary_size] = triangles_vertices[j % 3 + 1][current_triangle]
                    edge_boundary_v2[edge_boundary_size] = triangles_vertices[(j+1) % 3 + 1][current_triangle]
                end
            end
        end

        for i = 1, invalid_triangles_size do -- Queue invalid_triangles for removal in final mesh if part of said mesh, i.e. if isSurface. (Not part of Bowyer-Watson algorithm)
            if t_isSurface[invalid_triangles[i]] then
                delta_final_mesh_id.queue_pushLeft(invalid_triangles[i])
                delta_final_mesh_operation.queue_pushLeft(true) -- true == remove
            end
        end

        add_vertex(point[1], point[2], point[3]) -- assigned index to 'pointID'

        for i = 1, edge_boundary_size do -- Construct new triangles and setup/maintain neighboring triangle references
            add_triangle(edge_boundary_v1[i], edge_boundary_v2[i], pointID)  -- assigned index to 'new_triangle'

            -- Set neighbor to the edge_boundary_neighbor and its neighbor (if exist) to new_triangle
            current_boundary_neighbor = edge_boundary_neighbor[i]
            t_neighbor3[new_triangle] = current_boundary_neighbor
            if current_boundary_neighbor then -- if neighbor exist then find correct index to set neighbor reference to new_triangle
                for j = 1, 3 do
                    if not (t_v1[new_triangle] == triangles_vertices[j][current_boundary_neighbor] or t_v2[new_triangle] == triangles_vertices[j][current_boundary_neighbor]) then
                        triangles_neighbors[j][current_boundary_neighbor] = new_triangle
                        break
                    end
                end
            end

            for j = 1, 2 do -- Setup neighboring between new triangles
                hash_index = triangles_vertices[j][new_triangle]
                shared_triangle = edge_shared[hash_index]
                if shared_triangle then
                    triangles_neighbors[j%2+1][new_triangle] = shared_triangle
                    triangles_neighbors[j][shared_triangle] = new_triangle
                    edge_shared[hash_index] = nil -- clear index so table hash can be reused next new point insertion
                else
                    edge_shared[hash_index] = new_triangle
                    v_near_triangle[hash_index] = new_triangle -- Update near triangle reference of vertex
                end
            end

            -- Test if triangle should be added to final mesh (Not part of Bowyer-Watson algorithm)
            if min_enclosing_circleradius_of_triangle(new_triangle) < max_triangle_size_squared then              --t_v1[new_triangle] > 3 and t_v2[new_triangle] > 3 and t_v3[new_triangle] > 3 -- if vertices are not part of super-triangle
                t_isSurface[new_triangle] = true
                delta_final_mesh_id.queue_pushLeft(new_triangle)
                delta_final_mesh_operation.queue_pushLeft(false) -- false == add
            end
        end
        v_near_triangle[pointID] = new_triangle -- Set near triangle reference to new inserted point
    end
} end


local max_triangle_size_squared, point_min_density_squared = property.getNumber("Max_T"), property.getNumber("Min_D")
local triangulation_controller, pointBuffer = triangulation2_5d(max_triangle_size_squared), {}
local delta_amount, t1_id, t2_id, DT_triangles, DT_delta_final_mesh_id, isBoth
function onTick()
    renderOn = input.getBool(1)
    clear = input.getBool(2)

    for i = 1, 3 do
        pointBuffer[i] = input.getNumber(i) -- Get point
        output.setNumber(i+17, 0) -- clear point passthrough
        output.setBool(i, input.getBool(i)) -- Passthrough: renderOn, isFemale, clear
    end

    if clear then
        triangulation_controller = triangulation2_5d(max_triangle_size_squared)
    end

    if pointBuffer[1] ~= 0 and pointBuffer[2] ~= 0
        and triangulation_controller.DT_vertices_kdtree.pointsLen2[triangulation_controller.DT_vertices_kdtree.IKDTree_nearestNeighbors(pointBuffer, 1)[1]] > point_min_density_squared
    then
        triangulation_controller.DT_insert(pointBuffer)
        for i = 1, 3 do
            output.setNumber(i+17, pointBuffer[i]) -- Passthrough: point[18,20]
        end
    end

    DT_triangles = triangulation_controller.DT_triangles
    DT_delta_final_mesh_id = triangulation_controller.DT_delta_final_mesh_id
    for i = 0, 3 do
        delta_amount = DT_delta_final_mesh_id.last - DT_delta_final_mesh_id.first + 1     --inline DT_delta_final_mesh_id.queue_size() function to reduce char
        if delta_amount > 0 then
            t1_id = DT_delta_final_mesh_id.queue_popRight()
            DT_triangles.list_remove(t1_id) -- make old triangle data able to be overwritten
            isBoth = delta_amount > 1

            if isBoth then
                t2_id = DT_delta_final_mesh_id.queue_popRight()
                DT_triangles.list_remove(t2_id) -- make old triangle data able to be overwritten
            end

            for j = 1, 3 do
                output.setNumber(20 + i*3 + j, (('f'):unpack(('I'):pack( ((DT_triangles[j][t1_id]&0xffff)<<16) | ((isBoth and DT_triangles[j][t2_id] or 0)&0xffff)) )))                --inlined int32_to_uint16(DT_triangles[j][t1_id], isBoth and DT_triangles[j][t2_id] or 0)
            end
            for j = 4, isBoth and 5 or 4 do
                output.setBool(i*2 + j, triangulation_controller.DT_delta_final_mesh_operation.queue_popRight())
            end

        else -- Clear the rest of the triangle output when 'delta_amount' is 0
            for j = 21 + i*3, 32 do
                output.setNumber(j, 0)
            end
            break
        end
    end
end





---@section __DEBUG__
-- [[
do -- run in VSCode with F6 and press/hold right click to place point(s) to triangulate
    local triangulation_controller = triangulation2_5d(25^2)
    local pointBuffer = {0,0,0}
    local triangleMeshID = {}

    function onTick()
        local touchX, touchY, togglePress = input.getNumber(3), input.getNumber(4), input.getBool(11)
        pointBuffer[1] = touchX
        pointBuffer[2] = touchY

        if togglePress or true then
            if triangulation_controller.DT_vertices_kdtree.pointsLen2[ triangulation_controller.DT_vertices_kdtree.IKDTree_nearestNeighbors(pointBuffer, 1)[1] ] > 10 then
                triangulation_controller.DT_insert(pointBuffer)

                local queue_size = triangulation_controller.DT_delta_final_mesh_id.queue_size()
                for i = 1, queue_size do
                    local triangleID = triangulation_controller.DT_delta_final_mesh_id.queue_popRight()
                    if triangulation_controller.DT_delta_final_mesh_operation.queue_popRight() then
                        triangleMeshID[triangleID] = nil -- rem from final mesh
                        triangulation_controller.DT_triangles.list_remove(triangleID) -- make old triangle data able to be overwritten
                    else
                        triangleMeshID[triangleID] = true -- add
                    end
                end

                --for k in pairs(triangleMeshID) do --debug
                --    for i = 4, 6 do
                --        if triangulation_controller.triangles[8][ triangulation_controller.triangles[i][k] ] then
                --            error("Triangles have reference to invalid triangles")
                --        end
                --    end
                --end
            end
        end
    end

    function onDraw()
        local vx, vy = triangulation_controller.DT_vertices[1], triangulation_controller.DT_vertices[2]
        for k in pairs(triangleMeshID) do
            local tv1, tv2, tv3 = triangulation_controller.DT_triangles[1], triangulation_controller.DT_triangles[2], triangulation_controller.DT_triangles[3]
            screen.setColor(k*k%255, k*4%255, 100)
            screen.drawTriangleF(vx[tv1[k] ], vy[tv1[k] ], vx[tv2[k] ], vy[tv2[k] ], vx[tv3[k] ], vy[tv3[k] ])
        end

        screen.setColor(255,255,255)
        for i = 4, #triangulation_controller.DT_vertices[1] do
            screen.drawCircleF(vx[i], vy[i], 0.6)
        end
    end
end
--]]
---@endsection