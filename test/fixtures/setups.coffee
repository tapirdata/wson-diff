extdefs = require './extdefs'

connectors =
  Point: extdefs.Point
  Polygon:
    by: extdefs.Polygon
    create: (points) -> new extdefs.Polygon points
    split: (p) -> p.points
  Foo:
    by: extdefs.Foo
    split: (foo) -> [foo.dummy, foo.y, foo.x]
    postcreate: (foo, args) ->
      extdefs.Foo.call foo, args[2], args[1], args[0]
    diffKeys: ['y', 'x']
    postpatch: -> @setupArea()

module.exports = [
  {
    name: 'basic'
    options:
      wsonOptions:
        connectors: connectors
  }
]

