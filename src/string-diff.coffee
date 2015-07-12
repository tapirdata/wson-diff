_ = require 'lodash'
debug = require('debug') 'wson-diff:string-diff'

mdiff = require 'mdiff'


class StringDiff  

  constructor: (@state, have, wish) ->
    patches = []
    if have == wish
      @aborted = false
    else  
      edge = @state.differ.stringEdge
      if wish.length < edge
        @aborted = true
        return
      sd = @
      scanCb = (haveBegin, haveEnd, wishBegin, wishEnd) ->
        debug 'scan: %o..%o %o..%o', haveBegin, haveEnd, wishBegin, wishEnd
        patches.push [haveBegin, haveEnd - haveBegin, wish.slice wishBegin, wishEnd]

      limit = @state.differ.stringLimit
      if _.isFunction limit
        limit = limit(@wish)
      diffLen = mdiff(have, wish).scanDiff scanCb, limit
      aborted = not diffLen?
    @patches = patches

  
  getDelta: (isRoot) ->
    patches = @patches
    if patches.length == 0
      return null
    WSON = @state.differ.wsonDiff.WSON
    delta = if isRoot then '|[s' else '[s'
    for patch, patchIdx in patches
      [ofs, len, str] = patch
      if patchIdx > 0
        delta += '|'
      delta += ofs
      if len > 0
        delta += '+' + (len - 1)
      if str.length > 0
        delta += '=' + WSON.escape str
    delta += ']'    
    delta    


module.exports = StringDiff

