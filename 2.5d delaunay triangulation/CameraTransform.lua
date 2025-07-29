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
    simulator:setScreen(1, "3x3")

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)
        simulator:setInputBool(1, true) -- renderOn = true

                                                                            -- Debug sliders
        simulator:setInputNumber(1, 100+(simulator:getSlider(1) - 0) * 10)      -- x position
        simulator:setInputNumber(2, 100+(simulator:getSlider(2) - 0) * 10)      -- y position
        simulator:setInputNumber(3, 100+(simulator:getSlider(3) - 0.5) * 25)    -- z position
        simulator:setInputNumber(4, (simulator:getSlider(4)) * math.pi*2)   -- x rotation
        simulator:setInputNumber(5, (simulator:getSlider(5)) * math.pi*2)   -- y rotation
        simulator:setInputNumber(6, (simulator:getSlider(6)) * math.pi*2)   -- z rotation
    end;
end
---@endsection

--[====[ IN-GAME CODE ]====]




-- https://github.com/Jumper-44/Stormworks_JumperLib
require('JumperLib.JL_general')
require('JumperLib.Math.JL_matrix_transformations') -- also includes JumperLib.Math.JL_matrix_operations and JumperLib.Math.JL_vector_operations
require("Utility.propertyToTable")


local position, linearVelocity, angle, angularVelocity, head_position_offset, cameraTranslation, tempVec1_3d, tempVec2_3d = {}, {}, {}, {}, {}, {}, {}, {}
local renderOn, OFFSET = false, {}
local tempMatrix1_3x3, tempMatrix2_3x3, tempMatrix1_4x4, tempMatrix2_4x4, translationMatrix, rotationMatrixZYX, perspectiveProjectionMatrix, cameraTransformMatrix =
    matrix_initIdentity(3, 3), matrix_initIdentity(3, 3),
    matrix_initIdentity(4, 4), matrix_initIdentity(4, 4),
    matrix_initIdentity(4, 4), matrix_initIdentity(4, 4), -- translationMatrix, rotationMatrixZYX
    matrix_init(4, 4), matrix_init(4, 4)                  -- perspectiveProjectionMatrix, cameraTransformMatrix


--#region Settings
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
local SCREEN = multiReadPropertyNumbers "S"
SCREEN.n = SCREEN[3] + 0.635
SCREEN.f = SCREEN[4]
SCREEN.r = SCREEN[5]/2  + SCREEN[7]
SCREEN.l = -SCREEN[5]/2 + SCREEN[7]
SCREEN.t = SCREEN[6]/2  + SCREEN[8]
SCREEN.b = -SCREEN[6]/2 + SCREEN[8]


local HMD = { -- HEAD_MOUNTED_DISPLAY
    w     = 256,
    h     = 192,
    vFov  = 1.014197,
    n     = 0.1, -- arbitrary picked value
    f     = SCREEN[4]}
HMD.t     = HMD.n * math.tan(HMD.vFov/2)
HMD.r     = HMD.t * 4/3   -- HMD.t * HMD.w / HMD.h
HMD.l     = -HMD.r
HMD.b     = -HMD.t

local l_vel_sf, l_vel_isf, l_acc_sf, l_acc_isf, l_jerk_sf, l_jerk_isf, l_t1, l_t2, l_t3
l_t1 = property.getNumber("SeatTick") -- seat lookX|Y tick compensation (velocity)
l_t2 = (l_t1+1)^2 / 2                                                -- (acceleration)
l_t3 = (l_t1+2)^3 / 6                                                -- (jerk)

l_vel_sf, l_acc_sf, l_jerk_sf = table.unpack(strToNumbers "Mouse (Vel, Acc, Jerk) Smoothing") -- example values are (0.875, 0.975, 0.999), jerk not really helping here and just doing jittery with this implementation, so may remove option later
l_vel_isf, l_acc_isf, l_jerk_isf = 1-l_vel_sf, 1-l_acc_sf, 1-l_jerk_sf
local l_ex, l_ey, l_x, l_y, l_dx, l_dy, l_ddx, l_ddy, l_dddx, l_dddy = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 -- nr. of 'd' are nr. of derivatives
local l_px, l_py, l_pdx, l_pdy, l_pddx, l_pddy = 0, 0, 0, 0, 0, 0 -- 'p' is previous
local lookXMax, lookXMin = 0.35, -0.35
local lookYMax, lookYMin = 0.2, -0.2

OFFSET.GPS_to_camera = strToNumbers "GPS_to_camera" -- Offset from physics sensor block to seat headrest block. (X:right, Y:up, Z:forward)
OFFSET.PhysicsTick = property.getNumber("PhysicsTick")/60 -- physics sensor tick compensation
--#endregion Settings


---Estimating mouse look X|Y with respect to velocity, acceleration and jerk  
---(jerk not really helping)
---with exponential smoothing to mitigate noisy/jittery movement
---@param new_lx number
---@param new_ly number
function lookXY_estimation(new_lx, new_ly)
    local dx, dy, ddx, ddy, dddx, dddy
    dx = new_lx - l_px
    dy = new_ly - l_py
    ddx  = dx   - l_pdx
    ddy  = dy   - l_pdy
    dddx = clamp(ddx  - l_pddx, -0.001, 0.001)
    dddy = clamp(ddy  - l_pddy, -0.001, 0.001)

    l_x    = new_lx
    l_y    = new_ly
    l_dx   = l_dx   * l_vel_sf  + dx   * l_vel_isf
    l_dy   = l_dy   * l_vel_sf  + dy   * l_vel_isf
    l_ddx  = l_ddx  * l_acc_sf  + ddx  * l_acc_isf
    l_ddy  = l_ddy  * l_acc_sf  + ddy  * l_acc_isf
    l_dddx = l_dddx * l_jerk_sf + dddx * l_jerk_isf
    l_dddy = l_dddy * l_jerk_sf + dddy * l_jerk_isf

    -- Don't predict if likely not moving mouse
    if math.abs(dx) < 1e-9 and math.abs(dy) < 1e-9 then
        l_ex = new_lx
        l_ey = new_ly
        l_dx = 0
        l_dy = 0
        l_ddx = 0
        l_ddy = 0
        l_dddx = 0
        l_dddy = 0
    else
        l_ex = clamp(l_x + l_dx*l_t1 + l_ddx*l_t2 + l_dddx*l_t3, lookXMin, lookXMax)
        l_ey = clamp(l_y + l_dy*l_t1 + l_ddy*l_t2 + l_dddy*l_t3, lookYMin, lookYMax)
    end

    l_px = new_lx
    l_py = new_ly
    l_pdx = dx
    l_pdy = dy
    l_pddx = ddx
    l_pddy = ddy
end



---Calculates an approximation of the player head position relative to the seat  
---Origin is the center block of the (compact) seat headrest block  
---result_vec3d will be a 3d vector in which forward is +zAxis, right is +xAxis, and up is +yAxis  
---In game experimental values pulled with CheatEngine, which this function then approxmates to: https://www.geogebra.org/classic/uaphpn2k  
---@param lookX number        from seat
---@param lookY number        from seat
---@param isFemale boolean    camera offset is different depending on character gender
---@param result_vec3d vec3d  table
function calcLocalHeadPosition(lookX, lookY, isFemale, result_vec3d)
    local headAzimuthAng   = clamp(lookX, -0.277, 0.277) * 0.408 * tau -- 0.408 is to make 100° to 40.8°
    local headElevationAng = clamp(lookY, -0.125, 0.125) * 0.9 * tau + 0.404 + math.abs(headAzimuthAng/0.7101) * 0.122 -- 0.9 is to make 45° to 40.5°, 0.404 rad is 23.2°. 0.122 rad is 7° at max yaw.

    local distance = math.cos(headAzimuthAng) * 0.1523
    vec_init3d(result_vec3d,
        math.sin(headAzimuthAng) * 0.1523,
        math.sin(headElevationAng) * distance -(isFemale and 0.141 or 0.023),
        math.cos(headElevationAng) * distance +(isFemale and 0.132 or 0.161)
    )
end

---Calculates the camera transform matrix = perspectiveProjectionMatrix * rotationMatrixZYX^T * translationMatrix
---@param result_matrix4x4 matrix4x4
function calcCameraTransform(isHMD, result_matrix4x4)
    if isHMD then
        matrix_getPerspectiveProjection_facingZ(
            HMD.n, -- near
            HMD.f, -- far
            HMD.r, -- right
            HMD.l, -- left
            HMD.t, -- top
            HMD.b, -- bottom
            perspectiveProjectionMatrix -- return
        )
    else
        matrix_getPerspectiveProjection_facingZ(
            SCREEN.n - head_position_offset[3], -- near
            SCREEN.f                          , -- far
            SCREEN.r - head_position_offset[1], -- right
            SCREEN.l - head_position_offset[1], -- left
            SCREEN.t - head_position_offset[2], -- top
            SCREEN.b - head_position_offset[2], -- bottom
            perspectiveProjectionMatrix -- return
        )
    end

    vec_scale(angularVelocity, OFFSET.PhysicsTick*tau, angularVelocity)
    matrix_mult( -- rotation matrix with tick compensation
        matrix_getRotZYX(angularVelocity[1],  angularVelocity[2], angularVelocity[3], tempMatrix1_3x3),
        matrix_getRotZYX(angle[1],            angle[2],           angle[3],           tempMatrix2_3x3),
        rotationMatrixZYX -- return
    )

    vec_add( -- cameraTranslation
        vec_add(
            matrix_multVec3d(rotationMatrixZYX, vec_add(OFFSET.GPS_to_camera, head_position_offset, tempVec1_3d), tempVec2_3d), -- XYZ offset to physics sensor
            vec_scale(matrix_multVec3d(rotationMatrixZYX, linearVelocity, tempVec1_3d), OFFSET.PhysicsTick, tempVec1_3d),       -- position tick compensation
            cameraTranslation -- return
        ),
        position,         -- XYZ of physics sensor
        cameraTranslation -- return
    )

    if isHMD then -- apply player head rotation if HMD
        matrix_mult(
            matrix_getRotY( l_ex * tau, tempMatrix1_3x3),
            matrix_getRotX(-l_ey * tau, tempMatrix2_3x3),
            tempMatrix1_4x4
        )

        matrix_mult(
            rotationMatrixZYX,
            tempMatrix1_4x4,
            tempMatrix2_4x4
        )

        matrix_transpose(tempMatrix2_4x4, tempMatrix1_4x4)
    else
        matrix_transpose(rotationMatrixZYX, tempMatrix1_4x4)
    end

    vec_scale(cameraTranslation, -1, translationMatrix[4]) -- set translation in translationMatrix

    -- cameraTransformMatrix = perspectiveProjectionMatrix * rotationMatrixZYX^T * translationMatrix
    matrix_mult(tempMatrix1_4x4, translationMatrix, tempMatrix2_4x4)
    matrix_mult(perspectiveProjectionMatrix, tempMatrix2_4x4, result_matrix4x4)
end



function onTick()
    renderOn = input.getBool(1)

    -- Passthrough composite
    for i = 17, 32 do
        output.setNumber(i, input.getNumber(i))
    end
    for i = 1, 32 do
        output.setBool(i, input.getBool(i))
    end

    if renderOn then
        do -- calc cameraTransformMatrix
            local isFemale, isHMD = input.getBool(2), input.getBool(5)

            vec_init3d(position,        getNumber3(1, 2, 3))    -- physics sensor
            vec_init3d(angle,           getNumber3(4, 5, 6))    -- physics sensor
            vec_init3d(linearVelocity,  getNumber3(7, 8, 9))    -- physics sensor
            vec_init3d(angularVelocity, getNumber3(10, 11, 12)) -- physics sensor

            local lookX = input.getNumber(13) -- lookX from seat
            local lookY = input.getNumber(14) -- lookY from seat

            lookXY_estimation(lookX, lookY)
            calcLocalHeadPosition(l_ex, l_ey, isFemale, head_position_offset)
            calcCameraTransform(isHMD, cameraTransformMatrix)
        end

        for i = 1, 4 do
            for j = 1, 4 do
                output.setNumber((i-1)*4 + j, cameraTransformMatrix[i][j])
            end
        end
    end

end

--[[ Debug
function onDraw()
    screen.setColor(255, 255, 0)
    screen.drawText(0, HMD.h - 30, "Vel, Acc, Jerk:")
    screen.drawText(0, HMD.h - 20, ("x: %+0.6f / %+0.6f / %+0.6f"):format(l_dx, l_ddx, l_dddx))
    screen.drawText(0, HMD.h - 7,  ("y: %+0.6f / %+0.6f / %+0.6f"):format(l_dy, l_ddy, l_dddy))
end
--]]




--[[ Debug (Not updated/working)
-- Quick debug to draw the basis vectors of the world coordinate system to verify cameraTransformMatrix and other tests
local o = 100
local axisPoints = {{o+0, o+0, o+0, 1}, {o+1, o+0, o+0, 1}, {o+0, o+1, o+0, 1}, {o+0, o+0, o+1, 1}}
local axisColor = {{255,0,0,150}, {0,255,0,150}, {0,0,255,150}}
local drawBuffer = {}
local frustumPlanes = {{},{},{},{},{},{}}
local cameraTransform = {}
local buffer
local b2n = {[true] = 1, [false] = 0}

function extract_frustum_planes(cameraTransform)
    --for i = 1, 4 do -- extract frustum planes https://github.com/EQMG/Acid/blob/master/Sources/Physics/Frustum.cpp
    --    local temp1, temp2 = cameraTransform[i*4], (i-1)*4
    --    frustumPlanes[1][i] = temp1 + cameraTransform[temp2 + 1]
    --    frustumPlanes[2][i] = temp1 - cameraTransform[temp2 + 1]
    --    frustumPlanes[3][i] = temp1 + cameraTransform[temp2 + 2]
    --    frustumPlanes[4][i] = temp1 - cameraTransform[temp2 + 2]
    --    frustumPlanes[5][i] = temp1 + cameraTransform[temp2 + 3]
    --    frustumPlanes[6][i] = temp1 - cameraTransform[temp2 + 3]
    --end

    for i = 1, 4 do  -- extract frustum planes https://github.com/EQMG/Acid/blob/master/Sources/Physics/Frustum.cpp
        for j = 1, 6 do
            frustumPlanes[j][i] = cameraTransform[i*4] + cameraTransform[(i-1)*4 + (j+1)//2] * (j%2*2-1)
        end
    end

--    for i = 1, 6 do -- normalize
--        temp = frustumPlanes[i]
--        local magnitude = (temp[1]^2 + temp[2]^2 + temp[3]^2)^0.5
--        for j = 1, 4 do
--            temp[j] = temp[j] / magnitude
--        end
--    end
end
function f(f,p) return b2n[frustumPlanes[f][1]*p[1] + frustumPlanes[f][2]*p[2] + frustumPlanes[f][3]*p[3] + frustumPlanes[f][4] > 0] end
function vec_dot(a, b) local sum = 0 for i = 1, #a do sum = sum + a[i]*b[i] end return sum end
function vec_cross(a, b, _return) _return[1], _return[2], _return[3] = a[2]*b[3] - a[3]*b[2], a[3]*b[1] - a[1]*b[3], a[1]*b[2] - a[2]*b[1] return _return end
function three_plane_intersect(p1, p2, p3) -- https://gdbooks.gitbooks.io/3dcollisions/content/Chapter1/three_plane_intersection.html
    local m1 = {p1[1], p2[1], p3[1]}
    local m2 = {p1[2], p2[2], p3[2]}
    local m3 = {p1[3], p2[3], p3[3]}
    local d  = {p1[4], p2[4], p3[4]}

    local u = vec_cross(m2, m3, {})
    local v = vec_cross(m1, d,  {})
    local denom = 1/vec_dot(m1, u)

    if (math.abs(denom) < 1e-16) then err("don't intersect") end
    return {
        vec_dot(d, u) * denom,
        vec_dot(m3, v) * denom,
        -vec_dot(m2, v) * denom}
end

function draw(points)
    local width, height = screen.getWidth(), screen.getHeight()
    local cx, cy = width/2, height/2

    buffer = matrix_mult(cameraTransformMatrix, axisPoints)
    for i = 1, 4 do
        for j = 1, 4 do
            cameraTransform[(i-1)*4 + j] = cameraTransformMatrix[i][j]
        end
    end

    extract_frustum_planes(cameraTransform)
    local camera_position = three_plane_intersect(frustumPlanes[1], frustumPlanes[2], frustumPlanes[3])

    for i = 1, #points do
        local x,y,z,w = table.unpack(buffer[i])
        if 0<=z and z<=w then -- Point is between near and far plane
            w = 1/w
            drawBuffer[i] = {x*w*cx + cx, y*w*cy + cy, z*w}
        else
            drawBuffer[i] = false
        end
    end
end

function onDraw()
    if renderOn then
        draw(axisPoints)

        if drawBuffer[1] then
            for i = 1, 3 do
                screen.setColor(table.unpack(axisColor[i]))
                if drawBuffer[i+1] then
                    screen.drawLine(drawBuffer[1][1], drawBuffer[1][2], drawBuffer[i+1][1], drawBuffer[i+1][2])
                end
            end
        end

        -- testing frustum culling point in clip space vs. world space with frustum planes
        screen.setColor(255, 255, 255)
        local X,Y,Z,W = table.unpack(buffer[1])
        screen.drawText(0,1, string.format("%s%s%s%s%s%s", b2n[-W<=X], b2n[X<=W], b2n[-W<=Y], b2n[Y<=W], b2n[0<=Z], b2n[Z<=W]))
        local p = axisPoints[1]
        screen.drawText(0,7, string.format("%s%s%s%s%s%s", f(1,p), f(2,p), f(3,p), f(4,p), f(5,p), f(6,p)))

        c2 = 0
        for i = 1, 6 do
            c1 = 0
            for j = 1, 4 do
                temp = frustumPlanes[i]
                c1 = c1 + b2n[ temp[1]*axisPoints[j][1] + temp[2]*axisPoints[j][2] + temp[3]*axisPoints[j][3] + temp[4] > 0 ]
            end
            if c1 == 0 then
                break
            end
            c2 = c2 + b2n[c1 == 4]
        end

        screen.drawText(0,14, string.format("%s %s", b2n[c2 == 6], b2n[c1>0]))
    end
end
--]]