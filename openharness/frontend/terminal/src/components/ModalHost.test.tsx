import assert from 'node:assert/strict';
import test from 'node:test';
import {PassThrough} from 'node:stream';
import React from 'react';
import {render} from 'ink';

import {ModalHost} from './ModalHost.js';

const stripAnsi = (value: string): string => value.replace(/\u001B\[[0-9;?]*[ -/]*[@-~]/g, '');
const nextLoopTurn = (): Promise<void> => new Promise((resolve) => setImmediate(resolve));

type InkTestStdout = PassThrough & {
	isTTY: boolean;
	columns: number;
	rows: number;
	cursorTo: () => boolean;
	clearLine: () => boolean;
	moveCursor: () => boolean;
};

function createTestStdout(): InkTestStdout {
	return Object.assign(new PassThrough(), {
		isTTY: true,
		columns: 120,
		rows: 40,
		cursorTo: () => true,
		clearLine: () => true,
		moveCursor: () => true,
	});
}

async function waitForOutputToStabilize(getOutput: () => string): Promise<string> {
	let previous = '';
	let sawOutput = false;

	for (let i = 0; i < 50; i += 1) {
		await nextLoopTurn();
		const current = getOutput();
		sawOutput ||= current.length > 0;
		if (sawOutput && current === previous) {
			return current;
		}
		previous = current;
	}

	throw new Error(`Ink output did not stabilize: ${JSON.stringify(previous)}`);
}

test('renders edit diff preview with stats and always shortcut', async () => {
	const stdout = createTestStdout();
	let output = '';

	stdout.on('data', (chunk) => {
		output += chunk.toString();
	});

	const instance = render(
		<ModalHost
			modal={{
				kind: 'edit_diff',
				path: 'src/demo.txt',
				diff: '@@ -1 +1 @@\n-old line\n+new line',
				added: 1,
				removed: 1,
			}}
			modalInput=""
			setModalInput={() => undefined}
			onSubmit={() => undefined}
		/>,
		{stdout: stdout as unknown as NodeJS.WriteStream, debug: true, patchConsole: false},
	);

	const exitPromise = instance.waitUntilExit();
	const stableOutput = await waitForOutputToStabilize(() => output);
	instance.unmount();
	await exitPromise;
	instance.cleanup();
	stdout.destroy();

	const rendered = stripAnsi(stableOutput);
	assert.match(rendered, /Edit src\/demo\.txt/);
	assert.match(rendered, /\+1/);
	assert.match(rendered, /-1/);
	assert.match(rendered, /\+new line/);
	assert.match(rendered, /-old line/);
	assert.match(rendered, /\[a\] Always/);
});
