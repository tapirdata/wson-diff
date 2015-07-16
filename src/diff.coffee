debug = require('debug') 'wson-diff:diff'

StringDiff = require './string-diff'
ObjectDiff = require './object-diff'
ArrayDiff = require './array-diff'

class State

  constructor: (@differ) ->
    @wishStack = []

  stringify: (val) ->
    debug 'stringify val=%o wishStack=%o', val, @wishStack
    wishStack = @wishStack
    @differ.wsonDiff.WSON.stringify val, haverefCb: (backVal) ->
      debug 'stringify:   backVal=%o', backVal
      for wish, idx in wishStack
        debug 'stringify:     wish=%o, idx=%o', wish, idx
        if wish == backVal
          debug 'stringify:   found.'
          return wishStack.length - idx - 1
      null

  getPlainDelta: (have, wish, isRoot) ->
    debug 'getPlainDelta(have=%o, wish=%o, isRoot=%o)', have, wish, isRoot
    delta = @stringify wish
    if not isRoot
      delta = ':' + delta
    delta

  getStringDelta: (have, wish, isRoot) ->
    diff = new StringDiff @, have, wish
    if not diff.aborted
      delta = diff.getDelta isRoot
    if diff.aborted
      delta = @getPlainDelta have, wish, isRoot
    delta

  getObjectDelta: (have, wish, isRoot) ->
    @wishStack.push wish
    diff = new ObjectDiff @, have, wish
    if not diff.aborted
      delta = diff.getDelta isRoot
    @wishStack.pop()
    if diff.aborted
      delta = @getPlainDelta have, wish, isRoot
    delta

  getArrayDelta: (have, wish, isRoot) ->
    @wishStack.push wish
    diff = new ArrayDiff @, have, wish
    if not diff.aborted
      delta = diff.getDelta isRoot
    @wishStack.pop()
    if diff.aborted
      delta = @getPlainDelta have, wish, isRoot
    delta

  getDelta: (have, wish, isRoot) ->
    WSON = @differ.wsonDiff.WSON
    haveTi = WSON.getTypeid have
    wishTi = WSON.getTypeid wish
    if wishTi != haveTi
      @getPlainDelta have, wish, isRoot
    else
      switch haveTi
        when 8 # Number
          if have == wish or (have != have and wish != wish) # NaN
            null
          else
            @getPlainDelta have, wish, isRoot
        when 16 # Date
          if have.valueOf() == wish.valueOf()
            null
          else
            @getPlainDelta have, wish, isRoot
        when 20 # String
          @getStringDelta have, wish, isRoot
        when 24 # Array
          @getArrayDelta have, wish, isRoot
        when 32 # Object
          @getObjectDelta have, wish, isRoot
        else
          if have == wish
            null
          else
            @getPlainDelta have, wish, isRoot


class Differ

  constructor: (@wsonDiff, options) ->
    wdOptions = @wsonDiff.options
    options or= {}
    @stringEdge = if options.stringEdge?
      options.stringEdge
    else if wdOptions.stringEdge?
      wdOptions.stringEdge
    else
      16
    @stringLimit = if options.stringLimit?
      options.stringLimit
    else
      wdOptions.stringLimit
    @arrayLimit = if options.arrayLimit?
      options.arrayLimit
    else
      wdOptions.arrayLimit

  diff: (src, dst) ->
    state = new State @
    state.getDelta src, dst, true


exports.Differ = Differ
