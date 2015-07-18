debug = require('debug') 'wson-diff:diff'

StringDiff = require './string-diff'
ObjectDiff = require './object-diff'
ArrayDiff = require './array-diff'

class State

  constructor: (@differ) ->
    @wishStack = []
    @haveStack = []

  stringify: (val, useHave) ->
    stack = if useHave then @haveStack else @wishStack
    debug 'stringify val=%o stack=%o', val, stack
    @differ.wdiff.WSON.stringify val, haverefCb: (backVal) ->
      debug 'stringify:   backVal=%o', backVal
      for wish, idx in stack
        debug 'stringify:     wish=%o, idx=%o', wish, idx
        if wish == backVal
          debug 'stringify:   found.'
          return stack.length - idx - 1
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
    @haveStack.push have
    diff = new ObjectDiff @, have, wish
    if not diff.aborted
      delta = diff.getDelta isRoot
    @haveStack.pop()
    @wishStack.pop()
    if diff.aborted
      delta = @getPlainDelta have, wish, isRoot
    delta

  getArrayDelta: (have, wish, isRoot) ->
    @wishStack.push wish
    @haveStack.push have
    diff = new ArrayDiff @, have, wish
    if not diff.aborted
      delta = diff.getDelta isRoot
    @haveStack.pop()
    @wishStack.pop()
    if diff.aborted
      delta = @getPlainDelta have, wish, isRoot
    delta

  getDelta: (have, wish, isRoot) ->
    WSON = @differ.wdiff.WSON
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

  constructor: (@wdiff, options) ->
    wdOptions = @wdiff.options
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
