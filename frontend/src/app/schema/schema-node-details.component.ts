import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatListModule } from '@angular/material/list';
import { MatChipsModule } from '@angular/material/chips';

import { SchemaNode } from './schema.models';

@Component({
  selector: 'app-schema-node-details',
  standalone: true,
  imports: [CommonModule, MatCardModule, MatListModule, MatChipsModule],
  templateUrl: './schema-node-details.component.html',
  styleUrl: './schema-node-details.component.css',
})
export class SchemaNodeDetailsComponent {
  @Input() node: SchemaNode | null = null;

  protected readonly highlightedGroups = new Set([
    'taxProcedureGroup',
    'taxFactorGroup',
    'taxCompetenceGroup',
  ]);
}
