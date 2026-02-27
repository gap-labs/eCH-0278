import { ChangeDetectionStrategy, ChangeDetectorRef, Component, ElementRef, EventEmitter, Input, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NestedTreeControl } from '@angular/cdk/tree';
import { MatTreeModule, MatTreeNestedDataSource } from '@angular/material/tree';
import { MatButtonModule } from '@angular/material/button';

import { SchemaNode } from './schema.models';

@Component({
  selector: 'app-schema-tree',
  standalone: true,
  imports: [CommonModule, MatTreeModule, MatButtonModule],
  templateUrl: './schema-tree.component.html',
  styleUrl: './schema-tree.component.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SchemaTreeComponent {
  treeControl = new NestedTreeControl<SchemaNode>((node) => node.children);
  dataSource = new MatTreeNestedDataSource<SchemaNode>();
  private readonly nodeDomIds = new WeakMap<SchemaNode, string>();

  @Input() selectedNode: SchemaNode | null = null;
  @Output() nodeSelected = new EventEmitter<SchemaNode>();

  constructor(
    private readonly elementRef: ElementRef<HTMLElement>,
    private readonly changeDetectorRef: ChangeDetectorRef,
  ) {}

  @Input() set root(value: SchemaNode | null) {
    this.dataSource.data = value ? [value] : [];
    if (value) {
      this.indexNodeDomIds(value, '0');
      this.treeControl.expand(value);
    }
  }

  hasChild = (_: number, node: SchemaNode): boolean => node.children.length > 0;

  onSelect(node: SchemaNode): void {
    this.nodeSelected.emit(node);
  }

  isSelected(node: SchemaNode): boolean {
    return this.selectedNode === node;
  }

  expandPath(path: SchemaNode[]): void {
    path.forEach((node) => this.treeControl.expand(node));
  }

  collapseAll(): void {
    const rootNode = this.dataSource.data[0];
    if (rootNode) {
      this.collapseRecursively(rootNode);
    }

    this.treeControl.collapseAll();
    if (rootNode) {
      this.treeControl.expand(rootNode);
    }

    this.changeDetectorRef.detectChanges();
  }

  domId(node: SchemaNode): string {
    const id = this.nodeDomIds.get(node);
    return id ? `schema-node-${id}` : '';
  }

  scrollToNode(node: SchemaNode): void {
    const domId = this.domId(node);
    if (!domId) {
      return;
    }

    requestAnimationFrame(() => {
      const escapedId = typeof CSS !== 'undefined' && typeof CSS.escape === 'function' ? CSS.escape(domId) : domId;
      const nodeElement = this.elementRef.nativeElement.querySelector<HTMLElement>(`#${escapedId}`);
      nodeElement?.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'auto' });
    });
  }

  private indexNodeDomIds(node: SchemaNode, indexPath: string): void {
    this.nodeDomIds.set(node, indexPath);

    node.children.forEach((childNode, childIndex) => {
      this.indexNodeDomIds(childNode, `${indexPath}-${childIndex}`);
    });
  }

  private collapseRecursively(node: SchemaNode): void {
    this.treeControl.collapse(node);
    node.children.forEach((childNode) => this.collapseRecursively(childNode));
  }
}
