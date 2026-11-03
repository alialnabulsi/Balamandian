import { StrictMode, useCallback, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { OnboardingAuthUI, type Appearance, type StartupScreen } from '../src';
import './preview.css';

const screens: StartupScreen[] = [
  'splash',
  'campus',
  'community',
  'assistant',
  'getting-started',
  'sign-up',
  'sign-in',
  'account-setup',
];
const query = new URLSearchParams(window.location.search);
const requested = query.get('screen') as StartupScreen;
const canvas = query.has('canvas');

function Preview() {
  const [screen, setScreen] = useState<StartupScreen>(
    screens.includes(requested) ? requested : 'splash',
  );
  const [appearance, setAppearance] = useState<Appearance>(
    query.get('theme') === 'dark' ? 'dark' : 'light',
  );
  const [pending, setPending] = useState(query.has('pending'));
  const [status, setStatus] = useState('');
  const navigate = useCallback((next: StartupScreen) => {
    setStatus('');
    setScreen(next);
  }, []);

  return (
    <>
      {!canvas && (
        <header className="review-controls" aria-label="UI review controls">
          <strong>Balamandian · UI handoff</strong>
          <label>
            Screen
            <select
              value={screen}
              onChange={(event) => navigate(event.target.value as StartupScreen)}
            >
              {screens.map((item) => (
                <option key={item}>{item}</option>
              ))}
            </select>
          </label>
          <label>
            Appearance
            <select
              value={appearance}
              onChange={(event) => setAppearance(event.target.value as Appearance)}
            >
              <option>light</option>
              <option>dark</option>
            </select>
          </label>
          <label>
            <input
              type="checkbox"
              checked={pending}
              onChange={(event) => setPending(event.target.checked)}
            />{' '}
            Pending
          </label>
          <p>
            UI only. Submissions emit events; no account is verified or saved. Choose account-setup
            to review that screen.
          </p>
          {status && <p role="status">{status}</p>}
        </header>
      )}
      <OnboardingAuthUI
        screen={screen}
        onNavigate={navigate}
        appearance={appearance}
        pending={pending}
        holdSplash={query.has('hold')}
        formError={
          query.has('error') ? 'This action could not be completed. Please try again.' : undefined
        }
        onSignIn={() => setStatus('Sign-in UI submitted. No service is connected.')}
        onSignUp={() => setStatus('Sign-up UI submitted. No service is connected.')}
        onGuest={() => setStatus('Guest entry requested. The main app is outside this handoff.')}
        onSetupSubmit={() => setStatus('Profile UI submitted. No data was saved.')}
      />
    </>
  );
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Preview />
  </StrictMode>,
);
