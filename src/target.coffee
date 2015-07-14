debug = require('debug') 'wson-diff:target'

class Target

  get: (outSteps) ->
  budge: (outSteps, key) ->

  unset: (key) ->
  assign: (key, value) ->

  delete: (idx, len) ->
  move: (srcIdx, dstIdx, len, reverse) ->
  insert: (idx, values) ->
  replace: (idx, values) ->

  substitute: (patches) ->


module.exports = Target
