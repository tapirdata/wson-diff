debug = require('debug') 'wson-diff:value-target'

Target = require './target'

class ValueTarget extends Target

  constructor: (@WSON, root) ->
    @root = @current = root
    @stack = []
    @topKey = null
    @subTarget = null

  setSubTarget: (@subTarget) ->

  put_: (key, value) ->
    if key?
      @current[key] = value
    else
      @current = value
      stack = @stack
      if stack.length == 0
        @root = @current
      else
        stack[stack.length - 1][@topKey] = value
    return

  closeObjects_: (tillIdx) ->
    value = @current
    stack = @stack
    idx = stack.length
    loop
      debug 'closeObjects_ %o', value
      if typeof value == 'object' and value.constructor? and value.constructor != Object
        connector = @WSON.connectorOfValue value
        debug 'closeObjects_ connector=%o', connector
        connector?.postpatch?.call value
      if --idx < tillIdx
        break
      value = stack[idx]
    return

  get: (up) ->
    if not up? or up <= 0
      @current
    else
      stack = @stack
      stack[stack.length - up]

  budge: (up, key) ->
    debug 'budge(up=%o key=%o)', up, key
    debug 'budge: stack=%o current=%o', @stack, @current
    stack = @stack
    @subTarget?.budge up, key
    if up > 0
      newLen = stack.length - up
      @closeObjects_ newLen + 1
      current = stack[newLen]
      stack.splice newLen
    else
      current = @current
    if key?
      stack.push current
      current = current[key]
    @current = current
    @topKey = key
    return

  unset: (key) ->
    debug 'unset(key=%o) @current=%o', key, @current
    @subTarget?.unset key
    delete @current[key]
    return

  assign: (key, value) ->
    debug 'assign(key=%o value=%o)', key, value
    @subTarget?.assign key, value
    @put_ key, value
    return

  delete: (idx, len) ->
    debug 'delete(idx=%o len=%o) @current=%o', idx, len, @current
    @subTarget?.delete idx, len
    @current.splice idx, len
    return

  move: (srcIdx, dstIdx, len, reverse) ->
    debug 'move(srcIdx=%o dstIdx=%o len=%o reverse=%o)', srcIdx, dstIdx, len, reverse
    @subTarget?.move srcIdx, dstIdx, len, reverse
    current = @current
    chunk = current.splice srcIdx, len
    if reverse
      chunk.reverse()
    current.splice.apply current, [dstIdx, 0].concat chunk
    return

  insert: (idx, values) ->
    @subTarget?.insert idx, values
    current = @current
    current.splice.apply current, [idx, 0].concat values
    return

  replace: (idx, values) ->
    debug 'replace(idx=%o, values=%o)', idx, values
    @subTarget?.replace idx, values
    valuesLen = values.length
    if valuesLen == 0
      return
    current = @current
    valuesIdx = 0
    loop
      current[idx] = values[valuesIdx]
      if ++valuesIdx == valuesLen
        break
      else
        ++idx
    return

  substitute: (patches) ->
    debug 'substitute(patches=%o)', patches
    @subTarget?.substitute patches
    current = @current
    result = ''
    endOfs = 0
    for patch in patches
      [ofs, lenDiff, str] = patch
      if ofs > endOfs
        result += current.slice endOfs, ofs
      strLen = str.length
      if strLen > 0
        result += str
      endOfs = ofs + strLen - lenDiff
      debug 'substitute: patch=%o result=%o', patch, result
    if current.length > endOfs
      result += current.slice endOfs
    debug 'substitute: result=%o', result
    @put_ null, result
    return

  done: ->
    debug 'done: stack=%o current=%o', @stack, @current
    @subTarget?.done()
    @closeObjects_ 0
    return

  getRoot: -> @root


module.exports = ValueTarget

