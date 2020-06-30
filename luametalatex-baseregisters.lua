local value_values = token.values'value'
for i=0,#value_values do
  value_values[value_values[i]] = i
end
local count_code = value_values.integer
local dimen_code = value_values.dimension

local set_local = require'luametalatex-local'

local texmeta = getmetatable(tex)
local texmetaoldindex = texmeta.__index
local texmetaoldnewindex = texmeta.__newindex

local tex_variables = __luametalatex__preserved_tex_variables or {}
__luametalatex__preserved_tex_variables = nil

function texmeta.__index(t, k)
  return tex_variables[k] or texmetaoldindex(t, k)
end
function texmeta.__newindex(t, k, v)
  if tex_variables[k] then
    return set_local(tex_variables, k, v)
  else
    return texmetaoldnewindex(t, k, v)
  end
end

local function tex_variable(value, scanner, name, default)
  token.luacmd(name, function(_, scanning)
    if scanning == 'value' then
      return value, tex_variables[name]
    else
      token.scan_keyword'='
      return set_local(tex_variables, name, scanner(), scanning == 'global')
    end
  end, 'global', 'protected', 'value')
  if status.ini_version then
    tex_variables[name] = default
  end
end

local real_pdf_variables = __luametalatex__preserved_real_pdf_variables or {}
__luametalatex__preserved_real_pdf_variables = nil
local pdf_variable_names = {}
local pdf_toks_map = {}
local pdf_variables = setmetatable(pdf.variable, {
  __index = function(_, k)
    local v = real_pdf_variables[k]
    if v then return v end
    v = pdf_toks_map[k]
    if v then
      return tex.toks[v]
    end
  end,
  __newindex = function(_, k, v)
    if real_pdf_variables[k] then
      return set_local(real_pdf_variables, k, v)
    end
    local toks = pdf_toks_map[k]
    if toks then
      tex.toks[toks] = v
    end
  end,
})
pdf.variable_names = pdf_variable_names

local pdf_toks
if status.ini_version then
  local pdf_toks_list = {}
  function pdf_toks(name, default)
    pdf_variable_names[#pdf_variable_names+1] = name
    pdf_toks_list[#pdf_toks_list+1] = {name, default}
  end
  function initialize_pdf_toks()
    for i=1,#pdf_toks_list do
      local entry = pdf_toks_list[i]
      local csname = 'pdfvariable  ' .. entry[1]
      token.set_char(csname, 0) -- Ensure that csname exists
      local t = token.create(csname)
      tex.runtoks(function()
        token.put_next(token.create'newtoks', t)
      end)
      pdf_toks_map[entry[1]] = t.index
      tex.toks[t.index] = entry[2]
    end
  end
else
  function pdf_toks(name, default)
    pdf_variable_names[#pdf_variable_names+1] = name
    local t = token.create('pdfvariable  ' .. name)
    pdf_toks_map[name] = t.index
    tex.toks[t.index] = default
  end
end

local function pdf_variable(value, scanner, name, default, force_default)
  pdf_variable_names[#pdf_variable_names+1] = name
  token.luacmd('pdfvariable  ' .. name, function(_, scanning)
    if scanning == 'value' then
      return value, real_pdf_variables[name]
    elseif force_default then
      token.scan_keyword'='
      local new = scanner()
      if new ~= default then
        texio.write_nl('term and log', string.format("Unsupported PDF variable: \z
            %q is not supported and fixed to %i, but you tried to set it to %i", name, default, new))
      end
    else
      token.scan_keyword'='
      return set_local(real_pdf_variables, name, scanner(), scanning == 'global')
    end
  end, 'global', 'protected', 'value')
  if status.ini_version then
    real_pdf_variables[name] = default
  end
end

tex_variable(count_code, token.scan_int, 'suppressfontnotfounderror', 0)
tex_variable(count_code, token.scan_int, 'outputmode', 1) -- The "traditional" default would be 0,
                                                            -- but we do not actually support that.
tex_variable(dimen_code, token.scan_dimen, 'pageheight', tex.sp'297mm')
tex_variable(dimen_code, token.scan_dimen, 'pagewidth', tex.sp'210mm')

tex_variable(count_code, token.scan_int, 'bodydirection', 0)
tex_variable(count_code, token.scan_int, 'pagedirection', 0)

pdf_variable(dimen_code, token.scan_dimen, 'horigin', tex.sp'1in')
pdf_variable(dimen_code, token.scan_dimen, 'vorigin', tex.sp'1in')
pdf_variable(dimen_code, token.scan_dimen, 'linkmargin', tex.sp'0pt')
pdf_variable(dimen_code, token.scan_dimen, 'destmargin', tex.sp'0pt')
pdf_variable(count_code, token.scan_int, 'majorversion', 1)
pdf_variable(count_code, token.scan_int, 'minorversion', 7)
pdf_variable(count_code, token.scan_int, 'compresslevel', 0)

pdf_variable(count_code, token.scan_int, 'objcompresslevel', 0, true) -- TODO ... not particularly urgent
pdf_variable(count_code, token.scan_int, 'decimaldigits', 4, true) -- Will probably stay fixed, but should be more consistent
pdf_variable(count_code, token.scan_int, 'gentounicode', 0, true) -- We expect the fontloader to generade tounicode tables. Might change at some point
-- These two are ignored, but that is consistent with pdfTeX as long as imageapplygamma is 0:
pdf_variable(count_code, token.scan_int, 'gamma', 1000)
pdf_variable(count_code, token.scan_int, 'imagegamma', 1000)
pdf_variable(count_code, token.scan_int, 'imageapplygamma', 0, true)
pdf_variable(count_code, token.scan_int, 'imagehicolor', 1, true) -- We don't consider ancient PDF versions, no no reason to strip images
pdf_variable(count_code, token.scan_int, 'imageaddfilename', 0, true) -- Could be added, but I never saw a reason for this anyway.
pdf_variable(count_code, token.scan_int, 'inclusionerrorlevel', -1, true) -- FIXME: At least a warning should be supported
pdf_variable(count_code, token.scan_int, 'inclusioncopyfonts', 0, true) -- Would be fragile and restrict our ability to use "creative" font constructs
pdf_variable(count_code, token.scan_int, 'uniqueresname', 0, true) -- I add this if you show me a usecase
pdf_variable(count_code, token.scan_int, 'pagebox', 2, true) -- TODO (1: media, 2: crop, 3: bleed, 4: trim, 5: art
pdf_variable(count_code, token.scan_int, 'forcepagebox', 0, true) -- Considered obsolete even in pdfTeX
pdf_variable(count_code, token.scan_int, 'imageresolution', 72, true) -- TODO Also 0 should be the same as 72 ?!?!?!?
-- The following two relate to pk fonts which we don't support, so they are ignored on a different level
pdf_variable(count_code, token.scan_int, 'pkresolution', 72)
-- pdf_variable(toks_code, token.scan_string, 'pkmode', '')


pdf_toks('pageresources', '')

function tex.getbodydir() return tex.bodydirection end
function tex.getpagedir() return tex.pagedirection end
function tex.setbodydir(i) tex.bodydirection = i end
function tex.setpagedir(i) tex.pagedirection = i end
local dir_regs = require 'luametalatex-dir-registers'
dir_regs 'textdir'
dir_regs 'bodydir'
dir_regs 'pagedir'

if status.ini_version then
  -- Run in pre_dump callback:
  lua.prepared_code[#lua.prepared_code+1] = function()
    local settings = " "
    for k,v in next, {__luametalatex__preserved_tex_variables = tex_variables,
                      __luametalatex__preserved_real_pdf_variables = real_pdf_variables,} do
      local entries = {}
      for kk,vv in next, v do
        -- entries[#entries+1] = string.format("[%q=%i],", kk, vv) -- If we ever get more compicated names here
        entries[#entries+1] = string.format("%s=%i,", kk, vv)
      end
      settings = string.format("%s%s={%s}", settings, k, table.concat(entries))
    end
    return settings
  end
end
