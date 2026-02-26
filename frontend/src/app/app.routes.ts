import { Routes } from '@angular/router';
import { SchemaExplorerPageComponent } from './schema/schema-explorer-page.component';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'schema' },
  { path: 'schema', component: SchemaExplorerPageComponent },
];
