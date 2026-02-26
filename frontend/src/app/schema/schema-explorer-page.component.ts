import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';

import { SchemaNode, SchemaSummary } from './schema.models';
import { SchemaExplorerService } from './schema-explorer.service';
import { SchemaTreeComponent } from './schema-tree.component';
import { SchemaNodeDetailsComponent } from './schema-node-details.component';

@Component({
  selector: 'app-schema-explorer-page',
  standalone: true,
  imports: [
    CommonModule,
    MatSidenavModule,
    MatProgressSpinnerModule,
    SchemaTreeComponent,
    SchemaNodeDetailsComponent,
  ],
  templateUrl: './schema-explorer-page.component.html',
  styleUrl: './schema-explorer-page.component.css',
})
export class SchemaExplorerPageComponent implements OnInit {
  loading = true;
  error: string | null = null;
  summary: SchemaSummary | null = null;
  rootNode: SchemaNode | null = null;
  selectedNode: SchemaNode | null = null;

  constructor(private readonly schemaExplorerService: SchemaExplorerService) {}

  ngOnInit(): void {
    this.schemaExplorerService.getSummary().subscribe({
      next: (summary) => {
        this.summary = summary;
      },
      error: () => {
        this.error = 'Failed to load schema summary.';
        this.loading = false;
      },
    });

    this.schemaExplorerService.getTree().subscribe({
      next: (response) => {
        this.rootNode = response.root;
        this.selectedNode = response.root;
        this.loading = false;
      },
      error: () => {
        this.error = 'Failed to load schema tree.';
        this.loading = false;
      },
    });
  }

  onNodeSelected(node: SchemaNode): void {
    this.selectedNode = node;
  }
}
