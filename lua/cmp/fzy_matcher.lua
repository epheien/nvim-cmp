local char = require('cmp.utils.char')
local fzy = require('cmp.algos.fzy')

local M = {}

local FZY_SCORE_FLOOR = fzy.get_score_floor()

---positions => match list
---@param positions integer[]
---@return table[]
M.to_matches_table = function(positions)
  if #positions == 0 then
    return {}
  end
  local matches = {}
  for idx, pos in ipairs(positions) do
    local match = {
      input_match_start = idx,
      input_match_end = idx,
      word_match_start = pos,
      word_match_end = pos,
      strict_ratio = 0, -- unused
      fuzzy = true,
    }
    table.insert(matches, match)
  end
  return matches
end

---@param prompt string
---@param line string
---@return number valid range [1, inf], 0 means not match
M.score = function(prompt, line)
  if not fzy.has_match(prompt, line) then
    return 0
  end

  local fzy_score = fzy.score(prompt, line)

  -- The lowest value returned by `score`.
  --
  -- In two special cases:
  --  - an empty `needle`, or
  --  - a `needle` or `haystack` larger than than `get_max_length`,
  -- the `score` function will return this exact value, which can be used as a
  -- sentinel. This is the lowest possible score.
  if fzy_score == fzy.get_score_min() then
    return 1
  end

  return fzy_score - FZY_SCORE_FLOOR + 1
end

---Match entry
---@param input string
---@param word string
---@param option? table reference option of _match()
---@return integer, table
M.match = function(input, word, option)
  option = option or {}

  -- Empty input
  if #input == 0 then
    return 1, {}
  end

  -- Ignore if input is long than word
  if #input > #word then
    return 0, {}
  end

  -- Supported options:
  --  - disallow_prefix_unmatching: reject when first char of input doesn't match first char of word
  --  - disallow_fullfuzzy_matching: reject all matches (fzy is fully fuzzy, no non-fuzzy path)
  -- NOTE: other `matching.disallow_*` options (disallow_fuzzy_matching,
  -- disallow_partial_fuzzy_matching, disallow_partial_matching,
  -- disallow_symbol_nonprefix_matching) are intentionally NOT supported:
  -- fzy always matches in a fully-fuzzy manner, so these options are ignored.

  -- Check prefix matching.
  if option.disallow_prefix_unmatching then
    if not char.match(string.byte(input, 1), string.byte(word, 1)) then
      return 0, {}
    end
  end

  return M._match(input, word, option)
end

---Match entry
---@param input string
---@param word string
---@param option? { disallow_prefix_unmatching: boolean, disallow_fullfuzzy_matching: boolean }
---@return integer, table
M._match = function(input, word, option)
  if option and option.disallow_fullfuzzy_matching then
    return 0, {}
  end
  local score = M.score(input, word)
  if score == 0 then
    return 0, {}
  end
  local positions = fzy.positions(input, word)
  return score, M.to_matches_table(positions)
end

return M
