-- MIT License at end of this file
-- Author: Jumper
-- GitHub: https://github.com/Jumper-44
-- Workshop: https://steamcommunity.com/profiles/76561198084249280/myworkshopfiles/
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)


-- [[ DEBUG ONLY
do
    ---@type Simulator -- Set properties and screen sizes here - will run once when the script is loaded
    simulator = simulator
    simulator:setScreen(1, "10x10")

    local _isTouched = false

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)
        local screenConnection = simulator:getTouchScreen(1)
        if screenConnection.isTouched and screenConnection.isTouched ~= _isTouched then

        end
        _isTouched = screenConnection.isTouched
        simulator:setInputBool(2, simulator:getIsToggled(1))
        simulator:setInputBool(3, simulator:getIsToggled(2))
    end
end
--]]

--[====[ IN-GAME CODE ]====]

require("DataStructures.JL_list")
require("newTables")


---@section BallTree3D 1 _BALL_TREE_
---@class BallTree3D
---@field BT_nodes list
---@field BT_rootID integer
---@field BT_insert fun(id: integer): integer
---@field BT_remove fun(id: integer)
---@field BT_nnSearch fun(x: number, y: number, z: number): number, integer
---@field BT_treeCost fun(): number
-- ---@field BT_nnSearchApprox fun(x: number, y: number, z: number): integer

---https://en.wikipedia.org/wiki/Ball_tree
---A 3D bounding volume hierarchy of spheres where input data are points,  
---and support nearest neighbor search.  
---Using tree rotation heuristic to minimize sphere radius and tree depth.  
---@param px table
---@param py table
---@param pz table
---@return BallTree3D
BallTree3D = function(px, py, pz)
    local bt, nodesBuffer, buffer1, buffer2, nx, ny, nz, nr, nChild1, nChild2, nBucket, nParent, nDepth, nodes,
        unionSphere, refitSpheres, bucketFurthestSearch, refitBucket, sortBucketFunc, nDist2, pDist2, -- functions
        x,y,z, dx,dy,dz, i1,i2,i3, size, dist, bucket, bestDist, bestP, n -- other locals, also acts as "globals" in some specific places, so really spaghetti code
        =
        {px, py, pz},
        {false, false, 0,0,0,0, {}, false, 1},
        newTables{11}

    ---@cast nodesBuffer {[1]: number|false, [2]: number|false, [3]: number, [4]: number, [5]: number, [6]: number, [7]: table|false, [8]: number|false, [9]: number}

    nodes = list{nChild1, nChild2, nx, ny, nz, nr, nBucket, nParent, nDepth}
    nodes.list_insert(nodesBuffer)
    bt.BT_nodes = nodes
    bt.BT_rootID = 1

    nDist2 = function(n, x,y,z)
        dx = nx[n]-x
        dy = ny[n]-y
        dz = nz[n]-z
        return dx*dx + dy*dy + dz*dz
    end

    pDist2 = function(n, x,y,z)
        x = px[n]-x
        y = py[n]-y
        z = pz[n]-z
        return x*x + y*y + z*z
    end

    ---https://www.jasondavies.com/maps/circle-tree/  
    ---@param sA integer
    ---@param sB integer
    ---@return number r, number x, number y, number z
    ---@overload fun(integer, integer, table): r: number, x: number, y: number, z: number
    unionSphere = function(sA, sB, rA, rB, rC)
        if nr[sA] > nr[sB] then
            sA, sB = sB, sA
        end

        dist = nDist2(sB, nx[sA], ny[sA], nz[sA])^0.5
        rA = nr[sA]
        rB = nr[sB]

        if dist + rA <= rB then
            return rB, nx[sB], ny[sB], nz[sB]
        else
            rC = (rA + dist + rB) / 2
            dist = (rC - rA)/dist
            return rC, dx*dist + nx[sA], dy*dist + ny[sA], dz*dist + nz[sA]
        end
    end

    ---comment
    ---@param n integer
    ---@param sameR any local variable
    refitSpheres = function(n, sameR)
        while n do
            i1 = nChild1[n]
            i2 = nChild2[n]
            i3 = nDepth[n]
            nDepth[n] = math.max(nDepth[i1], nDepth[i2]) + 1

            if sameR then
                if i3 == nDepth[n] then
                    break
                end
            else
                nr[n], nx[n], ny[n], nz[n] = unionSphere(i1, i2)
                sameR = nr[n] == buffer1[4]
            end

            x = nParent[n]

            -- tree rotations reference: [https://box2d.org/files/ErinCatto_DynamicBVH_Full.pdf, page 111-126],
            -- but instead of surface area then minimize radius and depth
            -- [[ local rotation to minimize radius and tree depth
            if x then
                y = nParent[x]
                if y then
                    i1 = nChild1[x] == n and 2 or 1
                    z = nodes[i1][x] -- 'n' sibling

                    i2 = nChild1[y] == x and 2 or 1
                    i3 = nodes[i2][y] -- 'n'.parent sibling

                    -- heuristic:
                    -- new_r / old_r  +  old_depth / new_depth * depth_factor < 1 + depth_factor
                    if unionSphere(i3, z, buffer1) / (sameR and nr[n] or unionSphere(n, z)) + nDepth[i3] / nDepth[n] * 0.5 < 1.5 then
                        nParent[i3] = x
                        nParent[n]  = y
                        nodes[i1%2+1][x] = i3
                        nodes[i2][y] = n
                        sameR = false
                    end
                end
            end
            --]]

            n = x
        end
    end

    ---given a (x,y,z) then return furthest away point in bucket
    ---@param bucket table
    ---@param size integer
    ---@param x number
    ---@param y number
    ---@param z number
    ---@return integer, number
    bucketFurthestSearch = function(bucket, size, x, y, z)
        bestDist = 0
        for i = 1, size do
            i = bucket[i]
            size = pDist2(i, x,y,z)
            if size > bestDist then
                bestP = i
                bestDist = size
            end
        end

        ---@cast bestP integer
        return bestP, bestDist
    end

    refitBucket = function(n)
        bucket = nBucket[n]
        size = #bucket
        x = 0
        y = 0
        z = 0

        for j = 1, size do
            j = bucket[j]
            x = x + px[j]
            y = y + py[j]
            z = z + pz[j]
        end
        x = x/size
        y = y/size
        z = z/size

        nx[n] = x
        ny[n] = y
        nz[n] = z
        _, dist = bucketFurthestSearch(bucket, size, x,y,z)
        nr[n] = dist^0.5
    end

    sortBucketFunc = function(p1, p2)
        return buffer1[p1] < buffer1[p2]
    end

    ---@section BT_insert
    ---comment
    ---@param id integer
    bt.BT_insert = function(id)
        n = bt.BT_rootID
        bucket = nBucket[n]
        x = px[id]
        y = py[id]
        z = pz[id]

        if bucket then
            if #bucket == 0 then
                nx[n] = x
                ny[n] = y
                nz[n] = z
                nr[n] = 0
            end
        else
            repeat
                i1 = nChild1[n]
                i2 = nChild2[n]
                n = nDist2(i1, x,y,z) < nDist2(i2, x,y,z) and i1 or i2
                bucket = nBucket[n]
            until bucket
        end

        size = #bucket + 1
        bucket[size] = id
        if size == 8 then -- split bucket in two
            i1 = bucketFurthestSearch(bucket, 7, x, y, z) -- we know xyz is 8th point in bucket
            dx = px[i1]
            dy = py[i1]
            dz = pz[i1]
            i2 = bucketFurthestSearch(bucket, 8, dx, dy, dz)

            dx = dx - px[i2]
            dy = dy - py[i2]
            dz = dz - pz[i2]

            for i = 1, 8 do
                i = bucket[i]
                buffer1[i] = dx*px[i] + dy*py[i] + dz*pz[i]
            end

            table.sort(bucket, sortBucketFunc)

            for i = 1, 8 do -- table hash cleanup
                buffer1[bucket[i]] = nil
            end

            nodesBuffer[7] = {}
            for i = 5, 8 do
                nodesBuffer[7][i - 4] = bucket[i]
                bucket[i] = nil
            end

            i1 = nodes.list_insert(nodesBuffer) -- new sibling

            nodesBuffer[7] = false
            i2 = nodes.list_insert(nodesBuffer) -- new parent
            i3 = nParent[n] -- old parent

            nChild1[i2] = n
            nChild2[i2] = i1
            nParent[n] = i2
            nParent[i1] = i2
            if i3 then
                nParent[i2] = i3
                nodes[nChild1[i3] == n and 1 or 2][i3] = i2
            else -- old parent was root
                bt.BT_rootID = i2
            end

            -- update child nodes balls
            refitBucket(n)
            refitBucket(i1)
            refitSpheres(i2)
        else
            -- expand radius of node to include new inserted point if needed
            dist = nDist2(n, x,y,z)^0.5
            if nr[n] < dist then
                nr[n] = dist
                refitBucket(n)
                refitSpheres(nParent[n])
            end
        end
    end
    ---@endsection

    ---@section BT_remove
    ---assumes point 'id' to be removed is indeed in tree
    ---else another nearby point will be unknowingly removed
    ---easy check to mitigate, but assuming you know your data
    ---@param id integer point id
    bt.BT_remove = function(id)
        bt.BT_nnSearch(px[id], py[id], pz[id])
        n = i3             ---@cast n integer
        bucket = nBucket[n]
        size = #bucket
        if size == 1 then
            i1 = nParent[n]
            if i1 then
                nodes.list_remove(n)
                nodes.list_remove(i1)
                nBucket[n] = false -- not necessary, but allows garbage collection of table

                i2 = nParent[i1]
                i3 = nodes[nChild1[i1] == n and 2 or 1][i1] -- 'n' sibling
                nParent[i3] = i2

                if i2 then
                    nodes[nChild1[i2] == i1 and 1 or 2][i2] = i3 -- set 'n'.parent.parent.child(1|2) ref. to 'n' sibling instead of 'n'.parent
                    refitSpheres(i2)
                else -- 'n'.parent was root
                    bt.BT_rootID = i3
                end
            end
        else -- size > 1
            for i = 1, size-1 do
                if bucket[i] == id then
                    bucket[i] = bucket[size]
                end
            end
        end
        bucket[size] = nil
    end
    ---@endsection

    ---@section BT_nnSearch
    ---@param x number
    ---@param y number
    ---@param z number
    ---@return number dist2, integer pointID
    bt.BT_nnSearch = function(x,y,z, r1, r2)
        buffer1[1] = bt.BT_rootID -- buffer will act as a stack
        buffer2[1] = 0
        size = 1       -- size of buffer
        bestDist = 1e300
        bestP = -1

        while size > 0 do
            n = buffer1[size]
            dist = buffer2[size]
            size = size - 1

            bucket = nBucket[n]
            while not bucket and dist < bestDist do
                i1 = nChild1[n]
                i2 = nChild2[n]
                size = size + 1

                r1 = nDist2(i1, x,y,z) - nr[i1]^2
                r2 = nDist2(i2, x,y,z) - nr[i2]^2

                if r1 < r2 then
                    n = i1
                    dist = r1
                    buffer1[size] = i2
                    buffer2[size] = r2
                else
                    n = i2
                    dist = r2
                    buffer1[size] = i1
                    buffer2[size] = r1
                end

                bucket = nBucket[n]
            end

            if bucket then
                for i = 1, #bucket do
                    i = bucket[i]
                    r1 = pDist2(i, x,y,z)
                    if r1 < bestDist then
                        bestP = i
                        bestDist = r1
                        i3 = n -- 'i3' acts as global variable that can be accesed just after calling this func
                    end
                end
            end
        end
        return bestDist, bestP
    end
    ---@endsection

--    ---@section BT_nnSearchApprox
--    ---Returns nearest leaf node sphere center to (x,y,z)
--    ---@param x number
--    ---@param y number
--    ---@param z number
--    ---@return integer node
--    bt.BT_nnSearchApprox = function(x,y,z)
--        n = bt.BT_rootID
--        bucket = nBucket[n]
--        while not bucket do
--            i1 = nChild1[n]
--            i2 = nChild2[n]
--            n = nDist2(i1, x,y,z) < nDist2(i2, x,y,z) and i1 or i2
--            bucket = nBucket[n]
--        end
--        return n
--    end
--    ---@endsection

    ---@section BT_treeCost
    bt.BT_treeCost = function(cost, rec)
        cost = 0
        function rec(id)
            if not nBucket[id] then
                cost = cost + nr[id]
                rec(nChild1[id])
                rec(nChild2[id])
            end
        end
        rec(bt.BT_rootID)
        return cost
    end
    ---@endsection


    ---@cast bt +BallTree3D
    return bt
end
---@endsection _BALL_TREE_







---@section __DEBUG_BALL_TREE__
-- [===[
local px, py, pz = newTables{3}
local points = list{px, py, pz}
local pbuffer = {0,0,0}
local ballTree = BallTree3D(px, py, pz)

local num = 10000
local width, height = 32*10, 32*10

math.randomseed(0)
local rand = function(scale)
    return (math.random() - 0) * (scale or 1)
end

-- [=[
do
    for i = 1, num do -- init dataset
        pbuffer[1] = rand(width)
        pbuffer[2] = rand(height)
        points.list_insert(pbuffer)
    end

    local t1, t2
    t1 = os.clock()
    for i = 1, num do
        ballTree.BT_insert(i)
    end
    t2 = os.clock()
    print("Time insert: "..(t2-t1))
    print("TreeCost: "..ballTree.BT_treeCost())

    t1 = os.clock()
    for i = 1, num do
        ballTree.BT_remove(i)
    end
    t2 = os.clock()
    print("Time remove: "..(t2-t1))
    print("TreeCost: "..ballTree.BT_treeCost())

    t1 = os.clock()
    for i = 1, num do
        ballTree.BT_insert(i)
    end
    t2 = os.clock()
    print("Time insert: "..(t2-t1))
    print("TreeCost: "..ballTree.BT_treeCost())
end
--]=]


local nChild1, nChild2, nx, ny, nz, nr, nBucket, nParent, nDepth = table.unpack(ballTree.BT_nodes)
local drawNearestPoint, dist
local sx, sy, dx, dy
local _touched = false

function onTick()
    local touched = input.getBool(1)
    sx = input.getNumber(3)
    sy = input.getNumber(4)

    drawNearestPoint = input.getBool(3) and touched

    if drawNearestPoint then
        local d, p = ballTree.BT_nnSearch(sx, sy, 0)
        dx = px[p]
        dy = py[p]
        dist = d^0.5

    elseif touched and touched ~= _touched then
        if input.getBool(2) then
            local dist2, p = ballTree.BT_nnSearch(sx, sy, 0)
            ballTree.BT_remove(p)
        else
            pbuffer[1] = sx
            pbuffer[2] = sy
            local id = points.list_insert(pbuffer)
            ballTree.BT_insert(id)
        end
    end
    _touched = touched
end

function drawRecursion(n)
    local d = 128/nDepth[n]
    local b = nBucket[n]

    screen.setColor(128 + rand(127), 255 - d, rand(128-d), 2*d)
    screen.drawCircle(nx[n], ny[n], nr[n])

    if b then
        --screen.setColor(128 + rand(127), 255 - d, rand(255-d/2), d)
        --screen.drawCircle(nx[n], ny[n], nr[n])

        screen.setColor(0, 255, 0, 150)
        for i = 1, #b do
            i = b[i]
            screen.drawCircleF(px[i], py[i], 0.6)
        end
    else
        drawRecursion(nChild1[n])
        drawRecursion(nChild2[n])
    end
end

function onDraw()
    math.randomseed(1)
    drawRecursion(ballTree.BT_rootID)
    screen.setColor(255,255,255)
    screen.drawText(1,1, "Max Depth: "..tostring(nDepth[ballTree.BT_rootID]))

    if drawNearestPoint then
        screen.setColor(0, 255, 0)
        screen.drawLine(sx, sy, dx, dy)
        screen.drawText(1, 7, "Dist: "..dist)
    end
end

--]===]
---@endsection





-- MIT License
-- 
-- Copyright (c) 2025 Jumper-44
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.