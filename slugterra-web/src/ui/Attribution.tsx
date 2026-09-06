/**
 * Model credits.
 *
 * Every model in the build is CC Attribution, and attribution is the one thing
 * that licence actually requires. This is not decoration — shipping the meshes
 * without it would breach the terms we are relying on.
 *
 * Rendered as plain DOM over the canvas (TDD v2.0 §3: the HUD is React DOM, not
 * in-Canvas), so it costs nothing in draw calls.
 */

import { useState } from 'react';
import { credits } from '../assets/manifest';
import './attribution.css';

export function Attribution() {
  const [open, setOpen] = useState(false);
  const entries = credits();

  if (entries.length === 0) return null;

  return (
    <div className="attribution">
      <button
        type="button"
        className="attribution-toggle"
        onClick={() => setOpen((value) => !value)}
        aria-expanded={open}
      >
        Model credits ({entries.length})
      </button>

      {open && (
        <ul className="attribution-list">
          {entries.map((entry) => (
            <li key={entry.name}>
              <span className="attribution-name">{entry.name}</span>
              <span className="attribution-by">
                {' by '}
                <a href={entry.authorUrl} target="_blank" rel="noreferrer noopener">
                  {entry.author}
                </a>
                {' — CC Attribution, via '}
                <a
                  href="https://sketchfab.com/tags/slugterra"
                  target="_blank"
                  rel="noreferrer noopener"
                >
                  Sketchfab
                </a>
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
