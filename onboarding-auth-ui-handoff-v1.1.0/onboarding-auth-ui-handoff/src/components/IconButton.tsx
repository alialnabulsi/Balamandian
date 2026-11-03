import type { ButtonHTMLAttributes, ComponentType } from 'react';
import type { IconProps } from './Icons';

interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  icon: ComponentType<IconProps>;
  label: string;
}

export function IconButton({ icon: Icon, label, className = '', ...props }: IconButtonProps) {
  return (
    <button
      type="button"
      className={`icon-button ${className}`}
      aria-label={label}
      title={label}
      {...props}
    >
      <Icon size={21} />
    </button>
  );
}
