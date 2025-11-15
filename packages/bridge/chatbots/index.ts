// ts_src/chatbots/index.ts
import { aiStudioChatbot } from './ai-studio';
import { kimiChatbot } from './kimi';
import { zAiChatbot } from './z-ai';
import { Chatbot } from '../types/chatbot';

export { AiStudioChatbot, aiStudioChatbot } from './ai-studio';
export { kimiChatbot } from './kimi';
export { zAiChatbot } from './z-ai';

export const SUPPORTED_SITES: Record<string, Chatbot> = {
  ai_studio: aiStudioChatbot,
  kimi: kimiChatbot,
  z_ai: zAiChatbot,
};

