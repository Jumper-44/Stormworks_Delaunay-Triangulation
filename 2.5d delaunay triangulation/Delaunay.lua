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
        simulator:setInputBool(32, simulator:getIsClicked(1))       -- if button 1 is clicked, provide an ON pulse for input.getBool(31)
        simulator:setInputNumber(32, math.floor(simulator:getSlider(1)*20))        -- set input 31 to the value of slider 1

        --simulator:setInputBool(32, simulator:getIsToggled(2))       -- make button 2 a toggle, for input.getBool(32)
        --simulator:setInputNumber(32, simulator:getSlider(2) * 50)   -- set input 32 to the value from slider 2 * 50
    end;
end
---@endsection


--[====[ IN-GAME CODE ]====]




-- Inlined int32_to_uint16. uint16_to_int32 not used.
-- Bitwise operations can only be done to integers, but also need to send the numbers as float when sending from script to script as Stormworks likes it that way.
--function int32_to_uint16(a, b) -- Takes 2 int32 and converts them to uint16 residing in a single number
--	return (('f'):unpack(('I'):pack( ((a&0xffff)<<16) | (b&0xffff)) ))
--end
--
--local function uint16_to_int32(x) -- Takes a single number containing 2 uint16 and unpacks them.
--	x = ('I'):unpack(('f'):pack(x))
--	return x>>16, x&0xffff
--end

require("JumperLib.DataStructures.JL_kdtree")
require("JumperLib.DataStructures.JL_queue")

---@class triangulation2_5d
---@field DT_vertices list
---@field DT_vertices_kdtree IKDTree
---@field DT_triangles list
---@field DT_delta_final_mesh_triangle_id queue
---@field DT_delta_final_mesh_batch queue Everytime a point is inserted then 2 batches/integers are added to queue of first amount of removed and then amount of added triangles, to final/accepted mesh.
---@field DT_insert fun(point: table<number, number, number>)
---2.5D delaunay triangulation with Boywer-Watson algorithm. O(n*log n) average insertion.  
---Each new triangle is evaluated if part of final mesh by the radius of minimum enclosing circle of triangle.  
---Require "JumperLib.DataStructures.JL_kdtree" and "JumperLib.DataStructures.JL_queue"
---@param max_triangle_size_squared number
---@return triangulation2_5d
function triangulation2_5d(max_triangle_size_squared)
    local delta_final_mesh_triangle_id, delta_final_mesh_batch, v_x, v_y, v_z, v_near_triangle, t_v1, t_v2, t_v3, t_neighbor1, t_neighbor2, t_neighbor3, t_isChecked, t_isInvalid, t_isSurface, vertex_buffer, triangle_buffer = queue(),queue(), {},{},{},{}, {},{},{},{},{},{},{},{},{}, {0,0,0,1}, {0,0,0,false,false,false,false,false,false}
    local vertices, vertices_kdtree, triangles, triangles_vertices, triangles_neighbors,  triangle_check_queue, triangle_check_queue_pointer, triangle_check_queue_size,  invalid_triangles, invalid_triangles_size,  edge_boundary_neighbor, edge_boundary_v1, edge_boundary_v2, edge_boundary_size, edge_shared,  finalMeshID, finalMeshFreeID =
        list({v_x, v_y, v_z, v_near_triangle}),                                                                 -- vertices
        IKDTree(v_x, v_y, v_z),                                                                                 -- vertices_kdtree
        list({t_v1, t_v2, t_v3, t_neighbor1, t_neighbor2, t_neighbor3, t_isChecked, t_isInvalid, t_isSurface}), -- triangles
        {t_v1, t_v2, t_v3},                                                                                     -- triangles_vertices (Note: Could be removed and just use 'triangles', if chars are needed)
        {t_neighbor1, t_neighbor2, t_neighbor3},                                                                -- triangles_neighbors
        {}, 0, 0,           -- triangle_check_queue, triangle_check_queue_pointer, triangle_check_queue_size
        {}, 0,              -- invalid_triangles, invalid_triangles_size
        {}, {}, {}, 0, {},  -- edge_boundary_neighbor, edge_boundary_v1, edge_boundary_v2, edge_boundary_size, edge_shared
        0, {}               -- finalMeshID, finalMeshFreeID

    local add_vertex, add_triangle,  pointID, new_triangle, ccw, current_boundary_neighbor, hash_index, shared_triangle, current_triangle, current_neighbor,  adx, ady, bdx, bdy, cdx, cdy, ab, bc, ca, maxVal,  batch_amount

    ---@param a integer
    ---@param b integer
    ---@return number, number
    function pointSub(a, b)
        return v_x[a]-v_x[b], v_z[a]-v_z[b]
    end

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
        adx, ady = pointSub(v1, v3)
        bdx, bdy = pointSub(v2, v3)
        ccw = adx * bdy - ady * bdx < 0
        triangle_buffer[1] = ccw and v1 or v2
        triangle_buffer[2] = ccw and v2 or v1
        triangle_buffer[3] = v3 -- note that the 3rd vertex stays the same, but 1 & 2 may swap to set orientation counterclockwise (CCW)
        new_triangle = triangles.list_insert(triangle_buffer)
    end

-- inlined in_circle to reduce char
--    ---@param v1 integer
--    ---@param v2 integer
--    ---@param v3 integer
--    ---@param p integer
--    ---@return number
--    function in_circle(v1, v2, v3, p) -- https://www.cs.cmu.edu/afs/cs/project/quake/public/code/predicates.c     incirclefast
--        local adx, ady, bdx, bdy, cdx, cdy  --, abdet, bcdet, cadet, alift, blift, clift
--        adx, ady = pointSub(v1, p)
--        bdx, bdy = pointSub(v2, p)
--        cdx, cdy = pointSub(v3, p)
--
--        --abdet = adx * bdy - bdx * ady
--        --bcdet = bdx * cdy - cdx * bdy
--        --cadet = cdx * ady - adx * cdy
--        --alift = adx * adx + ady * ady
--        --blift = bdx * bdx + bdy * bdy
--        --clift = cdx * cdx + cdy * cdy
--        --return alift * bcdet + blift * cadet + clift * abdet
--
--        return (adx * adx + ady * ady) * (bdx * cdy - cdx * bdy) + (bdx * bdx + bdy * bdy) * (cdx * ady - adx * cdy) + (cdx * cdx + cdy * cdy) * (adx * bdy - bdx * ady)
--    end

-- inlined min_enclosing_circleradius_of_triangle to reduce char
--    ---If the triangle is acute then the circumscribed circle is the smallest circle,
--    ---else if the triangle is obtuse, then it is the circle enclosing the 2 opposite vertices of the obtuse angle,
--    ---in which the obtuse angled vertex is enclosed too.
--    ---@param v1 integer
--    ---@param v2 integer
--    ---@param v3 integer
--    ---@return number radius_squared
--    function min_enclosing_circleradius_of_triangle(v1, v2, v3)
--        local abx, aby, bcx, bcy, cax, cay, ab, bc, ca, maxVal
--        abx, aby = pointSub(v2, v1)
--        bcx, bcy = pointSub(v3, v2)
--        cax, cay = pointSub(v1, v3)
--
--        -- triangle side lengths squared
--        ab = abx*abx + aby*aby
--        bc = bcx*bcx + bcy*bcy
--        ca = cax*cax + cay*cay
--
--        -- reusing 'triangle_buffer' to reduce char, instead of an unique temporary table
--        triangle_buffer[1] = ab
--        triangle_buffer[2] = bc
--        triangle_buffer[3] = ca
--        maxVal = (ab >= bc and ab >= ca) and 1 or (bc >= ab and bc >= ca) and 2 or 3--
--        return (triangle_buffer[maxVal] > triangle_buffer[maxVal%3+1] + triangle_buffer[(maxVal+1)%3+1]) and (triangle_buffer[maxVal] / 4)  -- if triangle is obtuse (c² > a² + b²), in which 'c' is the longest side, then r² = c²/4, else
--            or (ab*bc*ca / (2*(ab*(bc + ca) + bc*ca) -ab*ab -bc*bc -ca*ca))                                                                 -- Circumradius:  r = a*b*c / sqrt((a+b+c) * (-a+b+c) * (a-b+c) * (a+b-c))    ->    r² = a²b²c² / (2(a²(b² + c²) + b²c²) -a^4 -b^4 -c^4)
--    end

    -- init super-triangle
    add_vertex(-9E5, 0, -9E5)
    add_vertex(9E5,  0, -9E5)
    add_vertex(0,    0,  9E5)
    add_triangle(1, 2, 3)


    return {
        DT_vertices = vertices;
        DT_vertices_kdtree = vertices_kdtree;
        DT_triangles = triangles;
        DT_delta_final_mesh_triangle_id = delta_final_mesh_triangle_id;
        DT_delta_final_mesh_batch = delta_final_mesh_batch;

        ---@param point table {x, y, z}, point is assumed to be within super-triangle. Will fail and soon crash if outside super-triangle
        DT_insert = function(point) -- Do Bowyer-Watson Algorithm and update the delta final mesh (The final mesh sent to next script)
            triangle_check_queue[1] = v_near_triangle[vertices_kdtree.IKDTree_nearestNeighbor(point)] -- Jump to a near triangle to 'point'. Keypoint for going from O(n*n) to O(n*log n) on average
            t_isChecked[triangle_check_queue[1]] = true
            triangle_check_queue_pointer = 1
            triangle_check_queue_size = 1
            invalid_triangles_size = 0
            add_vertex(point[1], point[2], point[3]) -- assigned index to 'pointID'

            repeat -- Find all invalid triangles, by walking around neighboring triangles till all invalid triangle(s) (which all touch each other) has been found
                current_triangle = triangle_check_queue[triangle_check_queue_pointer]

                -- inlined function: if in_circle(t_v1[current_triangle], t_v2[current_triangle], t_v3[current_triangle], pointID) < 1e-9 then
                adx, ady = pointSub(t_v1[current_triangle], pointID)
                bdx, bdy = pointSub(t_v2[current_triangle], pointID)
                cdx, cdy = pointSub(t_v3[current_triangle], pointID)
                if (adx * adx + ady * ady) * (bdx * cdy - cdx * bdy) + (bdx * bdx + bdy * bdy) * (cdx * ady - adx * cdy) + (cdx * cdx + cdy * cdy) * (adx * bdy - bdx * ady) < 1e-9 then -- Is current_triangle invalid? || Is point inside circumcircle of current_triangle?
                    t_isInvalid[current_triangle] = true
                    invalid_triangles_size = invalid_triangles_size + 1
                    invalid_triangles[invalid_triangles_size] = current_triangle
                end

                if t_isInvalid[current_triangle] or invalid_triangles_size == 0 then -- If current_triangle is invalid OR no invalid triangles has been found yet then try add neighboring triangles of current_triangle to check queue
                    for i = 1, 3 do
                        current_neighbor = triangles_neighbors[i][current_triangle]
                        if current_neighbor and not t_isChecked[current_neighbor] then -- if neighbor exist and has not been checked yet then add to check queue
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

            edge_boundary_size = 0
            for i = 1, invalid_triangles_size do -- Now the invalid_triangles makes up a polygon. Find the boundary edge of invalid_triangles
                current_triangle = invalid_triangles[i]
                for j = 1, 3 do
                    current_neighbor = triangles_neighbors[j][current_triangle]
                    if not (current_neighbor and t_isInvalid[current_neighbor]) then -- If edge doesn't have neighbor OR if neighbor exist and it is not invalid then add as edge_boundary, else then the edge neighbor is an invalid triangle (Don't care about shared edge of invalid triangles)
                        edge_boundary_size = edge_boundary_size + 1
                        edge_boundary_neighbor[edge_boundary_size] = current_neighbor
                        edge_boundary_v1[edge_boundary_size] = triangles_vertices[j % 3 + 1][current_triangle]
                        edge_boundary_v2[edge_boundary_size] = triangles_vertices[(j+1) % 3 + 1][current_triangle]
                    end
                end
            end

            batch_amount = 0
            for i = 1, invalid_triangles_size do -- Queue invalid_triangles for removal in final mesh if isSurface
                current_triangle = invalid_triangles[i]
                if t_isSurface[current_triangle] then
                    delta_final_mesh_triangle_id.queue_pushLeft(current_triangle)
                    finalMeshFreeID[#finalMeshFreeID+1] = t_isSurface[current_triangle]
                    batch_amount = batch_amount + 1
                end
            end
            delta_final_mesh_batch.queue_pushLeft(batch_amount)

            batch_amount = 0
            for i = 1, edge_boundary_size do -- Construct new triangles and setup/maintain neighboring triangle references
                add_triangle(edge_boundary_v1[i], edge_boundary_v2[i], pointID)  -- assigned index to 'new_triangle'

                -- Set neighbor to the edge_boundary_neighbor and its neighbor (if exist) to new_triangle
                current_boundary_neighbor = edge_boundary_neighbor[i]
                t_neighbor3[new_triangle] = current_boundary_neighbor
                if current_boundary_neighbor then -- if neighbor exist then find correct index to set neighbor reference to new_triangle
                    for j = 1, 3 do -- Find index to the not shared vertex of neighboring triangle
                        if not (t_v1[new_triangle] == triangles_vertices[j][current_boundary_neighbor] or t_v2[new_triangle] == triangles_vertices[j][current_boundary_neighbor]) then
                            triangles_neighbors[j][current_boundary_neighbor] = new_triangle
                            break
                        end
                    end
                end

                for j = 1, 2 do -- Setup neighboring between new triangles.
                    -- All new triangles share the 3rd vertex. There are always a minimum of 3 new triangles.
                    -- Use hash table and add 1st and 2nd vertices of new_triangle.
                    -- Same vertex will only be encountered 2 times, when iterated through all new_triangles.
                    -- The 2nd time the same vertex is tried to be added, then you know the triangle edge pair and can setup neighbor references.
                    hash_index = triangles_vertices[j][new_triangle]
                    shared_triangle = edge_shared[hash_index]
                    if shared_triangle then -- Same vertex encountered
                        triangles_neighbors[j%2+1][new_triangle] = shared_triangle  -- 'j%2+1' index works due to all triangles having same winding order
                        triangles_neighbors[j][shared_triangle] = new_triangle      -- 'j' index...
                        edge_shared[hash_index] = nil                               -- clear index so hash table can be reused next new point insertion
                    else -- First time seeing vertex
                        edge_shared[hash_index] = new_triangle      -- Add first unencountered vertex to hash table
                        v_near_triangle[hash_index] = new_triangle  -- Update near triangle reference of vertex
                    end
                end

                -- Test if triangle should be added to final mesh
                adx, ady = pointSub(t_v2[new_triangle], t_v1[new_triangle])
                bdx, bdy = pointSub(t_v3[new_triangle], t_v2[new_triangle])
                cdx, cdy = pointSub(t_v1[new_triangle], t_v3[new_triangle])
                ab = adx*adx + ady*ady -- triangle side lengths squared
                bc = bdx*bdx + bdy*bdy
                ca = cdx*cdx + cdy*cdy
                triangle_buffer[1] = ab -- reusing 'triangle_buffer' to reduce char, instead of an unique temporary table
                triangle_buffer[2] = bc
                triangle_buffer[3] = ca
                maxVal = (ab >= bc and ab >= ca) and 1 or (bc >= ab and bc >= ca) and 2 or 3
                if ((triangle_buffer[maxVal] > triangle_buffer[maxVal%3+1] + triangle_buffer[(maxVal+1)%3+1]) and (triangle_buffer[maxVal] / 4) -- -- inlined function: if min_enclosing_circleradius_of_triangle(t_v1[new_triangle], t_v2[new_triangle], t_v3[new_triangle]) < max_triangle_size_squared then
                    or (ab*bc*ca / (2*(ab*(bc + ca) + bc*ca) -ab*ab -bc*bc -ca*ca))) < max_triangle_size_squared
                then
                    if #finalMeshFreeID > 0 then
                        t_isSurface[new_triangle] = table.remove(finalMeshFreeID) -- pop stack
                    else
                        finalMeshID = finalMeshID + 1
                        t_isSurface[new_triangle] = finalMeshID
                    end
                    delta_final_mesh_triangle_id.queue_pushLeft(new_triangle)
                    batch_amount = batch_amount + 1
                end
            end

            delta_final_mesh_batch.queue_pushLeft(batch_amount)
            v_near_triangle[pointID] = new_triangle -- Set near triangle reference to new inserted point
        end
    }
end



local max_triangle_size_squared, point_min_density_squared = property.getNumber("Max_T"), property.getNumber("Min_D")
local triangulation_controller, pointBuffer, batch_sequence, batch_rest, output_buffer = triangulation2_5d(max_triangle_size_squared), {{},{},{},{},{},{}}, true, 0, {}
local accepted_points, cPBuffer, batch_add_ran, triangleID, output_buffer_pointer, _, dist

function onTick()
    if input.getBool(3) then -- if clear
        triangulation_controller = triangulation2_5d(max_triangle_size_squared)
        batch_sequence = true
        batch_rest = 0
    end

    for i = 1, 32 do
        output.setBool(i, input.getBool(i)) -- Passthrough bool channel: [1,3] = renderOn, isFemale, clear.  Reset/false = [4,24].  uint8 = [25,32]
        output_buffer[i] = 0 -- clear buffer
    end

    accepted_points = 0
    if #triangulation_controller.DT_vertices[1] < 65536 then
        for i = 1, 6 do -- Accepts first 2 valid points and discard other inputs
            cPBuffer = pointBuffer[i]
            for j = 1, 3 do
                cPBuffer[j] = input.getNumber((i-1)*3 + j)
            end

            if cPBuffer[1] ~= 0 and cPBuffer[3] ~= 0 then
                _, dist = triangulation_controller.DT_vertices_kdtree.IKDTree_nearestNeighbor(cPBuffer)
                if dist > point_min_density_squared then
                    triangulation_controller.DT_insert(cPBuffer)
                    for j = 1, 3 do
                        output.setNumber(16 + j + accepted_points*3, cPBuffer[j]) -- [17,22]
                    end
                    accepted_points = accepted_points + 1
                    output.setBool(20 + accepted_points, true) -- [21,22]
                    if accepted_points == 2 then break end
                end
            end
        end
    end

    batch_add_ran = (batch_rest > 0 and batch_sequence) and 1 or 0
    output_buffer_pointer = accepted_points > 0 and (accepted_points > 1 and 13 or 7) or 1
    repeat
        if output_buffer_pointer <= 30 then
            if (batch_rest == 0) and (triangulation_controller.DT_delta_final_mesh_batch.first <= triangulation_controller.DT_delta_final_mesh_batch.last) and (batch_add_ran < 2 or batch_sequence) and (output_buffer_pointer%2 == 1) then
                batch_sequence = not batch_sequence
                batch_add_ran = batch_sequence and batch_add_ran + 1 or batch_add_ran
                batch_rest = triangulation_controller.DT_delta_final_mesh_batch.queue_popRight()
            end

            if batch_rest > 0 then
                triangleID = triangulation_controller.DT_delta_final_mesh_triangle_id.queue_popRight()
                if batch_sequence then -- add triangle
                    output_buffer[output_buffer_pointer] = triangulation_controller.DT_triangles[1][triangleID] -- triangle vertex 1
                    output_buffer_pointer = output_buffer_pointer + 1
                    output_buffer[output_buffer_pointer] = triangulation_controller.DT_triangles[2][triangleID] -- triangle vertex 2
                    output_buffer[30 + batch_add_ran] = triangulation_controller.DT_triangles[3][triangleID]    -- triangle vertex 3
                else -- remove triangle
                    output_buffer[output_buffer_pointer] = triangulation_controller.DT_triangles[9][triangleID] -- triangle final mesh id to be removed
                    triangulation_controller.DT_triangles.removed_id[#triangulation_controller.DT_triangles.removed_id] = triangleID -- make old triangle data able to be overwritten       -- inlined function: triangulation_controller.DT_triangles.list_remove(triangleID)
                end

                batch_rest = batch_rest - 1
            end
        end

        if output_buffer_pointer % 2 == 0 then
            output.setNumber(16 + output_buffer_pointer/2, (('f'):unpack(('I'):pack( ((output_buffer[output_buffer_pointer-1]&0xffff)<<16) | (output_buffer[output_buffer_pointer]&0xffff)) )))      -- inlined function: output.setNumber(22 + output_buffer_pointer/2, int32_to_uint16(output_buffer[output_buffer_pointer-1], output_buffer[output_buffer_pointer]))
            output.setBool(3 + output_buffer_pointer/2, batch_sequence)
        end

        output_buffer_pointer = output_buffer_pointer + 1
    until output_buffer_pointer > 32
end





---@section __DEBUG__
--[[
do -- run in VSCode with F6 and press/hold right click to place point(s) to triangulate
    --require("JumperLib.DataStructures.JL_BVH")

    local pointBuffer = {0,0,0}
    local AABB_min_buffer, AABB_max_buffer = {0,0,0}, {0,0,0}

    local triangulation_controller
    local batch_sequence
    local triangle_buffer

    local bvh = BVH_AABB()
    local BVH_ID, DT_triangleID, colorR, colorG, colorB
    local triangles, triangles_buffer

    local function initialize()
        triangulation_controller = triangulation2_5d(30^2)
        batch_sequence = true;
        triangle_buffer = {}

        bvh = BVH_AABB()
        BVH_ID, DT_triangleID, colorR, colorG, colorB = {},{}, {},{},{}
        triangles, triangles_buffer =
            list({BVH_ID, DT_triangleID, colorR, colorG, colorB}),
            {0,0, 0,0,0}
    end
    initialize()


    ---comment
    ---@param tree BoundingVolumeHierarchyAABB
    ---@param maxDepth integer
    local function readBVH(tree, maxDepth)
        local _return = {}

        local function readBVH_recursive(index, depth, cR, cG, cB)
            if depth < maxDepth then
                cR, cG, cB = depth*depth*10%200, 200-depth*9%200, math.random()*150 + 100
            end

            local tri = tree.BVH_nodes[4][index]
            --local SAH = tree.BVH_nodes[5][index]
            --if SAH < maxDepth*50 then
            --    colorSet = true
            --    cR, cG, cB = depth*depth*10%200, 200-depth*9%200, math.random()*150 + 100
            --end

            if tri == false then
                depth = depth+1
                readBVH_recursive(tree.BVH_nodes[1][index], depth, cR, cG, cB)
                readBVH_recursive(tree.BVH_nodes[2][index], depth, cR, cG, cB)
            else
                _return[#_return+1] = tri
                colorR[tri] = cR
                colorG[tri] = cG
                colorB[tri] = cB
            end
        end

        if tree.BVH_rootIndex then
            readBVH_recursive(tree.BVH_rootIndex, 0, 255, 255, 255)
        end

        return _return
    end


    local prev_depth, addedPoint = 0, false
    function onTick()
        local touchX, touchY, isPressing = input.getNumber(3), input.getNumber(4), input.getBool(1)
        pointBuffer[1] = touchX
        pointBuffer[2] = math.random()*1e-6
        pointBuffer[3] = touchY

        local depth = input.getNumber(32)
        local clear = input.getBool(32)
        if clear then initialize() end

        if isPressing then
            local _, dist2 = triangulation_controller.DT_vertices_kdtree.IKDTree_nearestNeighbor(pointBuffer)
            if dist2 > 4 then
                addedPoint = true
                triangulation_controller.DT_insert(pointBuffer)
                local DT_vertices = triangulation_controller.DT_vertices
                local DT_triangles = triangulation_controller.DT_triangles

                for i = 1, triangulation_controller.DT_delta_final_mesh_batch.queue_size() do
                    local batch_size = triangulation_controller.DT_delta_final_mesh_batch.queue_popRight()

                    for j = 1, batch_size do
                        local triangleID = triangulation_controller.DT_delta_final_mesh_triangle_id.queue_popRight()
                        if batch_sequence then
                            triangles.list_remove(DT_triangles[9][triangleID])
                            bvh.BVH_remove(BVH_ID[DT_triangles[9][triangleID] ])
                            triangulation_controller.DT_triangles.list_remove(triangleID) -- make old triangle data able to be overwritten
                        else
                            local v1, v2, v3 = DT_triangles[1][triangleID], DT_triangles[2][triangleID], DT_triangles[3][triangleID]
                            for k = 1, 3 do
                                AABB_min_buffer[k] = math.min(DT_vertices[k][v1], DT_vertices[k][v2], DT_vertices[k][v3])
                                AABB_max_buffer[k] = math.max(DT_vertices[k][v1], DT_vertices[k][v2], DT_vertices[k][v3])
                            end

                            local new_t = triangles.list_insert(triangles_buffer)
                            BVH_ID[new_t] = bvh.BVH_insert(new_t, AABB_min_buffer, AABB_max_buffer)
                            DT_triangleID[new_t] = triangleID
                        end
                    end
                    batch_sequence = not batch_sequence
                end
            end
        end

        if addedPoint or depth ~= prev_depth then
            addedPoint = false
            triangle_buffer = readBVH(bvh, depth)
        end
        prev_depth = depth
    end

    function onDraw()
        local vx, vy = triangulation_controller.DT_vertices[1], triangulation_controller.DT_vertices[3]
        for k = 1, #triangle_buffer do
            local t = DT_triangleID[triangle_buffer[k] ]
            local tv1, tv2, tv3 = triangulation_controller.DT_triangles[1], triangulation_controller.DT_triangles[2], triangulation_controller.DT_triangles[3]
            screen.setColor(colorR[k], colorG[k], colorB[k])
            screen.drawTriangleF(vx[tv1[t] ], vy[tv1[t] ], vx[tv2[t] ], vy[tv2[t] ], vx[tv3[t] ], vy[tv3[t] ])
        end

        screen.setColor(255,255,255)
        for i = 4, #triangulation_controller.DT_vertices[1] do
            screen.drawCircleF(vx[i], vy[i], 0.6)
        end
    end
end
--]]
---@endsection