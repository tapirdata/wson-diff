import { Foo, Point, Polygon } from "./extdefs"

const connectors = {
  Point,
  Polygon: {
    by: Polygon,
    split(p: Polygon) {
      return p.points
    },
    create(points: Point[]) {
      return new Polygon(points)
    },
  },
  Foo: {
    by: Foo,
    split(foo: Foo) { return [foo.circumference, foo.h, foo.w] },  // add circumference as noise
    postcreate(foo: Foo, args: any[]) {
      [, foo.h, foo.w] = args
      return foo
    },
    diffKeys: ["h", "w"],
    postpatch(foo: Foo) {
      foo.setupArea()
    },
  },
}

export default [
  {
    name: "basic",
    options: {
      wsonOptions: {
        connectors,
      },
    },
  },
]
