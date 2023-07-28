require("3d surface triangulation.kdtree")

---@class SurfaceTriangulation
---@section SurfaceTriangulation 1 _SURFACE_TRIANGULATION_
---comment
---@return table
SurfaceTriangulation = function()
    local sub = function(p1, p2) return {p1[1] - p2[1], p1[2] - p2[2], p1[3] - p2[3]} end
    local dot = function(p1, p2) return p1[1] * p2[1] + p1[2] * p2[2] + p1[3] * p2[3] end
    local cross = function(p1, p2) return {
        p1[2] * p2[3] - p1[3] * p2[2],
        p1[3] * p2[1] - p1[1] * p2[3],
        p1[1] * p2[2] - p1[2] * p2[1]
    } end
    local det3d = function(a, b, c) return
        a[1]   * (b[2] * c[3] - c[2] * b[3])
        - b[1] * (a[2] * c[3] - c[2] * a[3])
        + c[1] * (a[2] * b[3] - b[2] * a[3])
    end

-- Inlined in NewTetrahedron()
--  local function orient3d(pa, pb, pc, pd)
--      return det3d(sub(pa, pd), sub(pb, pd), sub(pc, pd))
--  end

-- Inlined in repeat until loop where checking for invalid tetrahedra
--    local function insphere(tetrahedron, point)
--        local ae, be, ce, de = sub(tetrahedron[1], point), sub(tetrahedron[2], point), sub(tetrahedron[3], point), sub(tetrahedron[4], point)
--        return dot(de, de) * det3d(ae, be, ce) - dot(ce, ce) * det3d(de, ae, be) + dot(be, be) * det3d(ce, de, ae) - dot(ae, ae) * det3d(be, ce, de)
--    end


    local kdtree, vertices, triangle_action_queue = IKDTree(3), {},
        { -- https://www.lua.org/pil/11.4.html
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
        local avgCenter, orient = {}, det3d(sub(pointA, pointD), sub(pointB, pointD), sub(pointC, pointD)) > 0

        local tetrahedron = {
            orient and pointA or pointB,
            orient and pointB or pointA,
            pointC,
            pointD,
            triangles = {},
            neighbors = {},
            avgCenter = avgCenter,
            isInvalid = false,
            isChecked = false
        }

        for i = 1, 3 do -- Slight random variation in coordinates, as this IKDTree doesn't handle well if coordinates are equal
            avgCenter[i] = 0.25 * (pointA[i] + pointB[i] + pointC[i] + pointD[i]) + (math.random() - 0.5) * 1e-6
        end

        avgCenter.tetrahedron = tetrahedron
        kdtree.IKDTree_insert(avgCenter)

        return tetrahedron
    end

    ---@section __TETRAHEDRA_DEBUG__
--    local tetrahedra_debug = {}
--    local invalid_tetrahedra_debug = {}
    ---@endsection

    -- Init super-tetrahedron
    local p1, p2, p3, p4 =
        {0,     1e5,    0,      id = -1},
        {-1e6,  -1e2,   0,      id = -2},
        {1e6,   -1e2,   1e6,    id = -3},
        {1e6,   -1e2,   -1e6,   id = -4}
    NewTetrahedron(p1, p2, p3, p4).triangles = {
        NewTriangle(p2, p3, p4),
        NewTriangle(p3, p4, p1),
        NewTriangle(p4, p1, p2),
        NewTriangle(p1, p2, p3)
    }


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
                local ae, be, ce, de = sub(current_tetrahedron[1], point), sub(current_tetrahedron[2], point), sub(current_tetrahedron[3], point), sub(current_tetrahedron[4], point)
                if dot(de, de) * det3d(ae, be, ce) - dot(ce, ce) * det3d(de, ae, be) + dot(be, be) * det3d(ce, de, ae) - dot(ae, ae) * det3d(be, ce, de) > -1e-9 then -- Insphere test
                    current_tetrahedron.isInvalid = true
                    invalid_tetrahedra[#invalid_tetrahedra+1] = current_tetrahedron

                    kdtree.IKDTree_remove(current_tetrahedron.avgCenter)
                    --if not kdtree.IKDTree_remove(current_tetrahedron.avgCenter) then error("Failed to remove avgCenter from k-d tree",1) end -- DEBUG

                    current_tetrahedron.avgCenter = nil -- To allow gb
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
            local boundary_facets, boundary_facet_tetrahedron_neighbor, shared_facets_hash, new_shared_facets = {}, {}, {}, {}

            for i = 1, #invalid_tetrahedra do
                local current_invalid_tetrahedron = invalid_tetrahedra[i]
                for j = 1, 4 do
                    local current_neighbor, current_facet = current_invalid_tetrahedron.neighbors[j], current_invalid_tetrahedron.triangles[j]

                    -- If facet doesn't have neighbor OR if neighbor exist and it is not invalid then add facet to boundary_facets
                    -- else then the current_neighbor.isInvalid and therefore the facet is shared
                    if not current_neighbor or not current_neighbor.isInvalid then
                        boundary_facets[#boundary_facets + 1] = current_facet
                        boundary_facet_tetrahedron_neighbor[#boundary_facets] = current_neighbor
                    else
                        shared_facets_hash[current_facet] = current_facet
                    end

                    current_invalid_tetrahedron.neighbors[j] = nil -- To allow gb
                end
            end

            -- If a shared facet/triangle from invalid_tetrahedra isSurface then queue it for removal in final mesh.
            for shared_facet in pairs(shared_facets_hash) do
                if shared_facet.isSurface then triangle_action_queue:pushleft(shared_facet, false) end
            end

            ---@section __TETRAHEDRA_DEBUG__
--            local new_tetrahedra_array_debug = {} -- DEBUG
            ---@endsection

            -- Construct new tetrahedra
            for i = 1, #boundary_facets do
                local current_boundary_facet, current_boundary_facet_neighbor = boundary_facets[i], boundary_facet_tetrahedron_neighbor[i]
                local new_tetrahedron = NewTetrahedron(current_boundary_facet[1], current_boundary_facet[2], current_boundary_facet[3], point)

                ---@section __TETRAHEDRA_DEBUG__
--                tetrahedra_debug[new_tetrahedron] = new_tetrahedron -- DEBUG
--                new_tetrahedra_array_debug[#new_tetrahedra_array_debug+1] = new_tetrahedron -- DEBUG
                ---@endsection

                -- Setup the neighboring to the current_boundary_facet
                new_tetrahedron.triangles[4] = current_boundary_facet
                if current_boundary_facet_neighbor then
                    new_tetrahedron.neighbors[4] = current_boundary_facet_neighbor
                    for j = 1, 4 do
                        if current_boundary_facet_neighbor.triangles[j] == current_boundary_facet then
                            current_boundary_facet_neighbor.neighbors[j] = new_tetrahedron
                        end
                    end
                end


                -- Setup the neighboring to the new shared facets between the new tetrahedra
                for j = 1, 3 do
                    local v1, v2 = new_tetrahedron[j % 3 + 1], new_tetrahedron[(j+1) % 3 + 1]
                    local hash_index = v1.id < v2.id and v1.id.."@"..v2.id or v2.id.."@"..v1.id

                    if new_shared_facets[hash_index] then
                        local new_facet_and_tetrahedra_reference = new_shared_facets[hash_index]

                        new_tetrahedron.triangles[j] = new_facet_and_tetrahedra_reference[1]
                        new_tetrahedron.neighbors[j] = new_facet_and_tetrahedra_reference[2]
                        new_facet_and_tetrahedra_reference[2].neighbors[new_facet_and_tetrahedra_reference[3]] = new_tetrahedron
                        new_facet_and_tetrahedra_reference[3] = new_tetrahedron
                    else
                        local new_facet_and_tetrahedron_reference = {NewTriangle(v1, v2, point), new_tetrahedron, j}
                        new_tetrahedron.triangles[j] = new_facet_and_tetrahedron_reference[1]

                        new_shared_facets[hash_index] = new_facet_and_tetrahedron_reference
                        new_shared_facets[#new_shared_facets+1] = new_facet_and_tetrahedron_reference
                    end
                end
            end

            -- Determine if new shared facet/triangle should be part of the final mesh
            for i = 1, #new_shared_facets do
                local new_facet, new_t1, new_t2 = new_shared_facets[i][1], new_shared_facets[i][2], new_shared_facets[i][3]
                local v1, v2, v3 = new_facet[1], new_facet[2], new_facet[3]

                -- Don't if a vertex is part of the super-tetrahedron
                if not (v1.id < 0 or v2.id < 0 or v3.id < 0) then
                    --local v13, v23 = sub(v1, v3), sub(v2, v3)
                    --local cross_v = cross(v13, v23)
                    --local parallelogram_area_squared = dot(cross_v, cross_v)

                    if new_t1[1].id < 0 or new_t1[2].id < 0 or new_t1[3].id < 0 or new_t1[4].id < 0 or
                        new_t2[1].id < 0 or new_t2[2].id < 0 or new_t2[3].id < 0 or new_t2[4].id < 0
                    then
                        new_facet.isSurface = true
                        triangle_action_queue:pushleft(new_facet, true)
                    end
                end
            end



            ---@section __TETRAHEDRA_DEBUG__
--            for i = 1, #invalid_tetrahedra do
--                tetrahedra_debug[invalid_tetrahedra[i]] = nil
--                invalid_tetrahedra_debug[#invalid_tetrahedra_debug+1] = invalid_tetrahedra[i]
--
--                -- Any new tetrahedra have neighbor that is equal to a removed invalid tetrahedra?
--                for j = 1, #new_tetrahedra_array_debug do
--                    for k = 1, 4 do
--                        if invalid_tetrahedra[i] == new_tetrahedra_array_debug[j].neighbors[k] then error("Neighbor is equal to a removed invalid tetrahedron",1) end
--                        local neighbor = new_tetrahedra_array_debug[j].neighbors[k]
--                        if neighbor then
--                            for l = 1, 4 do
--                                if invalid_tetrahedra[i] == neighbor.neighbors[l] then error("Neighbor has neighbors equal to a removed invalid tetrahedron",1) end
--                            end
--                        end
--                    end
--                end
--            end
            ---@endsection
        end;
    }
end
---@endsection
