import { readFile } from 'node:fs/promises';
import { navigationProjectV5Schema } from '@johnbenz13/fplnav-spec';
import { navigationProjectV7Schema } from '@johnbenz13/fplnav-spec/schema/navigation-project-v7';

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

const v7FixtureURL = new URL(
  '../NavigationFlightTests/Fixtures/FPLNav/V7/Official/representative-v7.fplnav',
  import.meta.url,
);
const packageV7FixtureURL = new URL(
  '../node_modules/@johnbenz13/fplnav-spec/examples/v7/representative.fplnav',
  import.meta.url,
);
const v7Fixture = await readFile(v7FixtureURL, 'utf8');
const packageV7Fixture = await readFile(packageV7FixtureURL, 'utf8');
if (v7Fixture !== packageV7Fixture) {
  throw new Error('Staged V7 fixture differs from the pinned package example.');
}
navigationProjectV7Schema.parse(JSON.parse(v7Fixture));

for (const name of ['editor-wind', 'editor-no-wind', 'editor-calm']) {
  const editorFixture = await readFile(
    new URL(`../NavigationFlightTests/Fixtures/FPLNav/V7/Editor/${name}.fplnav`, import.meta.url),
    'utf8',
  );
  navigationProjectV7Schema.parse(JSON.parse(editorFixture));
}

console.log('Verified fplnav-spec 0.2.0 official V5/V7 vectors and Editor V7 vectors.');
