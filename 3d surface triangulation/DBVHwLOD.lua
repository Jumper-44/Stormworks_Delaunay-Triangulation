-- GitHub: https://github.com/Jumper-44

---Dynamic Bounding Volume Hierarchy with Level Of Detail.
---Specifically for triangles part of a mesh.
---@return table
DBVHwLOD = function()
    local triangleAABB = function(tri)
        return {
            math.min(tri[1][1], tri[2][1], tri[3][1]),
            math.min(tri[1][2], tri[2][2], tri[3][2]),
            math.min(tri[1][3], tri[2][3], tri[3][3]),
            math.max(tri[1][1], tri[2][1], tri[3][1]),
            math.max(tri[1][2], tri[2][2], tri[3][2]),
            math.max(tri[1][3], tri[2][3], tri[3][3])
        }
    end

    local unionAABB = function(a, b)
        return {
            math.min(a[1], b[1]),
            math.min(a[2], b[2]),
            math.min(a[3], b[3]);
            math.max(a[4], b[4]);
            math.max(a[5], b[5]);
            math.max(a[6], b[6]);
        }
    end

    local surfaceAreaAABB = function(AABB)
        local dx, dy, dz = AABB[3] - AABB[1], AABB[5] - AABB[2], AABB[6] - AABB[3]
        return 2 * (dx * dy + dy * dz + dz * dx)
    end

    return {
        insert = function()

        end;

        remove = function()

        end;

        frustumCull = function(cameraTransform)

        end
    }
end