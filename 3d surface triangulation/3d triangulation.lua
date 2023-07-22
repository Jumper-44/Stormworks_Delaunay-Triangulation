require("3d surface triangulation.kdtree")

---@class SurfaceTriangulation
---@section SurfaceTriangulation 1 _SURFACE_TRIANGULATION_
---comment
---@return table
SurfaceTriangulation = function()
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
            x = pointC[1] + dx,
            y = pointC[2] + dy,
            z = pointC[3] + dz,
            r2 = dx * dx + dy * dy + dz * dz
        }
    end


    ---     C
    ---    / \
    ---   b   a
    ---  /     \
    --- A___c___B
    ---@param pointA table
    ---@param pointB table
    ---@param pointC table
    ---@param neighborTriangle_a table|false
    ---@param neighborTriangle_b table|false
    ---@param neighborTriangle_c table|false
    ---@return table
    local NewTriangle = function(pointA, pointB, pointC, neighborTriangle_a, neighborTriangle_b, neighborTriangle_c)
        return {
            pointA, pointB, pointC,
            neighborTriangle_a, neighborTriangle_b, neighborTriangle_c,
            GetCircumCircle(pointA, pointB, pointC), false
        }

    end

    local kdtree = KDTree(3)
    local triangle_action_queue = {
        ---comment
        ---@param self table
        ---@param triangle table
        ---@param add_or_rem boolean
        insert = function(self, triangle, add_or_rem)
            table.insert(self, 1, {triangle, add_or_rem})
        end
    }
    local point_minimum_neighboring_len2 = 1^2
    local point_maximum_neighboring_len2 = 10^2


    return {
        triangle_action_queue = triangle_action_queue;

        ---Returns true if point got inserted else false
        ---@param point table
        ---@return boolean
        insert = function(point)
            local neighbors = kdtree.KDTree_nearestNeighbors(point, 3)

            -- If no neighboring point exist then add point to k-d tree
            -- If neighboring point exist then test len2 to nearest point and add if greater than point_minimum_neighboring_len2.
            if not neighbors[1] or neighbors[1].len2 > point_minimum_neighboring_len2 then
                point.triangles = {}
                kdtree.KDTree_insert(point)

                if #neighbors >= 2 and #neighbors[1].triangles == 0 and #neighbors[2].triangles == 0 then
                    local new_triangle = NewTriangle(point, neighbors[1], neighbors[2], false, false, false)
                    point.triangles[1] = new_triangle
                    neighbors[1].triangles[1] = new_triangle
                    neighbors[2].triangles[1] = new_triangle
                    triangle_action_queue:insert(new_triangle, true)
                end

                
                --[[
                -- Check if new point makes any near triangles illegal and then try boywer-watson algorithm
                local illegal_triangles_queue = {}
                local checked_triangles = {}

                for i = 1, #neighbors do
                    for j = 1, #neighbors[i].triangles do
                        for k = 1, #checked_triangles do
                            if neighbors[i].triangles[j] == checked_triangles[k] then goto continue end
                        end

                        checked_triangles[#checked_triangles+1] = neighbors[i].triangles[j]

                        if kdtree.len2(point, neighbors[i].triangles[j][7]) < neighbors[i].triangles[j][7].r2 then
                            illegal_triangles_queue[#illegal_triangles_queue+1] = neighbors[i].triangles[j]
                        end
                        
                        ::continue::
                    end
                end
                --]]


                return true
            end
            return false
        end;
    }
end
---@endsection
