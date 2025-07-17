-- Author: Jumper
-- GitHub: https://github.com/Jumper-44
-- Workshop: https://steamcommunity.com/profiles/76561198084249280/myworkshopfiles/
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)


-- require https://github.com/Jumper-44/Stormworks_JumperLib
require("DataStructures.JL_list") -- list{}, main point of this is to initialize and organize multiple tables in array and not hashmap part
require("newTables") -- helper function that returns *n* new tables by 'newTables{n}' -> '{}, {}, ...n'
require("DataStructures.Ball_Tree3D")


---@param str string
---@param t table
---@overload fun(str: string):table
function strToNumbers(str, t)
    t = t and t or {}
    for w in property.getText(str):gmatch"[+%w.-]+" do
        t[#t+1] = tonumber(w)
    end
    return t
end

---@param str string
---@param t table
function multiReadPropertyNumbers(str, t)
    for w in property.getText(str):gmatch"[^!]+" do
        strToNumbers(w, t)
    end
    return t
end

-- globally scoped locals
local v_x, v_y, v_z, v_near_dtriangle, v_sx, v_sy, v_sz, v_inNearAndFar, v_isVisible, v_frame,                          --v shorthand for vertex
    t_v1, t_v2, t_v3, t_colorR, t_colorG, t_colorB, t_cx, t_cy, t_cz, -- t_centroidDepth,                                                    --t shorthand for triangle
    dt_v1, dt_v2, dt_v3, dt_neighbor1, dt_neighbor2, dt_neighbor3, dt_isChecked, dt_isInvalid, dt_isSurface,            --dt shorthand for delaunay triangle
    dtriangle_check_queue, invalid_dtriangles, edge_boundary_neighbor, edge_boundary_v1, edge_boundary_v2, edge_shared,
    vertices, vertices_balltree, vertices_buffer, triangles, triangles_buffer, dtriangles, dtriangles_neighbors, dtriangles_buffer,
    traingle_balltree, check_queue, check_queue_ptr, check_queue_size,
    cameraTransform, triangleDrawBuffer,
    pointSub, add_vertex, add_dtriangle, -- functions
    px_cx, px_cy, px_cx_pos, px_cy_pos, frustumPlanes,
    v1, v2, v3,
    nChild1, nChild2, nx, ny, nz, nr, nBucket, x, y, z, w, X, Y, Z

local SCREEN, HMD, pointBuffer, point_min_density_squared, max_triangle_size_squared, triangle_buffer_refreshrate, max_drawn_triangles, colors =
    multiReadPropertyNumbers("SCREEN", {}),
    {256, 192, 128, 96, 128, 96}, -- {width, height, width/2, height/2, width/2, height/2}
    {0,0,0},
    property.getNumber("Min_D"), property.getNumber("Max_T"),
    property.getNumber("TBR"),   property.getNumber("MDT"),
    {{flat = strToNumbers "WF", steep = strToNumbers "WS"}, {flat = strToNumbers "GF", steep = strToNumbers "GS"}} -- colors = {color_water, color_ground}

--local SCREEN = {
--  [1]  w              -- Pixel width of screen
--  [2]  h              -- Pixel height of screen
--  [3]  near           -- Distance to near plane in meters, but added offset. So "near" is the distance from the end of (compact) seat model to the screen. I.e how many blocks between (compact) seat and screen divided by 4.
--  [4]  far            -- Distance to far plane in meters, max render distance
--  [5]  sizeX          -- Physical sizeX/width of screen in meters. (Important that it is the actual screen part with pixels and not model width)
--  [6]  sizeY          -- Physical sizeY/height of screen in meters. (Important that it is the actual screen part with pixels and not model height)
--  [7]  posOffsetX     -- Physical offset in the XY plane along X:right in meters.
--  [8]  posOffsetY     -- Physical offset in the XY plane along Y:up in meters. (HUD screen is 0.01 m offset in the model)
--  [9]  pxOffsetX      -- Pixel offset on screen, not applied to HMD
--  [10] pxOffsety      -- Pixel offset on screen, not applied to HMD
--}


---Helper function to reduce chars for arithemetic vector operation
---Returns the 2d vector coordinates that is locally relative to point 'a' and points to point 'b'
---@param a integer
---@param b integer
---@return number, number
function pointSub(a, b)
    return v_x[a]-v_x[b], v_z[a]-v_z[b]
end

---Insert new point in ball-tree and list of vertices
---@param x number world x-coordinate
---@param y number world y-coordinate
---@param z number world z-coordinate
---@return integer vertexID
function add_vertex(x, y, z, pointID)
    vertices_buffer[1] = x
    vertices_buffer[2] = y
    vertices_buffer[3] = z
    pointID = vertices.list_insert(vertices_buffer)
    vertices_balltree.BT_insert(pointID)
    return pointID
end

---@param v1 integer
---@param v2 integer
---@param v3 integer
---@return integer
function add_dtriangle(v1, v2, v3, adx, ady, bdx, bdy, ccw) -- checking sign of 2d determinant to set triangle orientation and inserts triangle in list
    adx, ady = pointSub(v1, v3)
    bdx, bdy = pointSub(v2, v3)
    ccw = adx * bdy - ady * bdx < 0
    dtriangles_buffer[1] = ccw and v1 or v2
    dtriangles_buffer[2] = ccw and v2 or v1
    dtriangles_buffer[3] = v3 -- note that the 3rd vertex stays the same, but 1 & 2 may swap to set orientation counterclockwise (CCW)
    return dtriangles.list_insert(dtriangles_buffer)
end

---initialize or reset state
function initialize()
    v_x, v_y, v_z, v_near_dtriangle, v_sx, v_sy, v_sz, v_inNearAndFar, v_isVisible, v_frame,
    t_v1, t_v2, t_v3, t_colorR, t_colorG, t_colorB, t_cx, t_cy, t_cz, -- t_centroidDepth,
    dt_v1, dt_v2, dt_v3, dt_neighbor1, dt_neighbor2, dt_neighbor3, dt_isChecked, dt_isInvalid, dt_isSurface,
    dtriangle_check_queue, invalid_dtriangles, edge_boundary_neighbor, edge_boundary_v1, edge_boundary_v2, edge_shared,
    fPlaneRight, fPlaneLeft, fPlaneBottom, fPlaneTop, fPlaneBack, fPlaneFront,
    check_queue,
    cameraTransform, triangleDrawBuffer = newTables{43}

    frustumPlanes = {fPlaneRight, fPlaneLeft, fPlaneBottom, fPlaneTop, fPlaneBack, fPlaneFront}

    vertices = list{v_x, v_y, v_z, v_near_dtriangle, v_sx, v_sy, v_sz, v_inNearAndFar, v_isVisible, v_frame}
    vertices_balltree = BallTree3D(v_x, v_y, v_z)
    vertices_buffer = {0,0,0, 1, 0,0,0, false,false,0}

    triangles = list{t_v1, t_v2, t_v3, t_colorR, t_colorG, t_colorB, t_cx, t_cy, t_cz} -- ,t_centroidDepth}
    triangles_buffer = {0,0,0, 0,0,0, 0,0,0} --,0}

    -- dt_v1-3        : <integer>       = delaunay triangle vertex 1-3
    -- dt_neighbor1-3 : <false|integer> = delaunay triangle neighbor ID connected by the edge opposite to this triangle vertex number (false if no neighbor)
    -- dt_isChecked   : <integer>       = whether a delaunay triangle has been checked (or added to check queue) this tick
    -- dt_isInvalid   : <integer>       = whether a checked triangle this tick is illegal, i.e. new point is inside the triangle circumcircle
    -- dt_isSurface   : <false|integer> = whether a delaunay triangle is deemed to be part of the final visible mesh if it meets the custom threshold of size property
    dtriangles = list{dt_v1, dt_v2, dt_v3, dt_neighbor1, dt_neighbor2, dt_neighbor3, dt_isChecked, dt_isInvalid, dt_isSurface}
    dtriangles_neighbors = {dt_neighbor1, dt_neighbor2, dt_neighbor3}
    dtriangles_buffer = {0,0,0, false,false,false, false,false,false}

    insertionTick = 0
    frameTick = 0
    triangleDrawBufferSize = 0

    -- init super-triangle, roughly covers the playable area with islands
    add_vertex(-9E5, 0, -9E5)
    add_vertex(9E5,  0, -9E5)
    add_vertex(0,    0,  9E5)
    add_dtriangle(1, 2, 3)

    ---@cast t_cx table
    ---@cast t_cy table
    ---@cast t_cz table
    traingle_balltree = BallTree3D(t_cx, t_cy, t_cz)

    nChild1, nChild2, nx, ny, nz, nr, nBucket = table.unpack(traingle_balltree.BT_nodes)

    ---@param n  any    local variable
    ---@param sx any    local variable
    ---@param sy any    local variable
    ---@param sz any    local variable
    ---@param sr any    local variable
    ---@param b  any    local variable
    function frustumCull(n, sx, sy, sz, sr, b)
        triangleDrawBuffer = {}
        triangleDrawBufferSize = 0
        check_queue_ptr = 1
        check_queue_size = 1
        check_queue[1] = traingle_balltree.BT_rootID

        repeat
            n = check_queue[check_queue_ptr]
            sx = nx[n]
            sy = ny[n]
            sz = nz[n]
            sr = -nr[n]

            if not (
               (sx*fPlaneRight[1]  + sy*fPlaneRight[2]  + sz*fPlaneRight[3]  + fPlaneRight[4]  < sr) or
               (sx*fPlaneLeft[1]   + sy*fPlaneLeft[2]   + sz*fPlaneLeft[3]   + fPlaneLeft[4]   < sr) or
               (sx*fPlaneBottom[1] + sy*fPlaneBottom[2] + sz*fPlaneBottom[3] + fPlaneBottom[4] < sr) or
               (sx*fPlaneTop[1]    + sy*fPlaneTop[2]    + sz*fPlaneTop[3]    + fPlaneTop[4]    < sr) or
               (sx*fPlaneBack[1]   + sy*fPlaneBack[2]   + sz*fPlaneBack[3]   + fPlaneBack[4]   < sr) or
               (sx*fPlaneFront[1]  + sy*fPlaneFront[2]  + sz*fPlaneFront[3]  + fPlaneFront[4]  < sr))
            then
                b = nBucket[n]
                if b then
                    for i = 1, #b do
                        triangleDrawBufferSize = triangleDrawBufferSize + 1
                        triangleDrawBuffer[triangleDrawBufferSize] = b[i]
                    end
                else
                    check_queue_size = check_queue_size + 2
                    check_queue[check_queue_size-1] = nChild1[n]
                    check_queue[check_queue_size]   = nChild2[n]
                end
            end

            check_queue_ptr = check_queue_ptr + 1
        until check_queue_ptr > check_queue_size

-- AABB culling
--        repeat ---@cast check_queue table
--            n = check_queue[check_queue_ptr]
--
--            if nItem[n] then -- since currently leaf node only contain 1 triangle, then just allow
--                triangleDrawBufferSize = triangleDrawBufferSize + 1
--                triangleDrawBuffer[triangleDrawBufferSize] = nItem[n]
--                goto continue
--            end
--
--            x = nxMin[n]
--            y = nyMin[n]
--            z = nzMin[n]
--            X = nxMax[n]
--            Y = nyMax[n]
--            Z = nzMax[n]
--
--            for i = 1, 6 do ---@cast i +table
--                i = frustumPlanes[i]
--                px = i[1]*x
--                pX = i[1]*X
--                py = i[2]*y
--                pY = i[2]*Y
--                pz = i[3]*z
--                pZ = i[3]*Z
--                i  = -i[4]
--
--                if  (px + py + pz < i) and
--                    (pX + py + pz < i) and
--                    (px + pY + pz < i) and
--                    (pX + pY + pz < i) and
--                    (px + py + pZ < i) and
--                    (pX + py + pZ < i) and
--                    (px + pY + pZ < i) and
--                    (pX + pY + pZ < i)
--                then
--                    goto continue
--                end
--            end
--
--            --if nItem[n] then
--            --    triangleDrawBufferSize = triangleDrawBufferSize + 1
--            --    triangleDrawBuffer[triangleDrawBufferSize] = nItem[n]
--            --else
--            check_queue_size = check_queue_size + 2
--            check_queue[check_queue_size-1] = nChild1[n]
--            check_queue[check_queue_size]   = nChild2[n]
--            --end
--
--            ::continue::
--            check_queue_ptr = check_queue_ptr + 1
--        until check_queue_ptr > check_queue_size
    end
end
initialize()


---https://en.wikipedia.org/wiki/Delaunay_triangulation#Algorithms  
---https://www.cs.cmu.edu/afs/cs/project/quake/public/code/predicates.c  
---https://github.com/mourner/robust-predicates/tree/main  
---May try to replicate a more robust version by above links, but takes a lot of chars,  
---so maybe need some form of custom bytecode interpreter by string input to do so.  
---Some people have reported crashing that I haven't been able to replicate,  
---which may be due to floating point error for all I know,  
---as I haven't encountered any script crashes in game.  
---@param v1 integer
---@param v2 integer
---@param v3 integer
---@param p integer
---@return number
function incirclefast(v1, v2, v3, p)
    adx, ady = pointSub(v1, p)
    bdx, bdy = pointSub(v2, p)
    cdx, cdy = pointSub(v3, p)

    return (adx * adx + ady * ady) * (bdx * cdy - cdx * bdy)
         + (bdx * bdx + bdy * bdy) * (cdx * ady - adx * cdy)
         + (cdx * cdx + cdy * cdy) * (adx * bdy - bdx * ady)
end

---If the triangle is acute then the circumscribed circle is the smallest circle,
---else if the triangle is obtuse, then it is the circle enclosing the 2 opposite vertices of the obtuse angle,
---in which the obtuse angled vertex is enclosed too.
---@param v1 integer
---@param v2 integer
---@param v3 integer
---@return number radius_squared
function min_enclosing_circleradius_of_triangle(v1, v2, v3)
    abx, aby = pointSub(v2, v1)
    bcx, bcy = pointSub(v3, v2)
    cax, cay = pointSub(v1, v3)

    -- triangle side lengths squared
    ab = abx*abx + aby*aby
    bc = bcx*bcx + bcy*bcy
    ca = cax*cax + cay*cay

    -- reusing table 'triangles_buffer' to reduce chars
    triangles_buffer[1] = ab
    triangles_buffer[2] = bc
    triangles_buffer[3] = ca
    maxVal = (ab >= bc and ab >= ca) and 1 or (bc >= ab and bc >= ca) and 2 or 3
    return (triangles_buffer[maxVal] > triangles_buffer[maxVal%3+1] + triangles_buffer[(maxVal+1)%3+1])
        and (triangles_buffer[maxVal] / 4)                                  -- if triangle is obtuse (c² > a² + b²), in which 'c' is the longest side, then r² = c²/4, else
        or (ab*bc*ca / (2*(ab*(bc + ca) + bc*ca) -ab*ab -bc*bc -ca*ca))     -- Circumradius:  r = a*b*c / sqrt((a+b+c) * (-a+b+c) * (a-b+c) * (a+b-c))    ->    r² = a²b²c² / (2(a²(b² + c²) + b²c²) -a^4 -b^4 -c^4)
end

---2.5D delaunay triangulation with Boywer-Watson algorithm. O(n*log n) average insertion.  
---Each new triangle is evaluated if part of final mesh by the radius of minimum enclosing circle of triangle.  
---@param nearVertexID integer
---@param point table {x, y, z}, point is assumed to be within super-triangle. Will fail and soon crash if outside super-triangle
function dt_insert_point(nearVertexID, point)
    local pointID, new_triangle, current_boundary_neighbor, hash_index, shared_triangle, current_triangle, current_neighbor, triangle_check_queue_pointer, triangle_check_queue_size, invalid_triangles_size, edge_boundary_size

    dtriangle_check_queue[1] = v_near_dtriangle[nearVertexID] -- Jump to a near dtriangle to 'point'. Keypoint for going from O(n*n) to O(n*log n) on average, as neighboring triangle search can be done
    dt_isChecked[dtriangle_check_queue[1]] = insertionTick
    triangle_check_queue_pointer = 1
    triangle_check_queue_size = 1
    invalid_triangles_size = 0
    pointID = add_vertex(table.unpack(point))

    repeat -- Find all invalid triangles, by walking around neighboring triangles till all invalid triangle(s) (which all touch each other) has been found
        current_triangle = dtriangle_check_queue[triangle_check_queue_pointer]

        if incirclefast(dt_v1[current_triangle], dt_v2[current_triangle], dt_v3[current_triangle], pointID) <= 0 then -- Is current_triangle invalid? || Is point inside circumcircle of current_triangle?
            dt_isInvalid[current_triangle] = true
            invalid_triangles_size = invalid_triangles_size + 1
            invalid_dtriangles[invalid_triangles_size] = current_triangle
        end

        if dt_isInvalid[current_triangle] or invalid_triangles_size == 0 then -- If current_triangle is invalid OR no invalid triangles has been found yet then try add neighboring triangles of current_triangle to check queue
            for i = 1, 3 do
                current_neighbor = dtriangles_neighbors[i][current_triangle]
                if current_neighbor and (dt_isChecked[current_neighbor] ~= insertionTick) then -- if neighbor exist and has not been checked yet then add to check queue
                    triangle_check_queue_size = triangle_check_queue_size + 1
                    dtriangle_check_queue[triangle_check_queue_size] = current_neighbor
                    dt_isChecked[current_neighbor] = insertionTick
                end
            end
        end

        triangle_check_queue_pointer = triangle_check_queue_pointer + 1
    until triangle_check_queue_size < triangle_check_queue_pointer

    edge_boundary_size = 0
    for i = 1, invalid_triangles_size do 
        current_triangle = invalid_dtriangles[i]
        for j = 1, 3 do -- Now the invalid_triangles makes up a polygon. Find the boundary edge of invalid_triangles
            current_neighbor = dtriangles_neighbors[j][current_triangle]
            if not (current_neighbor and dt_isInvalid[current_neighbor]) then -- If edge doesn't have neighbor OR if neighbor exist and it is not invalid then add as edge_boundary, else then the edge neighbor is an invalid triangle (Don't care about shared edge of invalid triangles)
                edge_boundary_size = edge_boundary_size + 1
                edge_boundary_neighbor[edge_boundary_size] = current_neighbor
                edge_boundary_v1[edge_boundary_size] = dtriangles[j % 3 + 1][current_triangle]
                edge_boundary_v2[edge_boundary_size] = dtriangles[(j+1) % 3 + 1][current_triangle]
            end
        end

        if dt_isSurface[current_triangle] then
            i = dt_isSurface[current_triangle]
            triangles.list_remove(i) -- mark invalid triangles of final mesh for removal, i.e. getting overwritten when new are added
            traingle_balltree.BT_remove(i)
        end

        dtriangles.list_remove(current_triangle) -- mark invalid triangles for removal, i.e. getting overwritten when new are added
    end

    for i = 1, edge_boundary_size do -- Construct new triangles and setup/maintain neighboring triangle references
        new_triangle = add_dtriangle(edge_boundary_v1[i], edge_boundary_v2[i], pointID)  -- assigned index to 'new_triangle'

        -- Set neighbor to the edge_boundary_neighbor and its neighbor (if exist) to new_triangle
        current_boundary_neighbor = edge_boundary_neighbor[i]
        dt_neighbor3[new_triangle] = current_boundary_neighbor
        if current_boundary_neighbor then -- if neighbor exist then find correct index to set neighbor reference to new_triangle
            for j = 1, 3 do -- Find index to the not shared vertex of neighboring triangle
                if not (dt_v1[new_triangle] == dtriangles[j][current_boundary_neighbor] or dt_v2[new_triangle] == dtriangles[j][current_boundary_neighbor]) then
                    dtriangles_neighbors[j][current_boundary_neighbor] = new_triangle
                    break
                end
            end
        end

        for j = 1, 2 do -- Setup neighboring between new triangles.
            -- All new triangles share the 3rd vertex. There are always a minimum of 3 new triangles.
            -- Use hash table and add 1st and 2nd vertices of new_triangle.
            -- Same vertex will only be encountered 2 times, when iterated through all new_triangles.
            -- The 2nd time the same vertex is tried to be added, then you know the triangle edge pair and can setup neighbor references.
            hash_index = dtriangles[j][new_triangle]
            shared_triangle = edge_shared[hash_index]
            if shared_triangle then -- Same vertex encountered
                dtriangles_neighbors[j%2+1][new_triangle] = shared_triangle  -- 'j%2+1' index works due to all triangles having same winding order
                dtriangles_neighbors[j][shared_triangle] = new_triangle      -- 'j'     index works due...
                edge_shared[hash_index] = nil                                -- clear index so hash table can be reused next new point insertion
            else -- First time seeing vertex
                edge_shared[hash_index] = new_triangle      -- Add first unencountered vertex to hash table
                v_near_dtriangle[hash_index] = new_triangle -- Update near triangle reference of vertex
            end
        end

        -- Test if triangle should be added to final mesh
        v1 = dt_v1[new_triangle]
        v2 = dt_v2[new_triangle]
        v3 = dt_v3[new_triangle]
        if min_enclosing_circleradius_of_triangle(v1, v2, v3) < max_triangle_size_squared then
            adz = v_z[v1]-v_z[v2]
            bdz = v_z[v2]-v_z[v3]

            -- crossproduct, but z-component is discarded
            cdx = (v_y[v1]-v_y[v2])*bdz - adz*(v_y[v2]-v_y[v3])
            cdy = adz*(v_x[v2]-v_x[v3]) - (v_x[v1]-v_x[v2])*bdz
                                                                    -- lightDirX, lightDirY = 0.28, -0.96  -- 0.28² + 0.96² = 1, light vector is normalized
            t = (0.28*cdx - 0.96*cdy) / (cdx*cdx + cdy*cdy)^0.5     -- (lightDirX*cdx + lightDirY*cdy) / cd_length
            t = t*t -- absoloute value and better curve
            inv_t = 1-t
            c = 0 > (v_y[v1] + v_y[v2] + v_y[v3]) and colors[1] or colors[2] -- is triangle centroid center less than 0, i.e. underwater

            for j = 1, 3 do
                triangles_buffer[j] = dtriangles[j][new_triangle]
                triangles_buffer[j+3] = (c.flat[j]*t + c.steep[j]*inv_t) * t*t*0.7 + 0.3 -- rgb

                i = vertices[j]
                triangles_buffer[j+6] = (i[v1] + i[v2] + i[v3])/3
            end

            t = triangles.list_insert(triangles_buffer)
            traingle_balltree.BT_insert(t)
            dt_isSurface[new_triangle] = t
        end
    end

    v_near_dtriangle[pointID] = new_triangle -- Set near triangle reference to new inserted point
    insertionTick = insertionTick + 1
end



--WorldToScreen_triangles_sortFunction = function(t1, t2)
--    return t_centroidDepth[t1] > t_centroidDepth[t2]
--end

WorldToScreen_triangles = function()
    local refreshCurrentFrame, currentTriangle, vertex_id, i
    refreshCurrentFrame = frameTick % triangle_buffer_refreshrate == 0

    if refreshCurrentFrame then
        frustumCull()
        debug = #triangleDrawBuffer
    end

    i = 1
    while i < triangleDrawBufferSize do
        currentTriangle = triangleDrawBuffer[i]

        for j = 1, 3 do
            vertex_id = triangles[j][currentTriangle]

            if v_frame[vertex_id] ~= frameTick then -- is the transformed vertex NOT already calculated
                v_frame[vertex_id] = frameTick

                X = v_x[vertex_id]
                Y = v_y[vertex_id]
                Z = v_z[vertex_id]

                x = cameraTransform[1]*X + cameraTransform[5]*Y + cameraTransform[9 ]*Z + cameraTransform[13]
                y = cameraTransform[2]*X + cameraTransform[6]*Y + cameraTransform[10]*Z + cameraTransform[14]
                z = cameraTransform[3]*X + cameraTransform[7]*Y + cameraTransform[11]*Z + cameraTransform[15]
                w = cameraTransform[4]*X + cameraTransform[8]*Y + cameraTransform[12]*Z + cameraTransform[16]

                v_inNearAndFar[vertex_id] = 0<=z and z<=w
                if v_inNearAndFar[vertex_id] then -- Is vertex between near and far plane
                    v_isVisible[vertex_id] = -w<=x and x<=w  and  -w<=y and y<=w -- Is vertex in frustum (excluded near and far plane test)

                    w = 1/w
                    v_sx[vertex_id] = x*w*px_cx + px_cx_pos
                    v_sy[vertex_id] = y*w*px_cy + px_cy_pos
                    v_sz[vertex_id] = z*w
                else
                    break
                end
            end
        end

        v1 = t_v1[currentTriangle]
        v2 = t_v2[currentTriangle]
        v3 = t_v3[currentTriangle]
        if -- (Most average cases) determining if triangle is visible / should be rendered
            v_inNearAndFar[v1] and v_inNearAndFar[v2] and v_inNearAndFar[v3]                                                                -- Are all vertices within near and far plane
            and (v_isVisible[v1] or v_isVisible[v2] or v_isVisible[v3])                                                                     -- and atleast 1 visible in frustum
            and (v_sx[v1]*v_sy[v2] - v_sx[v2]*v_sy[v1] + v_sx[v2]*v_sy[v3] - v_sx[v3]*v_sy[v2] + v_sx[v3]*v_sy[v1] - v_sx[v1]*v_sy[v3] > 0) -- and is the triangle facing the camera (backface culling CCW. Flip '>' for CW. Can be removed if triangles aren't consistently ordered CCW/CW)
        then
            --t_centroidDepth[currentTriangle] = v_sz[v1] + v_sz[v2] + v_sz[v3] -- centroid depth for sort
            i = i + 1
        else -- remove
            triangleDrawBuffer[i] = table.remove(triangleDrawBuffer)
            triangleDrawBufferSize = triangleDrawBufferSize - 1
        end
    end

    --if refreshCurrentFrame then
    --    table.sort(triangleDrawBuffer, WorldToScreen_triangles_sortFunction) -- painter's algorithm | triangle centroid depth sort
    --end

    for j = max_drawn_triangles+1, #triangleDrawBuffer do
        triangleDrawBuffer[j] = nil
    end
    triangleDrawBufferSize = #triangleDrawBuffer
end

function onTick()
    renderOn = input.getBool(1)

    if input.getBool(3) then -- reset/clear data
        initialize()
    end

    drawWireframe = input.getBool(4)

    if input.getBool(5) then -- is head mounted display (HMD)?
        width, height, px_cx, px_cy, px_cx_pos, px_cy_pos = table.unpack(HMD)
    else
        width  = SCREEN[1]
        height = SCREEN[2]
        px_cx  = width/2
        px_cy  = height/2
        px_cx_pos = px_cx + SCREEN[9]
        px_cy_pos = px_cy + SCREEN[10]
    end

    if renderOn then
        for i = 1, 16 do
            cameraTransform[i] = input.getNumber(i)
        end

        for i = 1, 6 do  -- extract frustum planes https://github.com/EQMG/Acid/blob/master/Sources/Physics/Frustum.cpp
            --local sign = (i%2*2-1) -- 1, -1, 1, -1, 1, -1
            for j = 1, 4 do
                frustumPlanes[i][j] = cameraTransform[j*4] + cameraTransform[(j-1)*4 + (i+1)//2] * (i%2*2-1)
            end

            -- normalize planes
            magnitude = (frustumPlanes[i][1]^2 + frustumPlanes[i][2]^2 + frustumPlanes[i][3]^2)^0.5
            for j = 1, 4 do
                frustumPlanes[i][j] = frustumPlanes[i][j] / magnitude
            end
        end

        -- solving for camera world position given 3 frustum planes (that isn't far or near plane), so linear system with 3 variables
        -- https://en.wikipedia.org/wiki/Cramer%27s_rule#Explicit_formulas_for_small_systems
        --local A, B, C, D, E, F
        --local a1, b1, c1, d1 = table.unpack(fPlaneRight)
        --local a2, b2, c2, d2 = table.unpack(fPlaneLeft)
        --local a3, b3, c3, d3 = table.unpack(fPlaneBottom)
        --A = b2*c3 - c2*b3
        --B = c2*a3 - a2*c3
        --C = a2*b3 - b2*a3
        --D = c2*d3 - d2*c3
        --E = d2*b3 - b2*d3
        --F = a2*d3 - d2*a3
        --d3 = -a1*A - b1*B - c1*C
        --cameraPos[1] = (d1*A + b1*D + c1*E) / d3
        --cameraPos[2] = (d1*B - a1*D + c1*F) / d3
        --cameraPos[3] = (d1*C - a1*E - b1*F) / d3

        color_alpha = 0
        for i = 25, 32 do
            color_alpha = color_alpha << 1 | (input.getBool(i) and 1 or 0)
        end
    end

    for i = 17, 29, 3 do -- read composite range [17;31], i.e. laser endpoint positions
        pointBuffer[1] = input.getNumber(i)
        pointBuffer[2] = input.getNumber(i+1)
        pointBuffer[3] = input.getNumber(i+2)

        if pointBuffer[1] ~= 0 and pointBuffer[2] ~= 0 then
            dist2, nearVertexID = vertices_balltree.BT_nnSearch(pointBuffer[1], pointBuffer[2], pointBuffer[3])

            if dist2 > point_min_density_squared then
                dt_insert_point(nearVertexID, pointBuffer)
            end
        end
    end
end


function onDraw()
    if renderOn then
        local prevColorHash, drawTri = 0, drawWireframe and screen.drawTriangle or screen.drawTriangleF

        WorldToScreen_triangles()
        for i = 1, triangleDrawBufferSize do
            i = triangleDrawBuffer[i]
            v1 = t_v1[i]
            v2 = t_v2[i]
            v3 = t_v3[i]

            colorHash = t_colorR[i]//10 << 16  |  t_colorG[i]//10 << 8  |  t_colorB[i]//16
            if prevColorHash ~= colorHash then
                prevColorHash = colorHash
                screen.setColor(t_colorR[i], t_colorG[i], t_colorB[i], color_alpha) -- setColor is roughly as expensive to call as drawTriangle
            end

            drawTri(v_sx[v1], v_sy[v1], v_sx[v2], v_sy[v2], v_sx[v3], v_sy[v3])
        end
        --screen.setColor(0, 0, 0, color_alpha)
        --screen.drawRectF(0, 0, width, height)
    end

    screen.setColor(0, 255, 0)
    screen.drawText(5,5, ("DT/T/View: %i/%i/%i"):format(#dt_v1, #t_v1, #triangleDrawBuffer))
    screen.drawText(5, 12, "Cull: "..tostring(debug))
    screen.drawText(5, 20, "MaxDepth: "..traingle_balltree.BT_nodes[9][traingle_balltree.BT_rootID])
    --screen.drawText(5, 13, ("Pos: %+0.6f / %+0.6f / %+0.6f"):format(cameraPos[1] or 0, cameraPos[2] or 0, cameraPos[3] or 0)) -- debug

    frameTick = frameTick + 1
end