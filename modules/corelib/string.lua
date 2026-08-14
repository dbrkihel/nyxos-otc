-- @docclass string

function string:split(delim)
  local start = 1
  local results = {}
  while true do
    local pos = string.find(self, delim, start, true)
    if not pos then
      break
    end
    table.insert(results, string.sub(self, start, pos-1))
    start = pos + string.len(delim)
  end
  table.insert(results, string.sub(self, start))
  table.removevalue(results, '')
  return results
end

function string:starts(start)
  return string.sub(self, 1, #start) == start
end

function string:ends(test)
   return test =='' or string.sub(self,-string.len(test)) == test
end

function string:trim()
  return string.match(self, '^%s*(.*%S)') or ''
end

function string:explode(sep, limit)
  if type(sep) ~= 'string' or tostring(self):len() == 0 or sep:len() == 0 then
    return {}
  end

  local i, pos, tmp, t = 0, 1, "", {}
  for s, e in function() return string.find(self, sep, pos) end do
    tmp = self:sub(pos, s - 1):trim()
    table.insert(t, tmp)
    pos = e + 1

    i = i + 1
    if limit ~= nil and i == limit then
      break
    end
  end

  tmp = self:sub(pos):trim()
  table.insert(t, tmp)
  return t
end

function string:contains(str, checkCase, start, plain)
  if(not checkCase) then
    self = self:lower()
    str = str:lower()
  end
  return string.find(self, str, start and start or 1, plain == nil and true or false)
end

function setStringColor(t, text, color)
    table.insert(t, text)
    table.insert(t, color)
end

function setStringFont(t, text, color, font)
  table.insert(t, text)
  table.insert(t, color)
  table.insert(t, font)
end

function string:parseHTML()
    local result = {}
    local currentIndex = 1

    -- Se a string não contiver tags HTML, retorne-a inteira
    if not self:find("<") or not self:find(">") then
        return {{"", self}}
    end

    while currentIndex <= #self do
        local startTag, endTagStart = self:find("<(.-)>", currentIndex)
        if startTag then
            local tag = self:sub(startTag + 1, endTagStart - 1)
            local endTag = "</" .. tag:match("^(%a+)") .. ">"
            local contentStart, contentEnd = self:find(endTag, endTagStart)

            if contentStart then
                local textBefore = self:sub(currentIndex, startTag - 1)
                if #textBefore > 0 then
                    table.insert(result, {"", textBefore})
                end

                local formatType, color, fontType, fontStyle
                if tag == "b" then
                    formatType = "bold"
                elseif tag == "i" then
                    formatType = "italic"
                elseif tag == "li" then
                    formatType = "list"
                elseif tag:match("^font") then
                    formatType = "font"
                    color = tag:match("color=\"(.-)\"")
                    fontType = tag:match("type=\"(.-)\"")
                    fontStyle = tag:match("style=\"(.-)\"")
                end

                local content = self:sub(endTagStart + 1, contentStart - 1)
                local data = {formatType, content}
                if color then
                  data[1] = "color"
                  data[3] = color
                elseif fontType then
                  data[1] = "fontType"
                  data[3] = fontType
                elseif fontStyle then
                  data[1] = "fontStyle"
                  data[3] = fontStyle
                end
                table.insert(result, data)

                currentIndex = contentEnd + 1
            else
                break
            end
        else
            break
        end
    end

    local textAfter = self:sub(currentIndex)
    if #textAfter > 0 then
        table.insert(result, {"", textAfter})
    end

    return result
end

function string:tocolored(defaltColor)
    local result = {}
    local pattern = "()({.-|.-})()"
    local lastEnd = 1

    if not defaltColor then
        defaltColor = "#F0F0F0"
    end

    local function add(text, color)
        if text ~= "" then
            table.insert(result, text)
            table.insert(result, color)
        end
    end

    for start, item, finish in self:gmatch(pattern) do
        add(self:sub(lastEnd, start - 1), defaltColor)

        local itemId = item:match("{(.-)|")
        local extractedItem = item:match("|(.-)}")
        add(extractedItem, getItemColor(tonumber(itemId)))

        lastEnd = finish
    end

    add(self:sub(lastEnd), defaltColor)

    return result
end

function string.empty(str)
  return #str == 0
end


function string.todivide(str, num)
    local words = {}
    for word in str:gmatch("%S+") do
        table.insert(words, word)
    end

    local textWithBreaks = ""
    local count = 0

    -- Percorre todas as palavras
    for i, word in ipairs(words) do
        textWithBreaks = textWithBreaks .. word
        count = count + 1

        if count == num then
            textWithBreaks = textWithBreaks .. "\n"
            count = 0
        else
            if i ~= #words then
                textWithBreaks = textWithBreaks .. " "
            end
        end
    end

    return textWithBreaks
end

function string.capitalize(str)
  return string.gsub(str, "(%w)([%w]*)", function(firstLetter, restOfString)
      return string.upper(firstLetter) .. string.lower(restOfString)
  end)
end

function string.lineBreaks(input, lineLength, spaceCount)
  if not spaceCount then
      spaceCount = 0
  end

  local result = ""
  local pos = 1
  local space = string.rep(" ", spaceCount)

  while pos <= #input do
      if pos + lineLength - 1 <= #input then
          result = result .. input:sub(pos, pos + lineLength - 1) .. "\n" .. space
      else
          result = result .. input:sub(pos)
      end
      pos = pos + lineLength
  end

  return result
end

function string.containsTable(str, substrings)
  for _, substring in ipairs(substrings) do
      if string.find(str, substring) then
          return true
      end
  end
  return false
end

function string.searchEscape(str)
    str = string.gsub(str, "\\", "\\\\")
    str = string.gsub(str, '"', '\\"')
    str = string.gsub(str, "'", "\\'")
    str = string.gsub(str, "\n", "\\n")
    str = string.gsub(str, "\t", "\\t")
    str = string.gsub(str, "\r", "\\r")
    str = string.gsub(str, "%[", "\\[")
    str = string.gsub(str, "%]", "\\]")
    return str
end

function string.escape(s)
  local matches = {
    ["^"] = "%^", ["$"] = "%$",
    ["("] = "%(", [")"] = "%)",
    ["%"] = "%%", ["."] = "%.",
    ["["] = "%[", ["]"] = "%]",
    ["*"] = "%*", ["+"] = "%+",
    ["-"] = "%-", ["?"] = "%?",
  }
  return (s:gsub(".", matches))
end

function string.tohex(str)
  return (str:gsub('.', function(c)
    return string.format('%02X', string.byte(c))
  end))
end

function string.utf8_to_latin1(src)
  local out = ""
  local i = 1

  while i <= #src do
      local c = src:byte(i)

      if (c >= 32 and c < 128) or c == 0x0D or c == 0x0A or c == 0x09 then
          out = out .. string.char(c)
          i = i + 1
      elseif c == 0xC2 or c == 0xC3 then
          local c2 = src:byte(i + 1)
          if c2 then
              if c == 0xC2 then
                  if c2 > 0xA1 and c2 < 0xBB then
                      out = out .. string.char(c2)
                  end
              elseif c == 0xC3 then
                  out = out .. string.char(64 + c2)
              end
          end
          i = i + 2
      elseif c >= 0xC4 and c <= 0xDF then
          i = i + 2
      elseif c >= 0xE0 and c <= 0xED then
          i = i + 3
      elseif c >= 0xF0 and c <= 0xF4 then
          i = i + 4
      else
          i = i + 1
      end
  end

  return out
end

function string.pack_custom(format, ...)
  local args = {...}
  local result = {}
  local index = 1

  local i = 1
  while i <= #format do
      local fmt = format:sub(i, i)
      local nextChar = format:sub(i + 1, i + 1)
      local specifier = fmt

      if nextChar:match("%d") then
          specifier = fmt .. nextChar
          i = i + 1
      end

      local value = args[index] or 0

      if specifier == "I1" then
          if value < 0 or value > 255 then
              error("Value out of range for I1: " .. tostring(value))
          end
          table.insert(result, string.char(value))

      elseif specifier == "I2" then
          if value < 0 or value > 65535 then
              error("Value out of range for I2: " .. tostring(value))
          end
          table.insert(result, string.char(value % 256, math.floor(value / 256)))

      elseif specifier == "I4" then
          if value < 0 or value > 4294967295 then
              error("Value out of range for I4: " .. tostring(value))
          end
          table.insert(result, string.char(
              value % 256,
              math.floor(value / 256) % 256,
              math.floor(value / 65536) % 256,
              math.floor(value / 16777216)
          ))

      else
          error("Invalid format specifier: " .. specifier)
      end

      index = index + 1
      i = i + 1
  end

  return table.concat(result)
end

function string.unpack_custom(format, data)
  local result = {}
  local index = 1

  local i = 1
  while i <= #format do
      local fmt = format:sub(i, i)
      local nextChar = format:sub(i + 1, i + 1)
      local specifier = fmt

      if nextChar:match("%d") then
          specifier = fmt .. nextChar
          i = i + 1
      end

      if specifier == "I1" then
          result[#result + 1] = string.byte(data, index)
          index = index + 1

      elseif specifier == "I2" then
          local b1, b2 = string.byte(data, index, index + 1)
          result[#result + 1] = b1 + (b2 * 256)
          index = index + 2

      elseif specifier == "I4" then
          local b1, b2, b3, b4 = string.byte(data, index, index + 3)
          result[#result + 1] = b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
          index = index + 4

      else
          error("Invalid format specifier: " .. specifier)
      end

      i = i + 1
  end

  return unpack(result)
end

-- function string.torichtext(str)
--     return str:gsub("<font color=['\"]?(#.-)['\"]?>(.-)</font>", "[color=%1]%2[/color]")
-- end
