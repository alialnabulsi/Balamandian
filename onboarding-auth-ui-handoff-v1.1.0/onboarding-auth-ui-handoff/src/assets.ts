import assistantRobot from './assets/images/campus-assistant-robot.png';
import image0 from './assets/images/onboarding-main-campus.png';
import image1 from './assets/images/onboarding-community-fair.png';
import image2 from './assets/images/onboarding-library-evening.png';
import image3 from './assets/images/uob-logo.png';

const images: Record<string, string> = {
  'campus-assistant-robot.png': assistantRobot,
  'onboarding-main-campus.png': image0,
  'onboarding-community-fair.png': image1,
  'onboarding-library-evening.png': image2,
  'uob-logo.png': image3,
};

export function asset(name: string): string {
  const url = images[name];
  if (!url) throw new Error(`Unknown UI asset: ${name}`);
  return url;
}
