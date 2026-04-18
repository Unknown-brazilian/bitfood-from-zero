import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './lib/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: '#EA1D2C',
        'primary-dark': '#C41020',
        'primary-light': '#FF4D5A',
        ifood: {
          red: '#EA1D2C',
          orange: '#FF6900',
          bg: '#F7F7F7',
          dark: '#3E3E3E',
          green: '#50A773',
        },
      },
    },
  },
  plugins: [],
};

export default config;
