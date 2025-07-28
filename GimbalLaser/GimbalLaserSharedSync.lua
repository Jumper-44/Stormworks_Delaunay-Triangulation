-- Author: Jumper
-- GitHub: https://github.com/Jumper-44
-- Workshop: https://steamcommunity.com/profiles/76561198084249280/myworkshopfiles/
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey


-- This file is for sharing functionality
-- that requires excact synchronization,
-- i.e. the laser scanning and property read



require('JumperLib.Math.JL_matrix_transformations')
require('JumperLib.JL_general')
require('Utility.propertyToTable')


laser_xy_pivotBuffer = {}
laser_xy_pivotBufferIndex = 1
laser_endpoint_xyz = {}

LASER_AMOUNT, TICK_DELAY, POINT_OUTPUT_AMOUNT, OUTPUT_BUFFER_SIZE = table.unpack(strToNumbers "LaserSum, tickDelay, PointOUTSum, OutBufferSize")

OFFSET_GPS_TO_LASER     = {}
LASER_ORIENTAION_MATRIX = {}
LASER_MIN_RANGE         = {}

isLaserScanOn = false
isResetOn = false

do
    local LASER_SPREAD_RANGE = {}
    local OFFSET_LASER_CENTER_TO_FACE = 0.125 + 0.017

    for i = 1, LASER_AMOUNT do
        local laser_config, forward, right, upward

        -- Laser Config: gpsOffset[x,y,z], fwrdDir[x,y,z], rghtDir[x,y,z], spread[L,R,B,T], minRange[n]
        laser_config = strToNumbers("Laser"..i)

        OFFSET_GPS_TO_LASER[i] = { table.unpack(laser_config, 1, 3) }
        forward                = { table.unpack(laser_config, 4, 6) }
        right                  = { table.unpack(laser_config, 7, 9) }
        upward                 = vec_cross(forward, right, {})
        LASER_ORIENTAION_MATRIX[i] = {right, upward, forward}

        vec_add(
            OFFSET_GPS_TO_LASER[i],
            vec_scale(forward, OFFSET_LASER_CENTER_TO_FACE, {}), -- offset from center block of laser head to block surface
            OFFSET_GPS_TO_LASER[i] -- return
        )

        local lx, ly = {}, {}
        for j = 1, TICK_DELAY do
            lx[j] = false
            ly[j] = false
        end
        laser_xy_pivotBuffer[i] = { x = lx, y = ly }
        laser_endpoint_xyz[i] = vec_init3d()

        local l, r, b, t = table.unpack(laser_config, 10, 13)
        LASER_SPREAD_RANGE[i] = {
            (r+l)/2 - 0.5,  -- xOffset
            r-l,            -- xScale
            (t+b)/2 - 0.5,  -- yOffset
            t-b             -- yScale
        }

        LASER_MIN_RANGE[i] = laser_config[14]
    end



    --local PHI = (1 + 5^0.5) / 2
    local TIME_STEP = 1 --PHI / 10
    local LASER_TIME_STEP = 1 --TIME_STEP / LASER_AMOUNT

    function laserScan(time, xOffset, xScale, yOffset, yScale)
        --local angle = tau * (PHI * time % 1 - 0.5)
        --local radius = LASER_SPREAD_MULTIPLIER * (tau * time % 1 - 0.5)
        --return radius * math.cos(angle), radius * math.sin(angle)

        math.randomseed(math.floor(time))
        local x = (math.random() + xOffset) * xScale
        local y = (math.random() + yOffset) * yScale
        return clamp(x, -1, 1), clamp(y, -1, 1)
    end


    local function resetScan()
        tick = 0
    end
    resetScan()

    function onTickInputUpdate()
        tick = tick + 1
        laser_xy_pivotBufferIndex = laser_xy_pivotBufferIndex % TICK_DELAY + 1

        isLaserScanOn = input.getBool(1)
        isResetOn = input.getBool(2)

        if isResetOn then
            resetScan()
        end
    end

    -- onTickInputUpdate should be called before this
    function onTickScanUpdate()
        local currentPivot, spread, x, y

        if isLaserScanOn then
            for i = 1, LASER_AMOUNT do
                spread = LASER_SPREAD_RANGE[i]
                x, y = laserScan(tick * TIME_STEP + (i-1) * LASER_TIME_STEP, spread[1], spread[2], spread[3], spread[4])

                currentPivot = laser_xy_pivotBuffer[i]
                currentPivot.x[laser_xy_pivotBufferIndex] = x
                currentPivot.y[laser_xy_pivotBufferIndex] = y
            end
        else
            for i = 1, LASER_AMOUNT do
                currentPivot = laser_xy_pivotBuffer[i]
                currentPivot.x[laser_xy_pivotBufferIndex] = false
                currentPivot.y[laser_xy_pivotBufferIndex] = false
            end
        end
    end
end