import 'package:flutter/material.dart';
import 'analysis_page.dart';
import 'info_page.dart';
import 'lists_pages.dart';
import 'portfolio_page.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Saham Teori',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: Colors.teal),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int idx = 0;
  final ak = GlobalKey<AnalysisPageState>();
  final wk = GlobalKey<WatchlistPageState>();
  final pk = GlobalKey<PortfolioPageState>();

  void open(String code) {
    setState(() => idx = 0);
    ak.currentState?.loadCode(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: idx, children: [
        AnalysisPage(key: ak),
        WatchlistPage(key: wk, onOpen: open),
        PortfolioPage(key: pk, onOpen: open),
        ScreenerPage(onOpen: open),
        const InfoPage(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          setState(() => idx = i);
          if (i == 1) wk.currentState?.refresh();
          if (i == 2) pk.currentState?.refresh();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Analisis'),
          NavigationDestination(icon: Icon(Icons.star), label: 'Watchlist'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Portofolio'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Screener'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Teori'),
        ],
      ),
    );
  }
}
