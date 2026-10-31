import 'package:flutter/material.dart';

import 'core/network/backend_api_service.dart';
import 'core/theme/app_theme.dart';
import 'features/terrenos/screens/pantalla_inicio.dart';

void main() {
  runApp(const ARSandboxApp());
}

class ARSandboxApp extends StatelessWidget {
  const ARSandboxApp({super.key, this.backendApiService});

  final BackendApiService? backendApiService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AR Sandbox',
      theme: AppTheme.theme,
      home: PantallaInicio(backendApiService: backendApiService),
    );
  }
}
