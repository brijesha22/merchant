  import 'dart:convert';
  import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
  import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
  import 'package:flutter/material.dart' hide Image;
  import 'package:flutter_mosambee_aar/flutter_mosambee_aar.dart';
  import 'package:intl/intl.dart';
  import 'Costcenter_model.dart';
  import 'FireConstants.dart';
  import 'NativeBridge.dart';
  import 'list_of_product_screen.dart';
  import 'package:http/http.dart' as http;
  import 'main_menu.dart';
  import 'main_menu_desk.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  
  import 'dart:typed_data';
  import 'package:flutter/foundation.dart';
  
  class Placeorderscreen extends StatefulWidget {
    const Placeorderscreen({super.key});
  
    @override
    _PlaceorderscreenState createState() => _PlaceorderscreenState();
  }
  
  class _PlaceorderscreenState extends State<Placeorderscreen> {
    String deviceName = 'Unknown';
    BluetoothDevice? selectedDevice;
    String ccname = '';
  
    @override
    void initState() {
      super.initState();
      futureCostcenters = fetchCostcenters();
      _getDeviceName();
    }

    Future<void> showBluetoothDevicePopup(
        String kotId,
        List<SelectedProduct> products,
        List<SelectedProductModifier> sms,
        String tableName,
        ) async {
      List<BluetoothDevice> foundDevices = [];
      bool isScanning = true;

      FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (!foundDevices.any((d) => d.id == r.device.id)) {
            foundDevices.add(r.device);
          }
        }
        isScanning = false;
        setState(() {}); // To update UI if you show a progress indicator
      });

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select Bluetooth Printer'),
              content: SizedBox(
                width: 350,
                height: 350,
                child: isScanning
                    ? Center(child: CircularProgressIndicator())
                    : ListView.builder(
                  itemCount: foundDevices.length,
                  itemBuilder: (context, index) {
                    final device = foundDevices[index];
                    return ListTile(
                      title: Text(device.name.isEmpty ? 'Unknown' : device.name),
                      subtitle: Text(device.id.id),
                      onTap: () async {
                        selectedDevice = device;
                        Navigator.pop(context);
                        await testBluetoothKOT(
                          selectedDevice!,
                          kotId,
                          products,
                          sms,
                          tableName,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('KOT sent to Bluetooth printer!')),
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Close'),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            );
          },
        ),
      );
    }
    Future<void> _getDeviceName() async {}
  
    Future<void> printTicket(List<int> ticket, String targetip) async {
      final printer = PrinterNetworkManager(targetip);
      PosPrintResult connect = await printer.connect();
      if (connect == PosPrintResult.success) {
        PosPrintResult printing = await printer.printTicket(ticket);
  
        print(printing.msg);
        printer.disconnect();
      }
    }
  
    Future<List<int>> testKOT(String kotno, List<SelectedProduct> items,
        List<SelectedProductModifier> modifiers, String tableno, {bool isGrouped = false, String? consolidatedPrinterIp})
    async {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];
  
      // Split the last 3 digits
      String prefix = kotno.substring(0, kotno.length - 3);
      String suffix = kotno.substring(kotno.length - 3);
  
      String cccode = items[0].costCenterCode.toString();
      List<String> printers = await getPrinterIPsByCode(cccode);
  
      String heading = 'KOT';
      if (ccname.startsWith("Bar")) {
        heading = "BOT";
      } else if (ccname.startsWith("Kitchen")) {
        heading = "KOT";
      }
    /*  List<int> bytes = [];
      String prefix = kotno.substring(0, kotno.length - 3);
      String suffix = kotno.substring(kotno.length - 3);
      Map<String, List<SelectedProduct>> groupedByCostCenter = {};
      for (var product in items) {
        if (!groupedByCostCenter.containsKey(product.costCenterCode)) {
          groupedByCostCenter[product.costCenterCode] = [];
        }
        groupedByCostCenter[product.costCenterCode]!.add(product);
      }
  
      List<Costcenter> costcenters = await futureCostcenters;
  
      String cccode = items[0].costCenterCode.toString();
      bool isGroupKOT = groupedByCostCenter.keys.length > 1;
      String heading = isGroupKOT ? 'Consolidated' : 'KOT';
      if (!isGroupKOT) {
        if (ccname.startsWith("Bar")) {
          heading = "BOT";
        } else if (ccname.startsWith("Kitchen")) {
          heading = "KOT";
        }
      }*/
  
  // Printing the heading
      bytes += generator.text(heading,
          styles: const PosStyles(
            fontType: PosFontType.fontB,
            bold: true,
            height: PosTextSize.size3,
            width: PosTextSize.size3,
            align: PosAlign.center,
          ));
  
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
  
      bytes += generator.text('________________________________________________',
          styles: PosStyles(
            fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ));

      bytes += generator.row([
        PosColumn(
          text: heading + ' No      :',
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
  
      bytes += generator.text('________________________________________________',
          styles: PosStyles(
            fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ));
  
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
      bytes += generator.text('________________________________________________',
          styles: PosStyles(
            fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ));
  
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
              bold: false,
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
              bold: false,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          ),
          PosColumn(
            text: '' + ' ',
            width: 1,
            styles: const PosStyles(
              fontType: PosFontType.fontB,
              align: PosAlign.right,
              bold: false,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          ),
        ]);
  
        bytes += generator.text('',
            styles: const PosStyles(
              fontType: PosFontType.fontA,
              bold: false,
              height: PosTextSize.size1,
              width: PosTextSize.size1,
            ));
  
        for (SelectedProductModifier modi in itemModifiers) {
          bytes += generator.row([
            PosColumn(
              text: modi.price_per_unit > 0 ? '>>' : '>',
              width: 2,
              styles: const PosStyles(
                fontType: PosFontType.fontB,
                align: PosAlign.left,
                bold: false,
                height: PosTextSize.size2,
                width: PosTextSize.size2,
              ),
            ),
            PosColumn(
              text: modi.quantity.toString() + ' x ' + modi.name,
              width: 9,
              styles: const PosStyles(
                fontType: PosFontType.fontB,
                align: PosAlign.left,
                bold: false,
                height: PosTextSize.size2,
                width: PosTextSize.size2,
              ),
            ),
            PosColumn(
              text: '' + ' ',
              width: 1,
              styles: const PosStyles(
                fontType: PosFontType.fontB,
                align: PosAlign.right,
                bold: false,
                height: PosTextSize.size2,
                width: PosTextSize.size2,
              ),
            ),
          ]);
  
          bytes += generator.text('',
              styles: const PosStyles(
                fontType: PosFontType.fontA,
                bold: false,
                height: PosTextSize.size1,
                width: PosTextSize.size1,
              ));
        }
      }
  
  
  
      // ITEMS SECTION - GROUPED BY COST CENTER
     /* for (var entry in groupedByCostCenter.entries) {
        // Get cost center name for this group
        String currentCcName = '';
        for (var cc in costcenters) {
          if (cc.code == entry.key) {
            currentCcName = cc.name;
            break;
          }
        }
  
  
        bytes += generator.row([
          PosColumn(
            text: ' ' + currentCcName + ' ',
            width: 11, // Adjust width to fit your text
            styles: const PosStyles(
              fontType: PosFontType.fontB, // Use font B for bold text
              bold: true, // Make the text bold
              height: PosTextSize.size2,
              width: PosTextSize.size2,
              align: PosAlign.center,
  
            ),
          ),
          PosColumn(
            text: '', // Blank column to balance the row
            width: 1,  // Adjust width as needed
            styles: const PosStyles(
              fontType: PosFontType.fontB,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
              align: PosAlign.center,
            ),
          ),
        ]);
  
  // Simulating a thicker underline with a line of underscores (or dashes)
        bytes += generator.row([
          PosColumn(
            text: '',  // A line of underscores to simulate a thick underline
            width: 11, // Same width as the text above
            styles: const PosStyles(
              fontType: PosFontType.fontB,  // Use bold for thicker appearance
              bold: true,  // Bold the line for thicker effect
              height: PosTextSize.size1,  // Normal height to keep it consistent
              width: PosTextSize.size2,
              align: PosAlign.center,  // Align to center to match the text
            ),
          ),
          PosColumn(
            text: '', // Blank column for alignment
            width: 1,  // Same width as before
            styles: const PosStyles(
              fontType: PosFontType.fontB,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
              align: PosAlign.center,
            ),
          ),
        ]);
  
  
  
  
        // Print items for this cost center
        for (SelectedProduct item in entry.value) {
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
                bold: false,
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
                bold: false,
                height: PosTextSize.size2,
                width: PosTextSize.size2,
              ),
            ),
            PosColumn(
              text: '' + ' ',
              width: 1,
              styles: const PosStyles(
                fontType: PosFontType.fontB,
                align: PosAlign.right,
                bold: false,
                height: PosTextSize.size2,
                width: PosTextSize.size2,
              ),
            ),
          ]);
  
          bytes += generator.text('',
              styles: const PosStyles(
                fontType: PosFontType.fontA,
                bold: false,
                height: PosTextSize.size1,
                width: PosTextSize.size1,
              ));
  
          for (SelectedProductModifier modi in itemModifiers) {
            bytes += generator.row([
              PosColumn(
                text: modi.price_per_unit > 0 ? '>>' : '>',
                width: 2,
                styles: const PosStyles(
                  fontType: PosFontType.fontB,
                  align: PosAlign.left,
                  bold: false,
                  height: PosTextSize.size2,
                  width: PosTextSize.size2,
                ),
              ),
              PosColumn(
                text: modi.quantity.toString() + ' x ' + modi.name,
                width: 9,
                styles: const PosStyles(
                  fontType: PosFontType.fontB,
                  align: PosAlign.left,
                  bold: false,
                  height: PosTextSize.size2,
                  width: PosTextSize.size2,
                ),
              ),
              PosColumn(
                text: '' + ' ',
                width: 1,
                styles: const PosStyles(
                  fontType: PosFontType.fontB,
                  align: PosAlign.right,
                  bold: false,
                  height: PosTextSize.size2,
                  width: PosTextSize.size2,
                ),
              ),
            ]);
  
            bytes += generator.text('',
                styles: const PosStyles(
                  fontType: PosFontType.fontA,
                  bold: false,
                  height: PosTextSize.size1,
                  width: PosTextSize.size1,
                ));
          }
        }
      }*/
  
      bytes += generator.text('________________________________________________',
          styles: PosStyles(
            fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ));
  
      bytes += generator.feed(1);
      bytes += generator.cut();
  
      for (String ip in printers) {
        printTicket(bytes, ip);
      }
     /* for (var entry in groupedByCostCenter.entries) {
        final costcenter = costcenters.firstWhere(
              (cc) => cc.code == entry.key,
          orElse: () => null as Costcenter,
        );
  
        if (costcenter != null) {
          int copies = costcenter.noOfcopies ?? 1;
  
          if (costcenter.printerip1 != null && costcenter.printerip1!.isNotEmpty) {
            for (int i = 0; i < copies; i++) {
              await printTicket(bytes, costcenter.printerip1!);
            }
          }
          if (costcenter.printerip2 != null && costcenter.printerip2!.isNotEmpty) {
            await printTicket(bytes, costcenter.printerip2!);
          }
          if (costcenter.printerip3 != null && costcenter.printerip3!.isNotEmpty) {
            await printTicket(bytes, costcenter.printerip3!);
          }
        }
      }*/
  
      return bytes;
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
  
  
  
  
      Future<void> testKOTMosambee(
          BuildContext context,
          String kotno,
          List<SelectedProduct> items,
          List<SelectedProductModifier> modifiers,
          String tableno,
          String waiterName,
          String ccName,
          String brandName,
          )
      async {
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
          FlutterMosambeeAar.printText2(
              "", FlutterMosambeeAar.PRINTLINE_CENTER); FlutterMosambeeAar.printText2(
              "", FlutterMosambeeAar.PRINTLINE_CENTER); FlutterMosambeeAar.printText2(
              "", FlutterMosambeeAar.PRINTLINE_CENTER);FlutterMosambeeAar.printText2(
              "", FlutterMosambeeAar.PRINTLINE_CENTER);

  
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



    Future<void> testBluetoothKOT(
        BluetoothDevice device,
        String kotno,
        List<SelectedProduct> items,
        List<SelectedProductModifier> modifiers,
        String tableno,
        )async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // Split the last 3 digits
    String prefix = kotno.substring(0, kotno.length - 3);
    String suffix = kotno.substring(kotno.length - 3);

    String cccode = items[0].costCenterCode.toString();
    List<String> printers = await getPrinterIPsByCode(cccode);

    String heading = 'KOT';
    if (ccname.startsWith("Bar")) {
    heading = "BOT";
    } else if (ccname.startsWith("Kitchen")) {
    heading = "KOT";
    }
    /*  List<int> bytes = [];
      String prefix = kotno.substring(0, kotno.length - 3);
      String suffix = kotno.substring(kotno.length - 3);
      Map<String, List<SelectedProduct>> groupedByCostCenter = {};
      for (var product in items) {
        if (!groupedByCostCenter.containsKey(product.costCenterCode)) {
          groupedByCostCenter[product.costCenterCode] = [];
        }
        groupedByCostCenter[product.costCenterCode]!.add(product);
      }

      List<Costcenter> costcenters = await futureCostcenters;

      String cccode = items[0].costCenterCode.toString();
      bool isGroupKOT = groupedByCostCenter.keys.length > 1;
      String heading = isGroupKOT ? 'Consolidated' : 'KOT';
      if (!isGroupKOT) {
        if (ccname.startsWith("Bar")) {
          heading = "BOT";
        } else if (ccname.startsWith("Kitchen")) {
          heading = "KOT";
        }
      }*/

    // Printing the heading
    bytes += generator.text(heading,
    styles: const PosStyles(
    fontType: PosFontType.fontB,
    bold: true,
    height: PosTextSize.size3,
    width: PosTextSize.size3,
    align: PosAlign.center,
    ));

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

    bytes += generator.text('________________________________________________',
    styles: PosStyles(
    fontType: PosFontType.fontA,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    ));

    bytes += generator.row([
    PosColumn(
    text: 'KOT No:',
    width: 3,
    styles: const PosStyles(
    fontType: PosFontType.fontA,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    align: PosAlign.left,
    ),
    ),
    PosColumn(
    text: prefix + suffix,
    width: 4,
    styles: const PosStyles(
    fontType: PosFontType.fontB,
    bold: false,
    height: PosTextSize.size2,
    width: PosTextSize.size2,
    align: PosAlign.left,
    ),
    ),
    PosColumn(
    text: '',
    width: 5,
    styles: const PosStyles(
    fontType: PosFontType.fontA,
    bold: true,
    height: PosTextSize.size2,
    width: PosTextSize.size2,
    align: PosAlign.left,
    ),
    ),
    ]);

    bytes += generator.row([
    PosColumn(
    text: 'Table No:',
    width: 3,
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
    width: 3,
    styles: const PosStyles(
    fontType: PosFontType.fontA,
    bold: false,
    height: PosTextSize.size2,
    width: PosTextSize.size2,
    align: PosAlign.left,
    ),
    ),
    PosColumn(
    text: ' ',
    width: 6,
    styles: const PosStyles(
    fontType: PosFontType.fontA,
    bold: true,
    height: PosTextSize.size2,
    width: PosTextSize.size2,
    align: PosAlign.left,
    ),
    ),
    ]);

    bytes += generator.row([
    PosColumn(
    text: 'KOT By :',
    width: 3,
    styles: const PosStyles(
    fontType: PosFontType.fontA,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    align: PosAlign.left,
    ),
    ),
    PosColumn(
    text: username,
    width: 3,
    styles: const PosStyles(
    fontType: PosFontType.fontA,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    align: PosAlign.left,
    ),
    ),
    PosColumn(
    text: ' ',
    width: 6,
    styles: const PosStyles(
    fontType: PosFontType.fontA,
    bold: true,
    height: PosTextSize.size2,
    width: PosTextSize.size2,
    align: PosAlign.left,
    ),
    ),
    ]);

    bytes += generator.row([
    PosColumn(
    text: 'Waiter :',
    width: 3,
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
    width: 3,
    styles: const PosStyles(
    fontType: PosFontType.fontA,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    align: PosAlign.left,
    ),
    ),
    PosColumn(
    text: ' ',
    width: 6,
    styles: const PosStyles(
    fontType: PosFontType.fontA,
    bold: true,
    height: PosTextSize.size2,
    width: PosTextSize.size2,
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
    text: DateFormat('dd-MM-yyyy hh:mm:ss a').format(DateTime.now()).toString(),
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

    bytes += generator.text('________________________________________________',
    styles: PosStyles(
    fontType: PosFontType.fontA,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    ));

    bytes += generator.row([
      PosColumn(
        text: 'Qty',
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
        text: 'Item',
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

    bytes += generator.text('________________________________________________',
    styles: PosStyles(
    fontType: PosFontType.fontA,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    ));

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
    bold: false,
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
    bold: false,
    height: PosTextSize.size2,
    width: PosTextSize.size2,
    ),
    ),
    PosColumn(
    text: '' + ' ',
    width: 1,
    styles: const PosStyles(
    fontType: PosFontType.fontB,
    align: PosAlign.right,
    bold: false,
    height: PosTextSize.size2,
    width: PosTextSize.size2,
    ),
    ),
    ]);

    bytes += generator.text('',
    styles: const PosStyles(
    fontType: PosFontType.fontA,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    ));

    for (SelectedProductModifier modi in itemModifiers) {
    bytes += generator.row([
    PosColumn(
    text: modi.price_per_unit > 0 ? '>>' : '>',
    width: 2,
    styles: const PosStyles(
    fontType: PosFontType.fontB,
    align: PosAlign.left,
    bold: false,
    height: PosTextSize.size2,
    width: PosTextSize.size2,
    ),
    ),
    PosColumn(
    text: modi.quantity.toString() + ' x ' + modi.name,
    width: 9,
    styles: const PosStyles(
    fontType: PosFontType.fontB,
    align: PosAlign.left,
    bold: false,
    height: PosTextSize.size2,
    width: PosTextSize.size2,
    ),
    ),
    PosColumn(
    text: '' + ' ',
    width: 1,
    styles: const PosStyles(
    fontType: PosFontType.fontB,
    align: PosAlign.right,
    bold: false,
    height: PosTextSize.size2,
    width: PosTextSize.size2,
    ),
    ),
    ]);

    bytes += generator.text('',
    styles: const PosStyles(
    fontType: PosFontType.fontA,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    ));
    }
    }



    // ITEMS SECTION - GROUPED BY COST CENTER
    /* for (var entry in groupedByCostCenter.entries) {
        // Get cost center name for this group
        String currentCcName = '';
        for (var cc in costcenters) {
          if (cc.code == entry.key) {
            currentCcName = cc.name;
            break;
          }
        }


        bytes += generator.row([
          PosColumn(
            text: ' ' + currentCcName + ' ',
            width: 11, // Adjust width to fit your text
            styles: const PosStyles(
              fontType: PosFontType.fontB, // Use font B for bold text
              bold: true, // Make the text bold
              height: PosTextSize.size2,
              width: PosTextSize.size2,
              align: PosAlign.center,

            ),
          ),
          PosColumn(
            text: '', // Blank column to balance the row
            width: 1,  // Adjust width as needed
            styles: const PosStyles(
              fontType: PosFontType.fontB,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
              align: PosAlign.center,
            ),
          ),
        ]);

  // Simulating a thicker underline with a line of underscores (or dashes)
        bytes += generator.row([
          PosColumn(
            text: '',  // A line of underscores to simulate a thick underline
            width: 11, // Same width as the text above
            styles: const PosStyles(
              fontType: PosFontType.fontB,  // Use bold for thicker appearance
              bold: true,  // Bold the line for thicker effect
              height: PosTextSize.size1,  // Normal height to keep it consistent
              width: PosTextSize.size2,
              align: PosAlign.center,  // Align to center to match the text
            ),
          ),
          PosColumn(
            text: '', // Blank column for alignment
            width: 1,  // Same width as before
            styles: const PosStyles(
              fontType: PosFontType.fontB,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
              align: PosAlign.center,
            ),
          ),
        ]);




        // Print items for this cost center
        for (SelectedProduct item in entry.value) {
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
                bold: false,
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
                bold: false,
                height: PosTextSize.size2,
                width: PosTextSize.size2,
              ),
            ),
            PosColumn(
              text: '' + ' ',
              width: 1,
              styles: const PosStyles(
                fontType: PosFontType.fontB,
                align: PosAlign.right,
                bold: false,
                height: PosTextSize.size2,
                width: PosTextSize.size2,
              ),
            ),
          ]);

          bytes += generator.text('',
              styles: const PosStyles(
                fontType: PosFontType.fontA,
                bold: false,
                height: PosTextSize.size1,
                width: PosTextSize.size1,
              ));

          for (SelectedProductModifier modi in itemModifiers) {
            bytes += generator.row([
              PosColumn(
                text: modi.price_per_unit > 0 ? '>>' : '>',
                width: 2,
                styles: const PosStyles(
                  fontType: PosFontType.fontB,
                  align: PosAlign.left,
                  bold: false,
                  height: PosTextSize.size2,
                  width: PosTextSize.size2,
                ),
              ),
              PosColumn(
                text: modi.quantity.toString() + ' x ' + modi.name,
                width: 9,
                styles: const PosStyles(
                  fontType: PosFontType.fontB,
                  align: PosAlign.left,
                  bold: false,
                  height: PosTextSize.size2,
                  width: PosTextSize.size2,
                ),
              ),
              PosColumn(
                text: '' + ' ',
                width: 1,
                styles: const PosStyles(
                  fontType: PosFontType.fontB,
                  align: PosAlign.right,
                  bold: false,
                  height: PosTextSize.size2,
                  width: PosTextSize.size2,
                ),
              ),
            ]);

            bytes += generator.text('',
                styles: const PosStyles(
                  fontType: PosFontType.fontA,
                  bold: false,
                  height: PosTextSize.size1,
                  width: PosTextSize.size1,
                ));
          }
        }
      }*/

    bytes += generator.text('________________________________________________',
    styles: PosStyles(
    fontType: PosFontType.fontA,
    bold: false,
    height: PosTextSize.size1,
    width: PosTextSize.size1,
    ));




      // Bluetooth Send Section
      try {
        await device.connect(timeout: const Duration(seconds: 5));
      } catch (e) {
        // Might already be connected
      }

      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? writeChar;

      for (var service in services) {
        for (var c in service.characteristics) {
          if (c.properties.write || c.properties.writeWithoutResponse) {
            writeChar = c;
            break;
          }
        }
        if (writeChar != null) break;
      }

      if (writeChar == null) {
        throw Exception('No writable characteristic found!');
      }

      // --- Write in chunks (to avoid "data longer than allowed" error) ---
      int mtu = 180; // 180 is safe for most printers, 237 may be possible, but 180 is safer

      for (int offset = 0; offset < bytes.length; offset += mtu) {
        final chunk = bytes.sublist(offset, offset + mtu > bytes.length ? bytes.length : offset + mtu);
        await writeChar.write(chunk, withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 20)); // Small delay
      }

      await device.disconnect();
    }
    @override
    Widget build(BuildContext context) {
      Map<String, dynamic> arguments =
      ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  
      List<SelectedProduct> selectedProducts =
      arguments['selectedProducts'] as List<SelectedProduct>;
      List<SelectedProductModifier> selectedModifiers =
      arguments['selectedModifiers'] as List<SelectedProductModifier>;
  
  
      ////////////cost center wise grouping/////////
      Map<String, List<SelectedProduct>> groupedByCostCenter = {};
      List<SelectedProduct> allProducts = [];
      for (var product in selectedProducts) {
        allProducts.add(product);
        if (groupedByCostCenter.containsKey(product.costCenterCode)) {
          groupedByCostCenter[product.costCenterCode]!.add(product);
        } else {
          groupedByCostCenter[product.costCenterCode] = [product];
        }
      }
  
      // Print the grouped products
      groupedByCostCenter.forEach((costCenterCode, products) {
        print('Cost Center Code: $costCenterCode');
        for (var product in products) {
        }
      });
  
      ////////////cost center wise grouping/////////
  
      Map<String, String> tableinfo =
      arguments['tableinfo'] as Map<String, String>;
  
      return Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            padding: const EdgeInsets.only(top: 15.0),
            child: Center(
              child: Text(
                'Order Summary',
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          backgroundColor: Color(0xFFD5282A),
          toolbarHeight: 60,
        ),
        body: Builder(
          builder: (context) {
            return Container(
                color: Colors.white, // 👈 white background for the entire body
                child: Padding(
                padding: const EdgeInsets.all(20.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  Center(
                    child: Padding(

                      padding: const EdgeInsets.only(top: 1.0, bottom: 2.0),
                        child: Text(
                          Lastclickedmodule == 'Dine'
                              ? 'Table ${tableinfo['name']!}'
                              : capitalizeWords(tableinfo['name']!),
                          style: const TextStyle(
                            fontFamily: 'HammersmithOne',
                            fontSize: 24,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        )
  
  
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 450,

                      margin: const EdgeInsets.only(bottom: 5.0),
                      child: Card(
                        elevation: 5.0,
                        color: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Column(
                          children: [
  
                            Container(
                              height: 55,
                              width: 450,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD5282A),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(8.0)),
                              ),
                              child: Padding(
                                padding:
                                const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Padding(
                                        padding:
                                        const EdgeInsets.only(left: 10.0),
                                        child: Text(
                                          'Item',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Text(
                                          'Price',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Text(
                                          'Qty',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Text(
                                          'Amount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Container(
                                  width: 450,
                                  color: Colors.white,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: selectedProducts.length,
                                    itemBuilder: (context, index) {
                                      final item = selectedProducts[index];
                                      final totalPrice =
                                          item.quantity * item.price;
                                      final itemModifiers = selectedModifiers
                                          .where((modifier) =>
                                      modifier.product_code == item.code)
                                          .toList();
  
                                      return Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              BorderRadius.circular(8.0),
                                              color: Colors.white,
                                            ),
                                            child: Column(
                                              children: [
                                                Padding(
                                                  padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8.0),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        flex: 4,
                                                        child: Padding(
                                                          padding:
                                                          const EdgeInsets
                                                              .only(
                                                              left: 10.0),
                                                          child: Text(
                                                            item.name,
                                                            style:
                                                            const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                              FontWeight
                                                                  .normal,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Center(
                                                          child: Text(
                                                            "${item.price.toStringAsFixed(2)}",
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
  
                                                      Expanded(
                                                        flex: 2,
                                                        child: Center(
                                                          child: Text(
                                                            "${item.quantity}",
                                                            style:
                                                            const TextStyle(
                                                                fontSize: 14),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Center(
                                                          child: Text(totalPrice.toStringAsFixed(2),
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14,),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                ListView.builder(
                                                  shrinkWrap: true,
                                                  physics:
                                                  const NeverScrollableScrollPhysics(),
                                                  itemCount: itemModifiers.length,
                                                  itemBuilder:
                                                      (context, modIndex) {
                                                    final modifier =
                                                    itemModifiers[modIndex];
                                                    return Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 4.0),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .start,
                                                        children: [
                                                          Expanded(
                                                            flex: 4,
                                                            child: Padding(
                                                              padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 10.0),
                                                              child: Text(
                                                                modifier.name,
                                                                style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .blueAccent,
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 2,
                                                            child: Center(
                                                              child: Text(
                                                                "${modifier.price_per_unit.toStringAsFixed(2)}",
                                                                style: const TextStyle(
                                                                  color: Colors.blueAccent,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
  
                                                          Expanded(
                                                            flex: 2,
                                                            child: Center(
                                                              child: Text(
                                                                "${modifier.quantity}",
                                                                style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .blueAccent,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 2,
                                                            child: Center(
                                                              child: Text(
                                                                (modifier.price_per_unit *
                                                                    modifier.quantity).toStringAsFixed(2),
                                                                style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .blueAccent,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          Divider(
                                              height: 1,
                                              color: Color(0xFFE0E0E0)),
                                          SizedBox(height: 10),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 0, thickness: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 5.0),
                        child: ElevatedButton(
                          onPressed: () {
                            if (Lastclickedmodule == "Take Away" ||
                                Lastclickedmodule == "Counter" ||
                                Lastclickedmodule == "Home Delivery" ||
                                Lastclickedmodule == "Online") {
                              Map<String, dynamic> routeArguments = {
                                'selectedProducts': selectedProducts,
                                'selectedModifiers': selectedModifiers,
                                'tableinfo': tableinfo,
                              };
                              Navigator.pushNamed(context, '/generatebillsscreen',
                                  arguments: routeArguments);
                            } else {
                              postData(context, selectedModifiers,
                                  selectedProducts, tableinfo);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(5)),
                              side: BorderSide(
                                color: Colors.black,
                                width: 0.1,
                              ),
                            ),
                            backgroundColor: Color(0xFFD5282A),
                            minimumSize: const Size(150, 50),
                          ),
                          child: const Text(
                            'Place order',
                            style: TextStyle(
                              fontFamily: 'HammersmithOne',
                              color: Colors.white,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),),
            );
          },
        ),
      );
    }
  
    final String apirl = '${apiUrl}order/create?DB=' + CLIENTCODE;
  
    late String gKOTNO;
  
    Future<void>postData(BuildContext context, List<SelectedProductModifier> sms,
        List<SelectedProduct> sps, Map<String, String> tableinfo)
    async {
      double screenWidth = MediaQuery.of(context).size.width;
      double screenHeight = MediaQuery.of(context).size.height;
  
      // Use selectedwaitername for waiter information
      for (SelectedProduct product in sps) {
        product.waiter = selectedwaitername;  // Assign selectedwaitername to waiter field
      }
  
      final orderItems = sps.map((product) => product.toJson()).toList();
      print("Order Items JSON: ${jsonEncode(orderItems)}");
  
      final orderModifiers = sms.map((product) => product.toJson()).toList();
  
      final response = await http.post(
        Uri.parse(apirl),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "orderItems": orderItems,
          "orderModifiers": orderModifiers,
          "order_type": Lastclickedmodule,
          "tableName": tableinfo['name'],
        }),
      );
  
      print("Hello${jsonEncode({
        "orderItems": orderItems,
      })}");
  
      if (response.statusCode == 201) {
        print("Data Posted Successfully");
  
        final String url2 =
            '${apiUrl}table/update/${tableinfo['id']!}?DB=$CLIENTCODE';
  
        final Map<String, dynamic> data2 = {
          "tableName": tableinfo['name'],
          "status": "Occupied",
          "id": tableinfo['id'],
          "area": tableinfo['area'],
          "pax": tableinfo['pax'] ?? 0,
        };
  
        final headers = {
          'Content-Type': 'application/json',
        };
  
        try {
          final response = await http.put(
            Uri.parse(url2),
            headers: headers,
            body: jsonEncode(data2),
          );
  
          if (response.statusCode == 200) {
            print('POST request successful');
            print('Response data: ${response.body}');
          } else {
            print('POST request failed with status: ${response.statusCode}');
            print('Response data: ${response.body}');
          }
        } catch (e) {
          print('Error sending POST request: $e');
        }
  
        Map<String, dynamic> parsedData = json.decode(response.body.toString());
        print(parsedData);
  
        String kotId = parsedData['orderNumber'];
        String itemName = parsedData['itemName'];
        int quantity = parsedData['quantity'];
        String status = parsedData['status'];
  
        print('KOT ID: $kotId');
        print('Item Name: $itemName');
        print('Quantity: $quantity');
        print('Status: $status');
  
        gKOTNO = kotId;
  
  
        Map<String, List<SelectedProduct>> groupedByCostCenter = {};
        List<SelectedProduct> allProducts = [];
  
        for (var product in sps) {
          allProducts.add(product);
          if (groupedByCostCenter.containsKey(product.costCenterCode)) {
            groupedByCostCenter[product.costCenterCode]!.add(product);
          } else {
            groupedByCostCenter[product.costCenterCode] = [product];
          }
        }
  
        for (var entry in groupedByCostCenter.entries) {
          final costCenterCode = entry.key;
          final products = entry.value;
  
          // Lookup cost center name for this group
          String groupCcName = '';
          List<Costcenter> costcenters = await futureCostcenters;
          for (var cc in costcenters) {
            if (cc.code == costCenterCode) {
              groupCcName = cc.name;
              break;
            }
          }

          testKOT(kotId, products, sms, tableinfo['name']!);////only consolidate print///


          await testKOTMosambee(
            context,
            kotId,
            products,
            sms,
            tableinfo['name']!,
            selectedwaitername,
            groupCcName,
            brandName,
          );

         /* final bluetoothPrinter = BluetoothDevice(
            remoteId: DeviceIdentifier('33:68:02:19:00:13'),
          );
// For each group if needed:
          await testBluetoothKOT(
            bluetoothPrinter,
            kotId,
            products,
            sms,
            tableinfo['name']!,
          );*/
        }
  //////without consolidate///// it will print below
     //   testKOT(kotId, allProducts, sms, tableinfo['name']!);
  
        // testKOT(kotId, sps,tableinfo['tableId']!);
        NativeBridge.callNativeMethodKot(
            gKOTNO,
            jsonEncode(orderItems).toString(),
            "₹",
            tableinfo['name']!,
            Lastclickedmodule);
  
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            Future.delayed(const Duration(seconds: 3), () {
              Navigator.of(context).pop();
  
              if (Lastclickedmodule == "Take Away") {
                Map<String, dynamic> routeArguments = {
                  'tableinfo': tableinfo,
                };
  
                Navigator.pushNamed(context, '/generatebillsscreen',
                    arguments: routeArguments);
              } else {
                if (screenWidth > screenHeight) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainMenuDesk(),
                    ),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainMenu(),
                    ),
                  );
                }
              }
            });
  
            final backgroundColor = Colors.white.withOpacity(0.7);
  
            return AlertDialog(
              backgroundColor: backgroundColor,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle,
                    size: 48.0,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'No.DN$kotId\nOrder Placed Successfully',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: const [],
            );
          },
        );
      } else {
        print("hello---${response.body}");
  
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            Future.delayed(const Duration(seconds: 3), () {
              Navigator.of(context).pop();
            });
  
            final backgroundColor = Colors.white.withOpacity(0.7);
  
            return AlertDialog(
              backgroundColor: backgroundColor,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle,
                    size: 48.0,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'Failed to place order',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: const [],
            );
          },
        );
  
        throw Exception('Failed to place order');
      }
    }
  
    String capitalizeWords(String input) {
      return input.split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }
  
  }
