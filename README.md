# ailia LLM Flutter Package

!! CAUTION !!
“ailia” IS NOT OPEN SOURCE SOFTWARE (OSS).
As long as user complies with the conditions stated in [License Document](https://ailia.ai/license/), user may use the Software for free of charge, but the Software is basically paid software.

## About ailia LLM

ailia LLM is a library for running local LLMs. It can load GGUF and easily implement chat functionality.

## macOS Download Attribute

If a security error occurs with a downloaded file on macOS, please execute the following command to remove the download attribute.

```
xattr -d com.apple.quarantine macos/libailia_llm.dylib
```

## Tool Use (Function Calling)

With models whose chat template supports tool calling (e.g. Gemma 4), pass OpenAI-compatible tool definitions with `setTools` and convert the raw output into tool calls with `parseResponse`. Keep the raw output as the `assistant` content of the history and return tool results as the content of messages with role `tool` (matched to the tool calls by order).

```dart
llm.setTools([
  {
    'type': 'function',
    'function': {
      'name': 'get_weather',
      'description': 'Get the current weather of a city.',
      'parameters': {'type': 'object', 'properties': {'city': {'type': 'string'}}, 'required': ['city']},
    },
  },
]);

final messages = <Map<String, dynamic>>[{'role': 'user', 'content': 'What is the weather in Tokyo?'}];
llm.setPrompt(messages);
final raw = StringBuffer();
String? delta;
while ((delta = llm.generate()) != null) { raw.write(delta); }
final response = llm.parseResponse(raw.toString()); // {'role': 'assistant', 'content': '', 'tool_calls': [...]}

messages.add({'role': 'assistant', 'content': raw.toString()}); // raw output as is
for (final call in (response['tool_calls'] as List? ?? [])) {
  // execute the tool, then return the result (matched to the tool calls by order)
  messages.add({'role': 'tool', 'content': 'Sunny, 25C'});
}
llm.setPrompt(messages);
while ((delta = llm.generate()) != null) { print(delta); }
```

## API specification

https://github.com/ailia-ai/ailia-sdk

