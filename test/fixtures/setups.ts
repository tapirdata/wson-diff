import addon from 'wson-addon';
import { DiffOptions } from '../../src/options';

import { Foo, Point, Polygon } from './extdefs';

const connectors = {
  Point,
  Polygon: {
    by: Polygon,
    split(p: Polygon): Point[] {
      return p.points;
    },
    create(points: Point[]): Polygon {
      return new Polygon(points);
    },
  },
  Foo: {
    by: Foo,
    split(foo: Foo): number[] {
      return [foo.circumference, foo.h, foo.w]; // add circumference as noise
    },
    postcreate(foo: Foo, args: number[]): Foo {
      [, foo.h, foo.w] = args;
      return foo;
    },
    diffKeys: ['h', 'w'],
    postpatch(foo: Foo): void {
      foo.setupArea();
    },
  },
};

export const setups: { name: string; options: DiffOptions }[] = [
  {
    name: 'basic js',
    options: {
      wsonOptions: {
        connectors,
        addon,
      },
    },
  },
  {
    name: 'basic with addon',
    options: {
      wsonOptions: {
        connectors,
        addon,
      },
    },
  },
];
