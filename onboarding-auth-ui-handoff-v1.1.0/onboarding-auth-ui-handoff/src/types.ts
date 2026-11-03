/** Eight UI screens; this package has no Home route or authentication service. */
export type StartupScreen =
  | 'splash'
  | 'campus'
  | 'community'
  | 'assistant'
  | 'getting-started'
  | 'sign-up'
  | 'sign-in'
  | 'account-setup';

export type Appearance = 'light' | 'dark';

/** Values entered by the user, passed to the host once, never persisted here. */
export interface Credentials {
  identifier: string;
  password: string;
}

/** Display-only values supplied by the consuming application. */
export interface UniversityIdentity {
  name: string;
  major: string;
  faculty: string;
}

export interface ProfileDraft {
  bio: string;
  photo: File | null;
}

export interface OnboardingAuthUIProps {
  screen: StartupScreen;
  onNavigate: (screen: StartupScreen) => void;
  onSignUp: (values: Credentials) => void;
  onSignIn: (values: Credentials) => void;
  onGuest: () => void;
  onSetupSubmit: (values: ProfileDraft) => void;
  identity?: UniversityIdentity;
  appearance?: Appearance;
  /** Supplied by the host; disables form submission and navigation. */
  pending?: boolean;
  /** A host-supplied form error, announced to assistive technology. */
  formError?: string;
  /** UI review only: hold the splash instead of advancing automatically. */
  holdSplash?: boolean;
}
