import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { App } from './App';
import './styles/global.css';

/**
 * Entry point.
 *
 * `env` is imported for its side effect: it validates configuration at module
 * load, so a bad `.env` fails here with a readable message rather than surfacing
 * as `NaN` inside a polling interval later.
 */
import '@/config/env';

const container = document.getElementById('root');

if (container === null) {
  throw new Error('Root container #root was not found in index.html');
}

createRoot(container).render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>,
);
