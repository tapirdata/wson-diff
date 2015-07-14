debug = require('debug') 'wson-diff:value-target'

assert = require 'assert'
_ = require 'lodash'

Target = require './target'


class ValueTarget extends Target

  constructor: (@root) ->
    @current = @root
    @stack = []
    @topKey = null

  get: (outSteps) ->
    if not outSteps? or outSteps <= 0
      @current
    else
      stack = @stack
      stack[stack.length - outSteps]

  budge: (outSteps, key) ->
    debug 'budge: outSteps=%o, key=%o', outSteps, key
    stack = @stack
    if outSteps > 0
      newLen = stack.length - outSteps
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
    debug 'unset: key=%o, @current=%o', key, @current
    delete @current[key]
    return

  assign: (key, value) ->
    debug 'assign: key=%o, value=%o', key, value
    if key?
      @current[key] = value
    else
      assert @stack.length == 0, 'assign can be used without key at root only'
      @current = value
      @root = @current
    return

  delete: (idx, len) ->
    debug 'delete: idx=%o, len=%o @current=%o', idx, len, @current
    current = @current
    current.splice idx, len
    return

  move: (srcIdx, dstIdx, len, reverse) ->
    debug 'move: srcIdx=%o dstIdx=%o len=%o reverse=%o', srcIdx, dstIdx, len, reverse
    current = @current
    chunk = current.splice srcIdx, len
    if reverse
      chunk.reverse()
    current.splice.apply current, [dstIdx, 0].concat chunk

  insert: (idx, values) ->
    current = @current
    current.splice.apply current, [idx, 0].concat values
    return

  replace: (idx, values) ->
    debug 'assign: idx=%o, values=%o', idx, values
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
    debug 'substitute: patches=%o', patches
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
    @current = result
    stack = @stack
    if stack.length == 0
      @root = result
    else
      stack[stack.length - 1][@topKey] = result

  getRoot: -> @root



module.exports = ValueTarget

