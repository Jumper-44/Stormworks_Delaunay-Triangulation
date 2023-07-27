require("3d surface triangulation.kdtree")

---@class SurfaceTriangulation
---@section SurfaceTriangulation 1 _SURFACE_TRIANGULATION_
---comment
---@return table
SurfaceTriangulation = function()
    ---@section GetCircumCircle
    ---!Not used!
    ---Returns the circumcircle of three points that make up a triangle in 3d, so points are assumed to be non-collinear.
    ---Math from https://en.wikipedia.org/wiki/Circumcircle#Higher_dimensions
    ---@param pointA table
    ---@param pointB table
    ---@param pointC table
    ---@return table
    local GetCircumCircle = function(pointA, pointB, pointC)
        local ca_x, ca_y, ca_z,  cb_x, cb_y, cb_z =
            pointA[1] - pointC[1],
            pointA[2] - pointC[2],
            pointA[3] - pointC[3],
            pointB[1] - pointC[1],
            pointB[2] - pointC[2],
            pointB[3] - pointC[3]

        local ca_len2, cb_len2 =
            ca_x * ca_x + ca_y * ca_y + ca_z * ca_z,
            cb_x * cb_x + cb_y * cb_y + cb_z * cb_z

        -- cpv = circumcircle_center_partial_vector = (||a||² b - ||b||² a)
        local cpv_x, cpv_y, cpv_z, ca_cb_cross_x, ca_cb_cross_y, ca_cb_cross_z =
            ca_len2 * cb_x - cb_len2 * ca_x,
            ca_len2 * cb_y - cb_len2 * ca_y,
            ca_len2 * cb_z - cb_len2 * ca_z,
            ca_y * cb_z - ca_z * cb_y,
            ca_z * cb_x - ca_x * cb_z,
            ca_x * cb_y - ca_y * cb_x

        -- d = 2||a × b||²
        local inv_d = 0.5 / (ca_cb_cross_x * ca_cb_cross_x + ca_cb_cross_y * ca_cb_cross_y + ca_cb_cross_z * ca_cb_cross_z)

        -- (cpv × ca_cb_cross) * inv_d
        local dx, dy, dz =
            (cpv_y * ca_cb_cross_z - cpv_z * ca_cb_cross_y) * inv_d,
            (cpv_z * ca_cb_cross_x - cpv_x * ca_cb_cross_z) * inv_d,
            (cpv_x * ca_cb_cross_y - cpv_y * ca_cb_cross_x) * inv_d

        return {
            pointC[1] + dx,                 -- x
            pointC[2] + dy,                 -- y
            pointC[3] + dz,                 -- z
            dx * dx + dy * dy + dz * dz     -- r*r
        }
    end
    ---@endsection



    local sub = function(p1, p2) return {p1[1] - p2[1], p1[2] - p2[2], p1[3] - p2[3]} end
    local dot = function(p1, p2) return p1[1] * p2[1] + p1[2] * p2[2] + p1[3] * p2[3] end
    local cross = function(p1, p2) return {p1[2] * p2[3] - p1[3] * p2[2], p1[3] * p2[1] - p1[1] * p2[3], p1[1] * p2[2] - p1[2] * p2[1]} end

    ---Returns the circumsphere of four points that make up a tetrahedron, so points are assumed to be non-collinear.
    ---Math from https://math.stackexchange.com/a/2414870
    ---@param pointA table
    ---@param pointB table
    ---@param pointC table
    ---@param pointD table
    ---@return table
    local GetCircumSphere = function(pointA, pointB, pointC, pointD)
        local AB, AC, AD, AO = sub(pointB, pointA), sub(pointC, pointA), sub(pointD, pointA), {}

        local AB_len2, AC_len2, AD_len2,  cross_AC_AD, cross_AD_AB, cross_AB_AC =
            dot(AB, AB), dot(AC, AC), dot(AD, AD),
            cross(AC, AD), cross(AD, AB), cross(AB, AC)

        local inv_denominator = 0.5 / dot(AB, cross_AC_AD)

        for i = 1, 3 do
            AO[i] = (AB_len2 * cross_AC_AD[i] + AC_len2 * cross_AD_AB[i] + AD_len2 * cross_AB_AC[i]) * inv_denominator
        end

        return {
            pointA[1] + AO[1],  -- x
            pointA[2] + AO[2],  -- y
            pointA[3] + AO[3],  -- z
            dot(AO, AO)         -- r*r
        }
    end


    local kdtree = IKDTree(3)
    local vertices = {}
    local triangle_action_queue = { -- https://www.lua.org/pil/11.4.html
        first = 0; last = -1;

        pushleft = function(self, triangle, isInserting_else_remove)
            local first = self.first - 1
            self.first = first
            self[first] = {triangle, isInserting_else_remove}
        end;
        popright = function(self)
            local last = self.last
            if self.first > last then return nil end
            local value = self[last]
            self[last] = nil         -- to allow garbage collection
            self.last = last - 1
            return value
        end
    }

    local NewTriangle = function(pointA, pointB, pointC)
        return {pointA, pointB, pointC, isSurface = false}
    end

    local NewTetrahedron = function(pointA, pointB, pointC, pointD)
        local sphere = GetCircumSphere(pointA, pointB, pointC, pointD)

        local tetrahedron = {
            pointA, pointB, pointC, pointD,
            triangles = {},
            neighbors = {},
            circumSphere = sphere,
            isInvalid = false,
            isChecked = false
        }

        sphere.tetrahedron = tetrahedron

        for i = 1, 3 do -- Slight random variation in coordinates, as this IKDTree doesn't handle well if coordinates are equal
            sphere[i] = sphere[i] + (math.random() - 0.5) * 1e-9
        end
        kdtree.IKDTree_insert(sphere)

        return tetrahedron
    end

    ---@section __TETRAHEDRA_DEBUG__
    local tetrahedra_debug = {}
    ---@endsection

    do -- Init super-tetrahedron
        local p1, p2, p3, p4 =
            {0,     1e4,    0,      id = -1},
            {-1e3,  -1e2,   0,      id = -2},
            {1e3,   -1e2,   1e3,    id = -3},
            {1e3,   -1e2,   -1e3,   id = -4}
        local superTerahedron = NewTetrahedron(p1, p2, p3, p4)
        superTerahedron.triangles = {
            NewTriangle(p2, p3, p4),
            NewTriangle(p3, p4, p1),
            NewTriangle(p4, p1, p2),
            NewTriangle(p1, p2, p3)
        }

        ---@section __TETRAHEDRA_DEBUG__
        tetrahedra_debug[superTerahedron] = superTerahedron
        ---@endsection
    end

    return {
        vertices = vertices;
        triangle_action_queue = triangle_action_queue;

        insert = function(point)
            -- Do Bowyer-Watson Algorithm
            local vertices_size, tetrahedra_check_queue, invalid_tetrahedra, tetrahedra_check_queue_pointer =
                #vertices + 1,
                kdtree.IKDTree_nearestNeighbors(point, 1),
                {}, 1
            vertices[vertices_size] = point
            point.id = vertices_size

            for i = 1, #tetrahedra_check_queue do
                tetrahedra_check_queue[i] = tetrahedra_check_queue[i].tetrahedron
                tetrahedra_check_queue[i].isChecked = true
            end

            -- Find all invalid tetrahedra
            repeat
                local current_tetrahedron = tetrahedra_check_queue[tetrahedra_check_queue_pointer]

                -- Is current_tetrahedron invalid?
                if kdtree.len2(point, current_tetrahedron.circumSphere) < current_tetrahedron.circumSphere[4] + 1e-9 then
                    current_tetrahedron.isInvalid = true
                    invalid_tetrahedra[#invalid_tetrahedra+1] = current_tetrahedron

                    --kdtree.IKDTree_remove(current_tetrahedron.circumSphere)
                    if not kdtree.IKDTree_remove(current_tetrahedron.circumSphere) then error("Failed to remove circumsphere from k-d tree",1) end -- DEBUG

                    current_tetrahedron.circumSphere = nil -- To allow gb
                end

                -- If current_tetrahedron is invalid OR no invalid tetrahedra has been found yet then try add neighboring tetrahedra to check queue
                if current_tetrahedron.isInvalid or #invalid_tetrahedra == 0 then
                    for i = 1, 4 do
                        local current_neighbor = current_tetrahedron.neighbors[i]

                        -- if neighbor exist and has not been checked yet then add to queue
                        if current_neighbor and not current_neighbor.isChecked then

                            tetrahedra_check_queue[#tetrahedra_check_queue+1] = current_neighbor
                            current_neighbor.isChecked = true
                        end
                    end
                end

                tetrahedra_check_queue_pointer = tetrahedra_check_queue_pointer + 1
            until #tetrahedra_check_queue < tetrahedra_check_queue_pointer

            -- reset isChecked state for checked tetrahedra
            for i = 1, #tetrahedra_check_queue do
                tetrahedra_check_queue[i].isChecked = false
            end

            -- Now the invalid_tetrahedra makes up a polyhedron
            -- Find all facets/triangles that are not shared and shared in invalid_tetrahedra
            local polyhedron_facets, polyhedron_facet_tetrahedron_neighbor, shared_facets_hash = {}, {}, {}

            for i = 1, #invalid_tetrahedra do
                local current_tetrahedron = invalid_tetrahedra[i]
                for j = 1, 4 do
                    local current_neighbor, current_facet = current_tetrahedron.neighbors[j], current_tetrahedron.triangles[j]

                    -- If facet doesn't have neighbor OR if neighbor exist and it is not invalid then add facet to polyhedron_facets
                    -- else then the current_neighbor.isInvalid and therefore the facet is shared
                    if not current_neighbor or not current_neighbor.isInvalid then
                        local polyhedron_facets_size = #polyhedron_facets + 1
                        polyhedron_facets[polyhedron_facets_size] = current_facet
                        polyhedron_facet_tetrahedron_neighbor[polyhedron_facets_size] = current_neighbor
                    else
                        shared_facets_hash[current_facet] = current_facet
                    end

                    current_tetrahedron.neighbors[j] = nil
                end
            end

            -- If a shared facet/triangle from invalid_tetrahedra isSurface then queue it for removal in final mesh.
            for shared_facet in pairs(shared_facets_hash) do
                if shared_facet.isSurface then triangle_action_queue:pushleft(shared_facet, false) end
            end

            ---@section __TETRAHEDRA_DEBUG__
            local new_tetrahedra_array_debug = {} -- DEBUG
            ---@endsection

            -- Construct new tetrahedra
            local new_shared_facets_array, new_shared_facets_hash = {}, {}

            for i = 1, #polyhedron_facets do
                local current_polyhedron_facet, current_polyhedron_facet_neighbor = polyhedron_facets[i], polyhedron_facet_tetrahedron_neighbor[i]
                local new_tetrahedron = NewTetrahedron(current_polyhedron_facet[1], current_polyhedron_facet[2], current_polyhedron_facet[3], point)

                ---@section __TETRAHEDRA_DEBUG__
                tetrahedra_debug[new_tetrahedron] = new_tetrahedron -- DEBUG
                new_tetrahedra_array_debug[#new_tetrahedra_array_debug+1] = new_tetrahedron -- DEBUG
                ---@endsection

                -- Setup the neighboring to the current_polyhedron_facet
                new_tetrahedron.triangles[4] = current_polyhedron_facet
                if current_polyhedron_facet_neighbor then
                    new_tetrahedron.neighbors[4] = current_polyhedron_facet_neighbor
                    for j = 1, 4 do
                        if current_polyhedron_facet_neighbor.triangles[j] == current_polyhedron_facet then
                            current_polyhedron_facet_neighbor.neighbors[j] = new_tetrahedron
                            break
                        end
                    end
                end

                -- Setup the neighboring to the new shared facets between the new tetrahedra
                for j = 1, 3 do
                    local v1, v2 = new_tetrahedron[j % 3 + 1], new_tetrahedron[(j+1) % 3 + 1]
                    local hash_index = v1.id < v2.id and v1.id.."@"..v2.id or v2.id.."@"..v1.id

                    if new_shared_facets_hash[hash_index] then
                        local new_facet_and_tetrahedra_reference = new_shared_facets_hash[hash_index]

                        new_tetrahedron.triangles[j] = new_facet_and_tetrahedra_reference[1]
                        new_tetrahedron.neighbors[j] = new_facet_and_tetrahedra_reference[2]
                        new_facet_and_tetrahedra_reference[2].neighbors[new_facet_and_tetrahedra_reference[3]] = new_tetrahedron
                        new_facet_and_tetrahedra_reference[3] = new_tetrahedron
                    else
                        local new_facet_and_tetrahedron_reference = {NewTriangle(v1, v2, point), new_tetrahedron, j}
                        new_tetrahedron.triangles[j] = new_facet_and_tetrahedron_reference[1]

                        new_shared_facets_hash[hash_index] = new_facet_and_tetrahedron_reference
                        new_shared_facets_array[#new_shared_facets_array+1] = new_facet_and_tetrahedron_reference
                    end
                end
            end

            -- Determine if new shared facet/triangle should be part of the final mesh
            for i = 1, #new_shared_facets_array do
                local new_facet, new_t1, new_t2 = new_shared_facets_array[i][1], new_shared_facets_array[i][2], new_shared_facets_array[i][3]
                local v1, v2, v3 = new_facet[1], new_facet[2], new_facet[3]

                -- Don't if a vertex is part of the super-tetrahedron
                if not (v1.id < 0 or v2.id < 0 or v3.id < 0) then
                    new_facet.isSurface = true
                    triangle_action_queue:pushleft(new_facet, true)
                end
            end

            ---@section __TETRAHEDRA_DEBUG__
            for i = 1, #invalid_tetrahedra do
                tetrahedra_debug[invalid_tetrahedra[i]] = nil

                -- Any new tetrahedra have neighbor that is equal to a removed invalid tetrahedra?
                for j = 1, #new_tetrahedra_array_debug do
                    for k = 1, 4 do
                        if invalid_tetrahedra[i] == new_tetrahedra_array_debug[j].neighbors[k] then error("Neighbor is equal to a removed invalid tetrahedron",1) end
                        local neighbor = new_tetrahedra_array_debug[j].neighbors[k]
                        if neighbor then
                            for l = 1, 4 do
                                if invalid_tetrahedra[i] == neighbor.neighbors[l] then error("Neighbor has neighbors equal to a removed invalid tetrahedron",1) end
                            end
                        end
                    end
                end

                -- Also test all current valid tetrahedra for reference to invalid tetrahedra
                for t in pairs(tetrahedra_debug) do
                    for k = 1, 4 do
                        if invalid_tetrahedra[i] == t.neighbors[k] then error("Neighbor is equal to a removed invalid tetrahedron",1) end
                    end
                end
            end
            ---@endsection
        end;
    }
end
---@endsection