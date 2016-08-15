import * as extdefs from './extdefs';

let connectors = {
  Point: extdefs.Point,
  Polygon: {
    by: extdefs.Polygon,
    create(points) { return new extdefs.Polygon(points); },
    split(p) { return p.points; }
  },
  Foo: {
    by: extdefs.Foo,
    split(foo) { return [foo.dummy, foo.y, foo.x]; },
    postcreate(foo, args) {
      return extdefs.Foo.call(foo, args[2], args[1], args[0]);
    },
    diffKeys: ['y', 'x'],
    postpatch() { return this.setupArea(); }
  }
};

export default [
  {
    name: 'basic',
    options: {
      wsonOptions: {
        connectors
      }
    }
  }
];

