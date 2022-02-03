import { Connector } from 'wson';

export type Value = unknown;
export type AnyArray = unknown[];
export type AnyRecord = Record<string, unknown>;

export type Delta = string | null;

export interface DiffConnector extends Connector {
  postpatch?: (value: Value) => void;
}
