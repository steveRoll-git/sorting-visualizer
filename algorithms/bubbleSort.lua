return function(values)
  local isSorted = false
  local lastSortedIndex = values.length
  while not isSorted do
    isSorted = true
    for i = 1, lastSortedIndex - 1 do
      local a = values.read(i)
      local b = values.read(i + 1)
      if a > b then
        isSorted = false
        values.swap(i, i + 1)
        if i + 1 >= lastSortedIndex - 1 then
          lastSortedIndex = i
        end
      end
    end
  end
end
