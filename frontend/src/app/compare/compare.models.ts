export interface CompareDiffSummary {
  changedValues: number;
  addedNodes: number;
  removedNodes: number;
}

export interface CompareResponse {
  xml1Valid: boolean;
  xml2Valid: boolean;
  diffSummary: CompareDiffSummary | null;
}
