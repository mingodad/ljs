--
-- MINCTEST - Minimal Lua Test Library - 0.1.1
-- This is based on minctest.h (https://codeplea.com/minctest)
--
-- Copyright (c) 2014, 2015, 2016 Lewis Van Winkle
--
-- http://CodePlea.com
--
-- This software is provided 'as-is', without any express or implied
-- warranty. In no event will the authors be held liable for any damages
-- arising from the use of this software.
--
-- Permission is granted to anyone to use this software for any purpose,
-- including commercial applications, and to alter it and redistribute it
-- freely, subject to the following restrictions:
--
-- 1. The origin of this software must not be misrepresented; you must not
--    claim that you wrote the original software. If you use this software
--    in a product, an acknowledgement in the product documentation would be
--    appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not be
--    misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source distribution.


-- MINCTEST - Minimal testing library for C
--
--
-- Example:
--
--
-- require "minctest"
--
-- lrun("test1", function()
--    lok('a' == 'a');          --assert true
-- end)
--
-- lrun("test2", function()
--    lequal(5, 6);             --compare integers
--    lfequal(5.5, 5.6);        --compare floats
-- end)
--
-- return lresults();           --show results
--
--
-- Hints:
--      All functions/variables start with the letter 'l'.
--
--

--[[
Multiline comment
is here
]]

--[==[
Multiline comment
is here too
]==]

local lstr = [[
Multiline string
is here
]]

local lstr2 = [=[
Multiline string
is here too
]=]

local lstr3 = [===[
Multiline string
is here too
]===]

local an, bn, cn, dn
cn = 10
cn, bn, an = cn-1, bn, an

local LTEST_FLOAT_TOLERANCE = 0.001


local ltests = 0
local lfails = 0

-- testing declarations
a = {i = 10}
self = 20
function a:x (x) return x+self.i end
function a.y (x) return x+self end

assert(a:x(1)+10 == a.y(1))

a.t = {i=-100}
a["t"].x = function (self, a,b) return self.i+a+b end

assert(a.t:x(2,3) == -95)

local t = 1; for j=1,10 do t = t + j end; t = 0

local var = 3;

do
  local a = {x=0}
  function a:add (x) self.x, a.y = self.x+x, 20; return self end
  assert(a:add(10):add(20):add(30).x == 60 and a.y == 20)
end

local x = 10
repeat
  x = x - 1
until x < 0

while x > 0 do x = x -1 end

local ary = {1,2,3,4,5,6}
for i,n in ipairs(ary) do print(i,n) end
for i=10,-1 do print(i) end

local simple = function()
  print "dad" --the boy
  goto test
  print {1,2,3}
::test::
  if lfails > 0 then
    print "failed"
  elseif ltest > 0 then
    print "done"
  end
  return 0;
  --the end
end

local secpos = 1

local function waction(a, num)
  if a or num then  secpos = secpos + (num or 1) end
  print(a, num, secpos)
end

waction(nil, nil);
waction("dad", nil);
waction(nil, 5);
waction("car", 6);


lresults = function()
    if (lfails == 0) then
        print("ALL TESTS PASSED (" .. ltests .. "/" .. ltests .. ")")
    else
        print("SOME TESTS FAILED (" .. ltests-lfails .. "/" .. ltests .. ")")
    end
    return lfails ~= 0
end


lrun = function(name, testfunc)
    local ts = ltests
    local fs = lfails
    local clock = os.clock()
    io.write(string.format("\t%-16s", name))
    testfunc()
    io.write(string.format("pass:%2d   fail:%2d   %4dms\n",
        (ltests-ts)-(lfails-fs), lfails-fs,
        math.floor((os.clock() - clock) * 1000)));
end

lok = function(test)
    ltests = ltests + 1
    if not test then
        lfails = lfails + 1
        io.write(string.format("%s:%d error \n",
            debug.getinfo(2, 'S').short_src,
            debug.getinfo(2, 'l').currentline))
    end
end

lequal = function(a, b)
    ltests = ltests + 1
    if a ~= b then
        lfails = lfails + 1
        io.write(string.format("%s:%d (%d != %d)\n",
            debug.getinfo(2, 'S').short_src,
            debug.getinfo(2, 'l').currentline,
            a, b))
    end
end

lfequal = function(a, b)
    ltests = ltests + 1
    if math.abs(a - b) > LTEST_FLOAT_TOLERANCE then
        lfails = lfails + 1
        io.write(string.format("%s:%d (%f != %f)\n",
            debug.getinfo(2, 'S').short_src,
            debug.getinfo(2, 'l').currentline,
            a, b))
    end
end
--[[
do --- jit shift/xor
  local a, b = 0x123456789abcdef0LL, 0x31415926535898LL
  for i=1,200 do
    a = bxor(a, b); b = sar(b, 14) + shl(b, 50)
    a = a - b; b = shl(b, 5) + sar(b, 59)
    b = bxor(a, b); b = b - shl(b, 13) - shr(b, 51)
  end
  assert(b == -7993764627526027113LL)
end
]]
local k = 0
local s = string.format(0 < k and k < 0x1p-1026 and "%+a" or "%+.14g", k)

if 1 == 2 then
  print("1 == 2");
end

local ia, ib;
ia = 5;
ib = 2;
local ic = ia // ib;
ic = ia ~ ib;


