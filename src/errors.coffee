


class WsonDiffError extends Error
  constructor: ->
    if Error.captureStackTrace
      Error.captureStackTrace @, @constructor


exports.WsonDiffError = WsonDiffError      


