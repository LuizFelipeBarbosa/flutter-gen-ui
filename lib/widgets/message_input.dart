import 'package:flutter/material.dart';

/// The message composer: a text field and send button.
///
/// While [isProcessing], input is disabled and the button shows a spinner.
/// Submitting via the keyboard or the button calls [onSend] with the text.
class MessageInput extends StatelessWidget {
  const MessageInput({
    required this.controller,
    required this.isProcessing,
    required this.onSend,
    this.suggestions = const [],
    this.hintText = 'Enter a message',
    super.key,
  });

  final TextEditingController controller;
  final bool isProcessing;
  final ValueChanged<String> onSend;
  final List<String> suggestions;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (suggestions.isNotEmpty) ...[
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return ActionChip(
                      label: Text(suggestion),
                      onPressed: isProcessing ? null : () => onSend(suggestion),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemCount: suggestions.length,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isProcessing,
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: isProcessing ? null : onSend,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: isProcessing
                      ? null
                      : () => onSend(controller.text),
                  style: FilledButton.styleFrom(
                    fixedSize: const Size.square(50),
                    padding: EdgeInsets.zero,
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
