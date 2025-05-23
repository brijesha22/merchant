import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:merchant/OnlineOrderReport.dart';
import 'package:merchant/TotalSalesReport.dart';
import 'package:merchant/KotSummaryReport.dart';
import 'Dashboard.dart';

final dbNamesProvider = StateProvider<List<String>>((ref) => []);

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

// Config & User Models
class Config {
  final String apiUrl;
  final String clientCode;

  Config({required this.apiUrl, required this.clientCode});

  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(
      apiUrl: json['apiUrl'],
      clientCode: json['clientCode'],
    );
  }

  static Future<Config> loadFromAsset() async {
    final jsonString = await rootBundle.loadString('assets/config.json');
    final jsonMap = json.decode(jsonString);
    return Config.fromJson(jsonMap);
  }
}

class UserData {
  final int id;
  final String dbName;
  final int usercode;
  final String username;
  final String password;

  UserData({
    required this.id,
    required this.dbName,
    required this.usercode,
    required this.username,
    required this.password,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      dbName: json['dbName'],
      usercode: json['usercode'],
      username: json['username'],
      password: json['password'],
    );
  }

  static Future<List<UserData>> fetchUsers(Config config) async {
    final url =
        "${config.apiUrl}${config.clientCode}/getAll?DB=${config.clientCode}";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => UserData.fromJson(e)).toList();
    } else {
      throw Exception("Failed to fetch user data");
    }
  }
  static Future<Map<String, String>> fetchBrandNames(Config config, List<String> dbNames) async {
    final Map<String, String> dbToBrandMap = {}; // Map to store DB-Brand mapping

    for (final db in dbNames) {
      final url = "${config.apiUrl}config/getAll?DB=$db";
      print("🔗 Requesting brand name from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);

          String? brandName;
          if (decoded is Map<String, dynamic>) {
            brandName = decoded['brandName'];
          } else if (decoded is List && decoded.isNotEmpty && decoded[0] is Map) {
            brandName = decoded[0]['brandName'];
          }

          if (brandName != null) {
            dbToBrandMap[db] = brandName; // Map the DB to its brand name
            print("✅ DB: $db → Brand Name: $brandName");
          } else {
            print("❓ Unexpected response format for DB: $db → $decoded");
          }
        } else {
          print("❌ Failed to fetch brand name for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching DB: $db → $e");
      }
    }

    return dbToBrandMap; // Return the populated map
  }

  static Future<Map<String, TotalSalesReport>> fetchTotalSalesForDbs(
      Config config, List<String> dbNames, String startDate, String endDate)
  async {
    final Map<String, TotalSalesReport> dbToTotalSalesMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/totalsale?startDate=$startDate&endDate=$endDate&DB=$db";
      print("🔗 Requesting total sales from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for total sales DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            final report = TotalSalesReport.fromJson(decoded);
            dbToTotalSalesMap[db] = report;
          } else {
          }
        } else {
        }
      } catch (e) {
      }
    }

    return dbToTotalSalesMap;
  }

  static Future<List<TimeslotSales>> fetchTimeslotSalesForDbs(
      Config config, List<String> dbNames, String startDate, String endDate)
  async {
    final dbParams = dbNames.map((db) => "DB=$db").join("&");
    final url = "${config.apiUrl}report/timeslotsale?startDate=$startDate&endDate=$endDate&$dbParams";
    print("🔗 Requesting timeslot sales from: $url");

    try {
      final response = await http.get(Uri.parse(url));
      print("📡 Status for timeslot sales: ${response.statusCode}");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          return decoded.map((e) => TimeslotSales.fromJson(e)).toList();
        }
      }
    } catch (e) {
      print("❌ Exception in fetchTimeslotSalesForDbs: $e");
    }
    return [];
  }

  static Future<Map<String, List<KotSummaryReport>>> fetchKotSummaryForDbs(
      Config config, List<String> dbNames, String startDate, String endDate)
  async {
    final Map<String, List<KotSummaryReport>> dbToKotSummaryMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/kotsummary?startDate=$startDate&endDate=$endDate&DB=$db";
      print("🔗 Requesting KOT summary from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for KOT summary DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToKotSummaryMap[db] =
                decoded.map<KotSummaryReport>((e) => KotSummaryReport.fromJson(e)).toList();
          } else {
            print("❓ Unexpected response format for KOT summary DB: $db → $decoded");
          }
        } else {
          print("❌ Failed to fetch KOT summary for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching KOT summary for DB: $db → $e");
      }
    }

    return dbToKotSummaryMap;
  }


  static Future<Map<String, List<OnlineOrderReport>>> fetchOnlineOrdersForDbs(
      Config config,
      List<String> dbNames,
      String startDate,
      String endDate,
      ) async {
    final Map<String, List<OnlineOrderReport>> dbToOnlineOrdersMap = {};

    for (final db in dbNames) {
      final url =
          "${config.apiUrl}report/onlinesales?DB=$db&startDate=$startDate&endDate=$endDate";
      print("🔗 Requesting online orders from: $url");

      try {
        final response = await http.get(Uri.parse(url));
        print("📡 Status for online orders DB '$db': ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            dbToOnlineOrdersMap[db] = decoded
                .map<OnlineOrderReport>((e) => OnlineOrderReport.fromJson(e))
                .toList();
          } else {
            print(
                "❓ Unexpected response format for online orders DB: $db → $decoded");
          }
        } else {
          print(
              "❌ Failed to fetch online orders for DB: $db → ${response.reasonPhrase}");
        }
      } catch (e) {
        print("🔥 Exception while fetching online orders for DB: $db → $e");
      }
    }

    return dbToOnlineOrdersMap;
  }

  // Inside your main widget's state (e.g. _MyAppState or your dashboard page)
  Map<String, List<KotSummaryReport>> dbToKotSummaryMap = {};
  List<KotSummaryReport> allOrders = [];
  List<KotSummaryReport> activeOrders = [];

// In your async function (e.g. initState or after user login)
  void fetchAllKOTOrders(Config config, List<String> dbNames, String startDate, String endDate) async {
    dbToKotSummaryMap = await UserData.fetchKotSummaryForDbs(config, dbNames, startDate, endDate);
    allOrders = dbToKotSummaryMap.values.expand((x) => x).toList();
    activeOrders = allOrders.where((o) => o.kotStatus == "active").toList();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merchant Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.poppins().fontFamily,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD5282B)),
      ),
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/dashboard') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => Dashboard(dbToBrandMap: args['dbToBrandMap']),
          );
        }
        // Add more routes here as needed
        return null;
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserData>>(
      future:
      Config.loadFromAsset().then((config) => UserData.fetchUsers(config)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFD5282B),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/images/reddpos.png", height: 120),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')));
        } else {
          return ResponsiveLoginPage(users: snapshot.data!);
        }
      },
    );
  }
}

class ResponsiveLoginPage extends StatelessWidget {
  final List<UserData> users;

  const ResponsiveLoginPage({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine layout based on screen size
    if (screenWidth < 600) {
      return LoginPageMobile(users: users);
    } else {
      return LoginPageDesktop(users: users);
    }
  }
}

// Desktop Login Page
class LoginPageDesktop extends ConsumerStatefulWidget {
  final List<UserData> users;

  const LoginPageDesktop({super.key, required this.users});

  @override
  ConsumerState<LoginPageDesktop> createState() => _LoginPageDesktopState();
}

class _LoginPageDesktopState extends ConsumerState<LoginPageDesktop> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  String? errorMessage;

  Future<void> login(BuildContext context, WidgetRef ref) async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final matchedUsers = widget.users.where((u) =>
    u.username.toLowerCase() == username.toLowerCase() &&
        u.password == password).toList();

    if (matchedUsers.isNotEmpty) {
      final dbNames =
      matchedUsers.map((user) => user.dbName).toSet().toList();
      ref.read(dbNamesProvider.notifier).state = dbNames;
      final config = await Config.loadFromAsset();
      final dbToBrandMap = await UserData.fetchBrandNames(config, dbNames);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => Dashboard(dbToBrandMap: dbToBrandMap), // Pass dbToBrandMap
        ),      );
    } else {
      setState(() {
        errorMessage = "Invalid username or password.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEDEB),
      body: Center(
        child: Row(
          children: [
            // Left Side: Image and Content
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/reddpos.png',
                      width: 120,
                      height: 120,
                    ),
                    Container(
                      width: 550, // Set the width explicitly
                      child: Image.asset(
                        'assets/images/login.png',
                        fit: BoxFit.fill,  // Ensures the image stretches to fill the space
                        height: 500, // Keep the height fixed or adjust
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right Side: Form
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Sign in",
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Username Field with Icon
                      TextField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          hintText: "Username",
                          prefixIcon: Icon(
                            Icons.person, // Icon for username field
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Field with Icon
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: "Password",
                          prefixIcon: Icon(
                            Icons.lock, // Icon for password field
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign In Button with Icon
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => login(context, ref),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD5282B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.login, // Icon for the sign-in button
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10), // Space between icon and text
                              const Text(
                                "Sign in",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Error message (if any)
                      if (errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),


                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}


class LoginPageMobile extends ConsumerStatefulWidget {
  final List<UserData> users;

  const LoginPageMobile({super.key, required this.users});

  @override
  ConsumerState<LoginPageMobile> createState() => _LoginPageMobileState();
}

class _LoginPageMobileState extends ConsumerState<LoginPageMobile> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? errorMessage;

  void login(BuildContext context, WidgetRef ref) {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final matchedUsers = widget.users.where((u) =>
    u.username.toLowerCase() == username.toLowerCase() &&
        u.password == password).toList();

    if (matchedUsers.isNotEmpty) {
      final dbNames = matchedUsers.map((user) => user.dbName).toSet().toList();
      ref.read(dbNamesProvider.notifier).state = dbNames;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Dashboard(dbToBrandMap: {},)),
      );
    } else {
      setState(() {
        errorMessage = "Invalid username or password.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEDEB),
      body: SingleChildScrollView(
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Red POS Logo
              Positioned(
                left: 10,
                top: 20,
                child: Image.asset(
                  'assets/images/reddpos.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  margin: const EdgeInsets.only(top: 200, left: 10, right: 30),
                  padding: const EdgeInsets.all(24),
                  width: 320,  // Adjust the width to make it smaller
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Image
                      SizedBox(
                        width: double.infinity,
                        height: 100,
                        child: Image.asset(
                          'assets/images/mobiletop.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        "Sign in",
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Username Field
                      TextField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          hintText: "Username",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: "Password",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 24),

                      // Sign in Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => login(context, ref),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD5282B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Sign in",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.w500)),
                      ]
                    ],
                  ),
                ),
              ),

              // Man Image (b.png)
              Positioned(
                right: -30,
                top: 240,
                child: SizedBox(
                  height: 340,
                  child: Image.asset(
                    'assets/images/b.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Top-right Image (c.png)
              Positioned(
                right: 10,
                top: 20,
                child: Image.asset(
                  'assets/images/c.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                right: 10,
                bottom: -200,
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.1), // Adjust darkness
                    BlendMode.modulate, // Darkens image pixels
                  ),
                  child: Image.asset(
                    'assets/images/d.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
