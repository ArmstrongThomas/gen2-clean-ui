return function()
  local Keyboard = {}
  local nicknameHookAvailable = false

  -- Gen1 Modern's nickname keyboard is deliberately adapted to Gen2's
  -- source-owned cursor contract. Gen2 always has nine cursor columns, so the
  -- numeric rows stay nine cells wide; the final row exposes 0 in column 0
  -- and harmless blank cells in the remaining columns. The released host
  -- still owns movement, character insertion, case, delete, and END.
  local MODERN_UPPER = {
    { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
    { "J", "K", "L", "M", "N", "O", "P", "Q", "R" },
    { "S", "T", "U", "V", "W", "X", "Y", "Z", " " },
    { "\xc3\x97", "(", ")", ":", ";", "[", "]", "<PK>", "<MN>" },
    { "-", "?", "!", "\xe2\x99\x82", "\xe2\x99\x80", "/", ".", ",", "&" },
    { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
    { "0", "", "", "", "", "", "", "", "" },
  }

  local function copyRows(rows, lower)
    local output = {}
    for rowIndex, row in ipairs(rows) do
      output[rowIndex] = {}
      for colIndex, value in ipairs(row) do
        if lower and value:match("^[A-Z]$") then
          output[rowIndex][colIndex] = value:lower()
        else
          output[rowIndex][colIndex] = value
        end
      end
    end
    return output
  end

  function Keyboard.nickname(lower)
    return copyRows(MODERN_UPPER, lower == true)
  end

  function Keyboard.setNicknameHookAvailable(value)
    nicknameHookAvailable = value == true
  end

  function Keyboard.nicknameEnabled()
    return nicknameHookAvailable
  end

  function Keyboard.isNicknameContext(context)
    return context == "nickname"
  end

  return Keyboard
end
