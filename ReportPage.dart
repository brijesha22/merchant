import 'package:flutter/material.dart';
import 'SidePanel.dart';

class ReportPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const ReportPage({Key? key, required this.dbToBrandMap}) : super(key: key);

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String? selectedBrand = "All";
  String searchQuery = "";

  // Example reports list (added more dummy reports)
  final List<ReportItem> allReports = [
    ReportItem(
      id: 1,
      name: "All Restaurant Sales Report",
      group: "All Restaurant Report",
      description: "Total sales of all your restaurant",
    ),
    ReportItem(
      id: 2,
      name: "Outlet-Item Wise Report (Row)",
      group: "All Restaurant Report",
      description: "Consolidated Summary of Item sales with outlets in row format",
    ),
    ReportItem(
      id: 3,
      name: "Invoice Report: All Restaurants",
      group: "All Restaurant Report",
      description: "Invoices for all outlets in one place",
    ),
    ReportItem(
      id: 4,
      name: "Pax Sales Report: Biller Wise",
      group: "All Restaurant Report",
      description: "Biller wise summary for all outlets",
    ),
    ReportItem(
      id: 5,
      name: "GST Summary Report",
      group: "All Restaurant Report",
      description: "GST summary for all sales and returns",
    ),
    ReportItem(
      id: 6,
      name: "Order Cancellation Report",
      group: "All Restaurant Report",
      description: "Cancelled orders and reasons grouped by outlet",
    ),
    ReportItem(
      id: 7,
      name: "KOT Pending Report",
      group: "All Restaurant Report",
      description: "Pending KOTs for all outlets",
    ),
    ReportItem(
      id: 8,
      name: "Discount Report",
      group: "All Restaurant Report",
      description: "Discounts given outlet-wise and bill-wise",
    ),
    ReportItem(
      id: 9,
      name: "Payment Mode Wise Report",
      group: "All Restaurant Report",
      description: "Sales split by payment mode",
    ),
  ];

  Set<int> favorites = {}; // report IDs marked as favorite
  String selectedReportGroup = "All Restaurant Report";

  @override
  Widget build(BuildContext context) {
    final brandNames = widget.dbToBrandMap.values.toSet();
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;

    // Filter reports according to favorite, group, and search
    final List<ReportItem> groupReports = allReports
        .where((r) =>
    r.group == selectedReportGroup &&
        (searchQuery.isEmpty ||
            r.name.toLowerCase().contains(searchQuery.toLowerCase())))
        .toList();

    final List<ReportItem> favoriteReports = allReports
        .where((r) => favorites.contains(r.id))
        .where((r) => searchQuery.isEmpty || r.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return SidePanel(
      dbToBrandMap: widget.dbToBrandMap,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            child: Row(
              children: [
                SizedBox(width: isMobile ? 8 : 16),
                Image.asset(
                  'assets/images/reddpos.png',
                  height: isMobile ? 30 : 40,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 80,
                      maxWidth: 200,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedBrand,
                        hint: const Text(
                          "All Outlets",
                          style: TextStyle(color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: "All",
                            child: Text("All Outlets"),
                          ),
                          ...brandNames.map((brand) => DropdownMenuItem(
                            value: brand,
                            child: Text(
                              brand,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedBrand = value;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        body: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 900;
              return Row(
                children: [
                  // LEFT: Report nav column
                  Container(
                    width: isMobile ? 180 : 290,
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Favourites
                        InkWell(
                          onTap: () => setState(() => selectedReportGroup = "Favourite"),
                          child: Container(
                            padding: const EdgeInsets.only(left: 24, top: 26, bottom: 12),
                            decoration: BoxDecoration(
                              border: selectedReportGroup == "Favourite"
                                  ? const Border(
                                  left: BorderSide(
                                      color: Color(0xFFD5282B), width: 3))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.star_border,
                                    color: selectedReportGroup == "Favourite"
                                        ? const Color(0xFFD5282B)
                                        : Colors.black54),
                                const SizedBox(width: 10),
                                Text(
                                  "Favourite",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: selectedReportGroup == "Favourite"
                                        ? const Color(0xFFD5282B)
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // All Restaurant Report
                        InkWell(
                          onTap: () => setState(() => selectedReportGroup = "All Restaurant Report"),
                          child: Container(
                            padding: const EdgeInsets.only(left: 24, top: 8, bottom: 8),
                            decoration: BoxDecoration(
                              border: selectedReportGroup == "All Restaurant Report"
                                  ? const Border(
                                  left: BorderSide(
                                      color: Color(0xFFD5282B), width: 3))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.restaurant_menu, color: Colors.black54),
                                const SizedBox(width: 10),
                                Text(
                                  "All Restaurant Report",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: selectedReportGroup == "All Restaurant Report"
                                        ? const Color(0xFFD5282B)
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  // RIGHT: Main content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search bar and settings
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F8FE),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "Search for reports here...",
                                      hintStyle: TextStyle(color: Colors.grey),
                                      prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                                    ),
                                    onChanged: (value) {
                                      setState(() => searchQuery = value);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(5),
                                onTap: () {}, // settings
                                child: Container(
                                  width: 38,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F8FE),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Icon(Icons.settings, color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  // FAVOURITE SECTION AT TOP, REST BELOW
                                  if (selectedReportGroup == "All Restaurant Report" && favoriteReports.isNotEmpty) ...[
                                    // FAVOURITE REPORTS SCROLLABLE ROW
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4, bottom: 0),
                                            child: Text(
                                              "Favourite",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                  color: Colors.black87),
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4, bottom: 6),
                                            child: Text(
                                              "All reports which are marked as favorites to refer frequently",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w400,
                                                  fontSize: 14,
                                                  color: Colors.black54),
                                            ),
                                          ),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: favoriteReports.map((r) =>
                                                  Container(
                                                    margin: const EdgeInsets.only(right: 12),
                                                    width: isMobile ? 350 : 420,
                                                    child: _reportCard(r, isFavorite: true, compact: true),
                                                  ),
                                              ).toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  // ALL RESTAURANT REPORT SECTION
                                  if (selectedReportGroup == "All Restaurant Report") ...[
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8, left: 4, bottom: 7),
                                      child: Text(
                                        "All Restaurant Report",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                            color: Colors.black87),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4, bottom: 18),
                                      child: Text(
                                        "Get insights to all your restaurant & sales related activities",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 15,
                                            color: Colors.black54),
                                      ),
                                    ),
                                    GridView.count(
                                      crossAxisCount: isMobile ? 1 : 2,
                                      crossAxisSpacing: 18,
                                      mainAxisSpacing: 17,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      childAspectRatio: isMobile ? 2.7 : 2.6,
                                      children: groupReports
                                          .where((r) => !favorites.contains(r.id))
                                          .map((r) => _reportCard(r, isFavorite: false))
                                          .toList(),
                                    ),
                                  ],
                                  // FAVOURITE PAGE (when left menu is on Favourite)
                                  if (selectedReportGroup == "Favourite") ...[
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 32),
                                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 26),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: favoriteReports.isEmpty
                                          ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Favourites empty illustration
                                          Icon(Icons.folder_special_outlined,
                                              size: 64, color: Colors.pink[200]),
                                          const SizedBox(height: 16),
                                          const Text(
                                            "There Are No Favorite Report",
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 18,
                                                color: Colors.black87),
                                          ),
                                          const SizedBox(height: 7),
                                          const Text(
                                            "Add Reports to Favorite by selecting the star mark",
                                            style: TextStyle(
                                                fontWeight: FontWeight.w400,
                                                fontSize: 15,
                                                color: Colors.black54),
                                          ),
                                        ],
                                      )
                                          : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: favoriteReports
                                            .map((r) => _reportCard(r, isFavorite: true))
                                            .toList(),
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
                ],
              );
            }
        ),
      ),
    );
  }

  Widget _reportCard(ReportItem r, {required bool isFavorite, bool compact = false}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[300]!)),
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 9 : 16,
          horizontal: compact ? 12 : 18,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon/Sticker
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Icon(Icons.receipt_long, color: Colors.pink[200], size: 28),
            ),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (favorites.contains(r.id)) {
                              favorites.remove(r.id);
                            } else {
                              favorites.add(r.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite ? const Color(0xFFD5282B) : Colors.grey,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, bottom: 7),
                    child: Text(
                      r.description,
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD5282B),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                      ),
                      onPressed: () {},
                      child: const Text("View Details"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportItem {
  final int id;
  final String name;
  final String group;
  final String description;

  ReportItem({
    required this.id,
    required this.name,
    required this.group,
    required this.description,
  });
}