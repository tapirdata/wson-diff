import { Value } from './types';

export class WsonDiffError extends Error {
  name = '?';

  constructor() {
    super();
  }
}

export function errRepr(x: Value): string {
  try {
    return JSON.stringify(x);
  } catch (error1) {
    return String(x);
  }
}
