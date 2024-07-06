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

    simulator:setProperty("Laser_amount", 2)
    simulator:setProperty("Laser_tick_offset", 6)
    simulator:setProperty("Point_Min_Density_Squared", 0.01)
    simulator:setProperty("Laser_Spread_Multiplier", 1.6)

    simulator:setProperty("Laser_GPS_to_head1", "-0.25, 0, 0")
    simulator:setProperty("Laser_forward_dir1", "0, 0, 1")
    simulator:setProperty("Laser_right_dir1", "1, 0, 0")

    simulator:setProperty("Laser_GPS_to_head2", "0.25, 0, 0")
    simulator:setProperty("Laser_forward_dir2", "0, 0, 1")
    simulator:setProperty("Laser_right_dir2", "1, 0, 0")

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)

        -- touchscreen defaults
        local screenConnection = simulator:getTouchScreen(1)
--        simulator:setInputBool(1, screenConnection.isTouched)
--        simulator:setInputNumber(1, screenConnection.width)
--        simulator:setInputNumber(2, screenConnection.height)
        simulator:setInputNumber(7, screenConnection.touchX)
        simulator:setInputNumber(8, screenConnection.touchY)

        -- NEW! button/slider options from the UI
        simulator:setInputBool(31, simulator:getIsClicked(1))       -- if button 1 is clicked, provide an ON pulse for input.getBool(31)
        simulator:setInputNumber(31, simulator:getSlider(1))        -- set input 31 to the value of slider 1

        simulator:setInputBool(32, simulator:getIsToggled(2))       -- make button 2 a toggle, for input.getBool(32)
        simulator:setInputNumber(32, simulator:getSlider(2) * 50)   -- set input 32 to the value from slider 2 * 50
    end;
end
---@endsection


--[====[ IN-GAME CODE ]====]

-- try require("Folder.Filename") to include code from another file in this, so you can store code in libraries
-- the "LifeBoatAPI" is included by default in /_build/libs/ - you can use require("LifeBoatAPI") to get this, and use all the LifeBoatAPI.<functions>!



--require('JumperLib.DataStructures.JL_kdtree')
require('JumperLib.Math.JL_matrix_transformations')
require('JumperLib.JL_general')

-- init laser scan function
local PHI = (1 + 5^0.5) / 2
local LASER_SPREAD_MULTIPLIER = property.getNumber("Laser_Spread_Multiplier")
local laser_scan_function = function(time)
    --local angle = tau * (PHI * time % 1 - 0.5)
    --local radius = LASER_SPREAD_MULTIPLIER * (tau * time % 1 - 0.5)
    --return radius * math.cos(angle), radius * math.sin(angle)
    return (math.random()-.5)*LASER_SPREAD_MULTIPLIER, (math.random()-.5)*LASER_SPREAD_MULTIPLIER
end

-- init laser buffer, offset, orientation
local OFFSET_LASER_CENTER_TO_FACE = 0.125 + 0.017
local laser_xy_pivot_buffer = {}
local laser_xy_pivot_buffer_index = 1
local laser_xyz = {}
local LASER_AMOUNT = property.getNumber("Laser_amount")
local TICK_DELAY = property.getNumber("Laser_tick_offset")
--local POINT_MIN_DENSITY_SQUARED = property.getNumber("Point_Min_Density_Squared")
local OFFSET_GPS_TO_LASER = {}
local LASER_ORIENTAION_MATRIX = {}
for i = 1, LASER_AMOUNT do -- laser(s) config init
    local forward, right, upward
    forward = str_to_vec(property.getText("Laser_forward_dir"..i))
    right = str_to_vec(property.getText("Laser_right_dir"..i))
    upward = vec_cross(forward, right, {})
    LASER_ORIENTAION_MATRIX[i] = {right, upward, forward}

    OFFSET_GPS_TO_LASER[i] = str_to_vec(property.getText("Laser_GPS_to_head"..i))
    vec_add(
        OFFSET_GPS_TO_LASER[i],
        vec_scale(forward, OFFSET_LASER_CENTER_TO_FACE, {}), -- offset from center block of laser head to block surface
        OFFSET_GPS_TO_LASER[i] -- return
    )

    laser_xy_pivot_buffer[i] = {x = {}, y = {}}
    laser_xyz[i] = vec_init3d()
end

local tick = 0
local TIME_STEP = PHI/10
local LASER_TIME_STEP = TIME_STEP / LASER_AMOUNT

local position, angle, rotationMatrixZYX = vec_init3d(), vec_init3d(), matrix_init(3, 3)
--local point_x, point_y, point_z = {}, {}, {}
--local points = list({point_x, point_y, point_z})
--local kd_tree = IKDTree(point_x, point_y, point_z)

local temp1Vec3d, temp2Vec3d = vec_init3d(), vec_init3d()

function onTick()
    is_laser_scan_on = input.getBool(1)
--    if input.getBool(2) then -- clear
--        point_x, point_y, point_z = {}, {}, {}
--        points = list({point_x, point_y, point_z})
--        kd_tree = IKDTree(point_x, point_y, point_z)
--    end

    tick = tick + 1
    laser_xy_pivot_buffer_index = laser_xy_pivot_buffer_index % TICK_DELAY + 1

    if is_laser_scan_on then
        vec_init3d(position, getNumber3(1, 2, 3))
        vec_init3d(angle, getNumber3(4, 5, 6))
        matrix_getRotZYX(angle[1], angle[2], angle[3], rotationMatrixZYX)

        for i = 1, LASER_AMOUNT do
            local laser_distance = input.getNumber(6 + i)

            if laser_distance > 0 and laser_distance < 4000 and laser_xy_pivot_buffer[i].x[laser_xy_pivot_buffer_index] ~= nil then
                local rY, rX = laser_xy_pivot_buffer[i].x[laser_xy_pivot_buffer_index], laser_xy_pivot_buffer[i].y[laser_xy_pivot_buffer_index]
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
                    laser_xyz[i] -- return
                )

                -- density filter
                --local nn = kd_tree.IKDTree_nearestNeighbors(laser_xyz[i], 1)
                --if nn[1] == nil or kd_tree.pointsLen2[nn[1]] > POINT_MIN_DENSITY_SQUARED then -- If nearest point in pointcloud is not too near then accept point
                --    kd_tree.IKDTree_insert(points.insert(laser_xyz[i]));
                --else
                --    vec_init3d(laser_xyz[i]) -- Set xyz to 0
                --end
            else
                vec_init3d(laser_xyz[i]) -- Set xyz to 0
            end

            local x, y = laser_scan_function(tick * TIME_STEP + (i-1) * LASER_TIME_STEP)

            laser_xy_pivot_buffer[i].x[laser_xy_pivot_buffer_index] = x / 8 * tau
            laser_xy_pivot_buffer[i].y[laser_xy_pivot_buffer_index] = y / 8 * tau

            local output_offset = (i - 1) * 5
            output.setNumber(output_offset + 1, x)
            output.setNumber(output_offset + 2, y)

            for j = 1, 3 do
                output.setNumber(output_offset + j + 2, laser_xyz[i][j])
            end
        end
    else
        for i = 1, LASER_AMOUNT do
            laser_xy_pivot_buffer[i].x[laser_xy_pivot_buffer_index] = nil
            laser_xy_pivot_buffer[i].y[laser_xy_pivot_buffer_index] = nil
        end

        for i = 1, 32 do
            output.setNumber(i, 0)
        end
    end
end



--[[ DEBUG
function onDraw()
    screen.setColor(255, 255, 0)
    for i = 1, 3 do
        screen.drawText(2, (i-1)*7, laser_xyz[1][i])
    end
end
--]]