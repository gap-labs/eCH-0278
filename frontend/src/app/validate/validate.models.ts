export interface ValidationAnalysis {
  taxProceduresFound: string[];
  phaseDetected: 'declaration' | 'taxation' | 'mixed' | 'unknown';
  snapshotWarning: boolean;
}

export interface NamespaceInfo {
  prefix: string;
  uri: string;
}

export interface ValidateResponse {
  xsdValid: boolean;
  errors: string[];
  namespaces: NamespaceInfo[];
  analysis?: ValidationAnalysis;
}
