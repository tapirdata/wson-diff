debug = require('debug') 'wson-diff:notifier-target'

class NotifierTarget

  constructor: (vt, notifiers) ->
    @vt        = vt
    @notifiers = notifiers
    current = vt.current
    depths = []
    for notifier, ndx in notifiers
      depths[ndx] = if false == notifier.checkedBudge 0, null, current
        0 # assign root
      else
        null
    @depths = depths    

  budge: (up, key) ->
    vt = @vt
    depths = @depths
    stack = vt.stack
    current = vt.current
    stackLen = stack.length
    newLen = stackLen - up
    for notifier, ndx in @notifiers
      notifyDepth = depths[ndx]
      if up > 0
        if notifyDepth?
          notifyUp = notifyDepth - newLen
          if notifyUp > 0
            notifyValue = if notifyDepth == stackLen
              current
            else
              stack[notifyDepth]
            notifier.assign null, notifyValue
            notifyDepth = null
          else
            notifyUp = 0
        else
          notifyUp = up
      else
        notifyUp = 0
      debug 'budge: notifyUp=%o', notifyUp
      if key?
        if not notifyDepth?
          if false == notifier.checkedBudge notifyUp, key, current
            notifyDepth = newLen + 1
      else if notifyUp > 0
        notifier.checkedBudge notifyUp, null, current
      debug 'budge: ->notifyDepth=%o', notifyDepth
      depths[ndx] = notifyDepth


  unset: (key) ->
    depths = @depths
    current = @vt.current
    for notifier, ndx in @notifiers
      if not depths[ndx]?
        notifier.unset key, current

  assign: (key, value) ->
    depths = @depths
    current = @vt.current
    for notifier, ndx in @notifiers
      if not depths[ndx]?
        notifier.assign key, value, current

  delete: (idx, len) ->
    depths = @depths
    current = @vt.current
    for notifier, ndx in @notifiers
      if not depths[ndx]?
        notifier.delete idx, len, current

  move: (srcIdx, dstIdx, len, reverse) ->
    depths = @depths
    current = @vt.current
    for notifier, ndx in @notifiers
      if not depths[ndx]?
        notifier.move srcIdx, dstIdx, len, reverse, current

  insert: (idx, values) ->
    depths = @depths
    current = @vt.current
    for notifier, ndx in @notifiers
      if not depths[ndx]?
        notifier.insert idx, values, current

  replace: (idx, values) ->
    depths = @depths
    current = @vt.current
    for notifier, ndx in @notifiers
      if not depths[ndx]?
        notifier.replace idx, values, current

  substitute: (patches) ->
    depths = @depths
    current = @vt.current
    for notifier, ndx in @notifiers
      if not depths[ndx]?
        notifier.substitute patches, current

  done: ->
    depths = @depths
    current = @vt.current
    stack = @vt.stack
    debug 'done: stack=%o current=%o depths=%o', stack, current, depths
    stackLen = stack.length
    for notifier, ndx in @notifiers
      notifyDepth = depths[ndx]
      if notifyDepth?
        notifyValue = if notifyDepth == stackLen
          current
        else
          stack[notifyDepth]
        debug 'done: ndx=%o value=%o', ndx, notifyValue
        notifier.assign null, notifyValue


module.exports = NotifierTarget


