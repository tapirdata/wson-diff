class Point {
  constructor(x, y) {
    this.x = x;
    this.y = y;
  }
  __wsonsplit__() { return [this.x, this.y]; }
}


class Polygon {
  constructor(points=[]) {
    this.points = points;
  }
}

class Foo {
  constructor(x, y, area) {
    this.x = x;
    this.y = y;
    this.area = area;
    this.setupArea();
  }

  setupArea() {
    return this.area = this.x * this.y;
  }
}

export { Point, Polygon, Foo };


