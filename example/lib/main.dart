import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:ailia_llm/ailia_llm_model.dart';
import 'utils/download_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AiliaLLMModel _ailiaLlmModel = AiliaLLMModel();
  String _predictText = "Downloading...";

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    _ailiaLLMTest();
  }

  void _ailiaLLMTest() async{
    print("Downloading model...");
    downloadModel("https://storage.googleapis.com/ailia-models/gemma/gemma-2-2b-it-Q4_K_M.gguf", "gemma-2-2b-it-Q4_K_M.gguf", (model_file) {
      print("Download model success");

      int nCtx = 512;
      _ailiaLlmModel.open(model_file.path, nCtx);

      List<Map<String, dynamic>> messages = List<Map<String, dynamic>>.empty(growable:true);
      messages.add({"role": "system", "content": "語尾に「わん」をつけてください。"});
      messages.add({"role": "user", "content": "こんにちは。"});
      
      _ailiaLlmModel.setPrompt(messages);
      _predictText = "";
      while(true){
        String? deltaText = _ailiaLlmModel.generate();
        if (deltaText == null){
          break;
        }
        _predictText = _predictText + deltaText;
      }

      messages.add({"role": "assistant", "content": _predictText});
      messages.add({"role": "user", "content": "前回の回答を英語にしてください。"});

      setState(() {
        _predictText = _predictText;
      });

      _ailiaLlmModel.setPrompt(messages);
      _predictText = _predictText + "\n";
      while(true){
        String? deltaText = _ailiaLlmModel.generate();
        if (deltaText == null){
          break;
        }
        _predictText = _predictText + deltaText;
      }

      if (_ailiaLlmModel.contextFull()){
        print("Context Full");
      }

      _ailiaLlmModel.close();

      print("Sueccess");

      setState(() {
        _predictText = _predictText;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('ailia LLM example app'),
        ),
        body: Center(
          child: Text('Text : $_predictText\n'),
        ),
      ),
    );
  }
}
