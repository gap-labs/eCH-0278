import { Component, EventEmitter, Input, Output } from '@angular/core';
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
})
export class SchemaTreeComponent {
  treeControl = new NestedTreeControl<SchemaNode>((node) => node.children);
  dataSource = new MatTreeNestedDataSource<SchemaNode>();

  @Input() selectedNode: SchemaNode | null = null;
  @Output() nodeSelected = new EventEmitter<SchemaNode>();

  @Input() set root(value: SchemaNode | null) {
    this.dataSource.data = value ? [value] : [];
    if (value) {
      this.treeControl.expand(value);
    }
  }

  hasChild = (_: number, node: SchemaNode): boolean => node.children.length > 0;

  onSelect(node: SchemaNode): void {
    this.nodeSelected.emit(node);
  }

  isSelected(node: SchemaNode): boolean {
    return this.selectedNode?.name === node.name && this.selectedNode?.kind === node.kind;
  }
}
