//
// Copyright 2020-2023 Picovoice Inc.
//
// You may not use this file except in compliance with the license. A copy of the license is located in the "LICENSE"
// file accompanying this source.
//
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

import 'package:bottom_picker/bottom_picker.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final String accessKey =
      "sK5ExWMbMPZpJ/BGXNasZ0eYjx0NnjtyaPO5rVzWE5gm+/Hn2XuUXQ=="; // AccessKey obtained from Picovoice Console (https://console.picovoice.ai/)

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late String _language;
  late List<String> _keywords;
  final Map<String, BuiltInKeyword> _keywordMap = {};

  bool isError = false;
  String errorMessage = "";

  bool isButtonDisabled = false;
  bool isProcessing = false;
  Color detectionColour = Color(0xff00e5c3);
  Color defaultColour = Color(0xfff5fcff);
  Color? backgroundColour;
  String currentKeyword = "Click to choose a keyword";
  PorcupineManager? _porcupineManager;

  @override
  void initState() {
    super.initState();
    setState(() {
      isButtonDisabled = true;
      backgroundColour = defaultColour;
    });
    WidgetsBinding.instance.addObserver(this);

    _initializeKeywordMap();
    _loadParams();
    _requestMicrophonePermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      await _stopProcessing();
      await _porcupineManager?.delete();
      _porcupineManager = null;
    }
  }

  Future<void> _loadParams() async {
    try {
      final paramsString = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/params.json');
      final params = json.decode(paramsString);

      String language = params["language"];
      List<String> keywords = List<String>.from(params["keywords"]);
      if (language == "en") {
        for (var builtIn in BuiltInKeyword.values) {
          String keyword =
              builtIn
                  .toString()
                  .split(".")
                  .last
                  .replaceAll("_", " ")
                  .toLowerCase();
          keywords.add(keyword);
        }
      }

      _language = language;
      _keywords = keywords;
    } catch (_) {
      errorCallback(
        PorcupineException(
          "Could not find `params.json`. Ensure 'prepare_demo.dart' script was run before launching the demo.",
        ),
      );
    }
  }

  Future<void> loadNewKeyword(String keyword) async {
    setState(() {
      isButtonDisabled = true;
    });

    if (!_keywords.contains(keyword)) {
      return;
    }

    if (isProcessing) {
      await _stopProcessing();
    }

    if (_porcupineManager != null) {
      await _porcupineManager?.delete();
      _porcupineManager = null;
    }
    try {
      if (_language == "en") {
        BuiltInKeyword builtIn = _keywordMap[keyword]!;

        _porcupineManager = await PorcupineManager.fromBuiltInKeywords(
          accessKey,
          [builtIn],
          wakeWordCallback,
          errorCallback: errorCallback,
        );
      } else {
        var platform = (Platform.isAndroid) ? "android" : "ios";
        var keywordPath = "assets/keywords/$platform/${keyword}_$platform.ppn";
        var modelPath = "assets/models/porcupine_params_$_language.pv";

        _porcupineManager = await PorcupineManager.fromKeywordPaths(
          accessKey,
          [keywordPath],
          wakeWordCallback,
          modelPath: modelPath,
          errorCallback: errorCallback,
        );
      }

      setState(() {
        currentKeyword = keyword;
        isError = false;
      });
    } on PorcupineActivationException {
      errorCallback(
        PorcupineActivationException("AccessKey activation error."),
      );
    } on PorcupineActivationLimitException {
      errorCallback(
        PorcupineActivationLimitException(
          "AccessKey reached its device limit.",
        ),
      );
    } on PorcupineActivationRefusedException {
      errorCallback(PorcupineActivationRefusedException("AccessKey refused."));
    } on PorcupineActivationThrottledException {
      errorCallback(
        PorcupineActivationThrottledException("AccessKey has been throttled."),
      );
    } on PorcupineException catch (ex) {
      errorCallback(ex);
    } finally {
      setState(() {
        isButtonDisabled = false;
      });
    }
  }

  void wakeWordCallback(int keywordIndex) {
    if (keywordIndex >= 0) {
      setState(() {
        backgroundColour = detectionColour;
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        setState(() {
          backgroundColour = defaultColour;
        });
      });
    }
  }

  void errorCallback(PorcupineException error) {
    setState(() {
      isError = true;
      errorMessage = error.message!;
    });
  }

  Future<void> _startProcessing() async {
    setState(() {
      isButtonDisabled = true;
    });

    // 마이크 권한 확인
    final microphoneStatus = await Permission.microphone.status;
    if (microphoneStatus != PermissionStatus.granted) {
      await _requestMicrophonePermission();
      final newStatus = await Permission.microphone.status;
      if (newStatus != PermissionStatus.granted) {
        errorCallback(PorcupineException("마이크 권한이 없어 음성 감지를 시작할 수 없습니다."));
        setState(() {
          isButtonDisabled = false;
        });
        return;
      }
    }

    if (_porcupineManager == null) {
      await loadNewKeyword(currentKeyword);
    }

    try {
      await _porcupineManager?.start();
      setState(() {
        isProcessing = true;
      });
    } on PorcupineException catch (ex) {
      errorCallback(ex);
    } finally {
      setState(() {
        isButtonDisabled = false;
      });
    }
  }

  Future<void> _stopProcessing() async {
    setState(() {
      isButtonDisabled = true;
    });

    await _porcupineManager?.stop();

    setState(() {
      isButtonDisabled = false;
      isProcessing = false;
    });
  }

  void _toggleProcessing() async {
    if (isProcessing) {
      await _stopProcessing();
    } else {
      await _startProcessing();
    }
  }

  void _initializeKeywordMap() {
    for (var builtIn in BuiltInKeyword.values) {
      String keyword =
          builtIn.toString().split(".").last.replaceAll("_", " ").toLowerCase();
      _keywordMap[keyword] = builtIn;
    }
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() {
        isError = true;
        errorMessage = "마이크 권한이 필요합니다. 설정에서 권한을 허용해주세요.";
      });
    }
  }

  Color picoBlue = Color.fromRGBO(55, 125, 255, 1);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        backgroundColor: backgroundColour,
        appBar: AppBar(
          title: const Text('Porcupine Demo'),
          backgroundColor: picoBlue,
        ),
        body: Column(
          children: [
            buildPicker(context),
            buildStartButton(context),
            buildErrorMessage(context),
            footer,
          ],
        ),
      ),
    );
  }

  buildPicker(BuildContext context) {
    return Expanded(
      flex: 1,
      child: Container(
        alignment: Alignment.bottomCenter,
        // color: Colors.blue,
        child: FractionallySizedBox(
          widthFactor: 0.9,
          child: OutlinedButton(
            child: Text(
              currentKeyword.toString(),
              style: TextStyle(fontSize: 20, color: picoBlue),
            ),
            onPressed: () {
              showPicker(context);
            },
          ),
        ),
      ),
    );
  }

  buildStartButton(BuildContext context) {
    final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: picoBlue,
      shape: CircleBorder(),
      textStyle: TextStyle(color: Colors.white),
    );

    return Expanded(
      flex: 2,
      child: Container(
        child: SizedBox(
          width: 150,
          height: 150,
          child: ElevatedButton(
            style: buttonStyle,
            onPressed: (isButtonDisabled || isError) ? null : _toggleProcessing,
            child: Text(
              isProcessing ? "Stop" : "Start",
              style: TextStyle(fontSize: 30),
            ),
          ),
        ),
      ),
    );
  }

  buildErrorMessage(BuildContext context) {
    return Expanded(
      flex: 1,
      child: Container(
        alignment: Alignment.center,
        margin: EdgeInsets.only(left: 20, right: 20),
        decoration:
            !isError
                ? null
                : BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(5),
                ),
        child:
            !isError
                ? null
                : Text(
                  errorMessage,
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
      ),
    );
  }

  Widget footer = Expanded(
    flex: 1,
    child: Container(
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(bottom: 20),
      child: const Text(
        "Made in Vancouver, Canada by Picovoice",
        style: TextStyle(color: Color(0xff666666)),
      ),
    ),
  );

  showPicker(BuildContext context) {
    BottomPicker picker = BottomPicker(
      pickerTitle: Text(
        "Choose a keyword",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      titleAlignment: Alignment.topCenter,
      gradientColors: [picoBlue, picoBlue],
      items: _keywords.toList().map((x) => Center(child: Text(x))).toList(),
      onSubmit: (index) {
        loadNewKeyword(_keywords[index]);
      },
    );
    picker.show(_scaffoldKey.currentContext!);
  }
}
