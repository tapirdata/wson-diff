// tslint:disable:max-classes-per-file

export class Point {

  public x?: number
  public y?: number

  constructor(x: number = 0, y: number = 0) {
    this.__wsonpostcreate__([x, y])
  }

  public __wsonsplit__() {
    return [this.x, this.y]
  }

  public __wsonpostcreate__(args: number[]) {
    [this.x, this.y] = args
  }

}

export class Polygon {

  public points: Point[]

  constructor(points: Point[] = []) {
    this.points = points
  }
}

export class Foo {

  public w: number
  public h: number
  public area!: number

  constructor(w: number, h: number) {
    this.w = w
    this.h = h
    this.setupArea()
  }

  public setupArea() {
    this.area = this.w * this.h
  }

  get circumference() {
    return this.w + this.h
  }
}
