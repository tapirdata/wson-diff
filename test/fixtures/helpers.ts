import util = require('util');
import { Value } from '../../src/types';

export function safeRepr(x: Value): string {
  try {
    return util.inspect(x, { depth: null });
  } catch (error0) {
    try {
      return JSON.stringify(x);
    } catch (error1) {
      return String(x);
    }
  }
}
