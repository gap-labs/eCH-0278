import { Routes } from '@angular/router';
import { WorkspacePageComponent } from './workspace/workspace-page.component';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'workspace/schema' },
  { path: 'workspace', pathMatch: 'full', redirectTo: 'workspace/schema' },
  { path: 'workspace/:tab', component: WorkspacePageComponent },
  { path: 'schema', pathMatch: 'full', redirectTo: 'workspace/schema' },
  { path: 'validate', pathMatch: 'full', redirectTo: 'workspace/validate' },
  { path: 'compare', pathMatch: 'full', redirectTo: 'workspace/compare' },
];
