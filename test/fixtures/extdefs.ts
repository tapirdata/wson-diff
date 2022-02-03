export type PointArgs = [number, number];

export class Point {
  constructor(public x = 0, public y = 0) {
    this.__wsonpostcreate__([x, y]);
  }

  __wsonsplit__(): PointArgs {
    return [this.x, this.y];
  }

  __wsonpostcreate__(args: PointArgs): void {
    [this.x, this.y] = args;
  }
}

export class Polygon {
  public points: Point[];

  constructor(points: Point[] = []) {
    this.points = points;
  }
}
export type FooValue = number;
export type FooArgs = [FooValue, FooValue];

export class Foo {
  public area!: number;

  constructor(public w: number, public h: number) {
    this.setupArea();
  }

  public setupArea(): void {
    this.area = this.w * this.h;
  }

  get circumference(): number {
    return this.w + this.h;
  }
}
