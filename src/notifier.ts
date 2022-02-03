import { Key, Patch } from './target';
import { AnyArray, Value } from './types';

export interface Notifier {
  checkedBudge: (up: number, key: Key, current: Value) => boolean;
  unset: (key: string, curent: Value) => void;
  assign: (key: Key, value: Value, current?: Value) => void;
  delete: (idx: number, len: number, current?: Value) => void;
  move: (srcIdx: number, dstIdx: number, len: number, reverse: boolean, current?: Value) => void;
  insert: (idx: number, values: AnyArray, current?: Value) => void;
  replace: (idx: number, values: AnyArray, current?: Value) => void;
  substitute: (patches: Patch[], current?: Value) => void;
}
