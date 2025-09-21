-- Author: Jumper
-- GitHub: https://github.com/Jumper-44

---@section strToNumbers 1 _STR_TO_NUMBERS_
---@param str string
---@param t table|nil
---@overload fun(str: string):table
function strToNumbers(str, t)
    t = t or {}
    for w in property.getText(str):gmatch"[+%w.-]+" do
        t[#t+1] = tonumber(w)
    end
    return t
end
---@endsection _STR_TO_NUMBERS_

---@section multiReadPropertyNumbers 1 _MULTI_READ_PROPERTY_NUMBERS_
---@param str string
---@param t any local variable
function multiReadPropertyNumbers(str, t)
    t = t or {}
    for w in property.getText(str):gmatch"[^!]+" do
        strToNumbers(w, t)
    end
    return t
end
---@endsection _MULTI_READ_PROPERTY_NUMBERS_