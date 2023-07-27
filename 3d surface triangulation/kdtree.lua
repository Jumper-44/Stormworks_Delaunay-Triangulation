-- *ReadMe*
--
-- There are two functions for k-d tree here: KDTree() and IKDTree()
-- Initially made KDTree(), in which points are in the internal nodes and only has insertion and nearestNeighbor(s) and rangeSearch functions.
-- Then I made IKDTree() for Incremental-KDTree, which only has points in leaf nodes and will buffer points in leaf before splitting. Has insert, remove and nearestNeighbor(s) functions.
-- I recommend to use IKDTree(), even if you don't need to remove from the tree, then it should hopefully still be more balanced, due to buffering up before splitting.
-- Also IDKTree doesn't handle well if points coordinates are equal


---@class KDTree
---@section KDTree 1 _KDTREE_
---@param k_dimensions interger
---@return table
KDTree = function(k_dimensions)
    ---Returns the squared length between two points
    ---@param pointA table
    ---@param pointB table
    ---@return number
    local len2 = function(pointA, pointB)
        local sum = 0
        for i = 1, k_dimensions do
            local dis = pointA[i] - pointB[i]
            sum = sum + dis*dis
        end
        return sum
    end

    ---@section KDTree_closest
    ---Given 2 nodes, return the node nearest to param point
    ---@param nodeA table|nil
    ---@param nodeB table|nil
    ---@param point table
    ---@return table|nil
    local KDTree_closest = function(nodeA, nodeB, point)
        return  nodeA == nil and nodeB or
                (nodeB == nil and nodeA or
        ---@cast nodeA -nil
        ---@cast nodeB -nil
                (len2(nodeA.point, point) < len2(nodeB.point, point) and nodeA or nodeB))
    end
    ---@endsection

    local tree_root = {}

    return {
        len2 = len2;

        ---@section KDTree_insert
        ---Inserts a point into the k-d tree
        ---@param point table
        KDTree_insert = function(point)
            local function insertRecursive(root, cd, depth)
                if root.point then
                    return insertRecursive(
                        point[cd] < root.point[cd] and root.left or root.right,
                        depth % k_dimensions + 1,
                        depth + 1
                    )
                else -- Create node if point is nil
                    root.point = point
                    root.left = {}
                    root.right = {}
                end
            end

            insertRecursive(tree_root, 1, 1)
        end;
        ---@endsection

        ---@section KDTree_nearestNeighbor
        ---Returns the nearest point in k-d tree to param point or nil if tree is empty
        ---Will NOT set a value to root.point.len2
        ---@param point table
        ---@return table|nil
        KDTree_nearestNeighbor = function(point)
            local function nearestNeighborRecursive(root, depth)
                if root.point == nil then return nil end

                local cd, nextBranch, ortherBranch = depth % k_dimensions + 1, root.right, root.left
                if point[cd] < root.point[cd] then
                    nextBranch, ortherBranch = root.left, root.right
                end

                local temp = nearestNeighborRecursive(nextBranch, depth+1)
                local best, dist = KDTree_closest(temp, root, point), point[cd] - root.point[cd]

                ---@cast best -nil
                if len2(point, best.point) >= dist*dist then
                    temp = nearestNeighborRecursive(ortherBranch, depth+1)
                    best = KDTree_closest(temp, best, point)
                end

                return best
            end

            local return_val = nearestNeighborRecursive(tree_root, 0)
            return return_val and return_val.point or return_val
        end;
        ---@endsection

        ---@section KDTree_nearestNeighbors
        ---Returns the nearest point(s) in k-d tree to param point up to param maxNeighbors
        ---Will set a value to root.point.len2 if node is traversed
        ---@param point table
        ---@param maxNeighbors integer
        ---@return table
        KDTree_nearestNeighbors = function(point, maxNeighbors)
            local nearestPoints = {
                ---Insertion sort
                ---@param self table
                ---@param p table
                insert = function(self, p)
                    for i = 1, #self do
                        if p.len2 < self[i].len2 then
                            table.insert(self, i, p)
                            return
                        end
                    end
                    self[#self+1] = p
                end
            }

            local function nearestNeighborsRecursive(root, depth)
                if root.point == nil then return nil end

                local cd, rootPoint, nextBranch, ortherBranch = depth % k_dimensions + 1, root.point, root.right, root.left
                if point[cd] < rootPoint[cd] then
                    nextBranch, ortherBranch = root.left, root.right
                end

                rootPoint.len2 = len2(point, rootPoint)
                if #nearestPoints < maxNeighbors then
                    nearestPoints:insert(rootPoint)
                else
                    if rootPoint.len2 < nearestPoints[#nearestPoints].len2 then
                        nearestPoints[maxNeighbors] = nil
                        nearestPoints:insert(rootPoint)
                    end
                end

                nearestNeighborsRecursive(nextBranch, depth+1)
                local dist = point[cd] - rootPoint[cd]
                if #nearestPoints < maxNeighbors or len2(point, nearestPoints[maxNeighbors]) >= dist*dist then
                    nearestNeighborsRecursive(ortherBranch, depth+1)
                end
            end

            nearestNeighborsRecursive(tree_root, 0)
            return nearestPoints
        end;
        ---@endsection

        ---@section KDTree_rangeSearch
        ---Returns all the point(s) in k-d tree that are within the param searchRadius_squared of param point
        ---Will set a value to root.point.len2 if in_range
        ---@param point table
        ---@param searchRadius_squared number
        ---@return table
        KDTree_rangeSearch = function(point, searchRadius_squared)
            local in_range = {}
            local function rangeSearchRecursive(root, depth)
                if root.point == nil then return nil end

                local cd, rootPoint, nextBranch, ortherBranch = depth % k_dimensions + 1, root.point, root.right, root.left
                if point[cd] < rootPoint[cd] then
                    nextBranch, ortherBranch = root.left, root.right
                end

                rangeSearchRecursive(nextBranch, depth+1)

                local dist = point[cd] - rootPoint[cd]
                if searchRadius_squared >= dist*dist then
                    rangeSearchRecursive(ortherBranch, depth + 1)
                end

                local point_to_rootPoint_len2 = len2(point, rootPoint)
                if point_to_rootPoint_len2 <= searchRadius_squared then
                    in_range[#in_range+1] = rootPoint
                    rootPoint.len2 = point_to_rootPoint_len2
                end
            end

            rangeSearchRecursive(tree_root, 0)
            return in_range
        end
        ---@endsection
    }
end
---@endsection _KDTREE_


---@section __KDTREE_DEBUG__
--[[
do
    local points = {}
    local t = KDTree(3)

    for i = 1, 10000 do
        points[i] = {(math.random()-.5)*400, (math.random()-.5)*400, (math.random()-.5)*400}
        t.KDTree_insert(points[i])
    end

    local p = {25,-25,25}

    do -- nearest neighbor
        local tree_n = t.KDTree_nearestNeighbor(p)
        local best, brute_n = 0x7fffffffffffffff, nil
        for i = 1, #points do
            if t.len2(p, points[i]) < best then
                best = t.len2(p, points[i])
                brute_n = points[i]
            end
        end

        print("--- nearest neighbor ---")
        print("tree: "..t.len2(p, tree_n))
        print("brute: "..best)
        print("is equal: "..tostring(tree_n==brute_n))
    end

    do -- nearest neighbors
        print("--- nearest neighbors ---")
        local tree_n = t.KDTree_nearestNeighbors(p, 5)
        for i = 1, #tree_n do
            print(tree_n[i].len2)
        end
    end

    do -- range search
        local lambda_sort = function(a,b)
            return t.len2(p,a) < t.len2(p,b)
        end

        local range = 100^2;

        local in_range_tree = t.KDTree_rangeSearch(p, range)
        local in_range_brute = {}

        for i = 1, #points do
            if t.len2(p, points[i]) <= range then
                table.insert(in_range_brute, points[i])
            end
        end

        table.sort(in_range_brute, lambda_sort)
        table.sort(in_range_tree, lambda_sort)

        print("--- range search; is brute the same as tree ---")
        local n_true, n_false = 0, 0
        for i = 1, #in_range_brute do
            if in_range_brute[i] == in_range_tree[i] then
                n_true = n_true + 1
            else
                n_false = n_false + 1
            end
        end

        for i = 1, 5 do
            print(in_range_tree[i].len2)
        end
        print("...")

        print(n_true.." true, "..n_false.." false")
    end
end
--]]
---@endsection



---@class IKDTree
---@section IKDTree 1 _IKDTREE_
---@param k_dimensions interger
---@return table
IKDTree = function(k_dimensions)
    ---Returns the squared length between two points
    ---@param pointA table
    ---@param pointB table
    ---@return number
    local len2 = function(pointA, pointB)
        local sum = 0
        for i = 1, k_dimensions do
            local dis = pointA[i] - pointB[i]
            sum = sum + dis*dis
        end
        return sum
    end

    local tree_root = {leaf = true}

    return {
        len2 = len2;

        ---@section IKDTree_insert
        ---Inserts a point into the k-d tree
        ---@param point table
        IKDTree_insert = function(point)
            local function insertRecursive(root, cd, depth)
                if root.leaf then
                    root[#root+1] = point
                    if #root == 16 then -- Split node when it contains 16 points
                        table.sort(root, function(a, b) return a[cd] < b[cd] end)
                        root.leaf = false
                        root.split = 0.5 * (root[8][cd] + root[9][cd])
                        root.left = {leaf = true}
                        root.right = {leaf = true}
                        for i = 1, 8 do
                            root.left[i] = root[i]
                            root[i] = nil
                        end
                        for i = 9, 16 do
                            root.right[i - 8] = root[i]
                            root[i] = nil
                        end
                    end
                else
                    return insertRecursive(
                        point[cd] < root.split and root.left or root.right,
                        depth % k_dimensions + 1,
                        depth + 1
                    )
                end
            end

            insertRecursive(tree_root, 1, 1)
        end;
        ---@endsection

        ---@section IKDTree_remove
        ---Finds leaf containing point (assumed to be the same table and not contents/coordinates of point) and removes it from leaf.
        ---Returns found point or nil if not found.
        ---@param point table
        ---@return table|nil
        IKDTree_remove = function(point)
            local function removeRecursive(root, cd, depth)
                -- Could try to slightly balance tree if removing last or very few points in leaf
                if root.leaf then
                    for i = 1, #root do
                        if point == root[i] then
                            return table.remove(root, i)
                        end
                    end
                    return
                else
                    return removeRecursive(
                    point[cd] < root.split and root.left or root.right,
                    depth % k_dimensions + 1,
                    depth + 1
                )
                end
            end

            return removeRecursive(tree_root, 1, 1)
        end;

        ---@section IKDTree_nearestNeighbors
        ---Returns the nearest point(s) in k-d tree to param point up to param maxNeighbors
        ---Will set a value to root[i].len2 if node is traversed
        ---@param point table
        ---@param maxNeighbors integer
        ---@return table
        IKDTree_nearestNeighbors = function(point, maxNeighbors)
            local nearestPoints = {
                ---Insertion sort
                ---@param self table
                ---@param p table
                insert = function(self, p)
                    for i = 1, #self do
                        if p.len2 < self[i].len2 then
                            table.insert(self, i, p)
                            return
                        end
                    end
                    self[#self+1] = p
                end
            }

            local function nearestNeighborsRecursive(root, depth)
                local cd, nextBranch, ortherBranch = depth % k_dimensions + 1, root.right, root.left

                if root.leaf then
                    for i = 1, #root do
                        root[i].len2 = len2(point, root[i])
                        if #nearestPoints < maxNeighbors then
                            nearestPoints:insert(root[i])
                        else
                            if root[i].len2 < nearestPoints[maxNeighbors].len2 then
                                nearestPoints[maxNeighbors] = nil
                                nearestPoints:insert(root[i])
                            end
                        end
                    end
                else
                    if point[cd] < root.split then
                        nextBranch, ortherBranch = root.left, root.right
                    end

                    nearestNeighborsRecursive(nextBranch, depth+1)
                    local dist = point[cd] - root.split
                    if #nearestPoints < maxNeighbors or nearestPoints[maxNeighbors].len2 >= dist*dist then
                        nearestNeighborsRecursive(ortherBranch, depth+1)
                    end
                end
            end

            nearestNeighborsRecursive(tree_root, 0)
            return nearestPoints
        end;
        ---@endsection
    }
end
---@endsection _IKDTREE_


---@section __IKDTREE_DEBUG__
--[[
do
    local points = {}
    local t = IKDTree(3)
    local t1, t2
    local rand = math.random
    math.randomseed(123)

    for i = 1, 100000 do
        points[i] = {(rand()-.5)*100, (rand()-.5)*100, (rand()-.5)*100}
        t.IKDTree_insert(points[i])
    end

    for i = 50000, 100000 do
        if not t.IKDTree_remove(points[i]) then error("Failed to find and remove point in k-d tree") end
        points[i] = nil
    end


    print("--- nearest neighbor ---")
    local time = {}
    for k = 1, 10 do -- nearest neighbor
        local p = {(rand()-.5)*100, (rand()-.5)*100, (rand()-.5)*100}

        t1 = os.clock()
        local tree_n = t.IKDTree_nearestNeighbors(p, 100)
        t2 = os.clock()

        local best, brute_n = 0x7fffffffffffffff, nil
        for i = 1, #points do
            if t.len2(p, points[i]) < best then
                best = t.len2(p, points[i])
                brute_n = points[i]
            end
        end

        time[k] = t2-t1
        print("tree: "..t.len2(p, tree_n[1])..", brute: "..best..", is equal: "..tostring(tree_n[1]==brute_n)..", time: "..time[k])
    end

    local avg = 0
    for k = 1, #time do
        avg = avg + time[k]/#time
    end
    print("iterations: "..#time..", avg: "..avg)

    do -- nearest neighbors
        local p = {(rand()-.5)*100, (rand()-.5)*100, (rand()-.5)*100}

        local brute_table = {}
        for i = 1, #points do
            brute_table[i] = points[i]
            points[i].len2 = t.len2(p, points[i])
        end
        table.sort(brute_table, function(a, b) return a.len2 < b.len2 end)

        print("--- nearest neighbors ---")
        t1 = os.clock()
        local tree_n = t.IKDTree_nearestNeighbors(p, 200)
        t2 = os.clock()
        print("time: "..(t2-t1))
        for i = 1, #tree_n do
            print("tree: "..tree_n[i].len2..", brute: "..brute_table[i].len2..", is equal: "..tostring(tree_n[i] == brute_table[i]))
        end
    end
end
--]]
---@endsection