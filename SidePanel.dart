import 'package:flutter/material.dart';
import 'package:merchant/KOTPage.dart';
import 'package:merchant/KotSummaryReport.dart';
import 'package:merchant/OnlineOrderRunningPage.dart';
import 'package:merchant/ReportPage.dart';
import 'package:merchant/RunningOrderPage.dart';

// Import your RunningOrderPage at the top

class SidePanel extends StatefulWidget {
  final Widget child;
  final Map<String, String> dbToBrandMap; // Add this to pass to RunningOrderPage
  final List<KotSummaryReport>? activeOrders; // <-- make optional with ?

  const SidePanel({super.key, required this.child, required this.dbToBrandMap, this.activeOrders,});

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  bool isPanelOpen = false; // Panel initially closed

  // State for collapsible sections
  final Map<String, bool> sectionStates = {
    "Daily Operations": false,
    "Menu": false,
    "Management": false,
    "CRM": false,
  };

  void togglePanel() {
    setState(() {
      isPanelOpen = !isPanelOpen;
    });
  }

  void toggleSection(String section) {
    setState(() {
      sectionStates[section] = !(sectionStates[section] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content (touches the edge of the panel)
          GestureDetector(
            onTap: () {
              if (isPanelOpen) {
                togglePanel(); // Close panel when tapping outside
              }
            },
            child: Container(
              color: Colors.grey[200],
              child: widget.child,
            ),
          ),

          // Side Panel: Animated sliding from left to right
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: isPanelOpen ? 0 : -250, // Panel opens from left to right
            top: 0,
            bottom: 0,
            child: Material(
              elevation: 4,
              child: Container(
                width: 250,
                color: Colors.white,
                child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Dashboard
                    _buildNavItem(
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      onTap: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/dashboard',
                          arguments: {'dbToBrandMap': widget.dbToBrandMap},
                        );
                      },
                    ),
                    const Divider(),

                    // Daily Operations Section
                    _buildCollapsibleSection(
                      title: "Daily Operations",
                      items: [
                        // In SidePanel.dart, inside _buildNavItem for Running Orders:
                        _buildNavItem(
                          icon: Icons.access_time,
                          label: "Running Orders",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RunningOrderPage(
                                  dbToBrandMap: widget.dbToBrandMap),
                              ),
                            );
                          },
                        ),

                        _buildNavItem(
                          icon: Icons.language,
                          label: "Online Orders",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OnlineOrderRunningPage(
                                  dbToBrandMap: widget.dbToBrandMap,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildNavItem(
                          icon: Icons.language,
                          label: "KOT",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KOTPage(
                                  dbToBrandMap: widget.dbToBrandMap,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildNavItem(
                          icon: Icons.store,
                          label: "Menu & Store Actions",
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/menu-store-actions');
                          },
                        ),
                      ],
                    ),

                    const Divider(),

                    // Menu Section
                    _buildCollapsibleSection(
                      title: "Menu",
                      items: [
                        _buildNavItem(
                          icon: Icons.track_changes,
                          label: "Store Status Tracking",
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/store-status-tracking');
                          },
                        ),
                        _buildNavItem(
                          icon: Icons.inventory,
                          label: "Item Out of Stock Tracking",
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/stock-tracking');
                          },
                        ),
                      ],
                    ),
                    const Divider(),

                    _buildNavItem(
                      icon: Icons.bar_chart,
                      label: "Reports",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportPage(
                              dbToBrandMap: widget.dbToBrandMap,
                            ),
                          ),
                        );
                      },
                    ),

                    const Divider(),

                    // Management Section
                    _buildCollapsibleSection(
                      title: "Management",
                      items: [
                        _buildNavItem(
                          icon: Icons.person,
                          label: "User Logs",
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/user-logs');
                          },
                        ),
                        _buildNavItem(
                          icon: Icons.add_location_alt,
                          label: "Create Zone",
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/create-zone');
                          },
                        ),
                        _buildNavItem(
                          icon: Icons.apps,
                          label: "Petpooja APPs",
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/petpooja-apps');
                          },
                        ),
                      ],
                    ),

                    const Divider(),

                    // CRM Section
                    _buildCollapsibleSection(
                      title: "CRM",
                      items: [
                        _buildNavItem(
                          icon: Icons.business,
                          label: "Google Business",
                          extraLabel: "Beta",
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/google-business');
                          },
                        ),
                        _buildNavItem(
                          icon: Icons.star,
                          label: "Reputation",
                          extraLabel: "Beta",
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/reputation');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
    ),
              ),
            ),
          ),

          // Hamburger Menu Icon (top-right corner)
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: togglePanel, // Toggle the side panel
              child: Icon(
                isPanelOpen ? Icons.close : Icons.menu, // Change between close and menu icon
                size: 30,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Collapsible section widget
  Widget _buildCollapsibleSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        ListTile(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Icon(
            sectionStates[title] ?? false ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          ),
          onTap: () => toggleSection(title),
        ),

        // Section Items (collapsible)
        if (sectionStates[title] ?? false) Column(children: items),
      ],
    );
  }

  // Navigation item widget
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? extraLabel,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Row(
        children: [
          Text(label),
          if (extraLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                extraLabel,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}