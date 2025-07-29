-- Author: Jumper
-- GitHub: https://github.com/Jumper-44
-- Workshop: https://steamcommunity.com/profiles/76561198084249280/myworkshopfiles/
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey


require("GimbalLaser.GimbalLaserSharedSync")

require("DataStructures.IKDTREE")


local outSetNum = output.setNumber
local bufX, bufY, bufZ = {}, {}, {}
local bufStart, bufEnd, bufSize

local function isBufferFull()
    return bufSize == OUTPUT_BUFFER_SIZE
end

local function bufferAdd(p)
--    if bufSize < OUTPUT_BUFFER_SIZE then
    bufEnd = bufEnd % OUTPUT_BUFFER_SIZE + 1
    bufSize = bufSize + 1

    bufX[bufEnd] = p[1]
    bufY[bufEnd] = p[2]
    bufZ[bufEnd] = p[3]
--        return true
--    end
--    return false
end

local function bufferPopToOutput(i)
    if bufSize > 0 then
        outSetNum(i,     bufX[bufStart])
        outSetNum(i + 1, bufY[bufStart])
        outSetNum(i + 2, bufZ[bufStart])

        bufStart = bufStart % OUTPUT_BUFFER_SIZE + 1
        bufSize = bufSize - 1
    else
        outSetNum(i,     0)
        outSetNum(i + 1, 0)
        outSetNum(i + 2, 0)
    end
end


local position, angle, rotationMatrixZYX = vec_init3d(), vec_init3d(), matrix_init(3, 3)
local temp1Vec3d, temp2Vec3d = vec_init3d(), vec_init3d()

local TURN_TO_RAD = math.pi / 4
local ACTIVE_OUTPUTS = POINT_OUTPUT_AMOUNT*3 - 2

local px, py, pz
local points
local minPointDist = property.getNumber("MinPointDist")

local function init()
    bufStart = 1
    bufEnd = 0
    bufSize = 0

    px = {}
    py = {}
    pz = {}
    points = list{px, py, pz}
    IKDTree(points, 3)
end
init()

function onTick()
    onTickInputUpdate()

    if isResetOn then
        init()
    end

    if isLaserScanOn then
        vec_init3d(position, getNumber3(1, 2, 3))
        vec_init3d(angle,    getNumber3(4, 5, 6))
        matrix_getRotZYX(angle[1], angle[2], angle[3], rotationMatrixZYX)

        for i = 1, LASER_AMOUNT do
            if isBufferFull() then
                break
            end

            local laser_distance = input.getNumber(6 + i)

            if laser_distance > LASER_MIN_RANGE[i] and laser_distance < 4000 and laser_xy_pivotBuffer[i].x[laser_xy_pivotBufferIndex] then
                local rY = laser_xy_pivotBuffer[i].x[laser_xy_pivotBufferIndex] * TURN_TO_RAD
                local rX = laser_xy_pivotBuffer[i].y[laser_xy_pivotBufferIndex] * TURN_TO_RAD
                local dist = math.cos(rX) * laser_distance

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
                    temp1Vec3d -- return
                )

                local p, dist2 = points.IKDTree_nearestNeighbor(temp1Vec3d)
                if dist2^0.5 >= minPointDist then
                    points.IKDTree_insert(points.list_insert(temp1Vec3d))
                    bufferAdd(temp1Vec3d)
                end
            end
        end
    end

    for i = 1, ACTIVE_OUTPUTS, 3 do
        bufferPopToOutput(i)
    end

    onTickScanUpdate()
end

