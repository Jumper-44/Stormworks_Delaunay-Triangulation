-- Author: Jumper
-- GitHub: https://github.com/Jumper-44
-- Workshop: https://steamcommunity.com/profiles/76561198084249280/myworkshopfiles/
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey


require("GimbalLaser.GimbalLaserSharedSync")


local position, angle, rotationMatrixZYX = vec_init3d(), vec_init3d(), matrix_init(3, 3)
local temp1Vec3d, temp2Vec3d = vec_init3d(), vec_init3d()
local TURN_TO_RAD = math.pi / 4
local outSetNum = output.setNumber

function onTick()
    onTickInputUpdate()

    if isLaserScanOn then
        vec_init3d(position, getNumber3(1, 2, 3))
        vec_init3d(angle,    getNumber3(4, 5, 6))
        matrix_getRotZYX(angle[1], angle[2], angle[3], rotationMatrixZYX)

        for i = 1, LASER_AMOUNT do
            local laser_distance = input.getNumber(6 + i)
            local laser_xyz_output = laser_endpoint_xyz[i]

            if laser_distance > LASER_MIN_RANGE[i] and laser_distance < 4000 and laser_xy_pivotBuffer[i].x[laser_xy_pivotBufferIndex] then
                local rY, rX, dist
                rY = laser_xy_pivotBuffer[i].x[laser_xy_pivotBufferIndex] * TURN_TO_RAD
                rX = laser_xy_pivotBuffer[i].y[laser_xy_pivotBufferIndex] * TURN_TO_RAD
                dist = math.cos(rX) * laser_distance

                -- calc laser endpoint xyz
                vec_add( -- Add physics block position
                    position,
                    matrix_multVec3d( -- Orient vector to the vehicle world orientation
                        rotationMatrixZYX,
                        vec_add( -- Add offset vector from the GPS/physics block to the laser head
                            OFFSET_GPS_TO_LASER[i],
                            matrix_multVec3d( -- Orient laser ray vector to the vehicle laser block local orientation
                                LASER_ORIENTAION_MATRIX[i],
                                vec_init3d(temp1Vec3d,              -- return
                                    math.sin(rY) * dist,            -- x
                                    math.sin(rX) * laser_distance,  -- y
                                    math.cos(rY) * dist             -- z
                                ),
                                temp2Vec3d -- return
                            ),
                            temp2Vec3d -- return
                        ),
                        temp1Vec3d -- return
                    ),
                    laser_xyz_output -- return
                )

            else
                vec_init3d(laser_xyz_output) -- Set xyz to 0
            end

            local offset = (i - 1) * 3
            outSetNum(offset + 1, laser_xyz_output[1])
            outSetNum(offset + 2, laser_xyz_output[2])
            outSetNum(offset + 3, laser_xyz_output[3])
        end
    end

    onTickScanUpdate()
end

