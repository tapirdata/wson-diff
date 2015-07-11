debug = require('debug') 'wson-diff:string-diff'

mdiff = require 'mdiff'


class StringDiff  

  constructor: (@state, have, wish) ->
    sd = @
    patches = []
    scanCb = (haveBegin, haveEnd, wishBegin, wishEnd) ->
      debug 'scan: %o..%o %o..%o', haveBegin, haveEnd, wishBegin, wishEnd
      patches.push [haveBegin, haveEnd - haveBegin, wish.slice wishBegin, wishEnd]

    diffLenLimit = null
    diffLen = mdiff(have, wish).scanDiff scanCb, diffLenLimit
    aborted = not diffLen?
    @patches = patches

  
  getDelta: ->
    WSON = @state.differ.wsonDiff.WSON
    patches = @patches
    if patches.length == 0
      return null
    delta = '[s'
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

