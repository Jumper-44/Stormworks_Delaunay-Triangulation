require("3d surface triangulation.kdtree")

---@class SurfaceTriangulation
---@section SurfaceTriangulation 1 _SURFACE_TRIANGULATION_
---comment
---@return table
SurfaceTriangulation = function()
    ---@section GetCircumCircle
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

        pushleft = function(self, triangle, add_or_rem)
            local first = self.first - 1
            self.first = first
            self[first] = {triangle, add_or_rem}
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
            vertices = {pointA, pointB, pointC, pointD},
            triangles = {false, false, false, false},
            neighbors = {false, false, false, false},
            circumSphere = sphere,
            isInvalid = false,
            isChecked = false
        }

        sphere.tetrahedron = tetrahedron
        kdtree.IKDTree_insert(sphere)

        return tetrahedron
    end

    do -- Init super-tetrahedron
        local p1, p2, p3, p4 =
            {0,     5e5,    0,      id = 0},
            {-9e5,  -3e4,   -9e5,   id = 0},
            {9e5,   -3e4,   9e5,    id = 0},
            {0,     -3e4,   9e5,    id = 0}
        local superTerahedron = NewTetrahedron(p1, p2, p3, p4)
        superTerahedron.triangles = {
            NewTriangle(p2, p3, p4),
            NewTriangle(p3, p4, p1),
            NewTriangle(p4, p1, p2),
            NewTriangle(p1, p2, p3)
        }
    end


    return {
        vertices = vertices;
        triangle_action_queue = triangle_action_queue;

        insert = function(point)
            -- Do Bowyer-Watson Algorithm
            local vertices_size, nearestCircumCenter_tetrahedron = #vertices + 1, kdtree.IKDTree_nearestNeighbors(point, 1).tetrahedron
            vertices[vertices_size] = point
            point.id = vertices_size

            nearestCircumCenter_tetrahedron.isChecked = true
            local invalid_tetrahedra, tetrahedra_check_queue, tetrahedra_check_queue_pointer = {}, {nearestCircumCenter_tetrahedron}, 1

            -- Find all invalid tetrahedra
            repeat
                local current_tetrahedron = tetrahedra_check_queue[tetrahedra_check_queue_pointer]

                -- Is current_tetrahedron invalid?
                if kdtree.len2(point, current_tetrahedron.circumSphere) < current_tetrahedron.circumSphere[4] then
                    current_tetrahedron.isInvalid = true
                    invalid_tetrahedra[#invalid_tetrahedra+1] = current_tetrahedron

                    current_tetrahedron.circumSphere.tetrahedron = nil
                    kdtree.IKDTree_remove(current_tetrahedron.circumSphere)
                end

                -- If current_tetrahedron is invalid OR no invalid tetrahedra has been found yet then try add neighboring tetrahedra to queue
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
            -- Find all facets that are not shared in invalid_tetrahedra
            local facets, facet_tetrahedron_neighbor = {}, {}

            for i = 1, #invalid_tetrahedra do
                local current_tetrahedron = invalid_tetrahedra[i]
                for j = 1, 4 do
                    local current_neighbor = current_tetrahedron.neighbors[j]

                    -- If facet doesn't have neighbor OR if neighbor exist and it is not invalid then add facet to table
                    if not current_neighbor or not current_neighbor.isInvalid then
                        local facets_size = #facets + 1
                        facets[facets_size] = current_tetrahedron.triangles[j]
                        facet_tetrahedron_neighbor[facets_size] = current_neighbor
                    end
                end
            end

            -- Construct new tetrahedra
            -- TODO
        end;
    }
end
---@endsection