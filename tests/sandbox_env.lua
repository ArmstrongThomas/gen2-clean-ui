-- Minimal copy of the public mod execution contract used to load the real
-- packaged product during tests. Test I/O stays outside this environment;
-- every chunk reached from main.lua inherits this private table.
local SandboxEnv = {}

local blockedModules = {
  io=true, os=true, debug=true, package=true, ffi=true,
}
local blockedLove = {
  filesystem=true, thread=true, system=true, event=true,
}

local function copy(source)
  local output = {}
  for key, value in pairs(source or {}) do output[key] = value end
  return output
end

function SandboxEnv.new(options)
  options = options or {}
  local realRequire = assert(options.require, "sandbox test requires require")
  local realLove = assert(options.love, "sandbox test requires love")
  local env = {
    assert=assert, error=error, ipairs=ipairs, next=next, pairs=pairs,
    pcall=pcall, xpcall=xpcall, select=select, tonumber=tonumber,
    tostring=tostring, type=type, unpack=unpack, rawequal=rawequal,
    rawget=rawget, rawset=rawset, rawlen=rawlen, setmetatable=setmetatable,
    getmetatable=getmetatable, print=print, collectgarbage=collectgarbage,
    _VERSION=_VERSION, coroutine=copy(coroutine), math=copy(math),
    string=copy(string), table=copy(table), bit=bit, jit=jit,
    os={time=os.time,date=os.date,clock=os.clock,difftime=os.difftime},
  }

  env.love = setmetatable({}, {
    __index=function(_, key)
      if blockedLove[key] then
        error("love." .. tostring(key) .. " is blocked in the mod sandbox", 2)
      end
      return realLove[key]
    end,
    __newindex=function(_, key)
      error("cannot assign love." .. tostring(key), 2)
    end,
  })
  env.require = function(name, ...)
    local root = type(name) == "string" and name:match("^([^%.]+)")
    if blockedModules[root] or (root == "love" and name ~= "love") then
      error(tostring(name) .. " is blocked in the mod sandbox", 2)
    end
    return realRequire(name, ...)
  end

  local function compile(source, chunkName)
    if type(source) ~= "string" then return nil, "source must be a string" end
    if source:sub(1, 1) == "\27" then return nil, "bytecode is blocked" end
    local chunk, compileError = loadstring(source, chunkName)
    if not chunk then return nil, compileError end
    setfenv(chunk, env)
    return chunk
  end
  env.load = compile
  env.loadstring = compile
  env._G = env

  return { env=env, compile=compile }
end

return SandboxEnv
