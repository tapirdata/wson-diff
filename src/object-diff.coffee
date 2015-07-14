_ = require 'lodash'
debug = require('debug') 'wson-diff:object-diff'


hasOwnProperty = Object::hasOwnProperty

class ObjectDiff

  constructor: (@state, have, wish) ->
    if have.constructor != wish.constructor
      @aborted = true
    else
      @have = have
      @wish = wish
      @aborted = false


  getDelta: (isRoot) ->
    have = @have
    wish = @wish
    debug 'getDelta(have=%o, wish=%o, isRoot=%o)', have, wish, isRoot
    delta = ''
    state = @state

    diffKeys = null
    if have.constructor? and have.constructor != Object
      connector = state.differ.wsonDiff.WSON.connectorOfValue have
      diffKeys = connector?.diffKeys
    hasDiffKeys = diffKeys?

    delCount = 0
    haveKeys = if hasDiffKeys then diffKeys else _(have).keys().sort().value()
    for key in haveKeys
      if not hasOwnProperty.call wish, key
        if delCount == 0
          if isRoot
            delta += '|'
          delta += '[-'
        else
          delta += '|'
        delta += state.stringify key
        ++delCount
    if delCount > 0
      delta += ']'

    setDelta = ''
    setCount = 0
    wishKeys = if hasDiffKeys then diffKeys else _(wish).keys().sort().value()
    for key in wishKeys
      if hasDiffKeys and not hasOwnProperty.call wish, key
        continue
      keyDelta = state.getDelta have[key], wish[key]
      debug 'getDelta: key=%o, keyDelta=%o', key, keyDelta
      if keyDelta?
        if setCount > 0
          setDelta += '|'
        setDelta += state.stringify(key) + keyDelta
        ++setCount
    debug 'getDelta: setDelta=%o, setCount=%o', setDelta, setCount
    if setCount > 0
      if isRoot
        if delCount == 0
          delta += '|'
        delta += setDelta
      else
        if setCount == 1 and delCount == 0
          delta += '|'
          delta += setDelta
        else
          delta += '[=' + setDelta + ']'
    if delta.length
      delta
    else
      null



module.exports = ObjectDiff
