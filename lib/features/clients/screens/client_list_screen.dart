import 'package:flutter/material.dart';
import '../../clients/widgets/client_list_widget.dart';

class ClientListScreen extends StatelessWidget {
  const ClientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ClientListWidget(),
    );
  }
}
