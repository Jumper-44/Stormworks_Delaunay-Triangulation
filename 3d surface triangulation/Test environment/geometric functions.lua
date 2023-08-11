-- GitHub: https://github.com/Jumper-44

local add = function(p1, p2) return {p1[1] + p2[1], p1[2] + p2[2], p1[3] + p2[3]} end
local sub = function(p1, p2) return {p1[1] - p2[1], p1[2] - p2[2], p1[3] - p2[3]} end
local scale = function(p, scalar) return {p[1] * scalar, p[2] * scalar, p[3] * scalar} end
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


---@section GetCircumCircleFast
---Returns the circumcircle of three points that make up a triangle in 3d, so points are assumed to be non-collinear.
---Math from https://en.wikipedia.org/wiki/Circumcircle#Higher_dimensions
---@param pointA table
---@param pointB table
---@param pointC table
---@return table
local GetCircumCircleFast = function(pointA, pointB, pointC)
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

local GetCircumscribedSphereCentersOfTriangle = function(p1, p2, p3, radius_squared)
    -- https://stackoverflow.com/a/11723659
    local p21, p31, n, n2, d, d2, p0, t
    p21, p31 = sub(p2, p1), sub(p3, p1)
    n = cross(p21, p31)
    n2 = dot(n, n)

    d = scale(
        cross(
            sub( scale(p31, dot(p21, p21)), scale(p21, dot(p31, p31)) )
        ,n), 0.5 / n2
    )
    d2 = dot(d, d)
    p0 = add(p1, d)

    if d2 > radius_squared then return false end
    t = ((radius_squared - d2) / n2)^0.5

    return add(scale(n, t), p0), add(scale(n, -t), p0)
end



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



-- https://www.cs.cmu.edu/afs/cs/project/quake/public/code/predicates.c

--- Return a positive value if the point pd lies below the     
--- plane passing through pa, pb, and pc; "below" is defined so
--- that pa, pb, and pc appear in counterclockwise order when  
--- viewed from above the plane.  Returns a negative value if  
--- pd lies above the plane.  Returns zero if the points are   
--- coplanar.  The result is also a rough approximation of six 
--- times the signed volume of the tetrahedron defined by the  
--- four points.
---@param pa table
---@param pb table
---@param pc table
---@param pd table
---@return number
local function orient3dfast(pa, pb, pc, pd)
    local adx, bdx, cdx
    local ady, bdy, cdy
    local adz, bdz, cdz

    adx = pa[1] - pd[1]
    bdx = pb[1] - pd[1]
    cdx = pc[1] - pd[1]
    ady = pa[2] - pd[2]
    bdy = pb[2] - pd[2]
    cdy = pc[2] - pd[2]
    adz = pa[3] - pd[3]
    bdz = pb[3] - pd[3]
    cdz = pc[3] - pd[3]

    return adx * (bdy * cdz - bdz * cdy)
         + bdx * (cdy * adz - cdz * ady)
         + cdx * (ady * bdz - adz * bdy)
end

local function orient3d(pa, pb, pc, pd)
    return det3d(sub(pa, pd), sub(pb, pd), sub(pc, pd))
end

local function inspherefast(pa, pb, pc, pd, pe)
    local aex, bex, cex, dex
    local aey, bey, cey, dey
    local aez, bez, cez, dez
    local alift, blift, clift, dlift
    local ab, bc, cd, da, ac, bd
    local abc, bcd, cda, dab

    aex = pa[1] - pe[1]
    bex = pb[1] - pe[1]
    cex = pc[1] - pe[1]
    dex = pd[1] - pe[1]
    aey = pa[2] - pe[2]
    bey = pb[2] - pe[2]
    cey = pc[2] - pe[2]
    dey = pd[2] - pe[2]
    aez = pa[3] - pe[3]
    bez = pb[3] - pe[3]
    cez = pc[3] - pe[3]
    dez = pd[3] - pe[3]

    ab = aex * bey - bex * aey
    bc = bex * cey - cex * bey
    cd = cex * dey - dex * cey
    da = dex * aey - aex * dey

    ac = aex * cey - cex * aey
    bd = bex * dey - dex * bey

    abc = aez * bc - bez * ac + cez * ab
    bcd = bez * cd - cez * bd + dez * bc
    cda = cez * da + dez * ac + aez * cd
    dab = dez * ab + aez * bd + bez * da

    alift = aex * aex + aey * aey + aez * aez
    blift = bex * bex + bey * bey + bez * bez
    clift = cex * cex + cey * cey + cez * cez
    dlift = dex * dex + dey * dey + dez * dez

    return (dlift * abc - clift * dab) + (blift * cda - alift * bcd)
end

local function insphere(pa, pb, pc, pd, pe)
    local ae, be, ce, de = sub(pa, pe), sub(pb, pe), sub(pc, pe), sub(pd, pe)
    return dot(de, de) * det3d(ae, be, ce) - dot(ce, ce) * det3d(de, ae, be) + dot(be, be) * det3d(ce, de, ae) - dot(ae, ae) * det3d(be, ce, de)
end



local p1, p2, p3, p4 =
    {0,     -1e1,    0   },
    {-1e1,  -1e1,   0   },
    {1e1,   -1e1,   1e1 },
    {1e1,   -1e1,   -1e1}

--print(orient3d(p1, p2, p3, p4))
--print(insphere(p1, p2, p3, p4, {0, -0.5, 0}))

local a, b = GetCircumscribedSphereCentersOfTriangle({-4.31, 2.46, 1.26}, {-5.67, 4.6, 3.13}, {-4.45, 5, 0.58}, 100)
print("break")