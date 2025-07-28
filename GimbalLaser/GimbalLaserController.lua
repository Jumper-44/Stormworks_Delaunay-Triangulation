-- Author: Jumper
-- GitHub: https://github.com/Jumper-44
-- Workshop: https://steamcommunity.com/profiles/76561198084249280/myworkshopfiles/
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey


require("GimbalLaser.GimbalLaserSharedSync")

local ACTIVE_OUTPUTS = LASER_AMOUNT*2

function onTick()
    onTickInputUpdate()
    onTickScanUpdate()

    if isLaserScanOn then
        for i = 1, LASER_AMOUNT do
            local offset = (i - 1) * 2
            output.setNumber(offset + 1, laser_xy_pivotBuffer[i].x[laser_xy_pivotBufferIndex])
            output.setNumber(offset + 2, laser_xy_pivotBuffer[i].y[laser_xy_pivotBufferIndex])
        end
    else
        for i = 1, ACTIVE_OUTPUTS do
            output.setNumber(i, 0)
        end
    end
end