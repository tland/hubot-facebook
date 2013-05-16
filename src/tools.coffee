# find an element from an array of objects that matches the id.
exports.findById = (array, id) ->
  i = 0

  while i < array.length
    return array[i]  if array[i].id is id
    i++
  null