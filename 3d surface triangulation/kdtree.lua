---@class KDTree
---@section KDTree 1 _KDTREE_
-- k-d tree is 3 dimentions only.
---@return table
local KDTree = function()
    ---Returns the squared magnitude/length between two points
    ---@param pointA table
    ---@param pointB table
    ---@return number
    local len2 = function(pointA, pointB)
        local sum = 0
        for i = 1, 3 do
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
        ---Inserts a point into the k-d tree, in which a param point = {x, y, z} or {[1] = x, [2] = y, [3] = z}
        ---@param point table
        KDTree_insert = function(point)
            local function insertRecursive(root, cd, depth)
                if root.point then
                    return insertRecursive(
                        point[cd] < root.point[cd] and root.left or root.right,
                        depth % 3 + 1,
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
        ---Returns the nearest point in k-d tree to param point
        ---Will NOT set a value to point.len2 if node is traversed
        ---@param point table
        ---@return table
        KDTree_nearestNeighbor = function(point)
            local function nearestNeighborRecursive(root, depth)
                if root.point == nil then return nil end

                local cd, nextBranch, ortherBranch = depth % 3 + 1, root.right, root.left
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

            return nearestNeighborRecursive(tree_root, 0).point
        end;
        ---@endsection

        ---@section KDTree_nearestNeighbors
        ---Returns the nearest point(s) in k-d tree to param point up to param maxNeighbors
        ---Will set a value to point.len2 if node is traversed
        ---@param point table
        ---@param maxNeighbors integer
        ---@return table
        KDTree_nearestNeighbors = function(point, maxNeighbors)
            local nearestPoints, lambda_sort = {}, function(a,b) return a.len2 < b.len2 end
            local function nearestNeighborsRecursive(root, depth)
                if root.point == nil then return nil end

                local cd, rootPoint, nextBranch, ortherBranch = depth % 3 + 1, root.point, root.right, root.left
                if point[cd] < rootPoint[cd] then
                    nextBranch, ortherBranch = root.left, root.right
                end

                rootPoint.len2 = len2(point, rootPoint)
                if #nearestPoints < maxNeighbors then
                    nearestPoints[#nearestPoints+1] = rootPoint
                    table.sort(nearestPoints, lambda_sort)
                else
                    if rootPoint.len2 < nearestPoints[#nearestPoints].len2 then
                        nearestPoints[maxNeighbors] = rootPoint
                        table.sort(nearestPoints, lambda_sort)
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
        ---Will set a value to point.len2 if node is traversed
        ---@param point table
        ---@param searchRadius_squared number
        ---@return table
        KDTree_rangeSearch = function(point, searchRadius_squared)
            local in_range = {}
            local function rangeSearchRecursive(root, depth)
                if root.point == nil then return nil end

                local cd, rootPoint, nextBranch, ortherBranch = depth % 3 + 1, root.point, root.right, root.left
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
    local t = KDTree()

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