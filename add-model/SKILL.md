---
name: add-model
description: Add a new AI model to the Cline codebase. Use when adding new model definitions, updating model configurations, or adding support for new AI models to existing providers.
---

# Add Model to Cline

This skill guides you through adding a new AI model to the Cline extension.

## Step 1: Gather Model Information

Before making any changes, ask the user these questions:

### Required Information
1. **Provider**: Which provider is this model for? (e.g., openai-native, anthropic, bedrock, gemini, cerebras, groq, etc.)
2. **Model ID**: What is the exact model identifier string? (e.g., "gpt-5.2", "claude-sonnet-4-5-20250929")
3. **Context Window**: What is the context window size in tokens?
4. **Max Output Tokens**: What is the maximum output tokens (maxTokens)?
5. **Pricing**: What are the prices per million tokens?
   - Input price
   - Output price
   - Cache writes price (if applicable)
   - Cache reads price (if applicable)

### Capability Questions
6. **Image Support**: Does this model support image inputs? (supportsImages: true/false)
7. **Prompt Caching**: Does this model support prompt caching? (supportsPromptCache: true/false)
8. **Reasoning/Thinking**: Does this model support reasoning mode? (supportsReasoning: true/false)
   - If yes, what is the thinking budget limit (thinkingConfig.maxBudget)?
   - Does it support thinking levels (low/high) like Gemini?
9. **Should this become the default model** for this provider?

### Provider-Specific Questions
10. **Temperature**: Does this model require a specific temperature setting?
11. **System Role**: Does this model use "developer" or "system" for system messages?
12. **Reasoning Effort**: Does this model support reasoning effort levels? (supportsReasoningEffort)
13. **API Format**: Does this model require a special API format (e.g., OpenAI Responses API)?
14. **Global Endpoint**: For Vertex/Gemini - does it support global endpoints? (supportsGlobalEndpoint)

## Step 2: Determine Complexity Level

Based on the answers, determine which level of changes are needed:

### Level 1: Simple Model Addition
**Criteria**: Adding a model to an existing provider with no special features.

**Files to modify**:
- `src/shared/api.ts` only

### Level 2: Standard Model Addition (with release notes)
**Criteria**: Model needs documentation or release announcement.

**Files to modify**:
- `src/shared/api.ts`
- `.changeset/<random-name>.md` (create new)
- Optional: `docs/provider-config/<provider>.mdx`
- Optional: `src/core/prompts/system-prompt/variants/*/config.ts`
- Optional: `src/utils/model-utils.ts`

### Level 3: Complex Model Addition
**Criteria**: Model requires new API format, handler changes, or UI updates.

**Additional files**:
- `proto/cline/models.proto` - if new API format enum needed
- `src/core/api/providers/<provider>.ts` - handler changes
- `src/core/controller/models/` - model fetching logic
- `webview-ui/src/components/settings/` - UI picker updates

## Step 3: Implement the Changes

### Adding the Model Entry in `src/shared/api.ts`

Find the appropriate models object for the provider. The pattern is:

```typescript
export const <provider>Models = {
    // Add new model here - typically at the TOP if it's the new default
    "new-model-id": {
        maxTokens: <number>,
        contextWindow: <number>,
        supportsImages: <boolean>,
        supportsPromptCache: <boolean>,
        inputPrice: <number>,        // per million tokens
        outputPrice: <number>,       // per million tokens
        cacheWritesPrice: <number>,  // if applicable
        cacheReadsPrice: <number>,   // if applicable
        // Optional fields:
        supportsReasoning: <boolean>,
        temperature: <number>,
        systemRole: "developer" | "system",
        supportsReasoningEffort: <boolean>,
        apiFormat: ApiFormat.<FORMAT>,
        description: "Model description",
        thinkingConfig: {
            maxBudget: <number>,
            outputPrice: <number>,
            geminiThinkingLevel: "low" | "high",
            supportsThinkingLevel: <boolean>,
        },
    },
    // ... existing models
} as const satisfies Record<string, ModelInfo>
```

### Updating the Default Model ID (if applicable)

```typescript
export const <provider>DefaultModelId: <Provider>ModelId = "new-model-id"
```

### Creating a Changeset (Level 2+)

Create `.changeset/<random-words>.md`:

```markdown
---
"claude-dev": patch
---

Add <model-name> model support
```

Use `patch` for new models. Use `minor` only if adding entirely new provider.

## Common Gotchas to Check

### 1. Type Constraints
- The models object must end with `as const satisfies Record<string, ModelInfo>`
- Model IDs in the type will be automatically derived

### 2. Pricing Consistency
- All prices are per **million tokens**
- If a model has no cost (free tier), use `inputPrice: 0, outputPrice: 0`
- If prompt caching not supported, omit `cacheWritesPrice` and `cacheReadsPrice`

### 3. Context Window vs Max Tokens
- `contextWindow`: Total input + output limit
- `maxTokens`: Maximum **output** tokens only
- These are different! Don't confuse them.

### 4. supportsPromptCache Flag
- Only set to `true` if the provider's handler actually implements caching
- Check the provider file in `src/core/api/providers/<provider>.ts`

### 5. Multiple Regions (Qwen, ZAi)
- Some providers have separate model lists for different regions
- Check if there are `international<Provider>Models` and `mainland<Provider>Models`
- Update BOTH if the model should be available in both regions

### 6. Tiered Pricing
- Some models have tiered pricing based on context length
- Use the `tiers` array for these cases

### 7. Model Ordering
- New models that become the default should go at the TOP
- This affects UI display order in some cases

### 8. Reasoning Models
- If `supportsReasoning: true`, consider if `thinkingConfig` is needed
- Check if `supportsReasoningEffort` should be true (for models like o3, gpt-5)

## Step 4: Verify Changes

After making changes:

1. **TypeScript Check**: Run `npm run type-check` to ensure no type errors
2. **Search for Similar Models**: Look at how similar models in the same provider are configured
3. **Check Provider Handler**: Verify the provider handler will work with your model configuration
4. **Test the UI**: Start the extension and verify the model appears in the picker

## Reference: Provider Locations

| Provider | Type Export | Models Object | Default ID |
|----------|-------------|---------------|------------|
| anthropic | `AnthropicModelId` | `anthropicModels` | `anthropicDefaultModelId` |
| bedrock | `BedrockModelId` | `bedrockModels` | `bedrockDefaultModelId` |
| vertex | `VertexModelId` | `vertexModels` | `vertexDefaultModelId` |
| openai-native | `OpenAiNativeModelId` | `openAiNativeModels` | `openAiNativeDefaultModelId` |
| gemini | `GeminiModelId` | `geminiModels` | `geminiDefaultModelId` |
| cerebras | `CerebrasModelId` | `cerebrasModels` | `cerebrasDefaultModelId` |
| groq | `GroqModelId` | `groqModels` | `groqDefaultModelId` |
| deepseek | `DeepSeekModelId` | `deepSeekModels` | `deepSeekDefaultModelId` |
| mistral | `MistralModelId` | `mistralModels` | `mistralDefaultModelId` |
| xai | `XAIModelId` | `xaiModels` | `xaiDefaultModelId` |
| fireworks | `FireworksModelId` | `fireworksModels` | `fireworksDefaultModelId` |
| baseten | `BasetenModelId` | `basetenModels` | `basetenDefaultModelId` |
| qwen | `InternationalQwenModelId` / `MainlandQwenModelId` | `internationalQwenModels` / `mainlandQwenModels` | region-specific defaults |
| zai | `internationalZAiModelId` / `mainlandZAiModelId` | `internationalZAiModels` / `mainlandZAiModels` | region-specific defaults |
