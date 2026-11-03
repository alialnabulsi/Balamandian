import oliveBranch from '../assets/illustrations/olive-branch.png';

/** Exact supplied silhouette, tinted with the screen's existing identity color. */
export function OliveBranch({ className = '' }: { className?: string }) {
  return (
    <span
      className={`onb-olive ${className}`}
      aria-hidden="true"
      style={{
        maskImage: `url("${oliveBranch}")`,
        WebkitMaskImage: `url("${oliveBranch}")`,
      }}
    />
  );
}
