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
    simulator:setProperty("w", 160)                 -- Pixel width of screen
    simulator:setProperty("h", 160)                 -- Pixel height of screen
    simulator:setProperty("near", 0.25)             -- Distance to near plane in meters, but added offset later on. So "near" is the distance from the end of (compact) seat model to the screen. I.e how many blocks between (compact) seat and screen divided by 4.
    simulator:setProperty("far", 1000)              -- Distance to far plane in meters, max render distance
    simulator:setProperty("sizeX", 0.71)            -- Physical sizeX/width of screen in meters. (Important that it is the actual screen part with pixels and not model width)
    simulator:setProperty("sizeY", 0.71)            -- Physical sizeY/height of screen in meters. (Important that it is the actual screen part with pixels and not model height)
    simulator:setProperty("positionOffsetX", 0)     -- Physical offset in the XY plane along X:right in meters.
    simulator:setProperty("positionOffsetY", 0.01)  -- Physical offset in the XY plane along Y:up in meters. (HUD screen is 0.01 m offset in the model)

    simulator:setProperty("tick", 0)                  -- tick compensation
    simulator:setProperty("GPS_to_camera", "0, 0, 0") -- Offset from physics sensor block to seat headrest block. (X:right, Y:up, Z:forward)

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)
        simulator:setInputBool(1, true) -- isRendering = true

                                                                            -- Debug sliders
        simulator:setInputNumber(1, (simulator:getSlider(1) - 0) * 10)      -- x position
        simulator:setInputNumber(2, (simulator:getSlider(2) - 0) * 10)      -- y position
        simulator:setInputNumber(3, (simulator:getSlider(3) - 0.5) * 25)    -- z position
        simulator:setInputNumber(4, (simulator:getSlider(4)) * math.pi*2)   -- x rotation
        simulator:setInputNumber(5, (simulator:getSlider(5)) * math.pi*2)   -- y rotation
        simulator:setInputNumber(6, (simulator:getSlider(6)) * math.pi*2)   -- z rotation
    end;
end
---@endsection

--[====[ IN-GAME CODE ]====]




-- https://github.com/Jumper-44/Stormworks_JumperLib
require('JumperLib.JL_general')
require('JumperLib.Math.JL_matrix_transformations')


local lookX, lookY, headAzimuthAng, distance, headElevationAng
local position, linearVelocity, angle, angularVelocity, head_position_offset, cameraTranslation, tempVec1_3d, tempVec2_3d = {}, {}, {}, {}, {}, {}, {}, {}
local tempMatrix1_3x3, tempMatrix2_3x3, tempMatrix1_4x4, tempMatrix2_4x4, translationMatrix, rotationMatrixZYX, perspectiveProjectionMatrix, cameraTransformMatrix = matrix_init(3, 3), matrix_init(3, 3), matrix_init(4, 4), matrix_init(4, 4),  matrix_initIdentity(4, 4), matrix_initIdentity(4, 4), matrix_init(4, 4), matrix_init(4, 4)
local isRendering, isFemale, OFFSET = false, false, {}

--#region Settings
local SCREEN = {
    w = property.getNumber("w"),                                -- Pixel width of screen
    h = property.getNumber("h"),                                -- Pixel height of screen
    near = property.getNumber("near") + 0.635,                  -- Distance to near plane in meters, but added offset. So "near" is the distance from the end of (compact) seat model to the screen. I.e how many blocks between (compact) seat and screen divided by 4.
    far = property.getNumber("far"),                            -- Distance to far plane in meters, max render distance
    sizeX = property.getNumber("sizeX"),                        -- Physical sizeX/width of screen in meters. (Important that it is the actual screen part with pixels and not model width)
    sizeY = property.getNumber("sizeY"),                        -- Physical sizeY/height of screen in meters. (Important that it is the actual screen part with pixels and not model height)
    positionOffsetX = property.getNumber("positionOffsetX"),    -- Physical offset in the XY plane along X:right in meters.
    positionOffsetY = property.getNumber("positionOffsetY")     -- Physical offset in the XY plane along Y:up in meters. (HUD screen is 0.01 m offset in the model)
}

SCREEN.r = SCREEN.sizeX/2  + SCREEN.positionOffsetX
SCREEN.l = -SCREEN.sizeX/2 + SCREEN.positionOffsetX
SCREEN.t = SCREEN.sizeY/2  + SCREEN.positionOffsetY
SCREEN.b = -SCREEN.sizeY/2 + SCREEN.positionOffsetY

OFFSET.GPS_to_camera = str_to_vec(property.getText("GPS_to_camera")) -- Offset from physics sensor block to seat headrest block. (X:right, Y:up, Z:forward)
OFFSET.tick = property.getNumber("tick")/60 -- tick compensation
--#endregion Settings


function onTick()
    isRendering = input.getBool(1)

    -- Passthrough composite
    for i = 17, 32 do
        output.setNumber(i, input.getNumber(i))
    end
    for i = 1, 32 do
        output.setBool(i, input.getBool(i))
    end

    if isRendering then
        do -- calc cameraTransformMatrix
            isFemale = input.getBool(2)
            vec_init3d(position,        getNumber3(1, 2, 3))    -- physics sensor
            vec_init3d(angle,           getNumber3(4, 5, 6))    -- physics sensor
            vec_init3d(linearVelocity,  getNumber3(7, 8, 9))    -- physics sensor
            vec_init3d(angularVelocity, getNumber3(10, 11, 12)) -- physics sensor

            -- head_position_offset (approximation)
            lookX, lookY = input.getNumber(13), input.getNumber(14) -- lookX|Y from seat
            headAzimuthAng =    clamp(lookX, -0.277, 0.277) * 0.408 * tau -- 0.408 is to make 100° to 40.8°
            headElevationAng =  clamp(lookY, -0.125, 0.125) * 0.9 * tau + 0.404 + math.abs(headAzimuthAng/0.7101) * 0.122 -- 0.9 is to make 45° to 40.5°, 0.404 rad is 23.2°. 0.122 rad is 7° at max yaw.

            distance = math.cos(headAzimuthAng) * 0.1523
            head_position_offset = vec_init3d(head_position_offset,
                math.sin(headAzimuthAng) * 0.1523,
                math.sin(headElevationAng) * distance -(isFemale and 0.141 or 0.023),
                math.cos(headElevationAng) * distance +(isFemale and 0.132 or 0.161)
            )
            -- /head_position_offset/

            matrix_getPerspectiveProjection_facingZ(
                SCREEN.near - head_position_offset[3], -- near
                SCREEN.far                           , -- far
                SCREEN.r    - head_position_offset[1], -- right
                SCREEN.l    - head_position_offset[1], -- left
                SCREEN.t    - head_position_offset[2], -- top
                SCREEN.b    - head_position_offset[2], -- bottom
                perspectiveProjectionMatrix -- return
            )

            vec_scale(angularVelocity, OFFSET.tick*tau, angularVelocity)
            matrix_mult( -- rotation matrix with tick compensation
                matrix_getRotZYX(angularVelocity[1],  angularVelocity[2], angularVelocity[3], tempMatrix1_3x3),
                matrix_getRotZYX(angle[1],            angle[2],           angle[3],           tempMatrix2_3x3),
                rotationMatrixZYX -- return
            )

            vec_add( -- cameraTranslation
                vec_add(
                    matrix_multVec3d(rotationMatrixZYX, vec_add(OFFSET.GPS_to_camera, head_position_offset, tempVec1_3d), tempVec2_3d), -- XYZ offset to physics sensor
                    vec_scale(matrix_multVec3d(rotationMatrixZYX, linearVelocity, tempVec1_3d), OFFSET.tick, tempVec1_3d),              -- position tick compensation
                    cameraTranslation -- return
                ),
                position,         -- XYZ of physics sensor
                cameraTranslation -- return
            )

            vec_scale(cameraTranslation, -1, translationMatrix[4]) -- set translation in translationMatrix

            -- cameraTransformMatrix = perspectiveProjectionMatrix * rotationMatrixZYX^T * translationMatrix
            matrix_mult(matrix_transpose(rotationMatrixZYX, tempMatrix1_4x4), translationMatrix, tempMatrix2_4x4)
            matrix_mult(perspectiveProjectionMatrix, tempMatrix2_4x4, cameraTransformMatrix)
        end

        for i = 1, 4 do
            for j = 1, 4 do
                output.setNumber((i-1)*4 + j, cameraTransformMatrix[i][j])
            end
        end
    end

end



--[=[ Debug
-- Quick debug to draw the basis vectors of the world coordinate system to verify cameraTransformMatrix

local axisPoints = {{0,0,0,1}, {1,0,0,1}, {0,1,0,1}, {0,0,1,1}}
local axisColor = {{255,0,0,150}, {0,255,0,150}, {0,0,255,150}}
local drawBuffer = {}

function draw(points)
    local width, height = screen.getWidth(), screen.getHeight()
    local cx, cy = width/2, height/2

    local buffer = matrix_mult(cameraTransformMatrix, axisPoints)

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
    if isRendering then
        draw(axisPoints)

        if drawBuffer[1] then
            for i = 1, 3 do
                screen.setColor(table.unpack(axisColor[i]))
                if drawBuffer[i+1] then
                    screen.drawLine(drawBuffer[1][1], drawBuffer[1][2], drawBuffer[i+1][1], drawBuffer[i+1][2])
                end
            end
        end
    end
end
--]=]