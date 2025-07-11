-- Author: Jumper
-- GitHub: https://github.com/Jumper-44
-- MIT License at end of this file

--[[ DEBUG ONLY
do
    ---@type Simulator -- Set properties and screen sizes here - will run once when the script is loaded
    simulator = simulator
    simulator:setScreen(1, "100x20")

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


require("JumperLib.DataStructures.JL_list")

---@section BVH_AABB 1 _BVH_AABB_
---@class BoundingVolumeHierarchyAABB
---@field BVH_nodes list
---@field BVH_rootIndex integer
---@field BVH_insert fun(item: number|table|true, minAABB: table<number, number, number>, maxAABB: table<number, number, number>): integer
---@field BVH_remove fun(LeafNode: integer)
---@field BVH_treeCost fun(): number

---Incrementive Bounding Volume Hierarchy (BVH) constructed by Surface Area Heuristic (SAH) of axis-aligned bounding box (AABB).  
---Base class with insert and remove. Implement own search like frustum culling or ray intersection.  
---For own search implementation use the tables 'BVH_nodes' and 'BVH_rootIndex'  
---Reference for implementation of insertion SAH https://box2d.org/files/ErinCatto_DynamicBVH_Full.pdf
---@return BoundingVolumeHierarchyAABB
BVH_AABB = function()
    local AABB_min_buffer, AABB_max_buffer, AABB_minX, AABB_minY, AABB_minZ, AABB_maxX, AABB_maxY, AABB_maxZ, node_child1, node_child2, node_parent, node_item, node_surfaceArea, node_buffer =
        {0,0,0}, {0,0,0},       -- AABB_min_buffer, AABB_max_buffer
        {}, {}, {}, {}, {}, {}, -- AABB_minX, AABB_minY, AABB_minZ, AABB_maxX, AABB_maxY, AABB_maxZ
        {}, {}, {}, {}, {},     -- node_child1, node_child2, node_parent, node_item, node_surfaceArea
        {false, false, false, false, 0, 0,0,0, 0,0,0}

    local BVH, nodes, AABB_min, AABB_max =
        {},
        list{node_child1, node_child2, node_parent, node_item, node_surfaceArea,  AABB_minX, AABB_minY, AABB_minZ, AABB_maxX, AABB_maxY, AABB_maxZ},
        {AABB_minX, AABB_minY, AABB_minZ}, {AABB_maxX, AABB_maxY, AABB_maxZ}

    local temp1, temp2, temp3, temp4, index, newNode, newNode_SA, unionNodeAABB, updateNodeAABB, unionAABB, surfaceAreaAABB, best_sibling, best_cost, inherited_cost

    BVH.BVH_rootIndex = false
    BVH.BVH_nodes = nodes
    BVH.BVH_AABBmin = AABB_min
    BVH.BVH_AABBmax = AABB_max

    ---@param nodeA integer
    ---@param nodeB integer
    ---@param min   any local variable
    ---@param max   any local variable
    function unionNodeAABB(nodeA, nodeB, min, max)
        for i = 1, 3 do
            min = AABB_min[i]
            max = AABB_max[i]
            AABB_min_buffer[i] = math.min(min[nodeA], min[nodeB])
            AABB_max_buffer[i] = math.max(max[nodeA], max[nodeB])
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

    ---@param node integer
    ---@param minAABB table<number, number, number>
    ---@param maxAABB table<number, number, number>
    function unionAABB(node, minAABB, maxAABB)
        for i = 1, 3 do
            AABB_min_buffer[i] = math.min(AABB_min[i][node], minAABB[i])
            AABB_max_buffer[i] = math.max(AABB_max[i][node], maxAABB[i])
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
    BVH.BVH_refitAABBs = function(node, i1, i2)
    --#if withoutTreeRotation
--        while node do
--            unionNodeAABB(node_child1[node], node_child2[node])
--            updateNodeAABB(node, AABB_min_buffer, AABB_max_buffer)
--            temp1 = node_surfaceArea[node]                            -- SAH before update
--            temp2 = surfaceAreaAABB(AABB_min_buffer, AABB_max_buffer) -- SAH after update
--            if temp1 == temp2 then break end                          -- Early termination if SAH remains the same
--
--            node_surfaceArea[node] = temp2
--            node = node_parent[node]
--        end

    --#elseif withTreeRotation
        while node do
            unionNodeAABB(node_child1[node], node_child2[node])
            updateNodeAABB(node, AABB_min_buffer, AABB_max_buffer)
            node_surfaceArea[node] = surfaceAreaAABB(AABB_min_buffer, AABB_max_buffer)

            -- Try tree rotation [Reference: Page 111-127], specifically [Reference: Page 115], where F in ref. is 'node'
            temp1 = node_parent[node]
            if temp1 then -- not root
                temp2 = node_parent[temp1] -- 'node'.parent.parent
                if temp2 then -- not root
                    i1 = node_child1[temp1] == node and 2 or 1
                    temp3 = nodes[i1][temp1] -- 'node' sibling

                    i2 = node_child1[temp2] == temp1 and 2 or 1
                    temp4 = nodes[i2][temp2] -- 'node'.parent sibling

                    unionNodeAABB(node, temp3)
                    best_cost = surfaceAreaAABB(AABB_min_buffer, AABB_max_buffer)
                    unionNodeAABB(temp3, temp4)
                    if surfaceAreaAABB(AABB_min_buffer, AABB_max_buffer) < best_cost then
                       node_parent[temp4] = temp1
                       node_parent[node]  = temp2
                       nodes[i1%2+1][temp1] = temp4
                       nodes[i2][temp2] = node
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
            unionAABB(index, minAABB, maxAABB)
            best_cost = surfaceAreaAABB(AABB_min_buffer, AABB_max_buffer)
            inherited_cost = best_cost - node_surfaceArea[index]

            -- Find best sibling that adds least surface area to tree. [Reference: Page 77-88]
            while (node_item[index] == false) and (newNode_SA + inherited_cost < best_cost) do -- Is node not a leaf and is lowerbound cost of child nodes less than best_cost. [Reference: Page 86-87]
                for i = 1, 2 do
                    temp4 = nodes[i][index] -- child1|2 index
                    unionAABB(temp4, minAABB, maxAABB)
                    temp1 = surfaceAreaAABB(AABB_min_buffer, AABB_max_buffer) + inherited_cost -- new_cost

                    if temp1 < best_cost then -- is new_cost better/less than best_cost
                        best_cost = temp1
                        best_sibling = temp4
                        inherited_cost = temp1 - node_surfaceArea[temp4]
                    end
                end

                if index == best_sibling then break end -- The children was not better cost than parent
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
        nodes.list_remove(leafNode)
        temp1 = node_parent[leafNode]

        if temp1 then -- leafNode was not root
            nodes.list_remove(temp1)
            temp2 = node_parent[temp1]

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

    local n = 20 -- Amount of AABB/objects to insert
    local temp = 0
    for i = 1, n do
        for j = 1, 3 do
            temp = i*100 -- rand(10000) -- can change argument

            AABB_buffer[j]   = temp - 5 + rand(3)
            AABB_buffer[j+3] = temp + 5 + rand(3)
        end
        AABB.list_insert(AABB_buffer)
    end
--
--    local t1 = os.clock()
--    for i = 1, n do
--        fetchAABB(i)
--        BVH_ID[i] = bvh.BVH_insert(i, AABB_min_buffer, AABB_max_buffer)
--    end
--    local t2 = os.clock()
--    print("init time1: "..(t2-t1))
--    print(bvh.BVH_treeCost())
--
--    for i = 1, n do
--        bvh.BVH_remove(BVH_ID[i])
--    end
--
--    t1 = os.clock()
--    for i = 1, n do
--        fetchAABB(i)
--        BVH_ID[i] = bvh.BVH_insert(i, AABB_min_buffer, AABB_max_buffer)
--    end
--    t2 = os.clock()
--
--    print("init time2: "..(t2-t1))
--    print(bvh.BVH_treeCost()) -- expected to be the same as earlier BVH.treeCost print


    ---
    --- Ensure that child nodes AABB reside in parent AABB (invariant)
    --- Calculate all leaf nodes depth in tree
    ---
    local tick = 0
    local drawBVH
    local count = 0
    local reverse = false
    local function debugInsert()
        if tick >= 10 then
            tick = 1
        else
            tick = tick + 1
        end

        if reverse then
            if tick == 1 and count > 1 then
                bvh.BVH_remove(BVH_ID[count])
                count = count - 1
            elseif count == 1 then
                reverse = false
            end
        else
            if tick == 1 and count < n then
                count = count + 1
                fetchAABB(count)
                BVH_ID[count] = bvh.BVH_insert(count, AABB_min_buffer, AABB_max_buffer)
            elseif count == n then
                reverse = true
                tick = -120
                print("TreeCost: "..bvh.BVH_treeCost())
            end
        end

        local depthLevels = {}
        local nodes = bvh.BVH_nodes
        local function test_invariant(nodeID, depth)
            local e = 1e-9
            local minX, minY, minZ, maxX, maxY, maxZ
            minX = nodes[6][nodeID]  - e
            minY = nodes[7][nodeID]  - e
            minZ = nodes[8][nodeID]  - e
            maxX = nodes[9][nodeID]  + e
            maxY = nodes[10][nodeID] + e
            maxZ = nodes[11][nodeID] + e

            for i = 1, 2 do
                local child = nodes[i][nodeID]
                if child then
                    if minX > nodes[6][child] or nodes[9][child]  > maxX
                    or minY > nodes[7][child] or nodes[10][child] > maxY
                    or minZ > nodes[8][child] or nodes[11][child] > maxZ
                    then
                        print("AABB bound error at child: "..tostring(child))
                    end
                    test_invariant(child, depth + 1)
                end
            end
            if not (nodes[1][nodeID] and nodes[2][nodeID]) then
                depthLevels[#depthLevels+1] = depth
            end
        end
        test_invariant(bvh.BVH_rootIndex, 0)

        t1 = os.clock()
        table.sort(depthLevels)
        local depth = {} -- view variables in debug mode.  Depth level
        local depthAmount = {}  --                         Amount of leafs at the depth level in 'depth'

        local currentDepth, currentDepthID
        for i = 1, #depthLevels do
            if currentDepth ~= depthLevels[i] then
                currentDepth = depthLevels[i]
                currentDepthID = #depth+1
                depth[currentDepthID] = currentDepth
                depthAmount[currentDepthID] = 1
            else
                depthAmount[currentDepthID] = depthAmount[currentDepthID] + 1
            end
        end
        t2 = os.clock()
        --print("--- Ran test_invariant in "..(t2-t1).." ---")

        local log = math.log(#nodes[1], 2)
        function drawBVH(i, x, y, d, l, r)
            screen.setColor(255, 255, 255)
            screen.drawText(x, y, i)
            local c1 = nodes[1][i]
            local c2 = nodes[2][i]
            local offset = math.max(0, (log-d)*50/(d))
            screen.setColor(0, 255, 0, 150)
            if (c1) then
                local nX = x-10 - offset
                local nY = y+15 + d*3
                screen.drawLine(x+3, y+3, nX+3, nY+3)
                drawBVH(c1, nX, nY, d+1, l+1, math.max(r-1, 0))
            end
            if (c2) then
                local nX = x+10 + offset
                local nY = y+15 + d*3
                screen.drawLine(x+3, y+3, nX+3, nY+3)
                drawBVH(c2, nX, nY, d+1, math.max(l-1, 0), r+1)
            end
        end
    end

    function onTick()
        debugInsert()
    end

    function onDraw()
        local w = screen.getWidth()
        drawBVH(bvh.BVH_rootIndex, w/2, 5, 1, 0, 0)
    end
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