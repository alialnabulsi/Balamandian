import { useCallback, useEffect, useRef, useState, type PointerEvent } from 'react';
import gsap from 'gsap';
import { ArrowLeft, ArrowRight, Calculator, CalendarDays, NotebookPen } from './components/Icons';
import { IconButton } from './components/IconButton';
import { Brand, Coin, Crest } from './components/Brand';
import { OliveBranch } from './components/OliveBranch';
import { AccessForm, AccountSetup } from './screens/Access';
import { asset } from './assets';
import type { OnboardingAuthUIProps, StartupScreen } from './types';

type Phase = 'splash' | 'tour' | 'welcome' | 'signup' | 'signin' | 'setup';
const tourScreens: StartupScreen[] = ['campus', 'community', 'assistant'];
const phaseScreens: Record<Exclude<Phase, 'tour'>, StartupScreen> = {
  splash: 'splash',
  welcome: 'getting-started',
  signup: 'sign-up',
  signin: 'sign-in',
  setup: 'account-setup',
};
function getScene(screen: StartupScreen): { phase: Phase; index: number } {
  const index = tourScreens.indexOf(screen);
  if (index >= 0) return { phase: 'tour', index };
  const phase = (Object.entries(phaseScreens).find(([, value]) => value === screen)?.[0] ??
    'splash') as Phase;
  return { phase, index: 0 };
}

const slides = [
  {
    title: ['Find your way.', 'Feel at home.'],
    description: 'Explore campus, discover buildings, and get to know your next stop.',
    name: 'Find your way',
    color: '#0e569e',
  },
  {
    title: ['Your people.', 'Your campus.'],
    description: 'Find your community, join a club, and share the moments in between.',
    name: 'Find your people',
    color: '#ffcf36',
  },
  {
    title: ['Your Campus', 'Assistant'],
    description:
      'Access smart campus tools, navigation, and your assistant. A little help for every day.',
    name: 'Tools and campus assistant',
    color: '#63a042',
  },
];

function useReducedMotion() {
  const [reduced, setReduced] = useState(
    () => window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  );
  useEffect(() => {
    const query = window.matchMedia('(prefers-reduced-motion: reduce)');
    const update = () => setReduced(query.matches);
    query.addEventListener('change', update);
    return () => query.removeEventListener('change', update);
  }, []);
  return reduced;
}

function SunRays({ className = '' }: { className?: string }) {
  return (
    <svg
      className={`onb-rays ${className}`}
      viewBox="0 0 440 480"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M398 430 5 250 24 193Z" />
      <path d="M398 430 36 149 80 99Z" />
      <path d="M398 430 118 62 176 29Z" />
      <path d="M398 430 220 11 279 0Z" />
      <path d="M398 430 324 0 382 11Z" />
      <path d="M398 430 422 30 460 63Z" />
    </svg>
  );
}

function CampusArtwork() {
  return (
    <div className="onb-art onb-campus-art">
      <div className="onb-art-sun" />
      <SunRays />
      <div className="onb-campus-photo">
        <img
          src={asset('onboarding-main-campus.png')}
          alt="The main University of Balamand campus, with its fountain and central walkway"
        />
      </div>
      <OliveBranch />
    </div>
  );
}

function CommunityArtwork() {
  return (
    <div className="onb-art onb-community-art">
      <div className="onb-art-sun" />
      <div className="onb-community-photo">
        <img
          src={asset('onboarding-community-fair.png')}
          alt="Students gathering at the University of Balamand club fair"
        />
      </div>
      <OliveBranch />
      <span className="onb-community-spark" aria-hidden="true">
        <i />
        <i />
        <i />
      </span>
    </div>
  );
}

function ToolsArtwork() {
  return (
    <div className="onb-art onb-tools-art" aria-hidden="true">
      <div className="onb-tools-orbit" />
      <SunRays />
      <div className="onb-assistant-composition">
        <div className="onb-assistant-preview">
          <div className="onb-assistant-heading">
            <div>
              <strong>Campus Assistant</strong>
              <small>Your campus companion</small>
            </div>
          </div>
          <div className="onb-assistant-question">Explore campus services</div>
          <div className="onb-assistant-answer">
            <Crest decorative />
            <p>Find your next stop, explore campus services, or get ready for class.</p>
          </div>
          <div className="onb-assistant-prompt">
            <span>Ask your campus assistant</span>
            <ArrowRight size={18} />
          </div>
        </div>
        <img
          className="onb-assistant-mascot"
          src={asset('campus-assistant-robot.png')}
          alt=""
          draggable={false}
        />
      </div>
      <div className="onb-tool-shortcuts">
        {[
          { icon: CalendarDays, label: 'Schedule' },
          { icon: NotebookPen, label: 'Notes' },
          { icon: Calculator, label: 'GPA' },
        ].map(({ icon: Icon, label }) => (
          <div key={label}>
            <span>
              <Icon size={24} />
            </span>
            <strong>{label}</strong>
          </div>
        ))}
      </div>
      <OliveBranch />
    </div>
  );
}

export function OnboardingAuthUI({
  screen,
  onNavigate,
  onSignUp,
  onSignIn,
  onGuest,
  onSetupSubmit,
  identity,
  appearance = 'light',
  pending = false,
  formError,
  holdSplash = false,
}: OnboardingAuthUIProps) {
  const { phase, index } = getScene(screen);
  const [transitioning, setBusy] = useState(false);
  const busy = transitioning || pending;
  const lastTour = useRef(0);
  useEffect(() => {
    if (phase === 'tour') lastTour.current = index;
  }, [phase, index]);
  const reduced = useReducedMotion();
  const wipe = useRef<HTMLDivElement>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  const timeline = useRef<gsap.core.Timeline | null>(null);
  const moving = useRef(false);
  const touchStart = useRef<{ x: number; y: number } | null>(null);

  useEffect(() => {
    // Load the next scene's real assets while the short splash is visible.
    [
      'onboarding-main-campus.png',
      'onboarding-community-fair.png',
      'onboarding-library-evening.png',
      'campus-assistant-robot.png',
    ].forEach((name) => {
      const image = new Image();
      image.src = asset(name);
    });
  }, []);

  const moveTo = useCallback(
    (nextPhase: Phase, nextIndex = index) => {
      if (pending || moving.current || (nextPhase === phase && nextIndex === index)) return;
      const change = () => {
        onNavigate(nextPhase === 'tour' ? tourScreens[nextIndex] : phaseScreens[nextPhase]);
      };
      if (reduced || !wipe.current) {
        change();
        return;
      }
      moving.current = true;
      setBusy(true);
      wipe.current.style.color = nextPhase === 'tour' ? slides[nextIndex].color : '#0e569e';
      const overlay = wipe.current;
      gsap.set(overlay, { yPercent: 0, visibility: 'visible' });
      timeline.current = gsap
        .timeline({
          onComplete: () => {
            gsap.set(overlay, { visibility: 'hidden', yPercent: 0 });
            moving.current = false;
            setBusy(false);
            timeline.current = null;
          },
        })
        .to(overlay, { yPercent: -80, duration: 0.36, ease: 'power2.inOut' })
        .call(change)
        .to(overlay, { yPercent: -170, duration: 0.46, ease: 'power2.inOut' }, '+=0.02');
    },
    [index, phase, reduced, pending, onNavigate],
  );

  useEffect(() => {
    if (phase !== 'splash' || holdSplash) return;
    const timer = window.setTimeout(() => moveTo('tour', 0), reduced ? 250 : 2350);
    return () => window.clearTimeout(timer);
  }, [phase, reduced, moveTo, holdSplash]);

  useEffect(() => {
    if (reduced) timeline.current?.progress(1);
  }, [reduced]);
  useEffect(
    () => () => {
      timeline.current?.kill();
    },
    [],
  );
  useEffect(() => {
    if (phase !== 'splash') heading.current?.focus({ preventScroll: true });
    window.scrollTo(0, 0);
  }, [phase, index]);

  const next = () => (index === slides.length - 1 ? moveTo('welcome') : moveTo('tour', index + 1));
  const previous = () => {
    if (index > 0) moveTo('tour', index - 1);
  };
  const startTouch = (event: PointerEvent) => {
    if (event.pointerType === 'touch' || event.pointerType === 'pen')
      touchStart.current = { x: event.clientX, y: event.clientY };
  };
  const endTouch = (event: PointerEvent) => {
    const start = touchStart.current;
    touchStart.current = null;
    if (!start || phase !== 'tour') return;
    const x = event.clientX - start.x;
    const y = event.clientY - start.y;
    if (Math.abs(x) >= 55 && Math.abs(x) > Math.abs(y) * 1.4) {
      if (x < 0) next();
      else previous();
    }
  };

  return (
    <div
      className={`onboarding onb-phase-${phase}`}
      data-theme={appearance}
      data-screen={screen}
      data-testid="onboarding"
      aria-busy={busy}
      onKeyDown={(event) => {
        if (phase !== 'tour' || event.altKey || event.ctrlKey || event.metaKey) return;
        if (event.key === 'ArrowRight') {
          event.preventDefault();
          next();
        }
        if (event.key === 'ArrowLeft') {
          event.preventDefault();
          previous();
        }
      }}
    >
      {phase === 'splash' ? (
        <main className="onb-splash" aria-label="Balamandian welcome">
          <SunRays />
          <div className="onb-splash-center">
            <Coin />
            <h1>Balamandian</h1>
            <p>Your campus, connected.</p>
          </div>
          <div className="onb-splash-signature">
            <OliveBranch />
            <p>Rooted in Balamand. Made for you.</p>
            <span className="onb-splash-progress" aria-hidden="true">
              <i />
            </span>
          </div>
        </main>
      ) : phase === 'tour' ? (
        <main
          className="onb-tour"
          aria-label="Welcome tour"
          onPointerDown={startTouch}
          onPointerUp={endTouch}
          onPointerCancel={() => {
            touchStart.current = null;
          }}
        >
          {index === 0 && (
            <div className="onb-campus-decoration" aria-hidden="true">
              <SunRays className="onb-ambient-rays" />
              <OliveBranch className="onb-ambient-olive-top" />
              <OliveBranch className="onb-ambient-olive-bottom" />
            </div>
          )}
          <header className="onb-header">
            <Brand />
            <button className="onb-skip" onClick={() => moveTo('welcome')} disabled={busy}>
              Skip
            </button>
          </header>
          <section
            key={index}
            className={`onb-scene onb-slide-${index}`}
            aria-labelledby="onb-title"
          >
            {index === 0 ? (
              <CampusArtwork />
            ) : index === 1 ? (
              <CommunityArtwork />
            ) : (
              <ToolsArtwork />
            )}
            <div className="onb-copy">
              <h1 id="onb-title" className="onb-title" ref={heading} tabIndex={-1}>
                {slides[index].title.map((line) => (
                  <span key={line}>{line}</span>
                ))}
              </h1>
              <p className="onb-description">{slides[index].description}</p>
            </div>
          </section>
          <footer className="onb-footer">
            <div className="onb-progress-row">
              <nav className="onb-progress" aria-label="Onboarding progress">
                {slides.map((slide, i) => (
                  <button
                    key={slide.name}
                    aria-label={`Go to step ${i + 1}: ${slide.name}`}
                    aria-current={index === i ? 'step' : undefined}
                    disabled={busy}
                    onClick={() => moveTo('tour', i)}
                  >
                    <span />
                  </button>
                ))}
              </nav>
            </div>
            <button className={`onb-primary onb-continue-${index}`} onClick={next} disabled={busy}>
              {index === slides.length - 1 ? 'Get started' : 'Continue'}
              <ArrowRight size={23} />
            </button>
          </footer>
          <span className="sr-only" role="status">
            Step {index + 1} of {slides.length}: {slides[index].name}
          </span>
        </main>
      ) : phase === 'welcome' ? (
        <main className="onb-welcome" aria-labelledby="onb-welcome-title">
          <img src={asset('onboarding-library-evening.png')} className="onb-welcome-photo" alt="" />
          <div className="onb-welcome-fade" />
          <header className="onb-header">
            <IconButton
              icon={ArrowLeft}
              label="Back to welcome tour"
              className="onb-welcome-back"
              onClick={() => moveTo('tour', lastTour.current)}
              disabled={busy}
            />
          </header>
          <div className="onb-welcome-brand">
            <Coin />
            <p className="onb-university-label">UNIVERSITY OF BALAMAND</p>
            <h1 ref={heading} tabIndex={-1} id="onb-welcome-title">
              Balamandian
            </h1>
            <p>
              Your campus. Your people.
              <br />
              Your place.
            </p>
          </div>
          <OliveBranch className="onb-welcome-olive" />
          <section className="onb-welcome-actions" aria-label="Get started">
            <button
              className="onb-primary onb-entry-login"
              onClick={() => moveTo('signin')}
              disabled={busy}
            >
              Log in with SIS
            </button>
            <p className="onb-entry-signup">
              <span>New here?</span>
              <button type="button" onClick={() => moveTo('signup')} disabled={busy}>
                Sign up with SIS
              </button>
            </p>
            <button className="onb-guest" onClick={onGuest} disabled={busy}>
              Continue as guest <ArrowRight size={20} />
            </button>
          </section>
        </main>
      ) : phase === 'setup' ? (
        <AccountSetup
          busy={busy}
          onBack={() => moveTo('signup')}
          identity={identity}
          formError={formError}
          onSubmit={onSetupSubmit}
        />
      ) : (
        <AccessForm
          key={phase}
          mode={phase}
          busy={busy}
          onBack={() => moveTo('welcome')}
          onSwitch={moveTo}
          formError={formError}
          onSubmit={phase === 'signup' ? onSignUp : onSignIn}
        />
      )}
      <div className="onb-wipe" ref={wipe} aria-hidden="true">
        <svg viewBox="0 0 440 1200" preserveAspectRatio="none">
          <path
            d="M0 125C110-5 280 235 440 85V1100C300 1215 130 1020 0 1140Z"
            fill="currentColor"
          />
        </svg>
      </div>
    </div>
  );
}
