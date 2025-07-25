-- Author: Jumper
-- GitHub: https://github.com/Jumper-44
-- MIT License at end of this file

--[[ DEBUG ONLY
do
    ---@type Simulator -- Set properties and screen sizes here - will run once when the script is loaded
    simulator = simulator
    simulator:setScreen(1, "100x30")

    local _isTouched = false

    -- Runs every tick just before onTick; allows you to simulate the inputs changing
    ---@param simulator Simulator Use simulator:<function>() to set inputs etc.
    ---@param ticks     number Number of ticks since simulator started
    function onLBSimulatorTick(simulator, ticks)
        local screenConnection = simulator:getTouchScreen(1)
        if screenConnection.isTouched and screenConnection.isTouched ~= _isTouched then

        end
        _isTouched = screenConnection.isTouched

    end
end
--]]


require("DataStructures.JL_list")
require("Utility.newTables")

---@section BVH_AABB 1 _BVH_AABB_
---@class BoundingVolumeHierarchyAABB
---@field BVH_nodes list {node_child1, node_child2, node_parent, node_item, node_surfaceArea,  AABB_minX, AABB_minY, AABB_minZ, AABB_maxX, AABB_maxY, AABB_maxZ}
---@field BVH_rootIndex integer
---@field BVH_insert fun(item: number|table|true, minAABB: table<number, number, number>, maxAABB: table<number, number, number>): integer
---@field BVH_remove fun(LeafNode: integer)
---@field BVH_treeCost fun(): number

---Incrementive Bounding Volume Hierarchy (BVH) constructed by Surface Area Heuristic (SAH) of axis-aligned bounding box (AABB).  
---Base class with insert and remove. Implement own search like frustum culling or ray intersection.  
---For own search implementation use the tables 'BVH_nodes' and 'BVH_rootIndex'  
---Reference for implementation of insertion SAH https://box2d.org/files/ErinCatto_DynamicBVH_Full.pdf
---@return BoundingVolumeHierarchyAABB
---@overload fun(): BoundingVolumeHierarchyAABB
BVH_AABB = function(temp1, temp2, temp3, temp4, i1, i2, index, newNode, newNode_SA, unionNodeAABB, updateNodeAABB, surfaceAreaAABB, best_sibling, best_cost, inherited_cost)
    local node_buffer, minBuffer1, maxBuffer1, minBuffer2, maxBuffer2, minBuffer3, maxBuffer3, AABB_minX, AABB_minY, AABB_minZ, AABB_maxX, AABB_maxY, AABB_maxZ, node_child1, node_child2, node_parent, node_item, node_surfaceArea, node_maxDepth =
        {false, false, false, false, 0,0,0, 0,0,0, 0,1}, newTables{18}

    local BVH, nodes, AABB_min, AABB_max =
        {},
        list{node_child1, node_child2, node_parent, node_item,  AABB_minX, AABB_minY, AABB_minZ, AABB_maxX, AABB_maxY, AABB_maxZ, node_surfaceArea, node_maxDepth},
        {AABB_minX, AABB_minY, AABB_minZ}, {AABB_maxX, AABB_maxY, AABB_maxZ}

    BVH.BVH_rootIndex = false
    BVH.BVH_nodes = nodes

    ---@param nodeA integer
    ---@param nodeB integer
    ---@param minBuffer table
    ---@param maxBuffer table
    ---@param min   any local variable
    ---@param max   any local variable
    ---@overload fun(nodeA: integer, nodeB: integer, minBuffer: table, maxBuffer: table)
    function unionNodeAABB(nodeA, nodeB, minBuffer, maxBuffer, min, max)
        for i = 1, 3 do
            min = AABB_min[i]
            max = AABB_max[i]
            minBuffer[i] = min[nodeA] < min[nodeB] and min[nodeA] or min[nodeB]
            maxBuffer[i] = max[nodeA] < max[nodeB] and max[nodeB] or max[nodeA]
        end
    end

    ---@param node integer
    ---@param minAABB table<number, number, number>
    ---@param maxAABB table<number, number, number>
    function updateNodeAABB(node, minAABB, maxAABB)
        for i = 1, 3 do
            AABB_min[i][node] = minAABB[i]
            AABB_max[i][node] = maxAABB[i]
        end
    end

    ---@param minAABB table<number, number, number>
    ---@param maxAABB table<number, number, number>
    ---@param dx      any local variable
    ---@param dy      any local variable
    ---@param dz      any local variable
    ---@return number
    function surfaceAreaAABB(minAABB, maxAABB, dx, dy, dz)
        dx = maxAABB[1] - minAABB[1]
        dy = maxAABB[2] - minAABB[2]
        dz = maxAABB[3] - minAABB[3]
        return dx * dy + dy * dz + dz * dx
    end

    ---@section BVH_refitAABBs
    ---Walk up the tree refitting AABBs and set node surface area
    ---@param node integer|false
    ---@param sameSA boolean|nil
    BVH.BVH_refitAABBs = function(node, sameSA)
--#if without tree rotation
--        while node do
--            unionNodeAABB(node_child1[node], node_child2[node], minBuffer1, maxBuffer1)
--            updateNodeAABB(node, minBuffer1, maxBuffer1)
--            temp1 = node_surfaceArea[node]                  -- SAH before update
--            temp2 = surfaceAreaAABB(minBuffer1, maxBuffer1) -- SAH after update
--            if temp1 == temp2 then break end                -- Early termination if SAH remains the same
--
--            node_surfaceArea[node] = temp2
--            node = node_parent[node]
--        end
--
--#elseif with tree rotation, no node depth penalty, no early termination
--        while node do
--            if not sameSA then
--                unionNodeAABB(node_child1[node], node_child2[node], minBuffer1, maxBuffer1)
--                updateNodeAABB(node, minBuffer1, maxBuffer1)
--                temp1 = node_surfaceArea[node]
--                temp2 = surfaceAreaAABB(minBuffer1, maxBuffer1)
--                node_surfaceArea[node] = temp2
--                sameSA = temp1 == temp2
--            end
--
--            -- Try tree rotation [Reference: Page 111-127], specifically [Reference: Page 115], where F in ref. is 'node'
--            temp1 = node_parent[node]
--            if temp1 then -- not root
--                temp2 = node_parent[temp1] -- 'node'.parent.parent
--                if temp2 then -- not root
--                    i1 = node_child1[temp1] == node and 2 or 1
--                    temp3 = nodes[i1][temp1] -- 'node' sibling
--
--                    i2 = node_child1[temp2] == temp1 and 2 or 1
--                    temp4 = nodes[i2][temp2] -- 'node'.parent sibling
--
--                    if sameSA then
--                        best_cost = node_surfaceArea[temp1]
--                    else
--                        unionNodeAABB(node, temp3, minBuffer1, maxBuffer1)
--                        best_cost = surfaceAreaAABB(minBuffer1, maxBuffer1)
--                    end
--
--                    unionNodeAABB(temp3, temp4, minBuffer1, maxBuffer1)
--                    if surfaceAreaAABB(minBuffer1, maxBuffer1) < best_cost then
--                       node_parent[temp4] = temp1
--                       node_parent[node]  = temp2
--                       nodes[i1%2+1][temp1] = temp4
--                       nodes[i2][temp2] = node
--                       sameSA = false
--                    end
--                end
--            end
--
--            node = temp1
--        end
--
--#elseif with tree rotation and depth penalty to balance tree more, with early termination
        while node do
            i1 = node_child1[node]
            i2 = node_child2[node]
            temp1 = node_maxDepth[node]
            node_maxDepth[node] = math.max(node_maxDepth[i1], node_maxDepth[i2]) + 1

            if sameSA and temp1 == node_maxDepth[node] then
                break
            end

            temp1 = node_parent[node] -- 'node'.parent
            if not sameSA then
                unionNodeAABB(i1, i2, minBuffer1, maxBuffer1)
                updateNodeAABB(node, minBuffer1, maxBuffer1)

                temp2 = node_surfaceArea[node]                  -- SA before update
                temp3 = surfaceAreaAABB(minBuffer1, maxBuffer1) -- SA after update
                sameSA = temp2 == temp3
                node_surfaceArea[node] = temp3
            end

            -- Try tree rotation [Reference: Page 111-127], specifically [Reference: Page 115], where F in ref. is 'node'
            if temp1 then -- not root
                temp2 = node_parent[temp1] -- 'node'.parent.parent
                if temp2 then -- not root
                    i1 = node_child1[temp1] == node and 2 or 1
                    temp3 = nodes[i1][temp1] -- 'node' sibling

                    i2 = node_child1[temp2] == temp1 and 2 or 1
                    temp4 = nodes[i2][temp2] -- 'node'.parent sibling

                    unionNodeAABB(temp3, temp4, minBuffer1, maxBuffer1)
                    best_sibling = surfaceAreaAABB(minBuffer1, maxBuffer1)

                    if sameSA then
                        best_cost = node_surfaceArea[temp1]
                    else
                        unionNodeAABB(node, temp3, minBuffer1, maxBuffer1)
                        best_cost = surfaceAreaAABB(minBuffer1, maxBuffer1)
                    end

                    if best_sibling / best_cost < 1 + node_maxDepth[node] - node_maxDepth[temp4] then -- SAH with depth penalty
                        node_parent[temp4] = temp1
                        node_parent[node]  = temp2
                        nodes[i1%2+1][temp1] = temp4
                        nodes[i2][temp2] = node
                        sameSA = false
                    end
                end
            end

            node = temp1
        end
--#end
    end
    ---@endsection

    ---@section BVH_insert
    ---comment
    ---@param item number|table|true
    ---@param minAABB table<number, number, number>
    ---@param maxAABB table<number, number, number>
    ---@return integer leafNode
    BVH.BVH_insert = function(item, minAABB, maxAABB) -- [Reference: Page 54]
        newNode = nodes.list_insert(node_buffer)
        node_item[newNode] = item
        newNode_SA = surfaceAreaAABB(minAABB, maxAABB)
        node_surfaceArea[newNode] = newNode_SA
        updateNodeAABB(newNode, minAABB, maxAABB)

        index = BVH.BVH_rootIndex
        if index then
            best_sibling = index
            unionNodeAABB(index, newNode, minBuffer3, maxBuffer3)
            best_cost = surfaceAreaAABB(minBuffer3, maxBuffer3)
            inherited_cost = best_cost - node_surfaceArea[index]

            temp4 = best_cost
            -- Find best sibling that adds least surface area to tree. [Reference: Page 77-88]
            while (node_item[index] == false) and (newNode_SA + inherited_cost < best_cost) do -- Is node not a leaf and is lowerbound cost of child nodes less than best_cost. [Reference: Page 86-87]
                i1 = node_child1[index]
                i2 = node_child2[index]
                unionNodeAABB(i1, newNode, minBuffer1, maxBuffer1)
                unionNodeAABB(i2, newNode, minBuffer2, maxBuffer2)
                temp1 = surfaceAreaAABB(minBuffer1, maxBuffer1)
                temp2 = surfaceAreaAABB(minBuffer2, maxBuffer2)

                temp3 = temp1 + inherited_cost
                if temp3 < best_cost then
                    best_cost = temp3
                    best_sibling = i1
                end

                temp3 = temp2 + inherited_cost
                if temp3 < best_cost then
                    best_cost = temp3
                    best_sibling = i2
                elseif index == best_sibling then -- the children was not better cost than parent
                    break
                end

                if node_surfaceArea[index] ~= temp4 then -- refit AABB if SA changes and index is not a sibling to new node
                    node_surfaceArea[index] = temp4
                    updateNodeAABB(index, minBuffer3, maxBuffer3)
                end

                if best_sibling == i1 then
                    temp4 = temp1
                    minBuffer3, minBuffer1 = minBuffer1, minBuffer3
                    maxBuffer3, maxBuffer1 = maxBuffer1, maxBuffer3
                else
                    temp4 = temp2
                    minBuffer3, minBuffer2 = minBuffer2, minBuffer3
                    maxBuffer3, maxBuffer2 = maxBuffer2, maxBuffer3
                end

                inherited_cost = best_cost - node_surfaceArea[best_sibling]
                index = best_sibling
            end

            -- Insert newNode in tree and walk back up the tree refitting AABBs [Reference: Page 56-57]
            temp1 = nodes.list_insert(node_buffer) -- newParent
            temp2 = node_parent[best_sibling]      -- oldParent
            node_parent[temp1] = temp2
            node_child1[temp1] = best_sibling
            node_child2[temp1] = newNode
            node_parent[best_sibling] = temp1
            node_parent[newNode] = temp1

            if temp2 then -- best_sibling was not root
                nodes[node_child1[temp2] == best_sibling and 1 or 2][temp2] = temp1
            else -- best_sibling was root
                BVH.BVH_rootIndex = temp1
            end

            BVH.BVH_refitAABBs(temp1)
        else -- Is first/root node in tree
            BVH.BVH_rootIndex = newNode
        end

        return newNode
    end
    ---@endsection

    ---@section BVH_remove
    ---Remove node containing 'item', i.e. a leaf node.  
    ---@param leafNode integer
    BVH.BVH_remove = function(leafNode)
        --node_item[leafNode] = false
        temp1 = node_parent[leafNode]
        nodes.list_remove(leafNode)

        if temp1 then -- leafNode was not root
            temp2 = node_parent[temp1]
            nodes.list_remove(temp1)

            temp3 = nodes[node_child1[temp1] == leafNode and 2 or 1][temp1] --leafNode sibling
            node_parent[temp3] = temp2

            if temp2 then -- Set leafNode.parent.parent child reference to leafNode sibling
                nodes[node_child1[temp2] == temp1 and 1 or 2][temp2] = temp3
            else -- leafNode.parent was root
                BVH.BVH_rootIndex = temp3
            end

            BVH.BVH_refitAABBs(temp2)
        else -- leafNode was root
            BVH.BVH_rootIndex = false
        end
    end
    ---@endsection

    ---@section BVH_treeCost
    ---Debug function. Returns the sum of all internal nodes area.  
    ---If two trees have the same leaf nodes, then the tree with smaller cost is better by SAH cost metric.  
    ---Note that this implementation doesn't take in that the tree may be unbalanced,  
    ---in which it isn't better to have a smaller SAH cost, as BVH may just be a linked list.  
    ---(But tree rotations are done, so it shouldn't be overly unbalanced.)  
    ---If -1 is returned, then it was undetermined. (Didn't bother code a brute force check depending on a condition)  
    ---[Reference: Page 74]
    ---@return number cost
    BVH.BVH_treeCost = function()
        local cost = 0
        if #nodes.removed_id == 0 then
            for i = 1, #node_item do
                if node_item[i] == false then -- is internal node
                    cost = cost + node_surfaceArea[i]
                end
            end
        else
            cost = -1
        end
        return cost
    end
    ---@endsection

    return BVH
end
---@endsection _BVH_AABB_









---@section __DEBUG_BVH_AABB__
--[[ DEBUG. Inserting and deleting from BVH, as well as rendering tree nodes illustration.
do
    local n = 10000 -- Amount of AABB/objects to insert
    local objectsPerInsertion = n
    local treeDrawWidthScale = 20
    debug = 0

    local bvh = BVH_AABB()
    local AABB_minX, AABB_minY, AABB_minZ, AABB_maxX, AABB_maxY, AABB_maxZ, BVH_ID = {},{},{}, {},{},{}, {}
    local AABB = list{AABB_minX, AABB_minY, AABB_minZ, AABB_maxX, AABB_maxY, AABB_maxZ, BVH_ID}
    local AABB_min, AABB_max = {AABB_minX, AABB_minY, AABB_minZ}, {AABB_maxX, AABB_maxY, AABB_maxZ}
    local AABB_buffer, AABB_min_buffer, AABB_max_buffer = {0,0,0, 0,0,0, 0}, {0,0,0}, {0,0,0}

    local fetchAABB = function(id)
        for i = 1, 3 do
            AABB_min_buffer[i] = AABB_min[i][id]
            AABB_max_buffer[i] = AABB_max[i][id]
        end
    end

    math.randomseed(0)
    local rand = function(scale)
        return (math.random() - 0.5) * (scale or 1)
    end

local temp = 0

--- Invalid AABB bounds insertion
--    AABB_buffer[3] = 0
--    AABB_buffer[6] = 0
--    local n_05 = math.ceil(n^0.5)
--    for i = 1, n_05 do
--        for j = 1, n_05 do
--            temp = rand(50000)
--            AABB_buffer[1] = temp - 4 + rand(50)
--            AABB_buffer[2] = temp - 4 + rand(50)
--            AABB_buffer[4] = temp + 4 + rand(50)
--            AABB_buffer[5] = temp + 4 + rand(50)
--            AABB.list_insert(AABB_buffer)
--        end
--    end

    for i = 1, n do
        for j = 1, 3 do
            temp = rand(10000)
            AABB_buffer[j]   = temp - 100 + rand(50)
            AABB_buffer[j+3] = temp + 100 + rand(50)
        end
        AABB.list_insert(AABB_buffer)
    end

--[===[
    local t1 = os.clock()
    for i = 1, n do
        fetchAABB(i)
        BVH_ID[i] = bvh.BVH_insert(i, AABB_min_buffer, AABB_max_buffer)
    end
    local t2 = os.clock()
    print("init time1: "..(t2-t1))
    print(bvh.BVH_treeCost())

    t1 = os.clock()
    for i = 1, n do
        bvh.BVH_remove(BVH_ID[i])
    end
    t2 = os.clock()
    print("Rem time2: "..(t2-t1))

    t1 = os.clock()
    for i = 1, n do
        fetchAABB(i)
        BVH_ID[i] = bvh.BVH_insert(i, AABB_min_buffer, AABB_max_buffer)
    end
    t2 = os.clock()

    print("init time2: "..(t2-t1))
    print(bvh.BVH_treeCost()) -- expected to be the same as earlier BVH.treeCost print
--]===]
-- [===[
    ---
    --- Ensure that child nodes AABB reside in parent AABB (invariant)
    --- Calculate all leaf nodes depth in tree
    ---
    local tick = -60 -- set negative for tick delay
    local drawBVH
    local count = 0
    local reverse = false
    local function debugInsert()
        local depthLevels = {}
        local nodes = bvh.BVH_nodes

        if tick >= 1 then
            tick = 1

            if reverse then
                if count > 1 then
                    bvh.BVH_remove(BVH_ID[count])
                    count = count - 1
                elseif count == 1 then
                    reverse = false
                end
            else
                if count < n then
                    local maxC = math.min(n - count, objectsPerInsertion)
                    local t1 = os.clock()
                    for i = 1, maxC do
                        count = count + 1
                        fetchAABB(count)
                        BVH_ID[count] = bvh.BVH_insert(count, AABB_min_buffer, AABB_max_buffer)
                    end
                    local t2 = os.clock()
                    print("Obj. Inserted: "..maxC..", time: "..(t2-t1))
                elseif count == n then
                    reverse = true
                    tick = -120
                    print("TreeCost: "..bvh.BVH_treeCost())
                end
            end

--            function test_invariant(nodeID, depth)
--                local e = 1e-9
--                local minX, minY, minZ, maxX, maxY, maxZ
--                minX = nodes[5][nodeID]  - e
--                minY = nodes[6][nodeID]  - e
--                minZ = nodes[7][nodeID]  - e
--                maxX = nodes[8][nodeID]  + e
--                maxY = nodes[9][nodeID]  + e
--                maxZ = nodes[10][nodeID] + e
--
--                for i = 1, 2 do
--                    local child = nodes[i][nodeID]
--                    if child then
--                        if minX > nodes[5][child] or nodes[8][child]  > maxX
--                        or minY > nodes[6][child] or nodes[9][child]  > maxY
--                        or minZ > nodes[7][child] or nodes[10][child] > maxZ
--                        then
--                            print("AABB bound error at child: "..tostring(child))
--                        end
--                        test_invariant(child, depth + 1)
--                    end
--                end
--                if not (nodes[1][nodeID] and nodes[2][nodeID]) then
--                    depthLevels[#depthLevels+1] = depth
--                end
--            end
--            test_invariant(bvh.BVH_rootIndex, 0)
--
--            t1 = os.clock()
--            table.sort(depthLevels)
--            local depth = {} -- view variables in debug mode.  Depth level
--            local depthAmount = {}  --                         Amount of leafs at the depth level in 'depth'
--
--            local currentDepth, currentDepthID
--            for i = 1, #depthLevels do
--                if currentDepth ~= depthLevels[i] then
--                    currentDepth = depthLevels[i]
--                    currentDepthID = #depth+1
--                    depth[currentDepthID] = currentDepth
--                    depthAmount[currentDepthID] = 1
--                else
--                    depthAmount[currentDepthID] = depthAmount[currentDepthID] + 1
--                end
--            end
--            t2 = os.clock()
            --print("--- Ran test_invariant in "..(t2-t1).." ---")
        else
            tick = tick + 1
        end


        local log = math.log(#nodes[1], 2)
        function drawBVH(i, x, y, d)
--            screen.setColor(255, 255, 255)
--            screen.drawText(x, y, i)
            local c1 = nodes[1][i]
            local c2 = nodes[2][i]
            local offset = math.max(0, (log-d)*treeDrawWidthScale/(d))
--            screen.setColor(0, 255, 0, 150)
            if (c1) then
                local nX = x-5 - offset
                local nY = y+5 + d*2
                screen.drawLine(x+3, y+3, nX+3, nY+3)
                d = d + 1
                drawBVH(c1, nX, nY, d)

                -- right node
                nX = x+5 + offset
                screen.drawLine(x+3, y+3, nX+3, nY+3)
                drawBVH(c2, nX, nY, d)
            end
        end
    end

    function onTick()
        debugInsert()
    end

    function onDraw()
        local w = screen.getWidth()
        screen.setColor(0, 255, 0, 100)
        drawBVH(bvh.BVH_rootIndex, w/2, 5, 1)
        if bvh.BVH_rootIndex then
            screen.setColor(255, 255, 0)
            screen.drawText(w/4, 5, "Max depth: "..bvh.BVH_nodes[12][bvh.BVH_rootIndex])
            screen.drawText(w/4, 12, "Objects: "..(#bvh.BVH_nodes[12]+1)//2)
            screen.drawText(w/4, 20, "debug: "..tostring(debug))
        end
    end
    --]===]
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