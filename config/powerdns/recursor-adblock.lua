-- AdBlock functionality + host overrides
local adblock = {}
local overrides_exact = {}
local overrides_wildcard = {}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Load blocked domains into a set. We do ancestor lookups at query time,
-- so a contained base like "example.com" also blocks "*.example.com".
local function load_blocked_domains(file_path)
  local file, err = io.open(file_path, "r")
  if not file then
    pdnslog("Failed to open AdBlock list file: " .. file_path .. ": " .. tostring(err), pdns.loglevels.Error)
    return
  end

  local count = 0
  for line in file:lines() do
    local s = trim(line)
    if s ~= "" and not s:match("^#") then
      s = s:lower()
      -- Normalize trailing dot and spaces
      s = s:gsub("%.$", "")
      adblock[s] = true
      count = count + 1
    end
  end
  file:close()
  pdnslog("Loaded AdBlock entries: " .. tostring(count) .. " from " .. file_path, pdns.loglevels.Info)
end

-- Load host overrides. Supports lines like:
--   mox.si=192.168.10.153
--   *.mox.si=192.168.10.153
local function load_host_overrides(file_path)
  local file, err = io.open(file_path, "r")
  if not file then
    pdnslog("Failed to open host overrides file: " .. file_path .. ": " .. tostring(err), pdns.loglevels.Warning)
    return
  end

  local exact, wild = 0, 0
  for line in file:lines() do
    local s = trim(line)
    if s ~= "" and not s:match("^#") then
      local name, ip = s:match("^([^=]+)=([^=]+)$")
      if name and ip then
        name = trim(name:lower()):gsub("%.$", "")
        ip = trim(ip)
        if name:sub(1,2) == "*." then
          local base = name:sub(3)
          if base ~= "" then
            overrides_wildcard[base] = ip
            wild = wild + 1
          end
        else
          overrides_exact[name] = ip
          exact = exact + 1
        end
      end
    end
  end
  file:close()
  pdnslog("Loaded overrides: exact=" .. tostring(exact) .. ", wildcard=" .. tostring(wild) .. " from " .. file_path, pdns.loglevels.Info)
end

local function ancestor_match_in_set(qname, set)
  local s = qname
  while s and s ~= "" do
    if set[s] then return true end
    local nexts = s:match("^[^.]+%.(.+)$")
    s = nexts
  end
  return false
end

local function wildcard_lookup_ip(qname)
  local s = qname
  while s and s ~= "" do
    if overrides_wildcard[s] then return overrides_wildcard[s] end
    s = s:match("^[^.]+%.(.+)$")
  end
  return nil
end

-- Load lists at startup
load_blocked_domains("/etc/powerdns/blocked_domains.txt")
load_host_overrides("/etc/powerdns/hosts_overrides.txt")

-- Called for every DNS query
function preresolve(dq)
  local qname = dq.qname:toString():lower()
  qname = qname:gsub("%.$", "") -- strip trailing dot

  -- Prefer host overrides over blocking
  local ovip = overrides_exact[qname]
  if not ovip then
    ovip = wildcard_lookup_ip(qname)
  end

  if ovip and (dq.qtype == pdns.A or dq.qtype == pdns.ANY) then
    dq:addAnswer(pdns.A, ovip)
    return true
  end

  -- Block if qname or any ancestor is in the block set
  if ancestor_match_in_set(qname, adblock) then
    dq.rcode = pdns.NXDOMAIN
    return true
  end

  return false
end

pdnslog("AdBlock + overrides script loaded", pdns.loglevels.Info)
