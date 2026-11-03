import { useEffect, useRef, useState, type ReactNode } from 'react';
import {
  ArrowLeft,
  ArrowRight,
  Camera,
  Check,
  Eye,
  EyeOff,
  GraduationCap,
  Users,
} from '../components/Icons';
import { IconButton } from '../components/IconButton';
import { Crest } from '../components/Brand';
import type { Credentials, ProfileDraft, UniversityIdentity } from '../types';

export type AccessMode = 'signup' | 'signin';

function AccessFrame({
  title,
  description,
  label,
  step,
  busy,
  onBack,
  children,
}: {
  title: string;
  description: string;
  label: string;
  step?: number;
  busy: boolean;
  onBack: () => void;
  children: ReactNode;
}) {
  const heading = useRef<HTMLHeadingElement>(null);
  useEffect(() => {
    heading.current?.focus({ preventScroll: true });
  }, []);
  return (
    <main className="onb-access" aria-labelledby="onb-access-title">
      <svg
        className="onb-access-arcs"
        viewBox="0 0 440 900"
        preserveAspectRatio="none"
        aria-hidden="true"
      >
        <path d="M340-50C240 90 600 200 390 450S210 730 510 940M360-50C260 90 620 200 410 450S230 730 530 940M380-50C280 90 640 200 430 450S250 730 550 940" />
      </svg>
      <header className="onb-access-header">
        <IconButton icon={ArrowLeft} label="Back" onClick={onBack} disabled={busy} />
        <span>{label}</span>
        <span className="onb-access-header-space" />
      </header>
      {step && (
        <div className="onb-setup-progress" aria-label={`Account setup: step ${step} of 2`}>
          <i className="complete" />
          <i className={step === 2 ? 'complete' : ''} />
        </div>
      )}
      <div className="onb-access-heading">
        <Crest />
        <p className="onb-university-label">UNIVERSITY OF BALAMAND</p>
        <h1 ref={heading} tabIndex={-1} id="onb-access-title">
          {title}
        </h1>
        <p>{description}</p>
      </div>
      {children}
    </main>
  );
}

export function AccessForm({
  mode,
  busy,
  onBack,
  onSwitch,
  onSubmit,
  formError,
}: {
  mode: AccessMode;
  busy: boolean;
  onBack: () => void;
  onSwitch: (mode: AccessMode) => void;
  onSubmit: (values: Credentials) => void;
  formError?: string;
}) {
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [visible, setVisible] = useState(false);
  const [errors, setErrors] = useState<{ identifier?: string; password?: string }>({});
  const idInput = useRef<HTMLInputElement>(null);
  const passwordInput = useRef<HTMLInputElement>(null);
  const signingUp = mode === 'signup';
  const identifierLabel = signingUp ? 'SIS ID' : 'Email or SIS ID';
  const clearAndGo = (action: () => void) => {
    setPassword('');
    setVisible(false);
    action();
  };

  return (
    <AccessFrame
      title={signingUp ? 'Create your account' : 'Welcome back'}
      description={
        signingUp
          ? 'Start with your university account. Make the experience yours next.'
          : 'Your campus is right where you left it.'
      }
      label={signingUp ? 'First-time setup' : 'Log in'}
      step={signingUp ? 1 : undefined}
      busy={busy}
      onBack={() => clearAndGo(onBack)}
    >
      <form
        className="onb-access-form"
        noValidate
        autoComplete="off"
        onSubmit={(event) => {
          event.preventDefault();
          if (busy) return;
          const next: typeof errors = {};
          if (!identifier.trim())
            next.identifier = `Enter your ${signingUp ? 'SIS ID' : 'email or SIS ID'}.`;
          if (!password) next.password = 'Enter your password.';
          setErrors(next);
          if (next.identifier || next.password) {
            (next.identifier ? idInput : passwordInput).current?.focus();
            return;
          }
          const values = { identifier: identifier.trim(), password };
          clearAndGo(() => onSubmit(values));
        }}
      >
        {formError && (
          <p className="onb-form-message" role="alert">
            {formError}
          </p>
        )}
        <div className={`onb-field ${errors.identifier ? 'has-error' : ''}`}>
          <label htmlFor="onb-sis-id">{identifierLabel}</label>
          <input
            ref={idInput}
            id="onb-sis-id"
            value={identifier}
            onChange={(event) => {
              setIdentifier(event.target.value);
              setErrors((current) => ({ ...current, identifier: undefined }));
            }}
            placeholder={signingUp ? 'Enter your SIS ID' : 'Enter your email or SIS ID'}
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            autoComplete="off"
            aria-invalid={!!errors.identifier}
            aria-describedby={errors.identifier ? 'onb-sis-error' : undefined}
            disabled={busy}
          />
          {errors.identifier && (
            <p className="onb-field-error" id="onb-sis-error" role="alert">
              {errors.identifier}
            </p>
          )}
        </div>
        <div className={`onb-field ${errors.password ? 'has-error' : ''}`}>
          <label htmlFor="onb-password">Password</label>
          <div className="onb-password-field">
            <input
              ref={passwordInput}
              id="onb-password"
              type={visible ? 'text' : 'password'}
              value={password}
              onChange={(event) => {
                setPassword(event.target.value);
                setErrors((current) => ({ ...current, password: undefined }));
              }}
              placeholder="Enter your password"
              autoComplete="off"
              aria-invalid={!!errors.password}
              aria-describedby={errors.password ? 'onb-password-error' : undefined}
              disabled={busy}
            />
            <IconButton
              icon={visible ? EyeOff : Eye}
              label={visible ? 'Hide password' : 'Show password'}
              aria-pressed={visible}
              disabled={busy}
              onClick={() => setVisible((current) => !current)}
            />
          </div>
          {errors.password && (
            <p className="onb-field-error" id="onb-password-error" role="alert">
              {errors.password}
            </p>
          )}
        </div>
        <button className="onb-primary onb-auth-submit" type="submit" disabled={busy}>
          {busy ? 'Please wait…' : signingUp ? 'Continue' : 'Log in'}
          <ArrowRight size={22} />
        </button>
        <div className="onb-access-switch">
          {signingUp ? 'Already have an account?' : 'New to Balamandian?'}{' '}
          <button
            type="button"
            disabled={busy}
            onClick={() => clearAndGo(() => onSwitch(signingUp ? 'signin' : 'signup'))}
          >
            {signingUp ? 'Log in' : 'Sign up'}
          </button>
        </div>
      </form>
    </AccessFrame>
  );
}

export function AccountSetup({
  busy,
  onBack,
  onSubmit,
  identity,
  formError,
}: {
  busy: boolean;
  onBack: () => void;
  onSubmit: (values: ProfileDraft) => void;
  identity?: UniversityIdentity;
  formError?: string;
}) {
  const [bio, setBio] = useState('');
  const [photo, setPhoto] = useState('');
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoError, setPhotoError] = useState('');
  const fileInput = useRef<HTMLInputElement>(null);
  const reader = useRef<FileReader | null>(null);
  const [readingPhoto, setReadingPhoto] = useState(false);
  const selection = useRef(0);
  useEffect(
    () => () => {
      selection.current += 1;
      reader.current?.abort();
    },
    [],
  );
  const initials =
    identity?.name
      .trim()
      .split(/\s+/)
      .map((part) => part[0])
      .slice(0, 2)
      .join('') ?? '';

  return (
    <AccessFrame
      title="A little about you"
      description="Add your photo and bio. Your university details will come from SIS."
      label="First-time setup"
      step={2}
      busy={busy}
      onBack={onBack}
    >
      <form
        className="onb-access-form onb-profile-setup"
        onSubmit={(event) => {
          event.preventDefault();
          if (busy || readingPhoto) return;
          onSubmit({ bio: bio.trim(), photo: photoFile });
        }}
      >
        {formError && (
          <p className="onb-form-message" role="alert">
            {formError}
          </p>
        )}
        <div className="onb-photo-setup">
          <button
            className="onb-setup-avatar"
            type="button"
            aria-label={photo ? 'Change profile photo' : 'Add profile photo'}
            disabled={busy || readingPhoto}
            onClick={() => fileInput.current?.click()}
          >
            {photo ? (
              <img src={photo} alt="Your selected profile photo" />
            ) : (
              <span>{initials || <Users size={32} />}</span>
            )}
            <i>
              <Camera size={16} />
            </i>
          </button>
          <div>
            <strong>Your campus face</strong>
            <div className="onb-photo-actions">
              <button
                className="onb-text-action"
                type="button"
                disabled={busy || readingPhoto}
                onClick={() => fileInput.current?.click()}
              >
                {readingPhoto ? 'Reading photo…' : photo ? 'Change photo' : 'Add a photo'}
              </button>
              {photo && (
                <button
                  className="onb-text-action"
                  type="button"
                  disabled={busy || readingPhoto}
                  onClick={() => {
                    setPhoto('');
                    setPhotoFile(null);
                    setPhotoError('');
                  }}
                >
                  Remove photo
                </button>
              )}
            </div>
            <small>Optional · JPG, PNG or WebP · Up to 1 MB</small>
          </div>
          <input
            type="file"
            ref={fileInput}
            accept="image/jpeg,image/png,image/webp"
            hidden
            aria-label="Profile photo"
            onChange={(event) => {
              const file = event.target.files?.[0];
              event.target.value = '';
              if (!file) return;
              if (
                !['image/jpeg', 'image/png', 'image/webp'].includes(file.type) ||
                file.size > 1_000_000
              ) {
                setPhotoError('Choose a JPG, PNG or WebP smaller than 1 MB.');
                return;
              }
              setPhotoError('');
              setReadingPhoto(true);
              const selected = ++selection.current;
              const nextReader = new FileReader();
              reader.current = nextReader;
              nextReader.onload = () => {
                const preview = new Image();
                preview.onload = () => {
                  if (selected !== selection.current) return;
                  setPhotoFile(file);
                  setPhoto(String(nextReader.result));
                  setReadingPhoto(false);
                };
                preview.onerror = () => {
                  if (selected !== selection.current) return;
                  setPhotoError('This image could not be opened. Please choose another.');
                  setReadingPhoto(false);
                };
                preview.src = String(nextReader.result);
              };
              nextReader.onerror = () => {
                if (selected !== selection.current) return;
                setPhotoError('This photo could not be read. Please choose another.');
                setReadingPhoto(false);
              };
              nextReader.readAsDataURL(file);
            }}
          />
        </div>
        {photoError && (
          <p className="onb-field-error" role="alert">
            {photoError}
          </p>
        )}
        <div className="onb-field">
          <label htmlFor="onb-bio">
            Bio <span className="onb-optional">Optional</span>
          </label>
          <textarea
            id="onb-bio"
            value={bio}
            maxLength={240}
            rows={3}
            placeholder="Your interests, your clubs, a little about you…"
            disabled={busy}
            aria-describedby="onb-bio-count"
            onChange={(event) => setBio(event.target.value)}
          />
          <span className="onb-bio-count" id="onb-bio-count">
            {bio.length} / 240
          </span>
        </div>
        <section className="onb-sis-summary" aria-label="Read-only SIS details">
          <div className="onb-sis-heading">
            <GraduationCap size={22} />
            <span>
              <strong>University details</strong>
              <small>From SIS · Read-only</small>
            </span>
          </div>
          <dl>
            <div>
              <dt>Name</dt>
              <dd>{identity?.name || 'Provided by SIS'}</dd>
            </div>
            <div>
              <dt>Major</dt>
              <dd>{identity?.major || 'Provided by SIS'}</dd>
            </div>
            <div>
              <dt>Faculty</dt>
              <dd>{identity?.faculty || 'Provided by SIS'}</dd>
            </div>
          </dl>
        </section>
        <button className="onb-primary" type="submit" disabled={busy || readingPhoto}>
          {busy ? 'Please wait…' : 'Finish setup'}
          <Check size={22} />
        </button>
      </form>
    </AccessFrame>
  );
}
