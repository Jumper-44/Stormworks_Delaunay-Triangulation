-- Author: Jumper
-- GitHub: https://github.com/Jumper-44

---@section newTables 1 _NEW_TABLES_
---helper function to initialize and return *n* new tables  
---call 'newTables{numberOfTables}'
---@param t table {numberOfTables}
function newTables(t)
    for i = 1, t[1] do t[i] = {} end
    return table.unpack(t)
end

--a, b, c, d = newTables{3}
--a -> {}
--b -> {}
--c -> {}
--d -> nil

---@endsection _NEW_TABLES_