debug = require('debug') 'wson-diff:value-target'

assert = require 'assert'
_ = require 'lodash'

Target = require './target'


class ValueTarget extends Target

  constructor: (@root) ->
    @current = @root
    @stack = []

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

  unset: (key) ->
    debug 'unset: key=%o, @current=%o', key, @current
    delete @current[key]
    return

  replace: (key, values) ->
    debug 'assign: key=%o, values=%o', key, values
    valuesLen = values.length
    if valuesLen == 0
      return
    current = @current
    valuesIdx = 0
    loop
      current[key] = values[valuesIdx]
      if ++valuesIdx == valuesLen
        break
      else
        ++key
    return

  delete: (key, len) ->
    debug 'delete: key=%o, len=%o @current=%o', key, len, @current
    current = @current
    current.splice key, len
    return

  insert: (key, values) ->
    current = @current
    current.splice.apply current, [key, 0].concat values
    return

  move: (srcKey, dstKey, len, reverse) ->
    debug 'move: srcKey=%o dstKey=%o len=%o reverse=%o', srcKey, dstKey, len, reverse
    current = @current
    chunk = current.splice srcKey, len
    if reverse
      chunk.reverse()
    current.splice.apply current, [dstKey, 0].concat chunk

  getRoot: -> @root




module.exports = ValueTarget

