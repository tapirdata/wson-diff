debug = require('debug') 'wson-diff:value-target'

assert = require 'assert'
_ = require 'lodash'

Target = require './target'


class ValueTarget extends Target

  constructor: (root, notifier) ->
    @root = root
    @current = root
    @stack = []
    @topKey = null
    @notifier = notifier
    @notifyDepth = if not notifier?
      -1 # never assign
    else if false == notifier.checkedBudge 0, null, @current
      0 # assign root
    else
      null

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

  get: (up) ->
    if not up? or up <= 0
      @current
    else
      stack = @stack
      stack[stack.length - up]

  budge: (up, key) ->
    debug 'budge(up=%o key=%o) notifyDepth=%o', up, key, @notifyDepth
    debug 'budge: stack=%o current=%o', @stack, @current
    stack = @stack
    notifyDepth = @notifyDepth
    if up > 0
      newLen = stack.length - up
      if notifyDepth?
        notifyUp = notifyDepth - newLen
        if notifyUp > 0
          notifyValue = if notifyDepth == stack.length
            @current
          else
            stack[notifyDepth]
          @notifier.assign null, notifyValue
          notifyDepth = null
        else
          notifyUp = 0
      else
        notifyUp = up
      current = stack[newLen]
      stack.splice newLen
    else
      current = @current
      notifyUp = 0
    debug 'budge: notifyUp=%o', notifyUp
    if key?
      stack.push current
      current = current[key]
      if not notifyDepth?
        if false == @notifier.checkedBudge notifyUp, key, @current
          notifyDepth = @stack.length
    else if notifyUp > 0
      @notifier.checkedBudge notifyUp, null, @current
    debug 'budge: ->notifyDepth=%o', notifyDepth
    @notifyDepth = notifyDepth
    @current = current
    @topKey = key
    return

  unset: (key) ->
    debug 'unset(key=%o) @current=%o', key, @current
    if not @notifyDepth?
      @notifier.unset key, @current
    delete @current[key]
    return

  assign: (key, value) ->
    debug 'assign(key=%o value=%o)', key, value
    if not @notifyDepth?
      @notifier.assign key, value, @current
    @put_ key, value
    return

  delete: (idx, len) ->
    debug 'delete(idx=%o len=%o) @current=%o', idx, len, @current
    current = @current
    if not @notifyDepth?
      @notifier.delete idx, len, current
    current.splice idx, len
    return

  move: (srcIdx, dstIdx, len, reverse) ->
    debug 'move(srcIdx=%o dstIdx=%o len=%o reverse=%o)', srcIdx, dstIdx, len, reverse
    current = @current
    if not @notifyDepth?
      @notifier.move srcIdx, dstIdx, len, reverse, current
    chunk = current.splice srcIdx, len
    if reverse
      chunk.reverse()
    current.splice.apply current, [dstIdx, 0].concat chunk
    return

  insert: (idx, values) ->
    current = @current
    if not @notifyDepth?
      @notifier.insert idx, values, current
    current.splice.apply current, [idx, 0].concat values
    return

  replace: (idx, values) ->
    debug 'replace(idx=%o, values=%o)', idx, values
    valuesLen = values.length
    if valuesLen == 0
      return
    current = @current
    if not @notifyDepth?
      @notifier.replace idx, values, current
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
    current = @current
    result = ''
    endOfs = 0
    if not @notifyDepth?
      @notifier.substitute patches, current
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
    debug 'done() notifyDepth=%o', @notifyDepth
    debug 'done: stack=%o current=%o', @stack, @current
    notifyDepth = @notifyDepth
    stack = @stack
    if notifyDepth? and notifyDepth >= 0
      notifyValue = if notifyDepth == stack.length
        @current
      else
        stack[notifyDepth]
      @notifier.assign null, notifyValue
    return

  getRoot: -> @root



module.exports = ValueTarget

