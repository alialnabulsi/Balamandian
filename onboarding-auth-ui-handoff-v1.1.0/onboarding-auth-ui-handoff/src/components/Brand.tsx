import { asset } from '../assets';

export function Crest({
  className = '',
  decorative = false,
}: {
  className?: string;
  decorative?: boolean;
}) {
  return (
    <span className={`onb-crest ${className}`}>
      <img
        src={asset('uob-logo.png')}
        alt={decorative ? '' : 'University of Balamand crest'}
        draggable={false}
      />
    </span>
  );
}

export function Brand() {
  return (
    <div className="onb-brand">
      <Crest />
      <span>Balamandian</span>
    </div>
  );
}

export function Coin({ className = '' }: { className?: string }) {
  return (
    <div
      className={`onb-coin ${className}`}
      data-testid="coin-logo"
      role="img"
      aria-label="University of Balamand crest"
    >
      <span className="onb-coin-face onb-coin-front">
        <Crest decorative />
      </span>
      <span className="onb-coin-face onb-coin-back">
        <Crest decorative />
      </span>
    </div>
  );
}
