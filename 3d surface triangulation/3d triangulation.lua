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

    local kdtree = KDTree()



    return {

    }
end
---@endsection
