--- Fuzzy matching and ranking for the palette choosers.
---
--- Pure Lua with no `hs.*` dependencies. Scoring follows fzy (https://github.com/jhawthorn/fzy,
--- MIT): matches right after a word boundary and runs of consecutive matches score highest,
--- gaps cost a little.

local M = {}

local NEG_INF = -math.huge

local SCORE_GAP_LEADING = -0.005
local SCORE_GAP_TRAILING = -0.005
local SCORE_GAP_INNER = -0.01
local SCORE_MATCH_CONSECUTIVE = 1.0
local SCORE_MATCH_SLASH = 0.9
local SCORE_MATCH_WORD = 0.8
local SCORE_MATCH_CAPITAL = 0.7
local SCORE_MATCH_DOT = 0.6

--- Score for a query that equals the text (ignoring ASCII case).
M.SCORE_EXACT = 1e6

--- Subtracted from matches found only in a choice's subText, so they rank after text matches.
M.SUBTEXT_PENALTY = 1e7

-- One UTF-8 encoded character. NUL is excluded; it never appears in titles.
local CHAR_PATTERN = "[\1-\127\194-\244][\128-\191]*"

-- Characters after which a match counts as the start of a word.
local WORD_SEPARATORS = {
  [" "] = true,
  ["-"] = true,
  ["_"] = true,
  [":"] = true,
  ["("] = true,
  ["["] = true,
  ["|"] = true,
  [","] = true,
  ["—"] = true,
  ["–"] = true,
  ["›"] = true,
  ["·"] = true,
  ["•"] = true,
}

local function splitChars(s)
  local out = {}
  for ch in s:gmatch(CHAR_PATTERN) do
    out[#out + 1] = ch
  end
  return out
end

local function bonusFor(prev, cur)
  if prev == nil or prev == "/" or prev == "\\" then
    return SCORE_MATCH_SLASH
  elseif WORD_SEPARATORS[prev] then
    return SCORE_MATCH_WORD
  elseif prev == "." then
    return SCORE_MATCH_DOT
  elseif prev:match("^%l$") and cur:match("^%u$") then
    return SCORE_MATCH_CAPITAL
  end
  return 0
end

local function isSubsequence(needle, haystack)
  local j = 1
  for i = 1, #needle do
    while j <= #haystack and haystack[j] ~= needle[i] do
      j = j + 1
    end
    if j > #haystack then
      return false
    end
    j = j + 1
  end
  return true
end

--- Scores how well `query` fuzzily matches `text`.
---
--- Returns nil when `query` is not a case-insensitive subsequence of `text`; otherwise a
--- number where higher is better. An empty query scores 0.
function M.score(query, text)
  if query == nil or query == "" then
    return 0
  end
  if type(text) ~= "string" or text == "" then
    return nil
  end

  local needle = splitChars(query:lower())
  local original = splitChars(text)
  local haystack = splitChars(text:lower())
  local n, m = #needle, #haystack

  if n > m or not isSubsequence(needle, haystack) then
    return nil
  end
  if n == m then
    return M.SCORE_EXACT
  end

  local bonus = {}
  for k = 1, m do
    bonus[k] = bonusFor(original[k - 1], original[k])
  end

  -- D[k]: best score with needle[i] matched exactly at k (ending a consecutive run).
  -- Mx[k]: best score for needle[1..i] within haystack[1..k].
  local prevD, prevM = {}, {}
  for i = 1, n do
    local curD, curM = {}, {}
    local best = NEG_INF
    local gap = (i == n) and SCORE_GAP_TRAILING or SCORE_GAP_INNER
    for k = 1, m do
      if needle[i] == haystack[k] then
        local score = NEG_INF
        if i == 1 then
          score = (k - 1) * SCORE_GAP_LEADING + bonus[k]
        elseif k > 1 then
          score = math.max(prevM[k - 1] + bonus[k], prevD[k - 1] + SCORE_MATCH_CONSECUTIVE)
        end
        curD[k] = score
        best = math.max(score, best + gap)
      else
        curD[k] = NEG_INF
        best = best + gap
      end
      curM[k] = best
    end
    prevD, prevM = curD, curM
  end

  return prevM[m]
end

--- Filters and orders chooser choices by fuzzy score against `text`, then `subText`.
---
--- Choices that match only through `subText` rank after every `text` match. Ties keep their
--- original relative order, so callers can pre-sort by recency. An empty query returns a
--- shallow copy of `choices` in the same order.
function M.rank(query, choices)
  local out = {}
  if query == nil or query == "" then
    for i, choice in ipairs(choices) do
      out[i] = choice
    end
    return out
  end

  local scored = {}
  for i, choice in ipairs(choices) do
    local score = M.score(query, choice.text)
    if score == nil then
      local sub = M.score(query, choice.subText)
      if sub ~= nil then
        score = sub - M.SUBTEXT_PENALTY
      end
    end
    if score ~= nil then
      scored[#scored + 1] = { choice = choice, score = score, index = i }
    end
  end

  table.sort(scored, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.index < b.index
  end)

  for i, entry in ipairs(scored) do
    out[i] = entry.choice
  end
  return out
end

return M
