-- Author: Jumper
-- GitHub: https://github.com/Jumper-44
-- MIT License at end of this file

---@class IKDTree
---@field IKDTree_insert fun(point: integer)
---@field IKDTree_nearestNeighbor fun(point: table): integer, number
--    ---@field IKDTree_len2 fun(pointA_Buffer: table, pointB_ID: integer)
--    ---@field IKDTree_remove fun(point: integer)
--    ---@field IKDTree_nearestNeighbors fun(point: table, maxReturnedNeighbors: integer): table
--    ---@field pointsLen2 table

require("DataStructures.JL_list")

---kd-tree with focus on using integer ID for references rather than tables,  
---but tables are still used in leaf nodes to hold buckets of points and split at size of 16 (arbitrarily picked number of 2^n),  
---to balance tree better on insertion as no other local rotation/reordering is implemented.  
---@section IKDTree 1 _IKDTREE_
---@param IKD_Tree table        ' {{x,x,...,x},{y,y,...,y}, ..., {n,n,...,n}} '
---@param k_dimensions integer  dimension/size to use of 'IKD_Tree'
---@overload fun(IKD_Tree: table, k_dimensions: integer)
IKDTree = function(IKD_Tree, k_dimensions, nodes, pointBuffer, points, sortFunction, nearestNeighborRecursive, bestPointID, bestLen2, dist, nodeID, cd, depth)
    --local IKDTree_len2, nearestPoints, maxNeighbors, insertSort, nearestNeighborsRecursive
    --local pointsLen2 = {}
    local nSplit, nLeft, nRight, nPoints, newNodeBuffer = {}, {}, {}, {}, {0, 0, 0, {}}

    nodes = list{
        nSplit, -- split value
        nLeft, -- left node_id
        nRight, -- right node_id
        nPoints  -- pointID table or false, if table then it is a leaf node
    }
    nodes.list_insert(newNodeBuffer)

    ---@section IKDTree_insert
    sortFunction = function(a, b) return IKD_Tree[cd][a] < IKD_Tree[cd][b] end

    ---Inserts a point into the k-d tree
    ---@param pointID integer
    IKD_Tree.IKDTree_insert = function(pointID)
        nodeID = 1
        cd     = 1
        depth  = 1

        repeat
            points = nPoints[nodeID]
            if points then  -- leaf node?
                points[#points+1] = pointID
                if #points == 16 then -- Split node when it contains 16 points and move half-half of points to children
                    table.sort(points, sortFunction)
                    nSplit[nodeID] = (IKD_Tree[cd][points[8]] + IKD_Tree[cd][points[9]]) / 2

                    nPoints[nodeID] = false
                    newNodeBuffer[4] = points
                    nLeft[nodeID] = nodes.list_insert(newNodeBuffer)
                    newNodeBuffer[4] = {}
                    nRight[nodeID] = nodes.list_insert(newNodeBuffer)

                    for i = 9, 16 do
                        newNodeBuffer[4][i - 8] = points[i]
                        points[i] = nil
                    end
                end
            else -- is internal node and therefore search further down the tree
                nodeID = IKD_Tree[cd][pointID] < nSplit[nodeID] and nLeft[nodeID] or nRight[nodeID]
                cd     = depth % k_dimensions + 1
                depth  = depth + 1
            end
        until points
    end
    ---@endsection

--    ---@section IKDTree_remove
--    ---Finds leaf containing pointID and removes it from leaf.
--    ---@param pointID table
--    IKD_Tree.IKDTree_remove = function(pointID)
--        nodeID = 1
--        cd     = 1
--        depth  = 1
--
--        repeat
--            points = nPoints[nodeID]
--            if points then -- leaf node?
--                for i = 1, #points do
--                    if pointID == points[i] then
--                        points[i] = points[#points]
--                        points[#points] = nil
--                    end
--                end
--            else -- is internal node and therefore search further down the tree
--                nodeID = IKD_Tree[cd][pointID] < nSplit[nodeID] and nLeft[nodeID] or nRight[nodeID]
--                cd     = depth % k_dimensions + 1
--                depth  = depth + 1
--            end
--        until points
--    end
--    ---@endsection

--    ---@section IKDTree_len2
--    ---@param pointA_buffer table
--    ---@param pointB_ID integer
--    ---@return number
--    function IKDTree_len2(pointA_buffer, pointB_ID)
--        local sum = 0
--        for i = 1, k_dimensions do
--            local dis = pointA_buffer[i] - IKD_Tree[i][pointB_ID]
--            sum = sum + dis*dis
--        end
--        return sum
--    end
--    IKD_Tree.IKDTree_len2 = IKDTree_len2
--    ---@endsection

--    ---@section IKDTree_nearestNeighbors
--    IKD_Tree.pointsLen2 = pointsLen2
--
--    ---Insertion sort to local nearestPoints
--    ---@param p table
--    function insertSort(p)
--        for i = 1, #nearestPoints do
--            if pointsLen2[p] < pointsLen2[nearestPoints[i]] then
--                table.insert(nearestPoints, i, p)
--                return
--            end
--        end
--        nearestPoints[#nearestPoints+1] = p
--    end
--
--    ---@param nodeID integer
--    ---@param depth integer
--    function nearestNeighborsRecursive(nodeID, depth)
--        local cd, nextBranch, ortherBranch = depth % k_dimensions + 1, nRight[nodeID], nLeft[nodeID]
--
--        points = nPoints[nodeID]
--        if points then -- leaf node?
--            for i = 1, #points do
--                pointsLen2[points[i]] = IKDTree_len2(pointBuffer, points[i])
--                if #nearestPoints < maxNeighbors then
--                    insertSort(points[i])
--                else
--                    if pointsLen2[points[i]] < pointsLen2[nearestPoints[maxNeighbors]] then
--                        nearestPoints[maxNeighbors] = nil
--                        insertSort(points[i])
--                    end
--                end
--            end
--        else
--            if pointBuffer[cd] < nSplit[nodeID] then
--                nextBranch, ortherBranch = ortherBranch, nextBranch
--            end
--
--            nearestNeighborsRecursive(nextBranch, depth+1)
--            dist = pointBuffer[cd] - nSplit[nodeID]
--            if #nearestPoints < maxNeighbors or pointsLen2[nearestPoints[maxNeighbors]] >= dist*dist then
--                nearestNeighborsRecursive(ortherBranch, depth+1)
--            end
--        end
--    end

--    ---Returns the nearest point(s)ID in k-d tree to @param point up to @param maxNeighbors
--    ---@param point table
--    ---@param maxReturnedNeighbors integer
--    ---@return table
--    IKD_Tree.IKDTree_nearestNeighbors = function(point, maxReturnedNeighbors)
--        nearestPoints = {}
--        pointBuffer = point
--        maxNeighbors = maxReturnedNeighbors
--        nearestNeighborsRecursive(1, 0)
--        return nearestPoints
--    end
--    ---@endsection

    ---@section IKDTree_nearestNeighbor
    ---comment
    ---@param nodeID integer
    ---@param depth integer
    ---@param cd any local variable
    ---@param cond any local variable
    ---@overload fun(nodeID: integer, depth: integer)
    function nearestNeighborRecursive(nodeID, depth, cd, cond)
        points = nPoints[nodeID]
        if points then -- leaf node?
            for i = 1, #points do
                --dist = IKDTree_len2(pointBuffer, points[i]) -- inlined function as only used here once
                dist = 0
                for j = 1, k_dimensions do
                    cd = pointBuffer[j] - IKD_Tree[j][points[i]]
                    dist = dist + cd*cd
                end

                if dist < bestLen2 then
                    bestLen2 = dist
                    bestPointID = points[i]
                end
            end
        else
            cd = depth % k_dimensions + 1
            cond = pointBuffer[cd] < nSplit[nodeID]

            nearestNeighborRecursive(cond and nLeft[nodeID] or nRight[nodeID], depth+1)
            if bestLen2 >= (pointBuffer[cd] - nSplit[nodeID])^2 then
                nearestNeighborRecursive(cond and nRight[nodeID] or nLeft[nodeID], depth+1)
            end
        end
    end

    ---Returns the nearest pointID in k-d tree to @param point
    ---@param point table
    ---@return integer, number
    IKD_Tree.IKDTree_nearestNeighbor = function(point)
        pointBuffer = point
        bestPointID = 0
        bestLen2 = 1e300
        nearestNeighborRecursive(1, 0)
        return bestPointID, bestLen2
    end
    ---@endsection

    ---@cast IKD_Tree +IKDTree
end
---@endsection _IKDTREE_





---@section __IKDTree_DEBUG__
--[[
do
    local s1, s2 = 1e6, 5e5
    local pointBuffer = {}
    local px,py,pz = {},{},{}
    local points = list({px,py,pz})
    local t = IKDTree(px,py,pz)
    local t1, t2
    local rand = math.random
    math.randomseed(123)

    for i = 1, s1 do
        pointBuffer[1] = (rand()-.5)*100
        pointBuffer[2] = (rand()-.5)*100
        pointBuffer[3] = (rand()-.5)*100
        points.list_insert(pointBuffer)
    end
    t1 = os.clock()
    for i = 1, s1 do
        t.IKDTree_insert(i)
    end
    print("IKDTree init: "..(os.clock()-t1))
    t1 = os.clock()
    for i = s2, s1 do
        t.IKDTree_remove(i)
    end
    print("IKDTree rem:  "..(os.clock()-t1))


    print("--- nearest neighbor ---")
    local time, nearest = {}, 0
    for k = 1, 10 do -- IKDTree nearest neighbor
        pointBuffer[1] = (rand()-.5)*100
        pointBuffer[2] = (rand()-.5)*100
        pointBuffer[3] = (rand()-.5)*100

        t1 = os.clock()
        for i = 1, 100 do
            nearest = t.IKDTree_nearestNeighbor(pointBuffer)      -- t.IKDTree_nearestNeighbors(pointBuffer, 1)[1]
        end
        t2 = os.clock()

        local best, brute_n = 0x7fffffffffffffff, nil
        for i = 1, s2 do
            if t.IKDTree_len2(pointBuffer, i) < best then
                best = t.IKDTree_len2(pointBuffer, i)
                brute_n = i
            end
        end

        time[k] = t2-t1
        print("tree: "..t.IKDTree_len2(pointBuffer, nearest)..", brute: "..best..", is equal: "..tostring(nearest==brute_n)..", time: "..time[k])
    end

    local avg = 0
    for k = 1, #time do
        avg = avg + time[k]/#time
    end
    print("nearest, iterations: "..#time..", avg: "..avg)

--    t1 = os.clock()
--    for k = 1, 1e4 do
--        pointBuffer[1] = (rand()-.5)*100
--        pointBuffer[2] = (rand()-.5)*100
--        pointBuffer[3] = (rand()-.5)*100
--
--        t.IKDTree_nearestNeighbors(pointBuffer, 1)
--    end
--    t2 = os.clock()
--    print("1 nearest, 1e4: "..(t2-t1))
--
--    t1 = os.clock()
--    for k = 1, 1e4 do
--        pointBuffer[1] = (rand()-.5)*100
--        pointBuffer[2] = (rand()-.5)*100
--        pointBuffer[3] = (rand()-.5)*100
--
--        t.IKDTree_nearestNeighbors(pointBuffer, 5)
--    end
--    t2 = os.clock()
--    print("5 nearest, 1e4: "..(t2-t1))
--
--    t1 = os.clock()
--    for k = 1, 1e4 do
--        pointBuffer[1] = (rand()-.5)*100
--        pointBuffer[2] = (rand()-.5)*100
--        pointBuffer[3] = (rand()-.5)*100
--
--        t.IKDTree_nearestNeighbors(pointBuffer, 10)
--    end
--    t2 = os.clock()
--    print("10 nearest, 1e4: "..(t2-t1))
--
--    t1 = os.clock()
--    for k = 1, 1e4 do
--        pointBuffer[1] = (rand()-.5)*100
--        pointBuffer[2] = (rand()-.5)*100
--        pointBuffer[3] = (rand()-.5)*100
--
--        t.IKDTree_nearestNeighbors(pointBuffer, 25)
--    end
--    t2 = os.clock()
--    print("25 nearest, 1e4: "..(t2-t1))
end
--]]
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