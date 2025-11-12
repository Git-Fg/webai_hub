// ts_src/chatbots/index.ts
import { aiStudioChatbot } from './ai-studio';
import { kimiChatbot } from './kimi';
import { Chatbot } from '../types/chatbot';

export * from './ai-studio';
export * from './kimi';

export const SUPPORTED_SITES: Record<string, Chatbot> = {
  ai_studio: aiStudioChatbot,
  kimi: kimiChatbot,
};

