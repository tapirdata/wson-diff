import { Wson, WsonOptions } from 'wson';
import { ArrayLimiter } from './array-diff';
import { Notifier } from './notifier';
import { StringLimiter } from './string-diff';

export interface DiffOptions {
  WSON?: Wson;
  wsonOptions?: WsonOptions;
  stringEdge?: number;
  stringLimit?: number | StringLimiter;
  arrayLimit?: number | ArrayLimiter;
  notifiers?: Notifier | Notifier[];
}

// eslint-disable-next-line @typescript-eslint/no-empty-interface
export interface PatchOptions {}
