import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { getSkillsToPreload, readSkillFile } from '../../skillLoader';
import type { LearnerContext } from '../../profileReader';

/**
 * Fixture: build a fake curriculum tree under MSSA_MENTOR_HOME so the
 * loader has real files to find.
 */
function seedCurriculum(home: string, methods: string[], tracks: string[]) {
  const root = path.join(home, 'curriculum', '.github', 'skills');
  fs.mkdirSync(path.join(root, 'learner-profile'), { recursive: true });
  fs.writeFileSync(
    path.join(root, 'learner-profile', 'SKILL.md'),
    '# Learner Profile',
    'utf8'
  );
  for (const m of methods) {
    fs.mkdirSync(path.join(root, 'methods', m), { recursive: true });
    fs.writeFileSync(path.join(root, 'methods', m, 'SKILL.md'), `# ${m}`, 'utf8');
  }
  for (const t of tracks) {
    fs.mkdirSync(path.join(root, 'tracks', t), { recursive: true });
    fs.writeFileSync(path.join(root, 'tracks', t, 'README.md'), `# ${t}`, 'utf8');
  }
}

const ctx = (overrides: Partial<LearnerContext> = {}): LearnerContext => ({
  username: 'alex',
  lastUsedMethod: 'ride-along',
  activeProjectCount: 0,
  profilePath: '/fake/profile.json',
  ...overrides
});

suite('skillLoader.ts', () => {
  let tmp: string;
  let savedHome: string | undefined;

  setup(() => {
    savedHome = process.env.MSSA_MENTOR_HOME;
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mssa-skill-'));
    process.env.MSSA_MENTOR_HOME = tmp;
  });

  teardown(() => {
    if (savedHome === undefined) {
      delete process.env.MSSA_MENTOR_HOME;
    } else {
      process.env.MSSA_MENTOR_HOME = savedHome;
    }
    try { fs.rmSync(tmp, { recursive: true, force: true }); } catch { /* ignore */ }
  });

  test('always loads learner-profile + last-used method', () => {
    seedCurriculum(tmp, ['ride-along'], []);
    const skills = getSkillsToPreload(ctx({ lastUsedMethod: 'ride-along' }));
    assert.ok(skills.some(s => s.relPath.endsWith('learner-profile/SKILL.md')));
    assert.ok(skills.some(s => s.relPath.endsWith('methods/ride-along/SKILL.md')));
  });

  test('falls back to ride-along when last-used method is missing on disk', () => {
    seedCurriculum(tmp, ['ride-along'], []);
    const skills = getSkillsToPreload(ctx({ lastUsedMethod: 'tdd' }));
    assert.strictEqual(
      skills.some(s => s.relPath.endsWith('methods/tdd/SKILL.md')),
      false
    );
    assert.ok(skills.some(s => s.relPath.endsWith('methods/ride-along/SKILL.md')));
  });

  test('loads active track README when present', () => {
    seedCurriculum(tmp, ['ride-along'], ['cloud-app-dev']);
    const skills = getSkillsToPreload(
      ctx({ activeTrack: 'cloud-app-dev' })
    );
    assert.ok(
      skills.some(s => s.relPath.endsWith('tracks/cloud-app-dev/README.md'))
    );
  });

  test('skips track silently when README not present', () => {
    seedCurriculum(tmp, ['ride-along'], []);
    const skills = getSkillsToPreload(
      ctx({ activeTrack: 'cybersecurity-ops' })
    );
    assert.strictEqual(skills.some(s => s.type === 'track'), false);
  });

  test('readSkillFile returns content when file exists', () => {
    seedCurriculum(tmp, ['ride-along'], []);
    const skills = getSkillsToPreload(ctx());
    const content = readSkillFile(skills[0].path);
    assert.ok(content);
    assert.match(content!, /Learner Profile/);
  });

  test('readSkillFile returns null on missing file', () => {
    assert.strictEqual(readSkillFile('/does/not/exist'), null);
  });
});
