import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sample/kot_model.dart';
import 'package:flutter_sample/main_menu.dart' as mm;
import 'package:http/http.dart' as http;
import 'package:flutter_sample/table_selection.dart';
import 'Costcenter_model.dart';
import 'FireConstants.dart';
import 'OrderModifier.dart';
import 'Order_Item_model.dart';
import 'ReceiptView.dart';
import 'package:flutter_mosambee_aar/flutter_mosambee_aar.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'list_of_product_screen.dart';
import 'main_menu.dart';
import 'main_menu_desk.dart';
import 'package:collection/collection.dart';
/*class SelectedProduct {
  String name;
  double price;
  int quantity;
  String code;
  String notes;
  String costCenterCode;
  SelectedProduct({
    required this.name,
    required this.price,
    required this.quantity,
    required this.code,
    required this.notes,
    required this.costCenterCode,
  });
}
class SelectedProductModifier {
  String code;
  int quantity;
  String name;
  double price_per_unit;
  String product_code;
  dynamic order_id;
  SelectedProductModifier({
    required this.code,
    required this.quantity,
    required this.name,
    required this.price_per_unit,
    required this.product_code,
    required this.order_id,
  });
}*/
/*class BillItem {
  String productCode;
  int quantity;
  double price;
  String itemName;
  double totalPrice;
  String? billItemId;
  BillItem({
    required this.productCode,
    required this.quantity,
    required this.price,
    required this.itemName,
    required this.totalPrice,
    this.billItemId,
  });
}*/
class TableItem {
  final String tableName;
  final String area;
  final String status;
  final int id;
  final double pax;
  TableItem({required this.tableName,required this.area,required this.status,required this.id,required this.pax});

  factory TableItem.fromMap(Map<String, dynamic> map) {
    return TableItem(
      tableName: map['tableName'],
      area: map['area'],
      status: map['status'],
      pax: map['pax'],
      id: map['id'],

    );
  }
  Map<String, dynamic> toJson() {
    return {
      'tableName': tableName,
      'area': area,
      'status': status,
      'pax': pax,
      'id': id,
    };
  }

}

bool _isLoading = true;
List<SelectedProductModifier> allbillmodifers = [];
List<BillItem> allbillitems = [];

class BusyTableScreen extends StatelessWidget {
  const BusyTableScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final Map<String, String> receivedStrings = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
    return Busytablescreen(receivedStrings: receivedStrings);
  }
}

class Busytablescreen extends StatefulWidget {
  final Map<String, String> receivedStrings;
  const Busytablescreen({super.key, required this.receivedStrings});
  @override
  State<Busytablescreen> createState() => _BusytablescreenState();
}

class _BusytablescreenState extends State<Busytablescreen> {
  List<String> selectedKOTIds = [];
  List<SelectedProduct> selectedProducts = [];
  List<SelectedProductModifier> selectedModifiers = [];
  Map<String, Map<String, TextEditingController>> qtyControllers = {};
  String ccname = '';
  Future<void> cancelkot(String kotid) async {
    print("[CANCEL KOT] Attempting to cancel KOT: $kotid");
    final response = await http.get(Uri.parse('${apiUrl}order/cancelkot/$kotid?DB=$CLIENTCODE'));
    print("[CANCEL KOT] Response: ${response.statusCode} ${response.body}");
    if (response.statusCode != 200) throw Exception('Failed to cancel KOT');
  }

  Future<void> freetable() async {
    print("[FREE TABLE] Freeing table: ${widget.receivedStrings['id']}");
    final String url2 = '${apiUrl}table/update/${widget.receivedStrings['id']!}?DB=$CLIENTCODE';
    final Map<String, dynamic> data2 = {
      "tableName": widget.receivedStrings['name'],
      "status": "Normal",
      "id": widget.receivedStrings['id'],
      'area': widget.receivedStrings['area'],
      "pax": widget.receivedStrings['pax'] ?? 0,
    };
    final headers = {'Content-Type': 'application/json'};
    final response = await http.put(Uri.parse(url2), headers: headers, body: jsonEncode(data2));
    print("[FREE TABLE] Response: ${response.statusCode} ${response.body}");
  }

  String trimedtime(String time) {
    int index = time.indexOf(' ');
    int index2 = time.indexOf('.');
    return time.substring(index + 1, index2);
  }

  Future<List<Kot>> fetchKots(String tablenumber) async {
    final response = await http.get(Uri.parse('${apiUrl}order/kotbytable/$tablenumber?DB=$CLIENTCODE'));
    if (response.statusCode == 200) {
      final parsed = json.decode(response.body).cast<Map<String, dynamic>>();
      return parsed.map<Kot>((json) => Kot.fromMap(json)).toList();
    } else {
      throw Exception('Failed to load Product');
    }
  }

  Future<List<OrderItem>> fetchKotItemsLatest(String tablenumber) async {
    allbillitems.clear();
    selectedProducts.clear();
    final response = await http.get(Uri.parse('${apiUrl}order/bytable/$tablenumber?DB=$CLIENTCODE'));
    if (response.statusCode == 200) {
      final parsed = json.decode(response.body).cast<Map<String, dynamic>>();
      List<OrderItem> toreturn = parsed.map<OrderItem>((json) => OrderItem.fromMap(json)).toList();
      for (OrderItem item in toreturn) {
        double tempitemtotal = item.quantity! * item.price!.toDouble();
        BillItem billItem = BillItem(
          productCode: item.itemCode.toString(),
          quantity: item.quantity ?? 0,
          price: item.price ?? 0,
          itemName: item.itemName.toString(),
          totalPrice: tempitemtotal,
          billItemId:""?? "",
        );
        allbillitems.add(billItem);
      }
      for (OrderItem item in toreturn) {
        selectedProducts.add(SelectedProduct(
          name: item.itemName.toString(),
          price: item.price ?? 0,
          quantity: item.quantity ?? 0,
          code: item.itemCode.toString(),
          notes: item.orderNumber.toString(),
          costCenterCode: item.costCenterCode.toString(),
        ));
      }
      _isLoading = false;
      return toreturn;
    } else {
      throw Exception('Failed to load Product');
    }
  }

  Future<List<OrderModifier>> fetchKotModifiersLatest(String tablenumber) async {
    allbillmodifers.clear();
    final response = await http.get(Uri.parse('${apiUrl}order/modifierbytable/$tablenumber?DB=$CLIENTCODE'));
    if (response.statusCode == 200) {
      final parsed = json.decode(response.body).cast<Map<String, dynamic>>();
      List<OrderModifier> toreturn = parsed.map<OrderModifier>((json) => OrderModifier.fromMap(json)).toList();
      for (OrderModifier item in toreturn) {
        SelectedProductModifier modifierItem = SelectedProductModifier(
          code: item.productCode.toString(),
          quantity: item.quantity ?? 0,
          name: item.name,
          price_per_unit: double.parse(item.pricePerUnit),
          product_code: item.productCode.toString(),
          order_id: item.kotId.kotId,
        );
        allbillmodifers.add(modifierItem);
      }
      _isLoading = false;
      return toreturn;
    } else {
      throw Exception('Failed to load Product');
    }
  }

  Future<List<OrderItem>> fetchKotItems(String tablenumber) async {
    selectedProducts.clear();
    final response = await http.get(Uri.parse('${apiUrl}order/bytable/$tablenumber?DB=$CLIENTCODE'));
    if (response.statusCode == 200) {
      final parsed = json.decode(response.body);
      List<OrderItem> toreturn = [];
      if (parsed is List) {
        toreturn = parsed.map<OrderItem>((json) => OrderItem.fromMap(json)).toList();
      } else if (parsed is Map<String, dynamic>) {
        toreturn = [OrderItem.fromMap(parsed)];
      }
      for (OrderItem item in toreturn) {
        selectedProducts.add(SelectedProduct(
          name: item.itemName.toString(),
          price: item.price ?? 0,
          quantity: item.quantity ?? 0,
          code: item.itemCode.toString(),
          notes: item.orderNumber.toString(),
          costCenterCode: item.costCenterCode.toString(),
        ));
      }
      return toreturn;
    } else {
      throw Exception('Failed to load Product');
    }
  }

  Future<List<TableItem>> fetchAllTables(String dbCode) async {
    final response = await http.get(Uri.parse('${apiUrl}table/getAll?DB='+CLIENTCODE));
    if (response.statusCode == 200) {
      final parsed = json.decode(response.body).cast<Map<String, dynamic>>();
      List<TableItem> toReturn = parsed.map<TableItem>((json) => TableItem.fromMap(json)).toList();
      return toReturn;
    } else {
      throw Exception('Failed to load tables');
    }
  }
  Future<bool> moveTable(BuildContext context, String existingTableNo, String newTableNo, String db) async {
    print("[MOVE TABLE] Moving all KOTs from Table $existingTableNo to $newTableNo");
    final response = await http.put(
      Uri.parse('${apiUrl}order/movetable?existingTableNo=$existingTableNo&newTableNo=$newTableNo&DB=$db'),
    );
    print("[MOVE TABLE] Response: ${response.statusCode} ${response.body}");
    return response.statusCode == 200;
  }

  Future<bool> moveKot(String kotId, String existingTableNo, String newTableNo) async {
    print("[MOVE KOT] Moving KOT $kotId from Table $existingTableNo to $newTableNo");
    final response = await http.put(
      Uri.parse('${apiUrl}order/movekot?kotId=$kotId&existingTableNo=$existingTableNo&newTableNo=$newTableNo&DB=$CLIENTCODE'),
    );
    print("[MOVE KOT] Response: ${response.statusCode} ${response.body}");
    return response.statusCode == 200;
  }

  Future<bool> moveItem(String kotId, String itemCode, String existingTableNo, String newTableNo, int qty) async {
    print("[MOVE ITEM] Moving item $itemCode (qty $qty) from KOT $kotId Table $existingTableNo to $newTableNo");
    final response = await http.put(
      Uri.parse('${apiUrl}order/moveitem?kotId=$kotId&itemCode=$itemCode&existingTableNo=$existingTableNo&newTableNo=$newTableNo&qty=$qty&DB=$CLIENTCODE'),
    );
    print("[MOVE ITEM] Response: ${response.statusCode} ${response.body}");
    return response.statusCode == 200;
  }

  Future<bool> cancelItem(String kotId, String itemCode, int tableNo, int cancelQty) async {
    print("[CANCEL ITEM] Cancelling item $itemCode from KOT $kotId Table $tableNo (qty $cancelQty)");
    final response = await http.put(
      Uri.parse('${apiUrl}order/cancelitem?kotId=$kotId&itemCode=$itemCode&tableNo=$tableNo&cancelQty=$cancelQty&DB=$CLIENTCODE'),
    );
    print("[CANCEL ITEM] Response: ${response.statusCode} ${response.body}");
    return response.statusCode == 200;
  }
  void exitToMainMenu(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesk = size.width > size.height;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => isDesk ? MainMenuDesk() : mm.MainMenu(),
      ),
          (route) => false,
    );
  }


  Future<void> printTicket(List<int> ticket, String targetip) async {
    final printer = PrinterNetworkManager(targetip);
    PosPrintResult connect = await printer.connect();
    if (connect == PosPrintResult.success) {
      PosPrintResult printing = await printer.printTicket(ticket);
      print(printing.msg);
      printer.disconnect();
    }
  }

  Future<List<String>> getPrinterIPsByCode(String code) async {
    List<String> printers = [];

    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    List<Costcenter> costcenters;

    if (screenWidth > screenHeight) {
      costcenters = await futureCostcentersWindows;
    } else {
      costcenters = await futureCostcenters;
    }

    for (var costcenter in costcenters) {
      if (costcenter.code == code) {
        ccname = costcenter.name;
        int copies = costcenter.noOfcopies ?? 1;
        print('primary printer: $copies');


        if (costcenter.printerip1 != null && costcenter.printerip1!.isNotEmpty) {
          for (int i = 0; i < copies; i++) {
            printers.add(costcenter.printerip1!);
          }
        }
        if (costcenter.printerip2 != null && costcenter.printerip2!.isNotEmpty) {
          printers.add(costcenter.printerip2!);
        }
        if (costcenter.printerip3 != null && costcenter.printerip3!.isNotEmpty) {
          printers.add(costcenter.printerip3!);
        }
      }
    }

    return printers;
  }
  Future<void> printKOTWithHeading({
    required String heading,
    required String kotno,
    required List<SelectedProduct> items,
    required List<SelectedProductModifier> modifiers,
    required String tableno,
    String? moveTableName,
  })
  async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    String prefix = kotno.length > 3 ? kotno.substring(0, kotno.length - 3) : kotno;
    String suffix = kotno.length > 3 ? kotno.substring(kotno.length - 3) : '';
    String cccode = items.isNotEmpty ? items[0].costCenterCode.toString() : '';
    List<String> printers = await getPrinterIPsByCode(cccode);


    // Inside printKOTWithHeading:
    if (heading == "DUPLICATE") {
      bytes += generator.text(heading,
          styles: const PosStyles(
            fontType: PosFontType.fontB,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            align: PosAlign.center,
          ));
    } else {
      bytes += generator.text(heading,
          styles: const PosStyles(
            fontType: PosFontType.fontB,
            bold: true,
            height: PosTextSize.size3,
            width: PosTextSize.size3,
            align: PosAlign.center,
          ));
    }

    bytes += generator.text('',
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));
    bytes += generator.text(brandName,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.center,
        ));
    bytes += generator.text('',
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));
    bytes += generator.text(ccname,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ));
    bytes += generator.text('',
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ));
    bytes += generator.text('Dine-In',
        styles: const PosStyles(
          fontType: PosFontType.fontB,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.center,
        ));

    bytes += generator.text('_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ', styles: const PosStyles());

    bytes += generator.row([
      PosColumn(
        text: 'KOT No      :',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: '$prefix$suffix',
        width: 8,
        styles: const PosStyles(
          fontType: PosFontType.fontB,
          bold: false,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.left,
        ),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        text: 'Table No    :',

        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: tableno,
        width: 8,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.left,
        ),
      ),

    ]);
    bytes += generator.row([
      PosColumn(
        text: 'KOT By      :',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: '$username',
        width: 8,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),

    ]);
    bytes += generator.row([
      PosColumn(
        text: 'Waiter      :',

        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: selectedwaitername,
        width: 8,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),

    ]);
    bytes += generator.row([
      PosColumn(
        text: 'Date & Time :',
        width: 4,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: DateFormat('dd-MM-yyyy hh:mm:ss a').format(DateTime.now()),
        width: 8,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),

    ]);
    bytes += generator.text('_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _', styles: const PosStyles());

    bytes += generator.row([
      PosColumn(
        text: 'Qty',
        width: 2,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: 'Item Name',
        width: 9,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: '' + ' ',
        width: 1,
        styles: const PosStyles(
          fontType: PosFontType.fontB,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.center,
        ),
      ),
    ]);
    bytes += generator.text('_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _', styles: const PosStyles());

    for (SelectedProduct item in items) {
      final itemModifiers = modifiers
          .where((modifier) => modifier.product_code == item.code)
          .toList();

      bytes += generator.row([
        PosColumn(
          text: item.quantity.toString(),
          width: 2,
          styles: const PosStyles(
            fontType: PosFontType.fontB,
            align: PosAlign.left,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
        PosColumn(
          text: item.name,
          width: 9,
          styles: const PosStyles(
            fontType: PosFontType.fontB,
            align: PosAlign.left,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        ),
        PosColumn(
          text: '',
          width: 1,
          styles: const PosStyles(),
        ),
      ]);
      bytes += generator.text('', styles: const PosStyles());

      for (SelectedProductModifier modi in itemModifiers) {
        bytes += generator.row([
          PosColumn(
            text: modi.price_per_unit > 0 ? '>>' : '>',
            width: 2,
            styles: const PosStyles(
              fontType: PosFontType.fontB,
              align: PosAlign.left,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          ),
          PosColumn(
            text: '${modi.quantity} x ${modi.name}',
            width: 9,
            styles: const PosStyles(
              fontType: PosFontType.fontB,
              align: PosAlign.left,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          ),
          PosColumn(
            text: '',
            width: 1,
            styles: const PosStyles(),
          ),
        ]);
        bytes += generator.text('', styles: const PosStyles());
      }
    }

    bytes += generator.text('_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _  _ _ _ _ _ _ _ _ _ _ _ _', styles: const PosStyles());
    bytes += generator.feed(1);
    bytes += generator.cut();

    await printTicket(bytes, "192.168.1.222");
  }

  Future<void> printKOTWithMosambee({
    required String kotno,
    required List<SelectedProduct> items,
    required List<SelectedProductModifier> modifiers,
    required String tableno,
    required String waiterName,
    required String ccName,
    required String brandName,
    required String username,
  }) async {
    try {
      print("[MOSAMBEE] Opening printer...");
      FlutterMosambeeAar.openPrinter();

      print("[MOSAMBEE] Getting printer state...");
      int? state = await FlutterMosambeeAar.getPrinterState();
      print("[MOSAMBEE] State: $state");

      FlutterMosambeeAar.setPrintFont("/system/fonts/Android-1.ttf");
      FlutterMosambeeAar.setPrintGray(2000);
      FlutterMosambeeAar.setLineSpace(5);

      // Header
      FlutterMosambeeAar.printText2("KOT", FlutterMosambeeAar.PRINTLINE_CENTER);
      FlutterMosambeeAar.printText4(brandName, FlutterMosambeeAar.PRINTLINE_CENTER, 30, true);
      FlutterMosambeeAar.printText2(ccName, FlutterMosambeeAar.PRINTLINE_CENTER);
      FlutterMosambeeAar.printText2("Dine-In", FlutterMosambeeAar.PRINTLINE_CENTER);

      FlutterMosambeeAar.printText2(
          "__________________________________", FlutterMosambeeAar.PRINTLINE_CENTER);

      // KOT Details
      FlutterMosambeeAar.printText2("KOT No: $kotno", FlutterMosambeeAar.PRINTLINE_LEFT);
      FlutterMosambeeAar.printText2("Table No: $tableno", FlutterMosambeeAar.PRINTLINE_LEFT);

      // Waiter line
      FlutterMosambeeAar.printText2("KOT By: $username", FlutterMosambeeAar.PRINTLINE_LEFT);
      FlutterMosambeeAar.printText2("Waiter: $waiterName", FlutterMosambeeAar.PRINTLINE_LEFT);

      // Format Date & Time with intl
      String formattedDateTime = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());

      FlutterMosambeeAar.printText2("Date & Time: $formattedDateTime", FlutterMosambeeAar.PRINTLINE_LEFT);

      FlutterMosambeeAar.printText2(
          "__________________________________", FlutterMosambeeAar.PRINTLINE_CENTER);

      FlutterMosambeeAar.printList("Qty", "Item Name", "", 24, true);

      FlutterMosambeeAar.printText2(
          "__________________________________", FlutterMosambeeAar.PRINTLINE_CENTER);

      // Items loop
      int lineWidth = 32; // or 24 or whatever your printer supports

      for (SelectedProduct item in items) {
        String qty = "${item.quantity}";
        String name = item.name;

        // Calculate padding
        int spaces = lineWidth - qty.length - name.length;
        if (spaces < 1) spaces = 1;
        String line = qty + " " * spaces + name;

        FlutterMosambeeAar.printText2(line, FlutterMosambeeAar.PRINTLINE_LEFT);

        // Modifiers for this item
        final itemModifiers = modifiers.where((m) => m.product_code == item.code).toList();
        for (SelectedProductModifier modi in itemModifiers) {
          FlutterMosambeeAar.printList(
              modi.price_per_unit > 0 ? ">>" : ">",
              "${modi.quantity} x ${modi.name}", "", 24, false
          );
        }
      }

      FlutterMosambeeAar.printText2(
          "__________________________________", FlutterMosambeeAar.PRINTLINE_CENTER);
      FlutterMosambeeAar.printText2("", FlutterMosambeeAar.PRINTLINE_CENTER);
      FlutterMosambeeAar.printText2("", FlutterMosambeeAar.PRINTLINE_CENTER);
      FlutterMosambeeAar.printText2("", FlutterMosambeeAar.PRINTLINE_CENTER);
      FlutterMosambeeAar.printText2("", FlutterMosambeeAar.PRINTLINE_CENTER);

      if (state != null && state == 4) {
        FlutterMosambeeAar.closePrinter();
        print("[MOSAMBEE] Printer closed (state 4)");
        return;
      }
      print("[MOSAMBEE] Calling beginPrint...");
      FlutterMosambeeAar.beginPrint();
      print("[MOSAMBEE] Mosambee print command sent!");
    } catch (e, stack) {
      print("[MOSAMBEE] Print failed: $e\n$stack");
    }
  }

  @override
  Widget build(BuildContext context) {
    mm.futurePost = mm.fetchPost();
    mm.futureCategory = mm.fetchCategory();
    Future<List<Kot>> futureKOTs = fetchKots(widget.receivedStrings['name']!);
    Future<List<OrderItem>> futureITEMs = fetchKotItemsLatest(widget.receivedStrings['name']!);
    Future<List<OrderModifier>> futureModifiers = fetchKotModifiersLatest(widget.receivedStrings['name']!);
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F8),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 0, bottom: 18, left: 18, right: 18),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Centered title text
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        "Table No. ${widget.receivedStrings['name']!}",
                        style: const TextStyle(
                          fontSize: 28,
                          color: Color(0xFFD5282B),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                  // Back arrow aligned to the left
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Icon(
                        Icons.arrow_back,
                        color: Color(0xFFD5282B),
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: Offset(0, -20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 14)],
                    ),
                    padding: EdgeInsets.all(10),
                    child: FutureBuilder<List<Kot>>(
                      future: futureKOTs,
                      builder: (context, snapshotkot) {
                        if (!snapshotkot.hasData) return Center(child: CircularProgressIndicator());
                        var kotList = snapshotkot.data!;
                        if (kotList.isEmpty) return Center(child: Text('No KOTs found'));
                        return FutureBuilder<List<OrderItem>>(
                          future: futureITEMs,
                          builder: (context, itemSnap) {
                            if (!itemSnap.hasData) return Center(child: CircularProgressIndicator());
                            var allItems = itemSnap.data!;
                            return FutureBuilder<List<OrderModifier>>(
                              future: futureModifiers,
                              builder: (context, modSnap) {
                                var allMods = modSnap.data ?? [];
                                return ListView.separated(
                                  itemCount: kotList.length,
                                  separatorBuilder: (_, __) => SizedBox(height: 16),
                                  itemBuilder: (context, idx) {
                                    Kot kot = kotList[idx];
                                    bool isChecked = selectedKOTIds.contains(kot.kotId.toString());
                                    var kotItems = allItems
                                        .where((item) => item.orderNumber == kot.kotId.toString())
                                        .toList();
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isChecked ? Color(0xFFD5282B) : Colors.grey[200]!,
                                        ),
                                      ),
                                      padding: EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Checkbox(
                                                value: isChecked,
                                                activeColor: Color(0xFFD5282B),
                                                onChanged: (val) {
                                                  setState(() {
                                                    if (val == true) {
                                                      selectedKOTIds.add(kot.kotId.toString());
                                                    } else {
                                                      selectedKOTIds.remove(kot.kotId.toString());
                                                    }
                                                  });
                                                },
                                              ),
                                              Text(
                                                "KOT ${kot.kotId}",
                                                style: TextStyle(
                                                  color: Color(0xFFD5282B),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Icon(Icons.timer, size: 16, color: Colors.grey),
                                              Text(
                                                trimedtime(kot.orderTime.toString()),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 3),
                                          Divider(),

                                          kotItems.isEmpty
                                              ? Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text('No items'),
                                          )
                                              : Column(
                                            children: [
                                              // 🔹 Column Labels
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 6),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        "Item",
                                                        style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.grey[700]),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        "Rate",
                                                        style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.grey[700]),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        "Qty",
                                                        style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.grey[700]),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        "Amount",
                                                        style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.grey[700]),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // 🔹 Item Rows
                                              ...kotItems.map((item) {
                                                double total =
                                                    (item.price ?? 0) * (item.quantity ?? 1);

                                                final itemModifiers = allMods.where((mod) =>
                                                mod.kotId.kotId.toString() == item.orderNumber &&
                                                    mod.productCode.toString() == item.itemCode.toString());
                                                return Column(
                                                  children: [
                                                    Padding(
                                                      padding: EdgeInsets.symmetric(vertical: 2.5),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                              flex: 3,
                                                              child: Text(item.itemName ?? "")),
                                                          Expanded(
                                                              child: Text(
                                                                  item.price?.toStringAsFixed(2) ?? "")),
                                                          Expanded(
                                                              child:
                                                              Text(item.quantity?.toString() ?? "")),
                                                          Expanded(
                                                            child: Text(
                                                              total.toStringAsFixed(2),
                                                              style: TextStyle(
                                                                  fontWeight: FontWeight.w600),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    // Show modifiers for the item
                                                    if (itemModifiers.isNotEmpty)
                                                      ...itemModifiers.map((mod) => Padding(
                                                        padding: EdgeInsets.only(left: 20, bottom: 2),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              flex: 3,
                                                              child: Text(
                                                                "+ ${mod.name}",
                                                                style: TextStyle(color: Color(0xFFD5282B), fontSize: 13),

                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                double.tryParse(mod.pricePerUnit.toString())?.toStringAsFixed(2) ?? "0.00",
                                                                style: TextStyle(color: Color(0xFFD5282B), fontSize: 13),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                mod.quantity.toString(),
                                                                style: TextStyle(color: Color(0xFFD5282B), fontSize: 13),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                (() {
                                                                  double price = double.tryParse(mod.pricePerUnit.toString()) ?? 0.0;
                                                                  int qty = int.tryParse(mod.quantity.toString()) ?? 0;
                                                                  double total = price * qty;
                                                                  print('Total for ${mod.name}: ${total.toStringAsFixed(2)}');
                                                                  return total.toStringAsFixed(2);
                                                                })(),
                                                                style: TextStyle(color: Color(0xFFD5282B), fontSize: 13),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )),

                                                  ],
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Builder(
              builder: (context) {
                final size = MediaQuery.of(context).size;
                final bool isLandscape = size.width > size.height;

                // --- All BUTTONS with BOTH printKOTWithHeading and printKOTWithMosambee ---
                final moveKotBtn = _ActionButton(
                  icon: Icons.compare_arrows,
                  label: "Move KOT",
                  color: Colors.deepPurple,
                  enabled: selectedKOTIds.isNotEmpty,
                  onPressed: () async {
                    List<TableItem> tables = await fetchAllTables(CLIENTCODE);
                    showDialog(
                      context: context,
                      builder: (context) => _TableGridDialog(
                        title: 'Select Table to Move KOT(s)',
                        tables: tables,
                        onTableTap: (table) async {
                          List<OrderItem> allKotItems = await fetchKotItemsLatest(widget.receivedStrings['name']!);
                          List<OrderModifier> allKotMods = await fetchKotModifiersLatest(widget.receivedStrings['name']!);
                          for (String kotId in selectedKOTIds) {
                            await moveKot(kotId, widget.receivedStrings['name']!, table.tableName);
                            final kotItems = allKotItems.where((item) => item.orderNumber == kotId).toList();
                            final kotMods = allKotMods.where((mod) => mod.kotId.kotId.toString() == kotId).toList();
                            List<SelectedProduct> products = kotItems.map((item) => SelectedProduct(
                              name: item.itemName ?? "",
                              price: item.price ?? 0,
                              quantity: item.quantity ?? 0,
                              code: item.itemCode.toString(),
                              notes: item.orderNumber.toString(),
                              costCenterCode: item.costCenterCode.toString(),
                            )).toList();
                            List<SelectedProductModifier> modifiers = kotMods.map((mod) => SelectedProductModifier(
                              code: mod.productCode.toString(),
                              quantity: mod.quantity ?? 0,
                              name: mod.name,
                              price_per_unit: double.tryParse(mod.pricePerUnit) ?? 0.0,
                              product_code: mod.productCode.toString(),
                              order_id: mod.kotId.kotId,
                            )).toList();
                            await printKOTWithHeading(
                              heading: "KOT MOVED ${table.tableName}",
                              kotno: kotId,
                              items: products,
                              modifiers: modifiers,
                              tableno: table.tableName,
                              moveTableName: table.tableName,
                            );
                            await printKOTWithMosambee(
                              kotno: kotId,
                              items: products,
                              modifiers: modifiers,
                              tableno: table.tableName,
                              waiterName: selectedwaitername,
                              ccName: ccname,
                              brandName: brandName,
                              username: username,
                            );
                          }
                          Navigator.of(context).pop(true);
                          setState(() => selectedKOTIds.clear());
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('KOT(s) moved!')),
                          );
                          final size = MediaQuery.of(context).size;
                          final isDesk = size.width > size.height;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => isDesk ? MainMenuDesk() : mm.MainMenu(),
                            ),
                                (route) => false,
                          );
                        },
                      ),
                    );
                  },
                );

                final cancelKotBtn = _ActionButton(
                  icon: Icons.cancel,
                  label: "Cancel KOT",
                  color: Colors.red.shade700,
                  enabled: selectedKOTIds.isNotEmpty,
                  onPressed: () async {
                    List<OrderItem> allKotItems = await fetchKotItemsLatest(widget.receivedStrings['name']!);
                    List<OrderModifier> allKotMods = await fetchKotModifiersLatest(widget.receivedStrings['name']!);
                    for (String kotId in selectedKOTIds) {
                      await cancelkot(kotId);
                      final kotItems = allKotItems.where((item) => item.orderNumber == kotId).toList();
                      final kotMods = allKotMods.where((mod) => mod.kotId.kotId.toString() == kotId).toList();
                      List<SelectedProduct> products = kotItems.map((item) => SelectedProduct(
                        name: item.itemName ?? "",
                        price: item.price ?? 0,
                        quantity: item.quantity ?? 0,
                        code: item.itemCode.toString(),
                        notes: item.orderNumber.toString(),
                        costCenterCode: item.costCenterCode.toString(),
                      )).toList();
                      List<SelectedProductModifier> modifiers = kotMods.map((mod) => SelectedProductModifier(
                        code: mod.productCode.toString(),
                        quantity: mod.quantity ?? 0,
                        name: mod.name,
                        price_per_unit: double.tryParse(mod.pricePerUnit) ?? 0.0,
                        product_code: mod.productCode.toString(),
                        order_id: mod.kotId.kotId,
                      )).toList();
                      await printKOTWithHeading(
                        heading: "CANCELLED KOT",
                        kotno: kotId,
                        items: products,
                        modifiers: modifiers,
                        tableno: widget.receivedStrings['name']!,
                      );
                      await printKOTWithMosambee(
                        kotno: kotId,
                        items: products,
                        modifiers: modifiers,
                        tableno: widget.receivedStrings['name']!,
                        waiterName: selectedwaitername,
                        ccName: ccname,
                        brandName: brandName,
                        username: username,
                      );
                    }
                    setState(() => selectedKOTIds.clear());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('KOT(s) cancelled!')),
                    );
                    final size = MediaQuery.of(context).size;
                    final isDesk = size.width > size.height;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => isDesk ? MainMenuDesk() : mm.MainMenu(),
                      ),
                          (route) => false,
                    );
                  },
                );

                final moveItemsBtn = _ActionButton(
                  icon: Icons.swap_horiz,
                  label: "Move Items",
                  color: Colors.orangeAccent.shade700,
                  enabled: selectedKOTIds.isNotEmpty,
                  onPressed: () async {
                    List<TableItem> tables = await fetchAllTables(CLIENTCODE);
                    final moveResult = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => _MoveOrCancelItemDialog(
                        kotIds: selectedKOTIds,
                        tableList: tables,
                        isMove: true,
                        fetchItems: fetchKotItemsLatest,
                        moveItemFunction: moveItem,
                        tableName: widget.receivedStrings['name']!,
                      ),
                    );
                    if (moveResult != null && moveResult["movedItems"] != null) {
                      List movedItems = moveResult["movedItems"];
                      List<OrderItem> allItems = await fetchKotItemsLatest(widget.receivedStrings['name']!);
                      List<OrderModifier> allMods = await fetchKotModifiersLatest(widget.receivedStrings['name']!);
                      for (var moved in movedItems) {
                        final kotId = moved["kotId"];
                        final itemCode = moved["itemCode"];
                        final qty = moved["qty"];
                        final newTableName = moved["newTableName"];
                        final OrderItem? item = allItems.firstWhereOrNull(
                              (item) => item.orderNumber == kotId && item.itemCode.toString() == itemCode,
                        );
                        if (item != null) {
                          final itemMods = allMods.where((mod) =>
                          mod.kotId.kotId.toString() == kotId &&
                              mod.productCode.toString() == itemCode).toList();
                          List<SelectedProduct> products = [
                            SelectedProduct(
                              name: item.itemName ?? "",
                              price: item.price ?? 0,
                              quantity: qty,
                              code: item.itemCode.toString(),
                              notes: item.orderNumber.toString(),
                              costCenterCode: item.costCenterCode.toString(),
                            )
                          ];
                          List<SelectedProductModifier> modifiers = itemMods.map((mod) => SelectedProductModifier(
                            code: mod.productCode.toString(),
                            quantity: mod.quantity ?? 0,
                            name: mod.name,
                            price_per_unit: double.tryParse(mod.pricePerUnit) ?? 0.0,
                            product_code: mod.productCode.toString(),
                            order_id: mod.kotId.kotId,
                          )).toList();
                          await printKOTWithHeading(
                            heading: "ITEM MOVED TO ${newTableName}",
                            kotno: kotId,
                            items: products,
                            modifiers: modifiers,
                            tableno: newTableName,
                          );
                          await printKOTWithMosambee(
                            kotno: kotId,
                            items: products,
                            modifiers: modifiers,
                            tableno: newTableName,
                            waiterName: selectedwaitername,
                            ccName: ccname,
                            brandName: brandName,
                            username: username,
                          );
                        }
                      }
                      setState(() => selectedKOTIds.clear());
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Items moved!')),
                      );
                      final size = MediaQuery.of(context).size;
                      final isDesk = size.width > size.height;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => isDesk ? MainMenuDesk() : mm.MainMenu(),
                        ),
                            (route) => false,
                      );
                    }
                  },
                );

                final cancelItemsBtn = _ActionButton(
                  icon: Icons.remove_circle_outline,
                  label: "Cancel Items",
                  color: Colors.indigo,
                  enabled: selectedKOTIds.isNotEmpty,
                  onPressed: () async {
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => _MoveOrCancelItemDialog(
                        kotIds: selectedKOTIds,
                        tableList: [],
                        isMove: false,
                        fetchItems: fetchKotItemsLatest,
                        cancelItemFunction: cancelItem,
                        tableName: widget.receivedStrings['name']!,
                      ),
                    );
                    if (result != null && result["cancelledItems"] != null) {
                      List cancelledItems = result["cancelledItems"];
                      List<OrderItem> allItems = await fetchKotItemsLatest(widget.receivedStrings['name']!);
                      List<OrderModifier> allMods = await fetchKotModifiersLatest(widget.receivedStrings['name']!);
                      for (var cancelled in cancelledItems) {
                        final kotId = cancelled["kotId"];
                        final itemCode = cancelled["itemCode"];
                        final qty = cancelled["qty"];
                        final itemList = allItems.where((item) =>
                        item.orderNumber == kotId && item.itemCode.toString() == itemCode
                        );
                        final OrderItem? item = itemList.isNotEmpty ? itemList.first : null;
                        if (item != null) {
                          final itemMods = allMods.where((mod) =>
                          mod.kotId.kotId.toString() == kotId &&
                              mod.productCode.toString() == itemCode).toList();
                          List<SelectedProduct> products = [
                            SelectedProduct(
                              name: item.itemName ?? "",
                              price: item.price ?? 0,
                              quantity: qty,
                              code: item.itemCode.toString(),
                              notes: item.orderNumber.toString(),
                              costCenterCode: item.costCenterCode.toString(),
                            )
                          ];
                          List<SelectedProductModifier> modifiers = itemMods.map((mod) => SelectedProductModifier(
                            code: mod.productCode.toString(),
                            quantity: mod.quantity ?? 0,
                            name: mod.name,
                            price_per_unit: double.tryParse(mod.pricePerUnit) ?? 0.0,
                            product_code: mod.productCode.toString(),
                            order_id: mod.kotId.kotId,
                          )).toList();
                          await printKOTWithHeading(
                            heading: "CANCELLED ITEM",
                            kotno: kotId,
                            items: products,
                            modifiers: modifiers,
                            tableno: widget.receivedStrings['name']!,
                          );
                          await printKOTWithMosambee(
                            kotno: kotId,
                            items: products,
                            modifiers: modifiers,
                            tableno: widget.receivedStrings['name']!,
                            waiterName: selectedwaitername,
                            ccName: ccname,
                            brandName: brandName,
                            username: username,
                          );
                        }
                      }
                      setState(() => selectedKOTIds.clear());
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Items cancelled!')),
                      );
                      final size = MediaQuery.of(context).size;
                      final isDesk = size.width > size.height;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => isDesk ? MainMenuDesk() : mm.MainMenu(),
                        ),
                            (route) => false,
                      );
                    }
                  },
                );

                final reprintBtn = _ActionButton(
                  icon: Icons.print,
                  label: "Reprint",
                  color: Colors.blueAccent,
                  enabled: selectedKOTIds.isNotEmpty,
                  onPressed: () async {
                    List<OrderItem> allItems = await fetchKotItemsLatest(widget.receivedStrings['name']!);
                    List<OrderModifier> allMods = await fetchKotModifiersLatest(widget.receivedStrings['name']!);
                    for (final kotId in selectedKOTIds) {
                      final kotItems = allItems.where((item) => item.orderNumber == kotId).toList();
                      final kotMods = allMods.where((mod) => mod.kotId.kotId.toString() == kotId).toList();
                      List<SelectedProduct> products = kotItems.map((item) => SelectedProduct(
                        name: item.itemName ?? "",
                        price: item.price ?? 0,
                        quantity: item.quantity ?? 0,
                        code: item.itemCode.toString(),
                        notes: item.orderNumber.toString(),
                        costCenterCode: item.costCenterCode.toString(),
                      )).toList();
                      List<SelectedProductModifier> modifiers = kotMods.map((mod) => SelectedProductModifier(
                        code: mod.productCode.toString(),
                        quantity: mod.quantity ?? 0,
                        name: mod.name,
                        price_per_unit: double.tryParse(mod.pricePerUnit) ?? 0.0,
                        product_code: mod.productCode.toString(),
                        order_id: mod.kotId.kotId,
                      )).toList();
                      await printKOTWithHeading(
                        heading: "DUPLICATE",
                        kotno: kotId,
                        items: products,
                        modifiers: modifiers,
                        tableno: widget.receivedStrings['name']!,
                      );
                      await printKOTWithMosambee(
                        kotno: kotId,
                        items: products,
                        modifiers: modifiers,
                        tableno: widget.receivedStrings['name']!,
                        waiterName: selectedwaitername,
                        ccName: ccname,
                        brandName: brandName,
                        username: username,
                      );
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('KOT(s) reprinted!')),
                    );
                  },
                );

                final billBtn = _MenuButton(
                  label: "Bill",
                  color: Colors.teal[700]!,
                  onPressed: () {
                    Map<String, dynamic> routeArguments = {
                      'tableinfo': widget.receivedStrings,
                    };
                    Navigator.pushNamed(context, '/generatebillsscreen', arguments: routeArguments);
                  },
                );

                final moveTableBtn = _MenuButton(
                  label: "Move Table",
                  color: Colors.green[700]!,
                  onPressed: () async {
                    List<TableItem> tables = await fetchAllTables(CLIENTCODE);
                    showDialog(
                      context: context,
                      builder: (context) => _TableGridDialog(
                        title: 'Move Table',
                        tables: tables,
                        onTableTap: (table) async {
                          List<OrderItem> allKotItems = await fetchKotItemsLatest(widget.receivedStrings['name']!);
                          List<OrderModifier> allKotMods = await fetchKotModifiersLatest(widget.receivedStrings['name']!);
                          List<Kot> kots = await fetchKots(widget.receivedStrings['name']!);
                          for (final kot in kots) {
                            final kotItems = allKotItems.where((item) => item.orderNumber == kot.kotId.toString()).toList();
                            final kotMods = allKotMods.where((mod) => mod.kotId.kotId.toString() == kot.kotId.toString()).toList();
                            List<SelectedProduct> products = kotItems.map((item) => SelectedProduct(
                              name: item.itemName ?? "",
                              price: item.price ?? 0,
                              quantity: item.quantity ?? 0,
                              code: item.itemCode.toString(),
                              notes: item.orderNumber.toString(),
                              costCenterCode: item.costCenterCode.toString(),
                            )).toList();
                            List<SelectedProductModifier> modifiers = kotMods.map((mod) => SelectedProductModifier(
                              code: mod.productCode.toString(),
                              quantity: mod.quantity ?? 0,
                              name: mod.name,
                              price_per_unit: double.tryParse(mod.pricePerUnit) ?? 0.0,
                              product_code: mod.productCode.toString(),
                              order_id: mod.kotId.kotId,
                            )).toList();
                            await printKOTWithHeading(
                              heading: "TABLE MOVED TO ${table.tableName}",
                              kotno: kot.kotId.toString(),
                              items: products,
                              modifiers: modifiers,
                              tableno: table.tableName,
                              moveTableName: table.tableName,
                            );
                            await printKOTWithMosambee(
                              kotno: kot.kotId.toString(),
                              items: products,
                              modifiers: modifiers,
                              tableno: table.tableName,
                              waiterName: selectedwaitername,
                              ccName: ccname,
                              brandName: brandName,
                              username: username,
                            );
                          }
                          bool success = await moveTable(context, widget.receivedStrings['name']!, table.tableName, CLIENTCODE);
                          Navigator.of(context).pop(true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(success ? 'Table moved!' : 'Move failed')),
                          );
                          exitToMainMenu(context);
                        },
                      ),
                    );
                  },
                );

                final addMoreBtn = _MenuButton(
                  label: "Add More",
                  color: Colors.redAccent,
                  onPressed: () {
                    Map<String, String> args = {
                      'name': widget.receivedStrings['name'].toString(),
                      'status': widget.receivedStrings['status'].toString(),
                      'id': widget.receivedStrings['id'].toString(),
                      'area': widget.receivedStrings['area'].toString(),
                      "pax": (widget.receivedStrings['pax'] != null ? widget.receivedStrings['pax'].toString() : '0'),
                    };
                    Navigator.pushNamed(context, '/itemlist', arguments: args);
                  },
                );

                if (isLandscape) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        moveKotBtn,
                        cancelKotBtn,
                        moveItemsBtn,
                        cancelItemsBtn,
                        reprintBtn,
                        billBtn,
                        moveTableBtn,
                        addMoreBtn,
                      ],
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              moveKotBtn,
                              SizedBox(width: 12),
                              cancelKotBtn,
                              SizedBox(width: 12),
                              reprintBtn,
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              moveItemsBtn,
                              SizedBox(width: 12),
                              cancelItemsBtn,
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              moveTableBtn,
                              SizedBox(width: 12),
                              addMoreBtn,
                              SizedBox(width: 12),
                              billBtn,
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onPressed;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: enabled ? color : Colors.grey, size: 22),
      label: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: enabled ? color : Colors.grey)),
      ),
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        elevation: 0.0,
        backgroundColor: enabled ? Colors.white : Colors.grey.shade200,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
          side: BorderSide(color: enabled ? color : Colors.grey, width: 1.6),
        ),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );
  }
}
class _MenuButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _MenuButton({required this.label, required this.color, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: onPressed,
      child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }
}
class _TableGridDialog extends StatelessWidget {
  final String title;
  final List<TableItem> tables;
  final void Function(TableItem table) onTableTap;
  const _TableGridDialog({required this.title, required this.tables, required this.onTableTap});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      content: SizedBox(
        width: 400,
        height: 350,
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: tables.length,
          itemBuilder: (context, index) {
            TableItem table = tables[index];
            return GestureDetector(
              onTap: () => onTableTap(table),
              child: Card(
                color: table.status == "Occupied"
                    ? const Color(0xFFD5282A)
                    : table.status == "Free"
                    ? const Color(0xFF9E9E9E)
                    : table.status == "Reserved"
                    ? const Color(0xFF24C92F)
                    : Colors.white,
                child: Center(
                  child: Text('${table.tableName}',
                      style: TextStyle(
                          color: table.status == "Occupied"
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
class _MoveOrCancelItemDialog extends StatefulWidget {
  final List<String> kotIds;
  final List<TableItem> tableList;
  final bool isMove; // if false: cancel item
  final Future<List<OrderItem>> Function(String) fetchItems;
  final Future<bool> Function(String, String, String, String, int)? moveItemFunction;
  final Future<bool> Function(String, String, int, int)? cancelItemFunction;
  final String tableName;
  const _MoveOrCancelItemDialog({
    required this.kotIds,
    required this.tableList,
    required this.isMove,
    required this.fetchItems,
    this.moveItemFunction,
    this.cancelItemFunction,
    required this.tableName,
  });
  @override
  State<_MoveOrCancelItemDialog> createState() => _MoveOrCancelItemDialogState();
}
class _MoveOrCancelItemDialogState extends State<_MoveOrCancelItemDialog> {
  final Map<String, Map<String, bool>> selectedItems = {}; // kotId -> {itemCode: selected}
  final Map<String, Map<String, TextEditingController>> qtyControllers = {}; // kotId -> {itemCode: qty ctrl}
  String? selectedTable;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isMove ? 'Move Items' : 'Cancel Items', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 420,
        height: 400,
        child: ListView(
          children: widget.kotIds.map((kotId) {
            return FutureBuilder<List<OrderItem>>(
              future: widget.fetchItems(widget.tableName),
              builder: (context, itemSnap) {
                if (!itemSnap.hasData) return CircularProgressIndicator();
                var kotItems = itemSnap.data!.where((item) => item.orderNumber == kotId).toList();
                if (kotItems.isEmpty) return Text("No items for KOT $kotId");
                selectedItems.putIfAbsent(kotId, () => {});
                qtyControllers.putIfAbsent(kotId, () => {});
                kotItems.forEach((item) {
                  selectedItems[kotId]!.putIfAbsent(item.itemCode.toString(), () => false);
                  qtyControllers[kotId]!.putIfAbsent(item.itemCode.toString(), () => TextEditingController(text: (item.quantity ?? 1).toString()));
                });
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10),
                    Text("KOT $kotId", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ...kotItems.map((item) {
                      final code = item.itemCode.toString();
                      final qtyCtrl = qtyControllers[kotId]![code]!;
                      return Row(
                        children: [
                          Checkbox(
                            value: selectedItems[kotId]![code],
                            onChanged: (val) {
                              setState(() {
                                selectedItems[kotId]![code] = val!;
                              });
                            },
                          ),
                          Expanded(child: Text(item.itemName ?? "")),
                          Text("Qty:"),
                          SizedBox(
                            width: 46,
                            child: TextField(
                              decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 6)),
                              keyboardType: TextInputType.number,
                              controller: qtyCtrl,
                            ),
                          )
                        ],
                      );
                    }).toList(),
                    SizedBox(height: 10),
                  ],
                );
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        if (widget.isMove)
          Row(
            children: [
              Text("To Table: "),
              GestureDetector(
                onTap: () async {
                  TableItem? pickedTable = await showDialog<TableItem>(
                    context: context,
                    builder: (_) => _TableGridDialog(
                      title: 'Select Table',
                      tables: widget.tableList,
                      onTableTap: (table) {
                        Navigator.of(context).pop(table);
                      },
                    ),
                  );
                  if (pickedTable != null) {
                    setState(() {
                      selectedTable = pickedTable.tableName;
                    });
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(selectedTable ?? 'Select Table'),
                      Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: selectedTable == null
                    ? null
                    : () async {
                  List<Map<String, dynamic>> movedItems = [];
                  for (final kotId in widget.kotIds) {
                    selectedItems[kotId]?.forEach((code, sel) async {
                      if (sel) {
                        int qty = int.tryParse(qtyControllers[kotId]![code]!.text) ?? 1;
                        await widget.moveItemFunction?.call(kotId, code, widget.tableName, selectedTable!, qty);
                        movedItems.add({
                          "kotId": kotId,
                          "itemCode": code,
                          "qty": qty,
                          "newTableName": selectedTable,
                        });
                      }
                    });
                  }
                  Navigator.of(context).pop({"movedItems": movedItems}); // << RETURN RESULT
                },
                child: Text("Move"),
              )
            ],
          ),
        if (!widget.isMove)
          ElevatedButton(
            onPressed: () async {
              List<Map<String, dynamic>> cancelledItems = [];
              for (final kotId in widget.kotIds) {
                selectedItems[kotId]?.forEach((code, sel) async {
                  if (sel) {
                    int qty = int.tryParse(qtyControllers[kotId]![code]!.text) ?? 1;
                    await widget.cancelItemFunction?.call(kotId, code, int.tryParse(widget.tableName) ?? 0, qty);
                    cancelledItems.add({
                      "kotId": kotId,
                      "itemCode": code,
                      "qty": qty,
                    });
                  }
                });
              }
              Navigator.of(context).pop({"cancelledItems": cancelledItems}); // << RETURN RESULT
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Items cancelled!')));
            },
            child: Text("Cancel"),
          ),
        TextButton(
          child: Text("Close"),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}