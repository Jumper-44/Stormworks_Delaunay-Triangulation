--https://pastebin.com/hkV8csW5

------------------------------------
---------{ Initialization }---------
------------------------------------
tau=math.pi*2

getN = function(...)
    local r = {}
    for i,v in ipairs({...}) do r[i]=input.getNumber(v) end
    return table.unpack(r)
end

Clamp = function(x,s,l) return x < s and s or x > l and l or x end

MatrixMul = function(m1,m2) --Assuming matrix multiplication is possible
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

MatrixTranspose = function(m) --Also used to copy identity matrix
    local r = {}
    for i=1,#m[1] do
        r[i] = {}
        for j=1,#m do
            r[i][j] = m[j][i]
        end
    end
    return r
end

WorldToScreen_Point = function(m, cameraTransform)
    local result, n = {}, 1

    for i=1, #m do
        local x,y,z = m[i][1], m[i][2], m[i][3]

        local X,Y,Z,W =
        cameraTransform[1][1]*x + cameraTransform[2][1]*y + cameraTransform[3][1]*z + cameraTransform[4][1],
        cameraTransform[1][2]*x + cameraTransform[2][2]*y + cameraTransform[3][2]*z + cameraTransform[4][2],
        cameraTransform[1][3]*x + cameraTransform[2][3]*y + cameraTransform[3][3]*z + cameraTransform[4][3],
        cameraTransform[1][4]*x + cameraTransform[2][4]*y + cameraTransform[3][4]*z + cameraTransform[4][4]

        if (-W<=X and X<=W) and (-W<=Y and Y<=W) and (0<=Z and Z<=W) then --clip and discard points
            W=1/W
            result[n] = {X*W*cx+SCREEN.centerX, Y*W*cy+SCREEN.centerY, Z*W, i}
            n = n+1
        end -- x & y are screen coordinates, z is depth, the 4th is the index of the point
    end

    return result
end

--Vector3 Class
function Vec3(x,y,z) return
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

tiltSensor = {} --forward, up, left
gps,offset = Vec3(),{}
memory = {ang=Vec3(), gps=Vec3()}


--pre setup of some matrices. Matrices are written as m[column][row]
identityMatrix4x4 = {
    {1,0,0,0},
    {0,1,0,0},
    {0,0,1,0},
    {0,0,0,1}
}

rotationMatrixZ = MatrixTranspose(identityMatrix4x4)
translationMatrix_world = MatrixTranspose(identityMatrix4x4)
translationMatrix_local = MatrixTranspose(identityMatrix4x4)
------------------------------------



------------------------------------
------{ Screen Configuration }------
------------------------------------
w,h=96,96 --Width & Height in pixels.
cx,cy=w/2,h/2 --Don't touch.

SCREEN={near=0.25, sizeX=0.7 ,sizeY=0.7, placementOffsetX=0, placementOffsetY=0.01, centerX=cx, centerY=cy}
--[[SCREEN Explanation
-near is the distance from tip of the (compact pilot) seat to the screen in meters.
 
-sixeX|Y are the dimensions of the screen in meters.
Note that tiny gap from the edge of the model to the screen in which you can see the edge pixels matters. You can estimate with paint block.
If the field of view (FOV) is wrong then this may be the case, as "near" and the screen dimensions determine the FOV.
 
-placementOffsetX|Y are when you look perpendicular from the seat to the screen(or the XY plane of it), how many meters is the screen offset from the center. X:+Right, Y:+Up.
Note that for example the 3x3 HUD when centered you'd want to have like "placementOffsetY = 0.01", as you can see if you look at the HUD up close, it is off by a little in the model,
which can be noticeable after the projection. Even this 1 cm matters. Of course the further away the screen is the less noticeable it is, as FOV gets smaller and the limit of screen resolution too.
 
-centerX|Y are the pixel coordinates of where to display on the screen if you want to offset.
Needed if using a camera pointed to a higher resolution monitor for higher screen resolution, then you may want to "cx-1" on x, else Default: centerX=cx, centerY=cy
 
Example SCREEN of a 3x3 HUD:
SCREEN={near=0.25, sizeX=0.7 ,sizeY=0.7, placementOffsetX=0, placementOffsetY=0.01, centerX=cx, centerY=cy}
--]]

offset.gps = Vec3(0,0,0) -- X:+Right, Y:+Foward, Z:+Up. Offset GPS to the block of the head.
offset.tick = 3 --It takes a few ticks from getting the newest data to presenting it, so predicting the future position by a few ticks helps with Vehicle GPS & Rotation.

f=10000 --Render Distance.

aspectRatio=w/h
------------------------------------



function onTick()
    renderOn = input.getBool(1)

    if renderOn then
        gps.x,gps.y,gps.z,z = getN(1,2,3,4)
        gps.z=(gps.z+z)/2 --Averages two altimeters for precision, so it's in the same place as gps in all rotations.

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



    end
end



function onDraw()

    if renderOn then

        ------{ Player Head Position }------
        headAzimuthAng =    Clamp(lookX, -0.277, 0.277) * 0.408 * tau -- 0.408 is to make 100° to 40.8°
        headElevationAng =  Clamp(lookY, -0.125, 0.125) * 0.9 * tau + 0.404 + math.abs(headAzimuthAng/0.7101) * 0.122 -- 0.9 is to make 45° to 40.5°, 0.404 rad is 23.2°. 0.122 rad is 7° at max yaw.

        distance = math.cos(headAzimuthAng) * 0.1523
        offset.head = Vec3(
            math.sin(headAzimuthAng) * 0.1523,
            math.cos(headElevationAng) * distance +(isFemale and 0.132 or 0.161),
            math.sin(headElevationAng) * distance -(isFemale and 0.141 or 0.023)
        )
        ------------------------------------


        --{ Perspective Projection Matrix Setup }--
        n=SCREEN.near+0.625 -offset.head.y
        r=SCREEN.sizeX/2    +SCREEN.placementOffsetX    -offset.head.x
        l=-SCREEN.sizeX/2   +SCREEN.placementOffsetX    -offset.head.x
        t=SCREEN.sizeY/2    +SCREEN.placementOffsetY    -offset.head.z
        b=-SCREEN.sizeY/2   +SCREEN.placementOffsetY    -offset.head.z

        --Right hand rule and looking down the +Y axis, +X is right and +Z is up. Projects to x|y:coordinates [-1;1], z:depth [0;1], w:homogeneous coordinate
        perspectiveProjectionMatrix = {
            {2*n/(r-l)*aspectRatio,     0,              0,              0},
            {-(r+l)/(r-l),              -(b+t)/(b-t),   f/(f-n),        1},
            {0,                         2*n/(b-t),      0,              0},
            {0,                         0,              -f*n/(f-n),     0}
        }
        -------------------------------------------


        ------{ Rotation Matrix Setup }-----
        local sx,sy,sz, cx,cy,cz = math.sin(ang.x),math.sin(ang.y),math.sin(ang.z), math.cos(ang.x),math.cos(ang.y),math.cos(ang.z)

        rotationMatrixXY = {
            {cy,    sx*sy,      -cx*sy,     0},
            {0,     cx,         sx,         0},
            {sy,    -sx*cy,     cx*cy,      0},
            {0,     0,          0,          1}
        }

        rotationMatrixZ[1][1] = cz
        rotationMatrixZ[2][2] = cz
        rotationMatrixZ[1][2] = sz
        rotationMatrixZ[2][1] = -sz

        rotationMatrixZXY = MatrixMul(rotationMatrixZ, rotationMatrixXY)
        ------------------------------------


        ------{ Translation Matrix Setup }-----
        translate_local = Vec3( table.unpack( MatrixMul(rotationMatrixZXY, {{offset.head:unpack(0)}})[1] ) )
        translate_world = Vec3( table.unpack( MatrixMul(rotationMatrixZXY, {{offset.gps:add(offset.head):unpack(0)}})[1] ) ):add(gps)

        translationMatrix_local[4] = {Vec3():sub(translate_local):unpack(1)}
        translationMatrix_world[4] = {Vec3():sub(translate_world):unpack(1)}
        ------------------------------------


        ------{ Final Camera Transform Matrix }-----
        cameraTransform_local = MatrixMul(perspectiveProjectionMatrix, MatrixMul(MatrixTranspose(rotationMatrixXY), translationMatrix_local))

        cameraTransform_world = MatrixMul(perspectiveProjectionMatrix, MatrixMul(MatrixTranspose(rotationMatrixZXY), translationMatrix_world))
        --------------------------------------------

        --End of Camera setup, Start Drawing Under




    end

end