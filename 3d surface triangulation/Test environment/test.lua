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
    simulator:setScreen(1, "16x16")
    simulator:setProperty("w", 16*32)
    simulator:setProperty("h", 16*32)
    simulator:setProperty("near", 0.25)
    simulator:setProperty("renderDistance", 1000)
    simulator:setProperty("sizeX", 0.7) --* 1.8)
    simulator:setProperty("sizeY", 0.7)
    simulator:setProperty("positionOffsetX", 0)
    simulator:setProperty("positionOffsetY", 0.01)

    simulator:setProperty("pxOffsetX", 0)
    simulator:setProperty("pxOffsetY", 0)

    simulator:setProperty("tick", 0)

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)

        -- touchscreen defaults
        local screenConnection = simulator:getTouchScreen(1)
        simulator:setInputBool(1, true) -- screenConnection.isTouched)
        --[[
        simulator:setInputNumber(1, screenConnection.width)
        simulator:setInputNumber(2, screenConnection.height)
        simulator:setInputNumber(3, screenConnection.touchX)
        simulator:setInputNumber(4, screenConnection.touchY)
        --]]

        simulator:setInputNumber(1, (simulator:getSlider(1) - 0) * 10)
        simulator:setInputNumber(2, (simulator:getSlider(2) - 0) * 10)
        simulator:setInputNumber(3, (simulator:getSlider(3) - 0.5) * 25)
        simulator:setInputNumber(4, (simulator:getSlider(4)) * math.pi*2)
        simulator:setInputNumber(5, (simulator:getSlider(5)) * math.pi*2)
        simulator:setInputNumber(6, (simulator:getSlider(6)) * math.pi*2)
        simulator:setInputNumber(7, simulator:getSlider(7))
        simulator:setInputNumber(8, simulator:getSlider(8))

        -- NEW! button/slider options from the UI
        simulator:setInputBool(31, simulator:getIsClicked(1))       -- if button 1 is clicked, provide an ON pulse for input.getBool(31)

        simulator:setInputBool(32, simulator:getIsToggled(2))       -- make button 2 a toggle, for input.getBool(32)

    end;
end
---@endsection


--[====[ IN-GAME CODE ]====]

-- https://github.com/Jumper-44/Stormworks_AR-3D-Render/blob/master/Template/CameraTransform.lua
local tau = math.pi*2

local Clamp = function(x,s,l) return x < s and s or x > l and l or x end

-- Vector3 Class
local function Vec3(x,y,z) return
    {x=x or 0; y=y or 0; z=z or 0;
    add =       function(a,b)   return Vec3(a.x+b.x, a.y+b.y, a.z+b.z) end;
    sub =       function(a,b)   return Vec3(a.x-b.x, a.y-b.y, a.z-b.z) end;
    scale =     function(a,b)   return Vec3(a.x*b, a.y*b, a.z*b) end;
    dot =       function(a,b)   return (a.x*b.x + a.y*b.y + a.z*b.z) end;
    cross =     function(a,b)   return Vec3(a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x) end;
    len =       function(a)     return a:dot(a)^0.5 end;
    normalize = function(a)     return a:scale(1/a:len()) end;
    unpack =    function(a,...) return a.x, a.y, a.z, ... end}
end

local MatrixMultiplication = function(m1,m2)
    local r = {}
    for i=1,#m2 do
        r[i] = {}
        for j=1,#m1[1] do
            r[i][j] = 0
            for k=1,#m1 do
                r[i][j] = r[i][j] + m1[k][j] * m2[i][k]
            end
        end
    end
    return r
end

local MatMul3xVec3 = function(m,v)
    return Vec3(
        m[1][1]*v.x + m[2][1]*v.y + m[3][1]*v.z,
        m[1][2]*v.x + m[2][2]*v.y + m[3][2]*v.z,
        m[1][3]*v.x + m[2][3]*v.y + m[3][3]*v.z
    )
end

local MatrixTranspose = function(m)
    local r = {}
    for i=1,#m[1] do
        r[i] = {}
        for j=1,#m do
            r[i][j] = m[j][i]
        end
    end
    return r
end

local getRotationMatrixZYX = function(ang)
    local sx,sy,sz, cx,cy,cz = math.sin(ang.x),math.sin(ang.y),math.sin(ang.z), math.cos(ang.x),math.cos(ang.y),math.cos(ang.z)
    return {
        {cy*cz,                 cy*sz,               -sy,       0},
        {-cx*sz + sx*sy*cz,     cx*cz + sx*sy*sz,    sx*cy,     0},
        {sx*sz + cx*sy*cz,      -sx*cz + cx*sy*sz,   cx*cy,     0},
        {0,                     0,                   0,         1}
    }
end

local position, linearVelocity = Vec3(), Vec3() -- Y-axis is up
local angle, angularVelocity = Vec3(), Vec3()
local isRendering, isFemale = false, false
local perspectiveProjectionMatrix, rotationMatrixZYX, cameraTransformMatrix, cameraTranslation = {}, {}, {}, Vec3()
local OFFSET = {}
--#endregion Initialization

--#region Settings
local SCREEN = {
    w = property.getNumber("w"),
    h = property.getNumber("h"),
    near = property.getNumber("near") + 0.625,
    far = property.getNumber("renderDistance"),
    sizeX = property.getNumber("sizeX"),
    sizeY = property.getNumber("sizeY"),
    positionOffsetX = property.getNumber("positionOffsetX"),
    positionOffsetY = property.getNumber("positionOffsetY")
}

SCREEN.r = SCREEN.sizeX/2  + SCREEN.positionOffsetX
SCREEN.l = -SCREEN.sizeX/2 + SCREEN.positionOffsetX
SCREEN.t = SCREEN.sizeY/2  + SCREEN.positionOffsetY
SCREEN.b = -SCREEN.sizeY/2 + SCREEN.positionOffsetY

OFFSET.GPS_to_camera = Vec3(
    property.getNumber("x"),
    property.getNumber("y"),
    property.getNumber("z")
)

OFFSET.tick = property.getNumber("tick")/60
--#endregion Settings


-- https://github.com/Jumper-44/Stormworks_AR-3D-Render/blob/master/Template/Render.lua
--#region Settings
local px_cx, px_cy = property.getNumber("w")/2, property.getNumber("h")/2
local px_cx_pos, px_cy_pos = px_cx + property.getNumber("pxOffsetX"), px_cy + property.getNumber("pxOffsetY")
--#endregion Settings

--#region Initialization
local getNumber = function(...)
    local r = {...}
    for i = 1, #r do r[i] = input.getNumber(r[i]) end
    return table.unpack(r)
end

local cameraTransform, cameraTranslation = {}, {}
--#endregion Initialization

--#region Render Function(s)
local WorldToScreen_points = function(points)
    local point_buffer = {}

    for i = 1, #points do
        local X, Y, Z, W =
            points[i][1] - cameraTranslation.x,
            points[i][2] - cameraTranslation.y,
            points[i][3] - cameraTranslation.z,
            0

        X,Y,Z,W =
            cameraTransform[1]*X + cameraTransform[5]*Y + cameraTransform[9]*Z,                         -- + cameraTransform[13],
            cameraTransform[2]*X + cameraTransform[6]*Y + cameraTransform[10]*Z,                        -- + cameraTransform[14],
            cameraTransform[3]*X + cameraTransform[7]*Y + cameraTransform[11]*Z + cameraTransform[13],  -- + cameraTransform[15],
            cameraTransform[4]*X + cameraTransform[8]*Y + cameraTransform[12]*Z                         -- + cameraTransform[16]

        -- is the point within the frustum
        if 0<=Z and Z<=W  and  -W<=X and X<=W  and  -W<=Y and Y<=W then
            W = 1/W
            -- point := {x[0;width], y[0;height], depth[0;1]}
            point_buffer[#point_buffer+1] = {X*W*px_cx + px_cx_pos, Y*W*px_cy + px_cy_pos, Z*W}
        end
    end

    return point_buffer
end

-- A triangle_buffer consist of {v1, v2, v3, color}
-- 'v = {x,y,z,id}'
-- 'color = {r,g,b}'
-- The 5th index for every triangle will be set to {tv1, tv2, tv3, triangle_depth}' by the function. 'tv' is the triangle transformed vertex
local WorldToScreen_triangles = function(triangle_buffer, isRemovingOutOfViewTriangles)
    local vertices_buffer = {}

    for i = #triangle_buffer, 1, -1 do -- Reverse iteration, so indexes can be removed from triangle_buffer while traversing if 'isRemovingOutOfViewTriangles == true'
        local currentTriangle, transformed_vertices = triangle_buffer[i], {}

        -- Loop is for finding or calculating the 3 transformed_vertices of currentTriangle
        for j = 1, 3 do
            local currentVertex = currentTriangle[j]
            local id = currentVertex[4]

            if vertices_buffer[id] == nil then -- is the transformed vertex NOT already calculated
                local X, Y, Z, W =
                    currentVertex[1] - cameraTranslation.x,
                    currentVertex[2] - cameraTranslation.y,
                    currentVertex[3] - cameraTranslation.z,
                    0

                X,Y,Z,W =
                    cameraTransform[1]*X + cameraTransform[5]*Y + cameraTransform[9]*Z,                         -- + cameraTransform[13],
                    cameraTransform[2]*X + cameraTransform[6]*Y + cameraTransform[10]*Z,                        -- + cameraTransform[14],
                    cameraTransform[3]*X + cameraTransform[7]*Y + cameraTransform[11]*Z + cameraTransform[13],  -- + cameraTransform[15],
                    cameraTransform[4]*X + cameraTransform[8]*Y + cameraTransform[12]*Z                         -- + cameraTransform[16]

                if 0<=Z and Z<=W then -- Is vertex between near and far plane
                    local w = 1/W
                    transformed_vertices[j] = {
                        X*w*px_cx + px_cx_pos, -- x
                        Y*w*px_cy + px_cy_pos, -- y
                        Z*w,                   -- z | depth[0;1]
                        -W<=X and X<=W  and  -W<=Y and Y<=W -- Is vertex in frustum
                    }
                    vertices_buffer[id] = transformed_vertices[j]
                else
                    vertices_buffer[id] = false
                    transformed_vertices[j] = false
                end
            else
                transformed_vertices[j] = vertices_buffer[id]
            end
        end

        local v1, v2, v3 = transformed_vertices[1], transformed_vertices[2], transformed_vertices[3]
        if
            v1 and v2 and v3                                                                            -- Are all vertices within near and far plane
            and (v1[4] or v2[4] or v3[4])                                                               -- and atleast 1 visible in frustum
            and (v1[1]*v2[2] - v2[1]*v1[2] + v2[1]*v3[2] - v3[1]*v2[2] + v3[1]*v1[2] - v1[1]*v3[2] > 0) -- and is the triangle facing the camera (backface culling CCW. Flip '>' for CW. Can be removed if triangles aren't consistently ordered CCW/CW)
        then
            currentTriangle[5] = {
                v1,
                v2,
                v3,
                v1[3] + v2[3] + v3[3] -- triangle depth for doing painter's algorithm
            }
        elseif isRemovingOutOfViewTriangles then
            table.remove(triangle_buffer, i)
        else
            currentTriangle[5] = false
        end
    end

    -- painter's algorithm
    table.sort(triangle_buffer,
        function(t1,t2)
            return t1[5] and t2[5] and (t1[5][4] > t2[5][4])
        end
    )
end
--#endregion Render Function(s)


function onTick()
    isRendering = input.getBool(1)
    output.setBool(1, isRendering)

    if isRendering then
        isFemale = input.getBool(2)

        position = Vec3(getNumber(1, 2, 3))
        angle = Vec3(getNumber(4, 5, 6))
        linearVelocity = Vec3(getNumber(7, 8, 9))
        angularVelocity = Vec3(getNumber(10, 11, 12))

        local lookX, lookY = input.getNumber(13), input.getNumber(14)

        -- CameraTransform calculation
        do ------{ Player Head Position }------
            local headAzimuthAng =    Clamp(lookX, -0.277, 0.277) * 0.408 * tau -- 0.408 is to make 100° to 40.8°
            local headElevationAng =  Clamp(lookY, -0.125, 0.125) * 0.9 * tau + 0.404 + math.abs(headAzimuthAng/0.7101) * 0.122 -- 0.9 is to make 45° to 40.5°, 0.404 rad is 23.2°. 0.122 rad is 7° at max yaw.

            local distance = math.cos(headAzimuthAng) * 0.1523
            head_position_offset = Vec3(
                math.sin(headAzimuthAng) * 0.1523,
                math.sin(headElevationAng) * distance -(isFemale and 0.141 or 0.023),
                math.cos(headElevationAng) * distance +(isFemale and 0.132 or 0.161)
            )
            -----------------------------------

            --{ Perspective Projection Matrix Setup }--
            local n = SCREEN.near - head_position_offset.z
            local f = SCREEN.far
            local r = SCREEN.r    - head_position_offset.x
            local l = SCREEN.l    - head_position_offset.x
            local t = SCREEN.t    - head_position_offset.y
            local b = SCREEN.b    - head_position_offset.y

            -- Looking down the +Z axis, +X is right and +Y is up. Projects to x|y:coordinates [-1;1], z:depth [0;1], w:homogeneous coordinate
            perspectiveProjectionMatrix = {
                {2*n/(r-l),         0,              0,              0},
                {0,                 2*n/(b-t),      0,              0},
                {-(r+l)/(r-l),      -(b+t)/(b-t),   f/(f-n),        1},
                {0,                 0,              -f*n/(f-n),     0}
            }

            rotationMatrixZYX = MatrixMultiplication(getRotationMatrixZYX(angularVelocity:scale(OFFSET.tick*tau)), getRotationMatrixZYX(angle))

            -- No translationMatrix due to just subtracting cameraTranslation from vertices before matrix multiplication with the cameraTransform
            cameraTranslation =
                MatMul3xVec3( rotationMatrixZYX, OFFSET.GPS_to_camera:add(head_position_offset) ) -- gps offset
                :add( MatMul3xVec3(rotationMatrixZYX, linearVelocity):scale(OFFSET.tick) ) -- Tick compensation
                :add( position )

            cameraTransformMatrix = MatrixMultiplication(perspectiveProjectionMatrix, MatrixTranspose(rotationMatrixZYX))
        end

        for i = 1, 3 do
            for j = 1, 4 do
                --output.setNumber((i-1)*4 + j, cameraTransformMatrix[i][j])
                cameraTransform[(i-1)*4 + j] = cameraTransformMatrix[i][j]
            end
        end
        cameraTransform[13] = cameraTransformMatrix[4][3]
        --output.setNumber(13, cameraTransformMatrix[4][3])
        --output.setNumber(14, cameraTranslation.x)
        --output.setNumber(15, cameraTranslation.y)
        --output.setNumber(16, cameraTranslation.z)
    end

end

function onDraw()
    if isRendering then

    end
end

















---@section __RENDER_DEBUG__
--[[ debug in VSCode for drawing points with WorldToScreen_points()
do
    local data = {}
    local rand = math.random
    for i = 1, 1E3 do
        data[i] = {(rand()-0.5)*50, (rand()-0.5)*50, (rand())*100}
    end

    -- linearize depth[0;1]
    -- zNear * zFar / (zFar + d * (zNear - zFar))
    local n,f = 0.25, 1000
    local n_mul_f = n*f
    local n_sub_f = n-f
    local t1,t2 = 0,0

    function onDraw()
        t1 = os.clock()

        if isRendering then
            local points_buffer = WorldToScreen_points(data)

            for i = 1, #points_buffer do
                local d = n_mul_f/(f + points_buffer[i][3]*n_sub_f)

                screen.setColor(d, 255-d, 0, 200)
                screen.drawCircleF(points_buffer[i][1], points_buffer[i][2], 0.6)
            end

            screen.setColor(255,0,0)
            screen.drawText(0,00, "in view: "..#points_buffer)
        end

        t2 = os.clock()
        screen.drawText(0,10, string.format("Elapsed time (sec): %.3f", t2-t1))
    end
end
--]]

-- [[ debug in VSCode for drawing traingles with WorldToScreen_triangles()
do

    --#region local unit cube data
    local unitCubePoints = {
        {-0.5, -0.5, -0.5},
        { 0.5, -0.5, -0.5},
        { 0.5,  0.5, -0.5},
        {-0.5,  0.5, -0.5},
        {-0.5, -0.5,  0.5},
        { 0.5, -0.5,  0.5},
        { 0.5,  0.5,  0.5},
        {-0.5,  0.5,  0.5}
    }

    local cubeTriangleOrder = { -- CW wounding order
        {1, 2, 3}, -- Back face -z
        {1, 3, 4},
        {5, 7, 6}, -- Front face +z
        {5, 8, 7},
        {1, 5, 6}, -- Bottom face -y
        {1, 6, 2},
        {4, 3, 7}, -- Top face +y
        {4, 7, 8},
        {1, 4, 8}, -- Left face -x
        {1, 8, 5},
        {2, 6, 7}, -- Right face +x
        {2, 7, 3}
    }

    local cubeColors = {
        {255, 255, 0}, -- Back face -z (Yellow)
        {255, 255, 0},
        {0, 255, 0}, -- Front face +z (Green)
        {0, 255, 0},
        {0, 255, 255}, -- Bottom face -y (Cyan)
        {0, 255, 255},
        {0, 0, 255}, -- Top face +y (Blue)
        {0, 0, 255},
        {255, 0, 255}, -- Left face -x (Magenta)
        {255, 0, 255},
        {255, 0, 0}, -- Right face +x (Red)
        {255, 0, 0}
    }
    --#endregion local unit cube data

    local MakeCube = function(triangle_buffer, translation, angle, size, id_offset)
        local sx,sy,sz, cx,cy,cz = math.sin(angle[1]),math.sin(angle[2]),math.sin(angle[3]), math.cos(angle[1]),math.cos(angle[2]),math.cos(angle[3])
        local rotXYZ = { -- http://www.songho.ca/opengl/gl_anglestoaxes.html
            {cy*cz,     sx*sy*cz+cx*sz,     -cx*sy*cz+sx*sz },
            {-cy*sz,    -sx*sy*sz+cx*cz,    cx*sy*sz+sx*cz  },
            {sy,        -sx*cy,             cx*cy           }
        }

        -- Get vertices of rotated unitCube
        local vertices = MatrixMultiplication(rotXYZ, unitCubePoints)

        for i = 1, 8 do
            -- set vertex id
            vertices[i][4] = i + id_offset*8

            for j = 1, 3 do
                -- Scale rotated unitCube by 'size' and add translation
                vertices[i][j] = vertices[i][j]*size + translation[j]
            end
        end

        -- Make triangle_buffer
        for i = 1, 12 do
            triangle_buffer[i + id_offset*12] = {
                vertices[ cubeTriangleOrder[i][2] ], -- Swap these 2 to change wounding order of CCW and CW
                vertices[ cubeTriangleOrder[i][1] ], -- 
                vertices[ cubeTriangleOrder[i][3] ],
                cubeColors[i]
            }
        end

        return triangle_buffer
    end


    local cubesAmount = 200
    local cubesPos = {}
    local cubesSize = {}
    local cubesAng = {}

    local rand = math.random
    for i = 1, cubesAmount do
        cubesPos[i] = {(rand()-0.5)*150, (rand()-0.5)*150, rand()*150}
        cubesSize[i] = rand()*7+1
        cubesAng[i] = {ang = {0, 0, 0}, deltaChange = {(rand()-0.5)*0.1, (rand()-0.5)*0.1, (rand()-0.5)*0.1}}
    end

    local t1,t2 = 0,0
    local changingSize = 0.1

    function onDraw()
        t1 = os.clock()

        if isRendering then
            local triangle_buffer = {}

            changingSize = changingSize + 0.05
            MakeCube(triangle_buffer, {3, 3, 30}, {0, 0, 0}, math.sin(changingSize)*4, 0)

            for i = 1, cubesAmount do
                for j = 1, 3 do
                    cubesAng[i].ang[j] = cubesAng[i].ang[j] + cubesAng[i].deltaChange[j]
                end
                MakeCube(triangle_buffer, cubesPos[i], cubesAng[i].ang, cubesSize[i], i)
            end

            WorldToScreen_triangles(triangle_buffer, true)

            for i = 1, #triangle_buffer do
                local tri = triangle_buffer[i][5]

                if tri then
                    local color = triangle_buffer[i][4]
                    screen.setColor(color[1], color[2], color[3], 200)
                    screen.drawTriangleF(tri[1][1], tri[1][2], tri[2][1], tri[2][2], tri[3][1], tri[3][2])
                end
            end

            screen.setColor(255,255,255)
            screen.drawText(0,0, "#Tri_Buffer: "..#triangle_buffer)
        end

        t2 = os.clock()
        screen.setColor(255, 255, 255)
        screen.drawText(0,10, string.format("Elapsed time (sec): %.3f", t2-t1))
    end
end
--]]
---@endsection