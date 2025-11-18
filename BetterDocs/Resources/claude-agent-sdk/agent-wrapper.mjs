#!/usr/bin/env node

import { query } from '@anthropic-ai/claude-agent-sdk';

const prompt = process.argv[2];
console.error(`[WRAPPER] Received prompt: ${prompt}`);

if (!prompt) {
  console.error(JSON.stringify({ error: 'No prompt provided' }));
  process.exit(1);
}

try {
  console.error('[WRAPPER] Creating query...');

  // Create a query with the prompt
  const queryStream = query({
    prompt,
    options: {
      systemPrompt: 'You are a helpful assistant analyzing documents and helping with document editing tasks.',
      permissionMode: 'bypassPermissions',
      allowDangerouslySkipPermissions: true
    }
  });

  console.error('[WRAPPER] Starting to iterate messages...');

  // Stream messages as they arrive
  for await (const message of queryStream) {
    console.error(`[WRAPPER] Received message type: ${message.type}`);
    console.error(`[WRAPPER] Full message: ${JSON.stringify(message, null, 2)}`);

    // Output each message as JSON
    if (message.type === 'assistant') {
      console.error(`[WRAPPER] Assistant message with ${message.message?.content?.length || 0} content blocks`);

      // Extract text from assistant messages - message.message.content is the actual content
      for (const block of message.message?.content || []) {
        console.error(`[WRAPPER] Block type: ${block.type}`);
        if (block.type === 'text') {
          console.error(`[WRAPPER] Outputting text: ${block.text.substring(0, 50)}...`);
          console.log(JSON.stringify({ type: 'text', content: block.text }));
        } else if (block.type === 'tool_use') {
          console.error(`[WRAPPER] Tool use: ${block.name}`);
          console.log(JSON.stringify({ type: 'tool_use', tool: block.name, input: block.input }));
        }
      }
    } else if (message.type === 'result') {
      console.error(`[WRAPPER] Result message: ${message.success ? 'success' : 'error'}`);
      console.log(JSON.stringify({ type: 'result', success: message.success }));
    }
  }

  console.error('[WRAPPER] Finished iterating messages');
} catch (error) {
  console.error(`[WRAPPER] Error: ${error.message}`);
  console.error(`[WRAPPER] Stack: ${error.stack}`);
  console.error(JSON.stringify({ type: 'error', error: error.message }));
  process.exit(1);
}
