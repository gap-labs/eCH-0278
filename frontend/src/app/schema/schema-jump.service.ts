import { Injectable } from '@angular/core';
import { Subject } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class SchemaJumpService {
  private pendingPath: string | null = null;
  private jumpInFlight = false;
  private readonly jumpRequestedSubject = new Subject<string>();

  readonly jumpRequested$ = this.jumpRequestedSubject.asObservable();

  requestJump(path: string): boolean {
    if (this.jumpInFlight) {
      return false;
    }

    this.pendingPath = path;
    this.jumpInFlight = true;
    this.jumpRequestedSubject.next(path);
    return true;
  }

  consumePendingPath(): string | null {
    return this.pendingPath;
  }

  completeJump(path: string): void {
    if (this.pendingPath !== path) {
      return;
    }

    this.pendingPath = null;
    this.jumpInFlight = false;
  }

  isJumpInFlight(path: string): boolean {
    return this.jumpInFlight && this.pendingPath === path;
  }
}