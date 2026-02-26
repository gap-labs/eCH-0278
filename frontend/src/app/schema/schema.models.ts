export type SchemaNodeKind = 'element' | 'complexType' | 'simpleType' | 'attribute';

export interface SchemaCardinality {
  min: number;
  max: number | 'unbounded';
}

export interface SchemaAttribute {
  name: string;
  kind: 'attribute';
  type: string | null;
  enum: string[];
  source: string | null;
}

export interface SchemaNode {
  name: string;
  kind: SchemaNodeKind;
  type: string | null;
  namespace: string;
  cardinality: SchemaCardinality | null;
  attributes: SchemaAttribute[];
  enumeration: string[] | null;
  children: SchemaNode[];
}

export interface SchemaSummary {
  schemaVersion: string;
  targetNamespace: string;
  schemaLocation: string;
  rootElements: string[];
  topLevelTypes: string[];
}

export interface SchemaTreeResponse {
  root: SchemaNode;
}
