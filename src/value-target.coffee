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
    delete @current[key]
    if not @notifyDepth?
      @notifier.unset key
    return

  assign: (key, value) ->
    debug 'assign(key=%o value=%o)', key, value
    @put_ key, value
    if not @notifyDepth?
      @notifier.assign key, value
    return

  delete: (idx, len) ->
    debug 'delete(idx=%o len=%o) @current=%o', idx, len, @current
    current = @current
    current.splice idx, len
    if not @notifyDepth?
      @notifier.delete idx, len
    return

  move: (srcIdx, dstIdx, len, reverse) ->
    debug 'move(srcIdx=%o dstIdx=%o len=%o reverse=%o)', srcIdx, dstIdx, len, reverse
    current = @current
    chunk = current.splice srcIdx, len
    if reverse
      chunk.reverse()
    current.splice.apply current, [dstIdx, 0].concat chunk
    if not @notifyDepth?
      @notifier.move srcIdx, dstIdx, len, reverse
    return

  insert: (idx, values) ->
    current = @current
    current.splice.apply current, [idx, 0].concat values
    if not @notifyDepth?
      @notifier.insert idx, values
    return

  replace: (idx, values) ->
    debug 'assign(idx=%o, values=%o)', idx, values
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
    if not @notifyDepth?
      @notifier.replace idx, values
    return

  substitute: (patches) ->
    debug 'substitute(patches=%o)', patches
    have = @current
    result = ''
    endOfs = 0
    for patch in patches
      [ofs, lenDiff, str] = patch
      if ofs > endOfs
        result += have.slice endOfs, ofs
      strLen = str.length
      if strLen > 0
        result += str
      endOfs = ofs + strLen - lenDiff
      debug 'substitute: patch=%o result=%o', patch, result
    if have.length > endOfs
      result += have.slice endOfs
    debug 'substitute: result=%o', result
    @put_ null, result
    if not @notifyDepth?
      @notifier.substitute patches
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

