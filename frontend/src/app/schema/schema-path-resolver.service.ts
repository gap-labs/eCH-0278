import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { map, shareReplay } from 'rxjs/operators';

import { SchemaNode } from './schema.models';
import { SchemaExplorerService } from './schema-explorer.service';

@Injectable({ providedIn: 'root' })
export class SchemaPathResolverService {
  private readonly rootNode$ = this.schemaExplorerService.getTree().pipe(
    map((response) => response.root),
    shareReplay(1),
  );

  constructor(private readonly schemaExplorerService: SchemaExplorerService) {}

  resolvePath(path: string): Observable<SchemaNode[] | null> {
    return this.rootNode$.pipe(map((rootNode) => this.resolvePathInRoot(rootNode, path)));
  }

  resolvePathInRoot(rootNode: SchemaNode, path: string): SchemaNode[] | null {
    const normalizedSegments = this.normalizePath(path);
    if (!normalizedSegments) {
      return null;
    }

    return this.findNodePath(rootNode, normalizedSegments);
  }

  private normalizePath(path: string): string[] | null {
    const trimmedPath = path.trim();
    if (!trimmedPath.startsWith('/')) {
      return null;
    }

    const rawSegments = trimmedPath
      .split('/')
      .map((segment) => segment.trim())
      .filter((segment) => segment.length > 0);

    if (rawSegments.length === 0) {
      return null;
    }

    const normalizedSegments = rawSegments
      .map((segment) => segment.split(':').pop()?.trim() ?? '')
      .filter((segment) => segment.length > 0);

    return normalizedSegments.length > 0 ? normalizedSegments : null;
  }

  private findNodePath(rootNode: SchemaNode, segments: string[]): SchemaNode[] | null {
    const nodePath: SchemaNode[] = [rootNode];
    let currentNode = rootNode;

    for (let index = 0; index < segments.length; index += 1) {
      const segment = segments[index];

      if (index === 0 && currentNode.name === segment) {
        continue;
      }

      const nextNode = currentNode.children.find((childNode) => childNode.name === segment);
      if (!nextNode) {
        if (index === 0) {
          const topLevelNode = rootNode.children.find((childNode) => childNode.name === segment);
          if (!topLevelNode) {
            return null;
          }

          nodePath.push(topLevelNode);
          currentNode = topLevelNode;
          continue;
        }

        return null;
      }

      nodePath.push(nextNode);
      currentNode = nextNode;
    }

    return nodePath;
  }
}