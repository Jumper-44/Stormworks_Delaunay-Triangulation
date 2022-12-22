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
    simulator:setScreen(1, "9x5")
    simulator:setProperty("ExampleNumberProperty", 123)

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)

        -- touchscreen defaults
        local screenConnection = simulator:getTouchScreen(1)
        simulator:setInputBool(1, screenConnection.isTouched)
        --simulator:setInputNumber(1, screenConnection.width)
        --simulator:setInputNumber(2, screenConnection.height)
        simulator:setInputNumber(1, screenConnection.touchX*0.01)
        simulator:setInputNumber(2, screenConnection.touchY*0.01)
        simulator:setInputNumber(3, screenConnection.touchX*0.01)
        simulator:setInputNumber(4, screenConnection.touchY*0.01)
        simulator:setInputNumber(5, screenConnection.touchX*0.01)
        simulator:setInputNumber(6, screenConnection.touchY*0.01)
        simulator:setInputNumber(7, screenConnection.touchX*0.01)
        simulator:setInputNumber(8, screenConnection.touchY*0.01)
        simulator:setInputNumber(9, screenConnection.touchX*0.01)
        simulator:setInputNumber(10, screenConnection.touchY*0.01)

        -- NEW! button/slider options from the UI
        simulator:setInputBool(31, simulator:getIsClicked(1))       -- if button 1 is clicked, provide an ON pulse for input.getBool(31)
        simulator:setInputNumber(31, simulator:getSlider(1))        -- set input 31 to the value of slider 1

        simulator:setInputBool(32, simulator:getIsToggled(2))       -- make button 2 a toggle, for input.getBool(32)
        simulator:setInputNumber(32, simulator:getSlider(2) * 50)   -- set input 32 to the value from slider 2 * 50
    end;
end
---@endsection


--[====[ IN-GAME CODE ]====]





--#region readme
--[[
Calculates the camera transform matrix for augmented reality
Calculates the coordinates to the laser endpoint

Sends the cameraTransform_world and laserPos to the next lua script (ingame)
--]]
--#endregion readme


--#region kdtree
local Dist2 = function(a,b)
    local sum, dis = 0, 0
    for i = 1, #a do
        dis = a[i]-b[i]
        sum = sum + dis*dis
    end
    return sum
end

local Closest = function(left, right, point)
    if left == nil then return right end
    if right == nil then return left end

    local d1,d2 =
        Dist2(left.point, point),
        Dist2(right.point, point)

    if (d1 < d2) then
        return left, d1
    else
        return right, d2
    end
end

-- https://youtu.be/Glp7THUpGow || https://bitbucket.org/StableSort/play/src/master/src/com/stablesort/kdtree/KDTree.java
-- https://www.geeksforgeeks.org/k-dimensional-tree/
local KDTree = function(k) return {
    k = k;
    tree = {};

    insert = function(self, point)
        self:insertRecursive(self.tree, point, 0)
    end;
    insertRecursive = function(self, root, point, depth)
        if root.point == nil then --Create node if nil
            root.point = point
            root.left = {}
            root.right = {}
            return
        end

        local cd = depth % self.k + 1

        if point[cd] < root.point[cd] then
            self:insertRecursive(root.left, point, depth + 1)
        else
            self:insertRecursive(root.right, point, depth + 1)
        end
    end;

    nearestNeighbor = function(self, point) -- Returns nearest node to point and distance squared
        return self:nearestNeighborRecursive(self.tree, point, 0)
    end;
    nearestNeighborRecursive = function(self, root, point, depth)
        if root.point == nil then return nil end

        local cd = depth % self.k + 1
        if point[cd] < root.point[cd] then
            nextBranch, ortherBranch = root.left, root.right
        else
            nextBranch, ortherBranch = root.right, root.left
        end

        local temp = self:nearestNeighborRecursive(nextBranch, point, depth+1)
        local best = Closest(temp, root, point)

        local r2, dist, r2_ =
            Dist2(point, best.point),
            point[cd] - root.point[cd],
            nil

        if r2 >= dist*dist then
            temp = self:nearestNeighborRecursive(ortherBranch, point, depth+1)
            best, r2_ = Closest(temp, best, point)
        end

        return best, r2_ or r2
    end
} end
--#endregion kdtree



--#region Initialization
local tau = math.pi*2

local getN = function(...)
    local r = {}
    for i,v in ipairs({...}) do r[i]=input.getNumber(v) end
    return table.unpack(r)
end

local Clamp = function(x,s,l) return x < s and s or x > l and l or x end

local MatrixMul = function(m1,m2) --Assuming matrix multiplication is possible
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

--Vector3 Class
local function Vec3(x,y,z) return
    {x=x or 0;y=y or 0;z=z or 0;
    add =   function(a,b) return Vec3(a.x+b.x, a.y+b.y, a.z+b.z) end;
    sub =   function(a,b) return Vec3(a.x-b.x, a.y-b.y, a.z-b.z) end;
    scale = function(a,b) return Vec3(a.x*b, a.y*b, a.z*b) end;
    dot =   function(a,b) return (a.x*b.x + a.y*b.y + a.z*b.z) end;
    cross = function(a,b) return Vec3(a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x) end;
    len =   function(a) return a:dot(a)^0.5 end;
    normalize = function(a) return a:scale(1/a:len()) end;
    unpack = function(a, ...) return a.x, a.y, a.z, ... end}
end

local tiltSensor = { --[[forward, up, left]] }
local gps, ang, offset = Vec3(), Vec3(), { --[[gps, tick, head]] }
local memory = {ang=Vec3(), gps=Vec3()}

local renderOn, clear, isFemale, compass, lookX, lookY = false, false, false, 0, 0, 0
local perspectiveProjectionMatrix, rotationMatrixZXY, camera_translation, cameraTransform_world = {}, {}, {}, {}


--[[ Sending camera/eye GPS coordinates instead of combining translation with the cameraTransform
translationMatrix_world = {
    {1,0,0,0},
    {0,1,0,0},
    {0,0,1,0},
    {0,0,0,1}
}
--]]


local kdtree = KDTree(3)
local minDist_squared = 30^2 -- minDist_squared is assigned in onTick().

local laserOFFSET = Vec3(
    property.getNumber("L_x"),
    property.getNumber("L_y"),
    property.getNumber("L_z")
)
--#endregion Initialization



--#region Screen Configuration
------------------------------------
------{ Screen Configuration }------ https://pastebin.com/hkV8csW5
------------------------------------
local w, h = property.getNumber("w"), property.getNumber("h") --Width & Height in pixels.
-- cx,cy=w/2,h/2 -- Since the cameraTransform is only calculated here, some things are definded in 'Render.lua'

-- SCREEN={near=0, sizeX=0.7, sizeY=0.7, placementOffsetX=0, placementOffsetY=-0.01}       -- , centerX=cx, centerY=cy}
local SCREEN={
    near=property.getNumber("near"),
    sizeX=property.getNumber("sizeX"),
    sizeY=property.getNumber("sizeY"),
    placementOffsetX=property.getNumber("offsetX"),
    placementOffsetY=property.getNumber("offsetY")
}
--[[SCREEN Explanation
-near is the distance from tip of the (compact pilot) seat to the screen in meters.
 
-sixeX|Y are the dimensions of the screen in meters.
Note that tiny gap from the edge of the model to the screen in which you can see the edge pixels matters. You can estimate with paint block.
If the field of view (FOV) is wrong then this may be the case, as "near" and the screen dimensions determine the FOV.
 
-placementOffsetX|Y are when you look perpendicular from the seat to the screen(or the XY plane of it), how many meters is the screen offset from the center. X:+Right, Y:+Up.
Note that for example the 3x3 HUD when centered you'd want to have like "placementOffsetY = 0.01", as you can see if you look at the HUD up close, it is off by a little in the model,
which can be noticeable after the projection. Even this 1 cm matters. Of course the further away the screen is the less noticeable it is, as FOV gets smaller and the limit of screen resolution too.
 
-centerX|Y are the pixel coordinates of where to display on the screen if you want to offset.
If a camera pointed to a higher resolution monitor for higher screen resolution, then you may want to "cx-1" on x, else Default: centerX=cx, centerY=cy
(This parameter is in the script that renders)
 
Example SCREEN of a 3x3 HUD:
SCREEN={near=0.25, sizeX=0.7 ,sizeY=0.7, placementOffsetX=0, placementOffsetY=0.01, centerX=cx, centerY=cy}
--]]

offset.gps = Vec3(  -- X:+Right, Y:+Foward, Z:+Up. Offset GPS to the block of the head.
    property.getNumber("x"),
    property.getNumber("y"),
    property.getNumber("z")
)
offset.tick = property.getNumber("tick") --It takes a few ticks from getting the newest data to presenting it, so predicting the future position by a few ticks helps with Vehicle GPS & Rotation.

local f = property.getNumber("renderDistance")

local aspectRatio=w/h
------------------------------------
--#endregion Screen Configuration



function onTick()
    renderOn = input.getBool(1)
    clear = input.getBool(3)
    minDist_squared = input.getNumber(15)^2

    if clear then
        kdtree = KDTree(3)
    end

    -- pass through --
    output.setBool(1, renderOn)
    output.setBool(2, clear)
    output.setNumber(20, input.getNumber(14)) -- Pass through color alpha value
    ------------------

    local laserOutput = {0,0,0}


    if renderOn then
        --#region cameraTransform_world
        gps.x,gps.y,gps.z,z = getN(1,2,3,4)
        gps.z=(gps.z+z)/2 --Averages two altimeters for precision, so it's in the same place as gps module in all rotations.

        isFemale = input.getBool(2) --Matters as height differs depending on sex.

        compass, tiltSensor.forward, tiltSensor.up, tiltSensor.left, lookX, lookY = getN(5,6,7,8,9,10)


        ---------{ Vehicle Rotation }---------
        ang = Vec3(
            tiltSensor.forward*tau,
            math.atan(math.sin(tiltSensor.left * tau), math.sin(tiltSensor.up * tau)),
            compass*tau
        )
        --------------------------------------


        --{ Position & Rotation Estimation }--
        gps, memory.gps = gps:add( gps:sub(memory.gps):scale(offset.tick) ), gps
        ang, memory.ang = ang:add( ang:sub(memory.ang):scale(offset.tick) ), ang
        --------------------------------------


        do ------{ Player Head Position }------
            local headAzimuthAng =    Clamp(lookX, -0.277, 0.277) * 0.408 * tau -- 0.408 is to make 100° to 40.8°
            local headElevationAng =  Clamp(lookY, -0.125, 0.125) * 0.9 * tau + 0.404 + math.abs(headAzimuthAng/0.7101) * 0.122 -- 0.9 is to make 45° to 40.5°, 0.404 rad is 23.2°. 0.122 rad is 7° at max yaw.

            local distance = math.cos(headAzimuthAng) * 0.1523
            offset.head = Vec3(
                math.sin(headAzimuthAng) * 0.1523,
                math.cos(headElevationAng) * distance +(isFemale and 0.132 or 0.161),
                math.sin(headElevationAng) * distance -(isFemale and 0.141 or 0.023)
            )
        end -----------------------------------


        do --{ Perspective Projection Matrix Setup }--
            local n=SCREEN.near+0.625 -offset.head.y
            local r=SCREEN.sizeX/2    +SCREEN.placementOffsetX    -offset.head.x
            local l=-SCREEN.sizeX/2   +SCREEN.placementOffsetX    -offset.head.x
            local t=SCREEN.sizeY/2    +SCREEN.placementOffsetY    -offset.head.z
            local b=-SCREEN.sizeY/2   +SCREEN.placementOffsetY    -offset.head.z

            --Right hand rule and looking down the +Y axis, +X is right and +Z is up. Projects to x|y:coordinates [-1;1], z:depth [0;1], w:homogeneous coordinate
            perspectiveProjectionMatrix = {
                {2*n/(r-l)*aspectRatio,     0,              0,              0},
                {-(r+l)/(r-l),              -(b+t)/(b-t),   f/(f-n),        1},
                {0,                         2*n/(b-t),      0,              0},
                {0,                         0,              -f*n/(f-n),     0}
            }
        end ------------------------------------------


        do ------{ Rotation Matrix Setup }-----
            local sx,sy,sz, cx,cy,cz = math.sin(ang.x),math.sin(ang.y),math.sin(ang.z), math.cos(ang.x),math.cos(ang.y),math.cos(ang.z)

            rotationMatrixZXY = {
                {cz*cy-sz*sx*sy,    sz*cy+cz*sx*sy,     -cx*sy, 0},
                {-sz*cx,            cz*cx,              sx,     0},
                {cz*sy+sz*sx*cy,    sz*sy-cz*sx*cy,     cx*cy,  0},
                {0,                 0,                  0,      1}
            }
        end -----------------------------------


        ------{ Translation Matrix Setup }------
        camera_translation = Vec3(table.unpack( MatrixMul(rotationMatrixZXY, {{offset.gps:add(offset.head):unpack(0)}})[1] ) )
            :add(gps)

        -- Not using a translation matrix but instead just sending 'camera_translation' by itself (gps of the eye/camera)
        -- translationMatrix_world[4] = {Vec3():sub(camera_translation):unpack(1)}
        ----------------------------------------


        ------{ Final Camera Transform Matrix }-----
        -- cameraTransform_world = MatrixMul(perspectiveProjectionMatrix, MatrixMul(MatrixTranspose(rotationMatrixZXY), translationMatrix_world))
        cameraTransform_world = MatrixMul(perspectiveProjectionMatrix, MatrixTranspose(rotationMatrixZXY))
        --------------------------------------------


        -- Output cameraTransform_world
        for i = 1, 3 do
            for j = 1, 4 do
                output.setNumber((i-1)*4 + j, cameraTransform_world[i][j])
            end
        end

        output.setNumber(13, cameraTransform_world[4][3])
        output.setNumber(14, camera_translation.x)
        output.setNumber(15, camera_translation.y)
        output.setNumber(16, camera_translation.z)
        --#endregion cameraTransform_world


        --#region laserPos
        do
            local laserDistance, laserCompass, laserTiltSensor = getN(11,12,13)

            if laserDistance > 1 and laserDistance < 4000 then
                laserDistance = laserDistance + 0.375
                local dis = math.cos((laserTiltSensor)*tau)*laserDistance

                -- laserPos = (laser_vector + gps_offset + gps)
                local laserPos = Vec3(
                    math.sin(-laserCompass*tau)*dis,
                    math.cos(-laserCompass*tau)*dis,
                    math.sin((laserTiltSensor)*tau)*laserDistance
                )
                    :add(Vec3( table.unpack(  MatrixMul(rotationMatrixZXY, {{laserOFFSET:unpack(1)}})[1]  ) )) -- gps_Offset
                    :add(gps)


                local point = {
                    laserPos.x,
                    laserPos.y,
                    (laserPos.z < -5) and (math.max(laserPos.z, -5)+laserPos.z%1) or laserPos.z -- Clamping height to -5 + z%1, to get a slight color variation of flat sea
                }

                -- Check the distance to the nearest saved point
                local node, dist_squared = kdtree:nearestNeighbor(point)

                if node == nil or dist_squared > math.max(minDist_squared - (node.point[3]-point[3])^2, 0.1) then
                    kdtree:insert(point)

                    laserOutput = point
                end
            end
        end
        --#endregion laserPos

    end -- if renderOn

    -- Outputs laserPos to 17-19
    for i = 1, 3 do output.setNumber(i+16, laserOutput[i]) end
end


--[[ debug
laserPos = {}
function onDraw()
    screen.setColor(255,255,0)

    screen.drawText(100,0, tostring(laserPos.x))
    screen.drawText(100,10, tostring(laserPos.y))
    screen.drawText(100,20, tostring(laserPos.z))
end
--]]