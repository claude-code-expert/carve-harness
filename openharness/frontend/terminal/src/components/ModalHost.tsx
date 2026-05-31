import React, {useEffect, useState} from 'react';
import {Box, Text, useInput} from 'ink';
import TextInput from 'ink-text-input';

const WAIT_FRAMES = [
	'Agent is waiting for your input   ',
	'Agent is waiting for your input.  ',
	'Agent is waiting for your input.. ',
	'Agent is waiting for your input...',
];
const MAX_DIFF_LINES = 40;

function WaitingAnimation(): React.JSX.Element {
	const [frame, setFrame] = useState(0);
	useEffect(() => {
		const timer = setInterval(() => setFrame((f) => (f + 1) % WAIT_FRAMES.length), 500);
		return () => clearInterval(timer);
	}, []);
	return (
		<Text color="magenta" dimColor>
			{WAIT_FRAMES[frame]}
		</Text>
	);
}

function QuestionModal({
	modal,
	modalInput,
	setModalInput,
	onSubmit,
}: {
	modal: Record<string, unknown>;
	modalInput: string;
	setModalInput: (value: string) => void;
	onSubmit: (value: string) => void;
}): React.JSX.Element {
	const [extraLines, setExtraLines] = useState<string[]>([]);

	useInput((_chunk, key) => {
		if (key.shift && key.return) {
			setExtraLines((lines) => [...lines, modalInput]);
			setModalInput('');
		}
	});

	const handleSubmit = (value: string): void => {
		const allLines = [...extraLines, value];
		setExtraLines([]);
		onSubmit(allLines.join('\n'));
	};

	const toolName = modal.tool_name ? String(modal.tool_name) : null;
	const reason = modal.reason ? String(modal.reason) : null;
	const question = String(modal.question ?? 'Question');

	return (
		<Box flexDirection="column" marginTop={1} borderStyle="double" borderColor="magenta" paddingX={1}>
			<WaitingAnimation />
			<Box marginTop={1}>
				<Text color="magenta" bold>{'\u2753 '}</Text>
				<Text bold>{question}</Text>
			</Box>
			{toolName ? (
				<Text dimColor>
					{'  '}Tool: <Text color="cyan">{toolName}</Text>
				</Text>
			) : null}
			{reason ? (
				<Text dimColor>{'  '}Reason: {reason}</Text>
			) : null}
			{extraLines.length > 0 && (
				<Box flexDirection="column" marginTop={1} marginLeft={2}>
					{extraLines.map((line, i) => (
						<Text key={i} dimColor>
							{line}
						</Text>
					))}
				</Box>
			)}
			<Box marginTop={1}>
				<Text color="cyan">{'> '}</Text>
				<TextInput value={modalInput} onChange={setModalInput} onSubmit={handleSubmit} />
			</Box>
			<Text dimColor>{'  '}shift+enter: newline | enter: submit</Text>
		</Box>
	);
}

type DiffLineKind = 'add' | 'del' | 'hunk' | 'context';

type ParsedDiffLine = {
	kind: DiffLineKind;
	content: string;
};

function parseDiffLines(diffText: string): ParsedDiffLine[] {
	return diffText
		.split('\n')
		.flatMap((raw): ParsedDiffLine[] => {
			if (!raw || raw.startsWith('+++') || raw.startsWith('---')) {
				return [];
			}
			if (raw.startsWith('@@')) {
				return [{kind: 'hunk', content: raw}];
			}
			if (raw.startsWith('+')) {
				return [{kind: 'add', content: raw.slice(1)}];
			}
			if (raw.startsWith('-')) {
				return [{kind: 'del', content: raw.slice(1)}];
			}
			return [{kind: 'context', content: raw.startsWith(' ') ? raw.slice(1) : raw}];
		});
}

function EditDiffModal({modal}: {modal: Record<string, unknown>}): React.JSX.Element {
	const path = String(modal.path ?? '');
	const added = Number(modal.added ?? 0);
	const removed = Number(modal.removed ?? 0);
	const lines = parseDiffLines(String(modal.diff ?? ''));
	const visibleLines = lines.slice(0, MAX_DIFF_LINES);
	const hiddenCount = lines.length - visibleLines.length;

	return (
		<Box flexDirection="column" marginTop={1}>
			<Text>
				<Text color="yellow" bold>{'\u250C '}</Text>
				<Text bold>Edit </Text>
				<Text color="cyan" bold>{path}</Text>
				<Text>{'  '}</Text>
				<Text color="green">{`+${added}`}</Text>
				<Text>{' '}</Text>
				<Text color="red">{`-${removed}`}</Text>
			</Text>
			{visibleLines.map((line, index) => {
				if (line.kind === 'hunk') {
					return (
						<Text key={index}>
							<Text color="yellow">{'\u2502 '}</Text>
							<Text color="cyan" dimColor>{line.content}</Text>
						</Text>
					);
				}
				if (line.kind === 'add') {
					return (
						<Text key={index}>
							<Text color="yellow">{'\u2502 '}</Text>
							<Text color="green">+</Text>
							<Text color="green">{line.content}</Text>
						</Text>
					);
				}
				if (line.kind === 'del') {
					return (
						<Text key={index}>
							<Text color="yellow">{'\u2502 '}</Text>
							<Text color="red">-</Text>
							<Text color="red">{line.content}</Text>
						</Text>
					);
				}
				return (
					<Text key={index}>
						<Text color="yellow">{'\u2502 '}</Text>
						<Text dimColor>{' '}{line.content}</Text>
					</Text>
				);
			})}
			{hiddenCount > 0 ? (
				<Text>
					<Text color="yellow">{'\u2502 '}</Text>
					<Text dimColor>... {hiddenCount} more lines hidden</Text>
				</Text>
			) : null}
			<Text>
				<Text color="yellow">{'\u2514 '}</Text>
				<Text color="green">[y] Once</Text>
				<Text>{'  '}</Text>
				<Text color="green">[a] Always</Text>
				<Text>{'  '}</Text>
				<Text color="red">[n] Deny</Text>
			</Text>
		</Box>
	);
}

function ModalHostInner({
	modal,
	modalInput,
	setModalInput,
	onSubmit,
}: {
	modal: Record<string, unknown> | null;
	modalInput: string;
	setModalInput: (value: string) => void;
	onSubmit: (value: string) => void;
}): React.JSX.Element | null {
	if (modal?.kind === 'permission') {
		return (
			<Box flexDirection="column" marginTop={1}>
				<Text>
					<Text color="yellow" bold>{'\u250C '}</Text>
					<Text bold>Allow </Text>
					<Text color="cyan" bold>{String(modal.tool_name ?? 'tool')}</Text>
					<Text bold>?</Text>
				</Text>
				{modal.reason ? (
					<Text>
						<Text color="yellow">{'\u2502 '}</Text>
						<Text dimColor>{String(modal.reason)}</Text>
					</Text>
				) : null}
				<Text>
					<Text color="yellow">{'\u2514 '}</Text>
					<Text color="green">[y] Allow</Text>
					<Text>{'  '}</Text>
					<Text color="red">[n] Deny</Text>
				</Text>
			</Box>
		);
	}
	if (modal?.kind === 'edit_diff') {
		return <EditDiffModal modal={modal} />;
	}
	if (modal?.kind === 'question') {
		return (
			<QuestionModal
				modal={modal}
				modalInput={modalInput}
				setModalInput={setModalInput}
				onSubmit={onSubmit}
			/>
		);
	}
	if (modal?.kind === 'mcp_auth') {
		return (
			<Box flexDirection="column" marginTop={1}>
				<Text>
					<Text color="yellow" bold>{'\u{1F511} '}</Text>
					<Text bold>MCP Authentication</Text>
				</Text>
				<Text dimColor>{String(modal.prompt ?? 'Provide auth details')}</Text>
				<Box>
					<Text color="cyan">{'> '}</Text>
					<TextInput value={modalInput} onChange={setModalInput} onSubmit={onSubmit} />
				</Box>
			</Box>
		);
	}
	return null;
}

export const ModalHost = React.memo(ModalHostInner);
