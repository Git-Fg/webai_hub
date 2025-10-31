enum AIProvider {
  aistudio('AI Studio', 'https://aistudio.google.com/prompts/new_chat'),
  qwen('Qwen', 'https://chat.qwen.ai/'),
  zai('Z-ai', 'https://chat.z.ai/'),
  kimi('Kimi', 'https://www.kimi.com/');

  const AIProvider(this.displayName, this.url);
  final String displayName;
  final String url;

  static AIProvider fromIndex(int index) {
    switch (index) {
      case 0:
        return aistudio;
      case 1:
        return qwen;
      case 2:
        return zai;
      case 3:
        return kimi;
      default:
        return aistudio;
    }
  }
}