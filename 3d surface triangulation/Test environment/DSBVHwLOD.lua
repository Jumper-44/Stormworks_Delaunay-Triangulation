-- GitHub: https://github.com/Jumper-44

-- Archived/put aside for now, as an AABB BVH seem to be much less computationaly intensive than spherical volumes for frequent updates.
-- AABB implementation will also take up less chars, which is tight.
-- The desire for spherical volumes was just due to frustum culling spheres is faster, but haven't benchmarked actual difference it would make.


---(Not implemented) Dynamic Spherical Bounding Volume Hierarchy with Level Of Detail.
---Specifically for triangles part of a mesh.
---@return table
DSBVHwLOD = function()
    local add, sub, scale, dot, cross

    add = function(p1, p2) return {p1[1] + p2[1], p1[2] + p2[2], p1[3] + p2[3]} end
    sub = function(p1, p2) return {p1[1] - p2[1], p1[2] - p2[2], p1[3] - p2[3]} end
    scale = function(p, scalar) return {p[1] * scalar, p[2] * scalar, p[3] * scalar} end
    dot = function(p1, p2) return p1[1] * p2[1] + p1[2] * p2[2] + p1[3] * p2[3] end
    cross = function(p1, p2) return {
        p1[2] * p2[3] - p1[3] * p2[2],
        p1[3] * p2[1] - p1[1] * p2[3],
        p1[1] * p2[2] - p1[2] * p2[1]
    } end

    ---https://www.jasondavies.com/maps/circle-tree/  
    ---table = {x, y, z, radius}
    ---@param sA table
    ---@param sB table
    ---@return table
    local mergeSpheres = function(sA, sB)
        local AB, distance, radiusA, radiusB, radiusC, sC
        if sA[4] > sB[4] then sA, sB = sB, sA end

        AB = sub(sB, sA)
        distance = dot(AB, AB)^0.5
        radiusA, radiusB = sA[4], sB[4]

        if distance + radiusA <= radiusB then return sB end

        radiusC = (radiusA + distance + radiusB) * 0.5
        sC = add(scale(AB, (radiusC - radiusA)/distance), sA)
        sC[4] = radiusC
        return sC
    end

    ---If the triangle is acute then the circumscribed circle is the smallest sphere,
    ---else if the triangle is obtuse, then it is the sphere enclosing the 2 opposite vertices of the obtuse angle,
    ---in which the obtuse angled vertex is enclosed too.  
    ---param v = {p1, p2, p3}, 'v' for vertices  
    ---p = {x, y, z}  
    ---returns sphere: {x, y, z, radius}
    ---@param v table
    ---@return table
    local getMinSphereOfTriangle = function(v)
        -- 'p21, p32, p13': triangle sides vectors. 't': arbitrary table name. 'n': norm vec3. 'd': vec3 pointing from a vertex to sphere center. 'p0': calculated sphere
        local p21, p32, p13, t, maxVal, maxValIndex, n, d, p0
        p21, p32, p13 = sub(v[2], v[1]), sub(v[3], v[2]), sub(v[1], v[3])
        t = {p21, p32, p13, dot(p21, p21), dot(p32, p32), dot(p13, p13)} -- table used for being able to index in a triangle winding order

        maxVal = math.max(t[4], t[5], t[6])
        maxValIndex = maxVal == t[4] and 1 or maxVal == t[5] and 2 or 3
        if t[maxValIndex + 3] > t[maxValIndex % 3 + 4] + t[(maxValIndex + 1) % 3 + 4] then -- is triangle obtuse (c^2 > a^2 + b^2), in which 'c' is the longest side
            d = scale(t[maxValIndex], 0.5)
            p0 = add(d, v[maxValIndex])
        else -- calculate circumcircle
            n = cross(p21, p13)
            d = scale(
                cross(
                    sub( scale(p13, -t[4]), scale(p21, t[6]) )
                ,n), -0.5 / dot(n, n)
            )
            p0 = add(d, v[1])
        end

        p0[4] = dot(d, d)^0.5 -- radius
        return p0 -- sphere : {x, y, z, r}
    end

    local getFrustumPlanes = function(cameraTransform)
        local planes = {}
        -- ...
        return planes
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