-- Author: Jumper
-- GitHub: https://github.com/Jumper-44
-- MIT License at end of this file

---@section list 1 _LIST_
---Table/list in which removed entries are marked for removal and overwritten by new inserted values.  
---Purpose for changing the table structure from {{a,b,c}, {a,b,c}, ...} to {{a ,a, ...}, {b, b, ...}, {c, c, ...}}, which reduces tables
---@param elements table -- expects: {{}, {}, ..., {}}
---@param removed_id nil -- dirty local to reduce char
---@param id nil -- dirty local to reduce char
---@overload fun(elements: table):list
---@return list
function list(elements, removed_id, id)
    ---@class list
    ---@field list_insert fun(new_elements: table):integer
    ---@field list_remove fun(index: integer)
    ---@field removed_id table

    removed_id = {}
    elements.removed_id = removed_id -- public access so function list_remove can be inlined if only used once, for char reduction

    ---@section list_insert
    ---@param new_elements table new_elements[1] must not be nil, as it relies on #elements[1] to get length
    ---@return integer element_id returns the given id to new_elements
    function elements.list_insert (new_elements)
        id = #removed_id > 0 and table.remove(removed_id) or #elements[1]+1
        for i = 1, #elements do
            elements[i][id] = new_elements[i]
        end
        return id
    end
    ---@endsection

    ---@section list_remove
    ---Assumes removed index is in range
    ---@param index integer
    function elements.list_remove(index)
        removed_id[#removed_id+1] = index
    end
    ---@endsection

    return elements
end
---@endsection _LIST_



---@section __list_DEBUG___
--[[ debug
do
    local arr = list({{},{},{}})
    local buffer = {}

    local t1, t2, t3, t4

    t1 = os.clock()
    for i = 1, 5e6 do
        buffer[1] = i
        buffer[2] = i % 3
        buffer[3] = i % 2 == 0

        arr.list_insert(buffer)
    end
    t2 = os.clock()
    for i = 1, 5e6 do
        arr.list_remove(i)
    end
    t3 = os.clock()
    for i = 1, 5e6 do
        buffer[1] = i
        buffer[2] = i % 5
        buffer[3] = i % 3 == 0

        arr.list_insert(buffer)
    end
    t4 = os.clock()

    print(t2-t1)
    print(t3-t2)
    print(t4-t3)
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