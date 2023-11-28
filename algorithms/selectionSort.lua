return function(values)
  for i = 1, values.length do
    local minIndex = i
    for j = i + 1, values.length do
      if values.read(j) < values.read(minIndex) then
        minIndex = j
      end
    end
    values.swap(i, minIndex)
  end
end
