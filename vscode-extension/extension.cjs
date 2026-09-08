'use strict';
const vscode = require('vscode');
const { requestImage, validateInput } = require('./image-client.cjs');

function activate(context) {
  for (const edit of [false, true]) {
    context.subscriptions.push(vscode.lm.registerTool(edit ? 'codexProxy_editImage' : 'codexProxy_generateImage', {
      prepareInvocation({ input }) {
        validateInput(input, edit);
        const message = new vscode.MarkdownString();
        message.appendText('Uses your ChatGPT image quota through the local proxy. Saves a new image in the configured output folder.');
        if (edit) {
          message.appendText('\nUploads these selected images to ChatGPT; originals are preserved:\n');
          message.appendCodeblock(input.images.join('\n'));
        }
        message.appendText('\nPrompt:\n');
        message.appendCodeblock(input.prompt);
        return {
          invocationMessage: edit ? 'Editing image with Codex…' : 'Generating image with Codex…',
          confirmationMessages: { title: edit ? 'Edit image with Codex' : 'Generate image with Codex', message }
        };
      },
      async invoke({ input }, token) {
        const controller = new AbortController();
        const listener = token.onCancellationRequested(() => controller.abort());
        if (token.isCancellationRequested) controller.abort();
        try {
          const config = vscode.workspace.getConfiguration('codexProxyTools');
          const result = await requestImage(input, { edit, proxyUrl: config.get('proxyUrl'), outputDirectory: config.get('outputDirectory'), signal: controller.signal });
          return new vscode.LanguageModelToolResult([
            new vscode.LanguageModelTextPart(`Image saved to ${result.destination}`),
            vscode.LanguageModelDataPart.image(result.bytes, result.mimeType)
          ]);
        } catch (error) {
          if (token.isCancellationRequested) throw new vscode.CancellationError();
          const message = error.name === 'TimeoutError' ? 'Image request timed out after 5 minutes. The service may still complete it; do not retry automatically.'
            : error.cause?.code === 'ECONNREFUSED' ? 'The local proxy is not running. Start start-proxy.ps1 and try again.' : error.message;
          return new vscode.LanguageModelToolResult([new vscode.LanguageModelTextPart(`Image tool failed: ${message}`)]);
        } finally { listener.dispose(); }
      }
    }));
  }
}
module.exports = { activate };
