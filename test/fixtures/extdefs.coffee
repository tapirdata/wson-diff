'use strict'

class Point
  constructor: (@x, @y) ->
  __wsonsplit__: () -> [@x, @y]


class Polygon
  constructor: (@points=[]) ->

class Foo
  constructor: (@x, @y, @dummy) ->


exports.Point = Point
exports.Polygon = Polygon
exports.Foo = Foo


