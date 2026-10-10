import { readFile } from 'node:fs/promises';
import { navigationProjectV5Schema } from '@johnbenz13/fplnav-spec';

const fixtureURL = new URL(
  '../NavigationFlightTests/Fixtures/FPLNav/V5/representative.fplnav',
  import.meta.url,
);
const packageFixtureURL = new URL(
  '../node_modules/@johnbenz13/fplnav-spec/examples/v5/representative.fplnav',
  import.meta.url,
);
const fixtureText = await readFile(fixtureURL, 'utf8');
const packageFixtureText = await readFile(packageFixtureURL, 'utf8');
if (fixtureText !== packageFixtureText) {
  throw new Error('Staged fixture differs from the pinned package example.');
}

const fixture = JSON.parse(fixtureText);
const parsed = navigationProjectV5Schema.parse(fixture);

if (parsed.formatVersion !== 5) {
  throw new Error(`Expected formatVersion 5, received ${parsed.formatVersion}`);
}

console.log('Verified official fplnav-spec 0.1.1 v5 representative fixture.');
