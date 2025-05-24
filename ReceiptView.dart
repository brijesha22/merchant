import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_sample/main_menu_desk.dart';
import 'package:flutter_sample/product_model.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_sample/list_of_product_screen.dart';
import 'package:flutter_sample/main_menu.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_whatsapp/share_whatsapp.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'Costcenter_model.dart';
import 'FireConstants.dart';
import 'global_constatnts.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_sample/Order_Item_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' hide Image;
import 'OrderModifier.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'ConstantUtils.dart';
import 'package:http/http.dart' as http;
void main() => runApp(const ReceiptView());
class ReceiptView extends StatelessWidget {

  const ReceiptView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context)
  {



    Map<String, dynamic> arguments = ModalRoute
        .of(context)!
        .settings
        .arguments as Map<String, dynamic>;

    List<dynamic> rawProductList = arguments['productList'] ?? [];
    List<Product> productList = rawProductList.map((e) => Product.fromMap(e)).toList();


    List<BillItem> billItems = arguments['billItems'] as List<BillItem>;
    List<SelectedProductModifier> billModifiers =
    (arguments['billModifiers'] as List).cast<SelectedProductModifier>();
    gREciptViewBillItems = billItems;
    gREciptViewBillModifiers = billModifiers;
    Map<String, String> billinfo = arguments['billinfo'] as Map<String,
        String>;

    gReciptViewStrings = billinfo;
    final homeDeliveryChargeString = billinfo['homeDeliveryCharge'] ?? '0.0';
    final homeDeliveryCharge = double.tryParse(homeDeliveryChargeString) ?? 0.0;

    List<LocalTax> billTaxes = List<LocalTax>.from(arguments['taxes'] ?? []);
    gReceiptViewTaxes = billTaxes; // Define this as a global list


    return Scaffold(

      body: PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) async {
          //   Navigator.of(context).pop();

          DuplicatePrint = 'N';
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const MainMenu(),

            ),
          );
        },
        child: MainPage(productList: productList),

      ),
    );

  }
}

class MainPage extends StatefulWidget {
  final List<Product> productList;
  const MainPage({Key? key, required this.productList}) : super(key: key);

  @override
  MainPageState createState() => MainPageState();
}
class MainPageState extends State<MainPage> {
  late List<Product> productList;
  WidgetsToImageController controller = WidgetsToImageController();
  Uint8List? bytes;
  TextEditingController phoneNumberController = TextEditingController();
  bool showContainer = false;
  final GlobalKey _receiptKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    productList = widget.productList;
  }


  Future<Uint8List> loadImage(String path) async {
    final ByteData data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }


  Future<void> captureAndPrintReceipt(BuildContext context) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        print("Starting capture process...");

        if (_receiptKey.currentContext == null) {
          print("Error: _receiptKey.currentContext is null.");
          return;
        }

        RenderRepaintBoundary? boundary =
        _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) {
          print("Error: Render boundary is null.");
          return;
        }

        print("Render boundary retrieved successfully.");
        print("Capturing the boundary as an image...");

        ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          print("Image captured successfully. Converting to bytes...");
          Uint8List bytes = byteData.buffer.asUint8List();
          print("Bytes converted successfully. Sending to printer...");
          await printImage(bytes);
        } else {
          print("Error: ByteData is null after capturing the image.");
        }

        // ✅ Determine screen orientation
        final size = MediaQuery.of(context).size;
        final isPortrait = size.height > size.width;

        // ✅ Navigate based on orientation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => isPortrait ? const MainMenu() : const MainMenuDesk(),
          ),
        );
      } catch (e) {
        print("Error during capture process: $e");
      }
    });
  }

  Future<void> printImage(Uint8List bytes) async {
    try {

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);

      img.Image? image = img.decodeImage(bytes);
      if (image == null) {
        return;
      }
      img.Image resizedImage = img.copyResize(image, width: 576);

      print("Generating print bytes...");
      List<int> printBytes = [];
      printBytes += generator.image(resizedImage);
      printBytes += generator.cut();

      print("Sending bytes to printer...");
      await sendToPrinter(Uint8List.fromList(printBytes));
      print("Image sent to printer successfully.");
    } catch (e) {
      print("Error during image printing: $e");
    }
  }
  Future<void> sendToPrinter(Uint8List bytes) async {
    List<Costcenter> costcenters = await fetchCostcentersWindows();

    for (var center in costcenters.where((e) => e.name == "Bill")) {
      int copies = center.noOfcopies ?? 1;

      if (center.printerip1 != null && center.printerip1!.isNotEmpty) {
        for (int i = 0; i < copies; i++) {
          await printTicket(bytes.toList(), center.printerip1!);
        }
      }
      if (center.printerip2 != null && center.printerip2!.isNotEmpty) {
        await printTicket(bytes.toList(), center.printerip2!);
      }
      if (center.printerip3 != null && center.printerip3!.isNotEmpty) {
        await printTicket(bytes.toList(), center.printerip3!);
      }
    }
  }





  static const darkGrey = Color(0xFF424242);

  late Future<List<OrderItem>> futureKOTs;

  late Future<List<OrderModifier>> futureModifiers;



  bool _isLoading = true;

  String deviceName = 'Unknown';

  String ccname = '';
  List<BillItem> allbillitems = [];
  List<BillItem> allbillitemslocal = [];
  List<SelectedProductModifier> allbillmodifers = [];
  List<LocalTax> allbilltaxes = [];
  String custname = '', custmobile = '', custgst = '',CustomerAddress ='';
  double homeDeliveryCharge = 0.0;
  String deliveryRemark = "";
  double cgst = 0.00;
  double sgst = 0.00;
  double vat = 0.00;
  double sc = 0.00;
  double subtotal = 0.00;
  double grandtotal = 0.00;
  double billamount = 0.00;
  double discount = 0.00;
  String discountremark = "";
  String settlementModeName = "";
  double cgstpercentage = 2.50;
  double sgstpercentage = 2.50;
  double vatpercentage = 0.00;
  double scpercentage = 0.00;
  double discountpercentage = 0;
  double sumoftax = 0.0;
  double serviceCharge=0.0;
  int totalQuantity=0;
  int modifierQuanity=0;
  int finalQuantity=0;

  Map<String, dynamic> groupedItems = {};
  final groupedModifiers = <String, Map<String, dynamic>>{};

  List<dynamic> combinedItems=[];
  List<dynamic> combinedModiferItem=[];

  Future<List<int>> testBILL( String billNo,
      List<BillItem> items,
      List<SelectedProductModifier> modifiers,
      String tableNo,
      double grandTotal,
      double discountPercentage,
      double discount,
      String discountRemark,
      int pax,
      String settlementModeName,
      double subtotal,
      List<LocalTax> localtaxes, Uint8List logoBytes ,String jsonData )
  async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    String billNo = gReciptViewStrings['BillNo'] ?? '';
    String tableNo = gReciptViewStrings['tableName'] ?? '';
    String settlementModeName = gReciptViewStrings['settlementModeName'] ?? '';
    double discountPercentage = double.parse(
        gReciptViewStrings['discountper'] ?? '0');
    double discount = double.parse(gReciptViewStrings['discount'] ?? '0');
    String discountRemark = gReciptViewStrings['discountremark'] ?? '';
    int pax = int.parse(gReciptViewStrings['pax'] ?? '0');
    String custname = gReciptViewStrings['custname'].toString() ?? '';
    String custmobile = gReciptViewStrings['custmobile'].toString() ?? '';
    String custgst = gReciptViewStrings['custgst'].toString() ?? '';
    String CustomerAddress = gReciptViewStrings['CustomerAddress'].toString() ??
        '';
    double subtotal = 0.00;
    double billamount = 0.00;
    double grandTotal = 0.00;


    // Calculate subtotal
    for (BillItem bill in gREciptViewBillItems) {
      subtotal += bill.totalPrice;
    }

    for (SelectedProductModifier modifier in gREciptViewBillModifiers) {
      double tamt = modifier.quantity * modifier.price_per_unit;
      subtotal += tamt;
    }

    // Apply discount
    if (discount > 0.0) {
      billamount = subtotal - discount;
    } else {
      billamount = subtotal;
    }

    // Calculate taxes
    for (var tax in globaltaxlist) {
      String isApplicableOncurrentmodlue = "N";

      switch (Lastclickedmodule) {
        case 'Dine':
          isApplicableOncurrentmodlue = tax.isApplicableonDinein;
          break;
        case 'Take Away':
          isApplicableOncurrentmodlue = tax.isApplicableonTakeaway;
          break;
        case 'Home Delivery':
          isApplicableOncurrentmodlue = tax.isApplicableonHomedelivery;
          break;
        case 'Counter':
          isApplicableOncurrentmodlue = tax.isApplicableCountersale;
          break;
        case 'Online':
          isApplicableOncurrentmodlue = tax.isApplicableOnlineorder;
          break;
      }

      if (isApplicableOncurrentmodlue == "Y") {
        double pec = double.parse(tax.taxPercent);
        double taxable = 0.0;

        if (discount > 0.0) {
          if (tax.taxName == "Service Charge") {
            if (GLOBALNSC == "Y") {
              taxable = (0.0 / 100.00) * billamount;
            } else {
              taxable = (pec / 100.00) * billamount;
              serviceCharge = taxable;
            }
          } else {
            if (serviceCharge != 0.0) {
              double subTotal = billamount +
                  serviceCharge; //added service charge
              taxable =
                  (pec / 100.00) * subTotal; //sub total equal to bill amount
            } else {
              taxable = (pec / 100.00) * billamount;
            }
          }
        } else {
          if (tax.taxName == "Service Charge") {
            if (GLOBALNSC == "Y") {
              taxable = (0.0 / 100.00) * subtotal;
            } else {
              taxable = (pec / 100.00) * subtotal;

              serviceCharge = taxable;
            }
          } else {
            if (serviceCharge != 0.0) {
              //double serviceCharge = double.parse(globaltaxlist[0].taxPercent.toString());
              double subTotal = subtotal + serviceCharge; //added service charge
              taxable = (pec / 100.00) * subTotal;
            } else {
              taxable = (pec / 100.00) * subtotal;
            }
          }
        }


        /*double taxable = (discount > 0.0) ? (pec / 100.00) * billamount : (pec / 100.00) * subtotal;
        if(Lastclickedmodule=="Dine"){
          if(tax.taxName == "Service Charge"){
            taxable = (discount > 0.0) ? (pec / 100.00) * billamount : (pec / 100.00) * subtotal;
             serviceCharge=(pec / 100.00) * subtotal;
          }else{
            var subtotalAmount=serviceCharge + subtotal;

            taxable = (discount > 0.0) ? (pec / 100.00) * billamount : (pec / 100.00) * subtotalAmount;
          }
        }*/
        grandTotal += taxable;
      }
    }

    // Add bill amount to grand total
    grandTotal += billamount;

    String prefix = billNo.substring(0, billNo.length - 3);
    String suffix = billNo.substring(billNo.length - 3);

    if (DuplicatePrint == 'Y') {
      bytes += generator.text('[Duplicate]',
          styles: const PosStyles(fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.center,
          ));
    }
    final img.Image? logo = img.decodeImage(logoBytes);
    if (logo != null) {
      final resizedLogo = img.copyResize(
          logo, width: 200); // Resize the logo if necessary
      bytes += generator.image(resizedLogo);
    }
    // Print settlementModeName
    /*   bytes += generator.text(settlementModeName,
        styles: const PosStyles(
          fontType: PosFontType.fontB,
          bold: false,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.center,
        ));*/

// Add an empty line for spacing
    // bytes += generator.text("");

// Print brandName
    bytes += generator.text(brandName,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.center,
        ));

    bytes += generator.text(Addresslineone,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ));


    bytes += generator.text(Addresslinetwo,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ));

    bytes += generator.text(Addresslinethree,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ));
    bytes += generator.text('Mobile No: ' + brandmobile,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        )
    );
    bytes += generator.text('Email ID: ' + emailid,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        )
    );

    bytes += generator.text(
        '________________________________________________', styles: PosStyles(
      fontType: PosFontType.fontA,
      bold: false,
      height: PosTextSize.size1,
      width: PosTextSize.size1,
    ));

    bytes += generator.text(Lastclickedmodule,
      styles: const PosStyles(fontType: PosFontType.fontB,
        bold: false,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        align: PosAlign.center,
      ),);

    if (custname.isNotEmpty) {
      bytes += generator.text(
          '________________________________________________', styles: PosStyles(
        fontType: PosFontType.fontA,
        bold: false,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ));
    }

    if (custname.isNotEmpty) {
      bytes += generator.row([
        PosColumn(
          text: '  Guest Name',
          width: 4,
          styles: const PosStyles(fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
        PosColumn(
          text: ':    ' + custname.toString(),
          width: 8,
          styles: const PosStyles(fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
      ]);
    }

    if (custmobile.isNotEmpty) {
      bytes += generator.row([
        PosColumn(
          text: '  Mobile No',
          width: 3,
          styles: const PosStyles(fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
        PosColumn(
          text: '    :    ' + custmobile.toString(),
          width: 9,
          styles: const PosStyles(fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
      ]);
    }

    if (custgst.isNotEmpty) {
      bytes += generator.row([
        PosColumn(
          text: '  GSTIN',
          width: 3,
          styles: const PosStyles(fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
        PosColumn(
          text: '    :    ' + custgst.toString(),
          width: 9,
          styles: const PosStyles(fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
      ]);
    }

    if (CustomerAddress.isNotEmpty) {
      bytes += generator.row([
        PosColumn(
          text: '  Address',
          width: 3,
          styles: const PosStyles(fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
        PosColumn(
          text: '    :    ' + CustomerAddress.toString(),
          width: 9,
          styles: const PosStyles(fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
      ]);
    }

    bytes += generator.text(
        '________________________________________________', styles: PosStyles(
      fontType: PosFontType.fontA,
      bold: false,
      height: PosTextSize.size1,
      width: PosTextSize.size1,
    ));

    bytes += generator.row([
      PosColumn(
        text: 'Bill No       :',
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
        text: prefix,
        width: 3,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          align: PosAlign.right,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
      PosColumn(
        text: suffix,
        width: 2,
        styles: const PosStyles(
          fontType: PosFontType.fontB,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.left,
        ),
      ),

      if (Lastclickedmodule == "Dine")
        PosColumn(
          text: 'PAX :' + pax.toString() + '  ',
          width: 3, // Total remains 12
          styles: const PosStyles(
            fontType: PosFontType.fontA,
            bold: true,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.right,
          ),
        ),

      // If Lastclickedmodule is NOT "Dine", adjust the column widths to 12
      if (Lastclickedmodule != "Dine")
        PosColumn(
          text: '', // Empty column to maintain total width 12
          width: 3, // Adjust width to balance the total
          styles: const PosStyles(
            fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.right,
          ),
        ),
    ]);

    if (Lastclickedmodule == "Dine" || Lastclickedmodule == "Online") {
      bytes += generator.row([
        PosColumn(
          text: '  Table No:',
          width: 5,
          styles: const PosStyles(
            fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
        PosColumn(
          text: ' $tableNo',
          width: 7,
          styles: const PosStyles(
            fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            align: PosAlign.left,
          ),
        ),
      ]);
    }


    if (Lastclickedmodule == "Dine") {
      bytes += generator.row([

        PosColumn(
          text: '  Waiter',
          width: 3,
          styles: const PosStyles(fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
        PosColumn(
          text: '    :    ' + gReciptViewStrings['waiter'].toString(),
          width: 9,
          styles: const PosStyles(fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
      ]);
    }
    if (Lastclickedmodule == "Take Away" || Lastclickedmodule == "Counter") {
      // Add a blank row for a little space
      bytes += generator.row([
        PosColumn(
          text: '',
          width: 12, // Adjust width if necessary
          styles: const PosStyles(
            fontType: PosFontType.fontA,
            bold: false,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
            align: PosAlign.left,
          ),
        ),
      ]);
    }

    bytes += generator.row([
      PosColumn(
        text: '  Date & Time',
        width: 4,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: ':    ' +
            DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now()),

        width: 8,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
    ]);

    bytes += generator.row([
      PosColumn(
        text: '  Bill By',
        width: 3,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: '    :    ' + username,
        width: 9,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
    ]);

    bytes += generator.text(
        '________________________________________________', styles: PosStyles(
      fontType: PosFontType.fontA,
      bold: false,
      height: PosTextSize.size1,
      width: PosTextSize.size1,
    ));

    bytes += generator.row([
      PosColumn(
        text: 'Item Name',
        width: 5,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: 'Qty',
        width: 2,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ),
      ),
      PosColumn(
        text: 'Price' + ' ',
        width: 2,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ),
      ),
      PosColumn(
        text: 'Amount' + ' ',
        width: 3,
        styles: const PosStyles(fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.right,
        ),
      ),
    ]);

    bytes += generator.text(
        '________________________________________________', styles: PosStyles(
      fontType: PosFontType.fontA,
      bold: false,
      height: PosTextSize.size1,
      width: PosTextSize.size1,
    ));

    for (var item in combinedItems) {
      //final itemModifiers = gREciptViewBillModifiers.where((modifier) => modifier.product_code == item.productCode).toList();

      BillItem billItem = item['item'] as BillItem;

      final itemModifiers = combinedModiferItem.where((
          modifier) => modifier['product_code'] == billItem.productCode)
          .toList();


      String temp = billItem.itemName;
      String fpart = '';
      String spart = '';
      bool ismultline = false;

      if (temp.length <= 20) {
        print('String length is less than or equal to 20 characters: $temp');
      } else {
        int spaceIndex = temp.lastIndexOf(' ', 19);
        if (spaceIndex == -1) {
          print('No space found before 20 characters.');
        } else {
          ismultline = true;
          fpart = temp.substring(0, spaceIndex);
          spart = temp.substring(spaceIndex + 1);
        }
      }

      if (ismultline) {
        bytes += generator.row([
          PosColumn(
            text: fpart,
            width: 5,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.left,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
          PosColumn(
            text: item['quantity'].toString(),
            width: 2,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
          PosColumn(
            text: item['price'].toStringAsFixed(3),
            width: 2,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
          PosColumn(
            text: item['totalPrice'].toStringAsFixed(3) + ' ',
            width: 3,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
        ]);

        bytes += generator.row([
          PosColumn(
            text: spart,
            width: 6,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.left,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
          PosColumn(
            text: '',
            width: 2,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.left,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
          PosColumn(
            text: '',
            width: 2,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.left,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
          PosColumn(
            text: '  ',
            width: 2,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
        ]);
      } else {
        bytes += generator.row([
          PosColumn(
            text: billItem.itemName,
            width: 5,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.left,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
          PosColumn(
            text: item['quantity'].toString(),
            width: 2,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
          PosColumn(
            text: item['price'].toStringAsFixed(3),
            width: 2,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
          PosColumn(
            text: item['totalPrice'].toStringAsFixed(3) + ' ',
            width: 3,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
        ]);
      }

      for (var modi in itemModifiers) {
        double tamount = modi['price_per_unit'] * modi['quantity'];
        bytes += generator.row([
          PosColumn(
            text: modi['price_per_unit'] > 0 ? '>> ' + modi['name'] : '> ' +
                modi['name'],
            width: 5,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.left,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
          PosColumn(
            text: modi['quantity'].toString(),
            width: 2,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
          PosColumn(
            text: modi['price_per_unit'].toStringAsFixed(3),
            width: 2,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
          PosColumn(
            text: tamount.toStringAsFixed(3) + ' ',
            width: 3,
            styles: const PosStyles(fontType: PosFontType.fontA,
              align: PosAlign.right,
              bold: true,
              height: PosTextSize.size1,
              width: PosTextSize.size1,),
          ),
        ]);
      }
    }

    bytes += generator.text(
        '________________________________________________', styles: PosStyles(
      fontType: PosFontType.fontA,
      bold: false,
      height: PosTextSize.size1,
      width: PosTextSize.size1,
    ));

    bytes += generator.row([


      PosColumn(
        text: 'Sub Total',
        width: 6,
        styles: const PosStyles(
          align: PosAlign.left, bold: true, height: PosTextSize.size1,
          width: PosTextSize.size1,),

      ),

      PosColumn(
        text: "x" + finalQuantity.toString(),
        width: 2,
        styles: const PosStyles(
          align: PosAlign.left, bold: true, height: PosTextSize.size1,
          width: PosTextSize.size1,),
      ),

      PosColumn(
        width: 2,
      ),
      PosColumn(
        text: subtotal.toStringAsFixed(3) + ' ',
        width: 2,
        styles: const PosStyles(
          align: PosAlign.right, bold: true, height: PosTextSize.size1,
          width: PosTextSize.size1,),
      ),
    ]);

    bytes += generator.text(
        '________________________________________________', styles: PosStyles(
      fontType: PosFontType.fontA,
      bold: false,
      height: PosTextSize.size1,
      width: PosTextSize.size1,
    ));


    // Add discount details if applicable
    if (discount > 0.0) {
      bytes += generator.row([
        PosColumn(
          text: 'Discount ' + discountPercentage.toStringAsFixed(0) + '%',
          width: 5,
          styles: const PosStyles(
            align: PosAlign.left, underline: false, height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),
        PosColumn(
          width: 3,
        ),
        PosColumn(
          text: discount.toStringAsFixed(3) + ' ',
          width: 4,
          styles: const PosStyles(
            align: PosAlign.right, height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),
      ]);

      bytes += generator.row([
        PosColumn(
          text: 'Remark(' + discountRemark + ')',
          width: 10,
          styles: const PosStyles(
            align: PosAlign.left, underline: false, height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),
        PosColumn(
          width: 1,
        ),
        PosColumn(
          text: '  ',
          width: 1,
          styles: const PosStyles(
            align: PosAlign.right, height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),
      ]);
    }

// Calculate bill amount after discount
    if (discount > 0.0) {
      billamount = subtotal - discount;
      bytes += generator.row([
        PosColumn(
          text: 'Bill Amount',
          width: 5,
          styles: const PosStyles(
            align: PosAlign.left, underline: false, height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),
        PosColumn(
          width: 3,
        ),
        PosColumn(
          text: billamount.toStringAsFixed(3) + ' ',
          width: 4,
          styles: const PosStyles(
            align: PosAlign.right, height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        ),
      ]);
    }

// Calculate and display taxes after discount
    for (var tax in globaltaxlist) {
      String isApplicableOncurrentmodlue = "N";

      switch (Lastclickedmodule) {
        case 'Dine':
          isApplicableOncurrentmodlue = tax.isApplicableonDinein;
          break;
        case 'Take Away':
          isApplicableOncurrentmodlue = tax.isApplicableonTakeaway;
          break;
        case 'Home Delivery':
          isApplicableOncurrentmodlue = tax.isApplicableonHomedelivery;
          break;
        case 'Counter':
          isApplicableOncurrentmodlue = tax.isApplicableCountersale;
          break;
        case 'Online':
          isApplicableOncurrentmodlue = tax.isApplicableOnlineorder;
          break;
      }

      if (isApplicableOncurrentmodlue == "Y") {
        double pec = double.parse(tax.taxPercent);
        double taxable = 0.0;

        if (discount > 0.0) {
          if (tax.taxName == "Service Charge") {
            if (GLOBALNSC == "Y") {
              taxable = (0.0 / 100.00) * billamount;
            } else {
              taxable = (pec / 100.00) * billamount;
              serviceCharge = taxable;
            }
          } else {
            if (serviceCharge != 0.0) {
              double subTotal = billamount +
                  serviceCharge; //added service charge
              taxable =
                  (pec / 100.00) * subTotal; //sub total equal to bill amount
            } else {
              taxable = (pec / 100.00) * billamount;
            }
          }
        } else {
          if (tax.taxName == "Service Charge") {
            if (GLOBALNSC == "Y") {
              taxable = (0.0 / 100.00) * subtotal;
            } else {
              taxable = (pec / 100.00) * subtotal;

              serviceCharge = taxable;
            }
          } else {
            if (serviceCharge != 0.0) {
              //double serviceCharge = double.parse(globaltaxlist[0].taxPercent.toString());
              double subTotal = subtotal + serviceCharge; //added service charge
              taxable = (pec / 100.00) * subTotal;
            } else {
              taxable = (pec / 100.00) * subtotal;
            }
          }
        }

        bytes += generator.row([
          PosColumn(
            text: '${tax.taxName} ${tax.taxPercent}%',
            width: 5,
            styles: const PosStyles(
              align: PosAlign.left, underline: false, height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          ),
          PosColumn(
            width: 3,
          ),
          PosColumn(
            text: taxable.toStringAsFixed(3) + ' ',
            width: 4,
            styles: const PosStyles(
              align: PosAlign.right, height: PosTextSize.size1,
              width: PosTextSize.size1,
            ),
          ),
        ]);
      }
    }

    /*bytes += generator.row([
      PosColumn(
        text: 'Round Off',
        width: 5,
        styles: const PosStyles(
          align: PosAlign.left, underline: false, height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),
      PosColumn(
        width: 3,
      ),
      PosColumn(
        text: (() {
          double roundOff = grandTotal -
              grandTotal.toInt(); // Get the decimal part
          String sign = roundOff <= 0.50 ? '-' : '+';
          double roundValue = roundOff <= 0.50 ? roundOff : (1 - roundOff);
          return "$sign${roundValue.toStringAsFixed(3)}" + ' ';
        })(),
        width: 4,
        styles: const PosStyles(
          align: PosAlign.right,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
        ),
      ),

    ]);*/

// Ensure the grand total is displayed correctly
    bytes += generator.text(
        '________________________________________________', styles: PosStyles(
      fontType: PosFontType.fontA,
      bold: false,
      height: PosTextSize.size1,
      width: PosTextSize.size1,
    ));
    print('Rounded Grand Total: ${ConstantUtils.customRound(double.parse(grandTotal.toStringAsFixed(2)))}');

    bytes += generator.row([
      PosColumn(
        text: 'Grand Total',
        width: 5,
        styles: const PosStyles(fontType: PosFontType.fontB,
          bold: false,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        width: 3,
      ),
      PosColumn(
        text: ConstantUtils.customRound(
          double.parse(grandTotal.toStringAsFixed(3)),),
        width: 4,
        styles: const PosStyles(fontType: PosFontType.fontB,
          bold: false,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          align: PosAlign.right,
        ),
      ),
    ]);

    bytes += generator.text(
        '________________________________________________', styles: PosStyles(
      fontType: PosFontType.fontA,
      bold: false,
      height: PosTextSize.size1,
      width: PosTextSize.size1,
    ));
    bytes += generator.row([
      PosColumn(
        text: '  Paid', // No leading spaces for 'Paid'
        width: 2, // Adjusted width for space between columns
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: ': ' + gReciptViewStrings["settlementModeName"].toString(),
        // No space before the colon
        width: 10,
        // Adjusted width
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.left,
        ),
      ),
    ]);


   /* bytes += generator.row([
      PosColumn(
        text: '',
        width: 12,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        text: '  GST NO : ',
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
        text: ': ' + brandGst,
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
        text: '  FSSAI NO : ',
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
        text: ': ' + brandFssai,
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
        text: '',
        width: 12,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ),
      ),
    ]);*/
    bytes += generator.row([
      PosColumn(
        text: footer,
        width: 12,
        styles: const PosStyles(
          fontType: PosFontType.fontA,
          bold: false,
          height: PosTextSize.size1,
          width: PosTextSize.size1,
          align: PosAlign.center,
        ),
      ),

    ]);


    bytes += generator.feed(1);
    bytes += generator.cut();

    List<Costcenter> costcenters = await fetchCostcentersWindows();

    for (var center in costcenters.where((e) => e.name == "Bill")) {
      int copies = center.noOfcopies ?? 1;
      if (center.printerip1 != null && center.printerip1!.isNotEmpty) {
        for (int i = 0; i < copies; i++) {
          await printTicket(bytes, center.printerip1!);
        }
      }
      if (center.printerip2 != null && center.printerip2!.isNotEmpty) {
        await printTicket(bytes, center.printerip2!);
      }
      if (center.printerip3 != null && center.printerip3!.isNotEmpty) {
        await printTicket(bytes, center.printerip3!);
      }
    }
    return bytes;

  }

  Future<void> printTicket(List<int> ticket, String targetIp) async {
    final printer = PrinterNetworkManager(targetIp);
    if (await printer.connect() == PosPrintResult.success) {
      print("Printing to $targetIp: " + (await printer.printTicket(ticket)).msg);
      printer.disconnect();
    } else {
      print("Failed to connect to printer at $targetIp");
    }
  }
  void openWhatsApp({required String phoneNumber, required String message}) async {
    String url = "https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}";
    Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  void shareImageToWhatsApp(Uint8List imageBytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/image.png');
    await file.writeAsBytes(imageBytes);
    final exists = await file.exists();
    if (exists) {
      print('Image file exists: ${file.path}');
    } else {
      print('Image file does not exist!');
    }
    XFile xFile = XFile(file.path);
    shareWhatsapp.shareFile(xFile);
  }

  @override
  Widget build(BuildContext context) {

    double screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    double screenHeight = MediaQuery

        .of(context)
        .size
        .height;

    return Scaffold(
      backgroundColor: Color(0xFFC7C7C7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD5282B),
        title: const Text('', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          alignment: Alignment.topLeft,
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => screenWidth > screenHeight ?  MainMenuDesk():MainMenu(),
              ),
            );
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: WidgetsToImage(
                  controller: controller,
                  child: cardWidget(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.save, color: Colors.blue, size: 50),
                    onPressed: () => captureAndPrintReceipt(context), // ✅ Correct
                  ),

                   IconButton(
                       icon: const Icon(
                         Icons.print,
                         color: Color(0xFFDAA520),
                         size: 50.0,
                       ),
                       onPressed: () async {
                         try {
                           // Fetch cost centers
                          List<Costcenter> costCenters = await fetchCostcentersWindows();

                           // Fetch JSON data
                           String jsonData = await getCostCenterJson(); // Define jsonData here

                          String billNo = gReciptViewStrings['BillNo'] ?? '';
                           String tableNo = gReciptViewStrings['tableName'] ?? '';
                           String totalStr = gReciptViewStrings['Total'] ?? '0';
                           String discountPerStr = gReciptViewStrings['discountper'] ?? '0';
                         String discountStr = gReciptViewStrings['discount'] ?? '0';
                           String discountRemark = gReciptViewStrings['discountremark'] ?? '';
                          String paxStr = gReciptViewStrings['pax'] ?? '0';
                           String settleModeName = gReciptViewStrings['settlemodename'] ?? '';
                           String custname = gReciptViewStrings['custname'] ?? '';

                           // Parse values
                           double total = double.tryParse(totalStr) ?? 0.0;
                           double discountPer = double.tryParse(discountPerStr) ?? 0.0;
                          double discount = double.tryParse(discountStr) ?? 0.0;
                           int pax = int.tryParse(paxStr) ?? 0;

                           // Calculate subtotal
                           double subtotal = 0.0;
                           List<LocalTax> localtaxes = [];

                           for (BillItem bill in gREciptViewBillItems) {
                             subtotal += bill.totalPrice;
                           }

                           for (SelectedProductModifier modifier in gREciptViewBillModifiers) {
                             double tamt = modifier.quantity * modifier.price_per_unit;
                             subtotal += tamt;
                           }

                           double billamt = subtotal - discount;

                           for (var tax in globaltaxlist) {
                             String isApplicableOncurrentmodlue = "N";

                             switch (Lastclickedmodule) {
                              case 'Dine':
                                 isApplicableOncurrentmodlue = tax.isApplicableonDinein;
                                 break;
                               case 'Take Away':
                                 isApplicableOncurrentmodlue = tax.isApplicableonTakeaway;
                                 break;
                               case 'Home Delivery':
                                 isApplicableOncurrentmodlue = tax.isApplicableonHomedelivery;
                                 break;
                               case 'Counter':
                                 isApplicableOncurrentmodlue = tax.isApplicableCountersale;
                                 break;
                               case 'Online':
                                isApplicableOncurrentmodlue = tax.isApplicableOnlineorder;
                                 break;
                             }

                             if (isApplicableOncurrentmodlue == "Y") {
                              double pec = double.parse(tax.taxPercent);
                               double taxable = (discount > 0.0) ? (pec / 100.00) * billamt : (pec / 100.00) * subtotal;
                               localtaxes.add(LocalTax(tax.taxCode, tax.taxName, tax.taxPercent, taxable));
                             }
                           }

                  //         // Call print function
                           await testBILL(
                               billNo,
                               gREciptViewBillItems,
                              gREciptViewBillModifiers,
                               tableNo,
                              total,
                              discountPer,
                              discount,
                               discountRemark,
                               pax,
                               settlementModeName,
                              subtotal,
                               localtaxes,
                               await loadImage('assets/images/reddpos.png'),
                               jsonData // Ensure jsonData is properly passed
                             // costCenters  <-- Remove if testBILL() does not accept this
                           );

                         } catch (e) {
                           print("Error fetching cost centers or processing bill: $e");
                         }
                       }

                   ),



                  // WhatsApp number input field on the right with reduced width
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: 30.0),  // Reduced left padding
                      child: TextField(
                        controller: phoneNumberController,
                        keyboardType: TextInputType.phone,
                        cursorColor: Colors.green, // Set the cursor color here
                        style: TextStyle(
                          color: Colors.green,
                          fontFamily: 'HammersmithOne',
                          fontSize: 24,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Whatsapp number',
                          labelStyle: TextStyle(color: Colors.green),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.green),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Theme(
        data: ThemeData(
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            elevation: 0.0,
          ),
        ),
        child: FloatingActionButton(
          child: const Icon(FontAwesomeIcons.whatsapp, color: Colors.white),
          onPressed: () async {
            final bytes = await controller.capture();
            setState(() {
              this.bytes = bytes;
            });
            if (bytes != null) {
              shareImageToWhatsApp(bytes);
            }

            openWhatsApp(
              phoneNumber: '91' + phoneNumberController.text,
              message: "Here is your Bill from " + brandName + " link: https://example.com powered by DPOS",
            );
          },
          mini: true,
          backgroundColor: Colors.green,
        ),
      ),
    );

  }
  double gSubtotal = 0.0;
  double gGrandTotal = 0.0;
  double gSumOfTax = 0.0;


  Widget cardWidget() {
    List<LocalTax> localtaxes = [];

    double sttl = 0.00;
    double discount = 0.00;
    double discountper = 0.00;
    double billamt = 0.00;
    String discountremark = '';

    discount = double.tryParse(gReciptViewStrings['discount'] ?? '0') ?? 0.0;

    if (discount != 0.0) {
      discountper = double.tryParse(gReciptViewStrings['discountper'] ?? '0') ?? 0.0;
      discountremark = gReciptViewStrings['discountremark'] ?? '';
    }

    double st = 0.00;
    for (BillItem bill in gREciptViewBillItems) {
      if (groupedItems.containsKey(bill.itemName)) {
        groupedItems[bill.itemName]['quantity'] += bill.quantity;
        groupedItems[bill.itemName]['totalPrice'] += bill.totalPrice;
      } else {
        groupedItems[bill.itemName] = {
          'item': bill,
          'quantity': bill.quantity,
          'price': bill.price,
          'totalPrice': bill.totalPrice,
        };
      }
    }

    groupedItems.forEach((itemName, data) {
      st += (data['totalPrice'] as num).toDouble();
      totalQuantity += int.tryParse(data['quantity'].toString()) ?? 0;
    });
    combinedItems = groupedItems.values.toList();
// Convert grouped items to a list
/*
    for (SelectedProductModifier modifier in gREciptViewBillModifiers) {
      double tamt = modifier.quantity * modifier.price_per_unit;
      st += tamt;
      modifierQuanity += modifier.quantity;
    }*/
// Group modifiers by name

    for (SelectedProductModifier modifier in gREciptViewBillModifiers) {
      String key = "${modifier.name}_${modifier.price_per_unit}";

      if (groupedModifiers.containsKey(key)) {
        groupedModifiers[key]!['quantity'] += modifier.quantity;
        groupedModifiers[key]!['totalAmount'] += modifier.quantity * modifier.price_per_unit;

      } else {
        groupedModifiers[key] = {
          'name': modifier.name,
          'quantity': modifier.quantity,
          'price_per_unit': modifier.price_per_unit,
          'totalAmount': modifier.quantity * modifier.price_per_unit,
          'product_code': modifier.product_code,
          'order_id': modifier.order_id,

        };
      }
    }

    groupedModifiers.forEach((name, data) {
      st += data['totalAmount'];
      modifierQuanity += int.tryParse(data['quantity'].toString()) ?? 0;
    });

    combinedModiferItem = groupedModifiers.values.toList();

    finalQuantity=totalQuantity + modifierQuanity;
    if (discount != null) {
      billamt = st - discount;
    }
    for (var tax in globaltaxlist) {
      String isApplicableOncurrentmodlue = "N";

      switch (Lastclickedmodule) {
        case 'Dine':
          isApplicableOncurrentmodlue = tax.isApplicableonDinein;
          break;
        case 'Take Away':
          isApplicableOncurrentmodlue = tax.isApplicableonTakeaway;
          break;
        case 'Home Delivery':
          isApplicableOncurrentmodlue = tax.isApplicableonHomedelivery;
          break;
        case 'Counter':
          isApplicableOncurrentmodlue = tax.isApplicableCountersale;
          break;
        case 'Online':
          isApplicableOncurrentmodlue = tax.isApplicableOnlineorder;
          break;
      }

      if (isApplicableOncurrentmodlue == "Y") {
        double pec = double.parse(tax.taxPercent);
        double taxable = 0.0;

        if (discount > 0.0) {
          if (tax.taxName == "Service Charge") {
            if (GLOBALNSC == "Y") {
              taxable = (0.0 / 100.00) * billamt;
            } else {
              taxable = (pec / 100.00) * billamt;
              serviceCharge=taxable;

            }
          } else {
            if(serviceCharge!=0.0){
              double subTotal=billamt+serviceCharge;
              taxable = (pec / 100.00) * subTotal;
            }else{
              taxable = (pec / 100.00) * billamt;
            }
          }
        } else {
          if (tax.taxName == "Service Charge") {
            if (GLOBALNSC == "Y") {
              taxable = (0.0 / 100.00) * st;
            } else {
              taxable = (pec / 100.00) * st;

              serviceCharge=taxable;
            }
          } else {
            if(serviceCharge!=0.0){
              //double serviceCharge = double.parse(globaltaxlist[0].taxPercent.toString());
              double subTotal=st+serviceCharge; //added service charge
              taxable = (pec / 100.00) * subTotal;
            }else{
              taxable = (pec / 100.00) * st;
            }
          }
        }

        localtaxes.add(LocalTax(tax.taxCode, tax.taxName, tax.taxPercent, taxable));
        sttl += taxable;
      }
    }

/////for sepeparte tax wise////////
 /*   gReceiptViewTaxes.sort((a, b) => a.code.compareTo(b.code));

    for (var tax in gReceiptViewTaxes) {
      double taxAmount = tax.amount ?? 0.0;

      // Add the tax to localtaxes
      localtaxes.add(LocalTax(
        tax.code,
        tax.name,
        tax.percent,
        taxAmount,
      ));

      sttl += taxAmount; // Add the tax amount to the total
    }*/

    /*Map<String, LocalTax> taxMap = {};
    ///////////////////////////for merge tax////////

    for (var tax in gReceiptViewTaxes) {
      double taxAmount = tax.amount ?? 0.0;
      double taxPercent = double.tryParse(tax.percent) ?? 0.0;
      String key = taxPercent.toStringAsFixed(1); // Key based on tax rate

      if (taxMap.containsKey(key)) {
        final existing = taxMap[key]!;

        taxMap[key] = LocalTax(
          key,
          existing.name, // Keep the tax name (e.g., "GST")
          (double.parse(existing.percent) + taxPercent).toStringAsFixed(0),
          existing.amount + taxAmount, // Sum the amounts
        );
      } else {
        taxMap[key] = LocalTax(
          key,
          "GST", // Use "GST" as the tax name
          taxPercent.toStringAsFixed(1),
          taxAmount,
        );
      }
    }

// Sort and add to list
    final sortedTaxes = taxMap.values.toList()
      ..sort((a, b) => double.parse(a.percent).compareTo(double.parse(b.percent)));

    for (var tax in sortedTaxes) {
      localtaxes.add(LocalTax(
        "${tax.name} (${tax.percent}%)", // Shows the summed percent correctly
        tax.name,
        tax.percent,
        tax.amount,
      ));
      sttl += tax.amount; // Add the tax amount to the grand total
    }

*/



    sttl += billamt;

    String lastThreeDigits = gReciptViewStrings['BillNo'].toString().substring(gReciptViewStrings['BillNo'].toString().length - 3);
    String remainingString = gReciptViewStrings['BillNo'].toString().substring(0, gReciptViewStrings['BillNo'].toString().length - 3);

    return Column(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Color(0xFFFFFFFF),
            BlendMode.srcIn,
          ),
          child: SizedBox(
            width: 400.0,
            child: Image.asset(
              'assets/images/LinesUpsideDown.png',
              fit: BoxFit.fill,
            ),
          ),
        ),

        // Main Card Content1

        showContainer
            ? Container(
          width: 400,
          color: Color(0xFFFFFFFF),
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/reddpos.png',
                        height: 90,
                      ),
                      if (DuplicatePrint == 'N')
                        Text('[Duplicate]', style: TextStyle(color: darkGrey)),

                      Text(
                        brandName,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkGrey),
                      ),
                      SizedBox(height: 8),
                      Text(Addresslineone, style: TextStyle(color: darkGrey)),
                      Text(Addresslinetwo, style: TextStyle(color: darkGrey)),
                      Text(Addresslinethree, style: TextStyle(color: darkGrey)),
                      Text('Tel No.: $brandmobile', style: const TextStyle(color: darkGrey)),
                      Text('Email: $emailid', style: const TextStyle(color: darkGrey)),
                    ],
                  ),
                ),
                SizedBox(height: 2),
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Debug print:
                      Builder(
                        builder: (context) {
                          final orderType = gReciptViewStrings['orderType'] ?? '';
                          return Text(
                            orderType,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          );
                        },
                      ),
                    ],
                  ),
                ),


                if (gReciptViewStrings['custname'].toString().isNotEmpty)
                  Divider(thickness: 1, color: Colors.black),

                if (gReciptViewStrings['custname'].toString().isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Guest Name',
                          style: const TextStyle(color: Colors.black87),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 10,
                        child: Text(
                          ':',
                          style: const TextStyle(color: Colors.black87),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          textAlign: TextAlign.left,
                          gReciptViewStrings['custname'].toString(),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                if (gReciptViewStrings['custmobile'].toString().isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Mobile no',
                          style: const TextStyle(color: Colors.black87),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 10,
                        child: Text(
                          ':',
                          style: const TextStyle(color: Colors.black87),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          textAlign: TextAlign.left,
                          gReciptViewStrings['custmobile'].toString(),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                if (gReciptViewStrings['custgst'].toString().isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'GSTIN',
                          style: const TextStyle(color: Colors.black87),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 10,
                        child: Text(
                          ':',
                          style: const TextStyle(color: Colors.black87),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          textAlign: TextAlign.left,
                          gReciptViewStrings['custgst'].toString(),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),

                if (gReciptViewStrings['CustomerAddress']?.toString()?.isNotEmpty ?? false)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Address',
                          style: const TextStyle(color: Colors.black87, fontSize: 16),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 10,
                        child: Text(
                          ':',
                          style: const TextStyle(color: Colors.black87, fontSize: 16),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          textAlign: TextAlign.left,
                          gReciptViewStrings['CustomerAddress'].toString(),
                          style: const TextStyle(color: Colors.black87, fontSize: 16),
                        ),
                      ),
                    ],
                  ),

                Divider(thickness: 1, color: Colors.black),

                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        'Bill No',
                        style: const TextStyle(color: Colors.black87),
                        overflow: TextOverflow.visible,
                        maxLines: null,
                      ),
                    ),
                    SizedBox(
                      width: 10,
                      child: Text(
                        ':',
                        style: const TextStyle(color: Colors.black87),
                        overflow: TextOverflow.visible,
                        maxLines: null,
                      ),
                    ),
                    SizedBox(
                      width: 65,
                      child: Text(
                        textAlign: TextAlign.left,
                        remainingString,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        textAlign: TextAlign.left,
                        lastThreeDigits,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                if (Lastclickedmodule != "Take Away" && Lastclickedmodule != "Counter" && Lastclickedmodule != "Home Delivery")
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Table Name',
                          style: const TextStyle(color: Colors.black87),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),

                      SizedBox(
                        width: 10,
                        child: Text(
                          ':',
                          style: const TextStyle(color: Colors.black87),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          textAlign: TextAlign.left,
                          gReciptViewStrings['tableName'].toString(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                if (Lastclickedmodule != "Take Away" && Lastclickedmodule != "Counter" && Lastclickedmodule != "Home Delivery")
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Waiter',
                          style: const TextStyle(color: Colors.black87),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 10,
                        child: Text(
                          ':',
                          style: const TextStyle(color: Colors.black87),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          textAlign: TextAlign.left,
                          gReciptViewStrings['waiter'].toString(),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        'Date and Time',
                        style: const TextStyle(color: Colors.black87),
                        overflow: TextOverflow.visible,
                        maxLines: null,
                      ),
                    ),
                    SizedBox(
                      width: 10,
                      child: Text(
                        ':',
                        style: const TextStyle(color: Colors.black87),
                        overflow: TextOverflow.visible,
                        maxLines: null,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        textAlign: TextAlign.left,
                        gReciptViewStrings['DNT'].toString(),
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        'Bill By',
                        style: const TextStyle(color: Colors.black87),
                        overflow: TextOverflow.visible,
                        maxLines: null,
                      ),
                    ),
                    SizedBox(
                      width: 10,
                      child: Text(
                        ':',
                        style: const TextStyle(color: Colors.black87),
                        overflow: TextOverflow.visible,
                        maxLines: null,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        textAlign: TextAlign.left,
                        gReciptViewStrings['user'].toString(),
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                Divider(thickness: 1, color: Colors.black87),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Item Name",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                          SizedBox(height: 4),

                        ],
                      ),
                    )
                    ,
                    Padding(
                      padding: EdgeInsets.only(left: 40),
                      child: Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Qty",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                              overflow: TextOverflow.visible,
                              maxLines: null,
                            ),
                            SizedBox(height: 4),

                          ],
                        ),
                      ),
                    )

                    ,
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Price",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                          SizedBox(height: 4),

                        ],
                      ),
                    )
                    ,
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Amount",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                          SizedBox(height: 4),

                        ],
                      ),
                    )
                    ,
                  ],
                ),
                Divider(thickness: 1, color: Colors.black),

                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: combinedItems.length,
                  itemBuilder: (context, index) {
                    final groupedItem = combinedItems[index];
                    final billItem = groupedItem['item'];
                    final int combinedQuantity = groupedItem['quantity'];
                    final double combinedPrice = groupedItem['price'];

                    final itemModifiers = combinedModiferItem
                        .where((modifier) =>
                    modifier['product_code'] == billItem.productCode)
                        .toList();


                    return Column(
                      children: [
                        ReceiptItem(
                          index: index,
                          itemName: billItem.itemName,
                          quantity: combinedQuantity,
                          price: combinedPrice,
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: itemModifiers.length,
                          itemBuilder: (context, modIndex) {

                            final modi=itemModifiers[modIndex];
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 120,
                                        child: Text(
                                          modi['price_per_unit'] > 0.0 ? '>>' + modi['name'] : '>' + modi['name'],
                                          style: const TextStyle(color: Colors.black87),
                                          overflow: TextOverflow.visible,
                                          maxLines: null,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          modi['quantity'].toString(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.black87),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          textAlign: TextAlign.right,
                                          '$brandcurrencysymball${modi['price_per_unit'].toStringAsFixed(3)}',
                                          style: const TextStyle(color: Colors.black87),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          textAlign: TextAlign.right,
                                          '$brandcurrencysymball${modi['totalAmount'].toStringAsFixed(3)}',
                                          style: const TextStyle(color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                Divider(thickness: 1, color: Colors.black87),
                SizedBox(height: 2),
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    SizedBox(
                      width: 100,
                      child: const Text(
                        'Sub Total',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    Text(
                      "x"+finalQuantity.toString(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      "",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      st.toStringAsFixed(3),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),

// ... after Sub Total Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sub Total',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      "x" + finalQuantity.toString(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      "",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      st.toStringAsFixed(3),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),

// --- Insert Home Delivery Charge Row here ---
                if (double.tryParse(homeDeliveryCharge as String) != null && double.parse(homeDeliveryCharge as String) > 0.0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Delivery Charge',
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        double.parse(homeDeliveryCharge as String).toStringAsFixed(3),
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                if (discount > 0.0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discount ' + discountper.toStringAsFixed(0) + '%',
                        style: TextStyle(color: Colors.black87),
                      ),
                      Text(
                        discount.toStringAsFixed(3),
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                if (discount > 0.0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Remark(' + discountremark + ')',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                if (discount > 0.0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bill Amount',
                        style: TextStyle(color: Colors.black87),
                      ),
                      Text(
                        billamt.toStringAsFixed(3),
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: localtaxes.length,
                  itemBuilder: (context, index) {
                    final taxItem = localtaxes[index];
                    return TaxItem(
                      amt: taxItem.amount,
                      taxName: taxItem.name,
                      percent: taxItem.percent,
                    );
                  },
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Grand Total',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),

                        ],
                      ),
                    ),
                    Text(
                      sttl.toStringAsFixed(3),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paid By: ${gReciptViewStrings['settlementMode'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),

                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Text(
                    'Thank you Visit Us Again!',
                    style: TextStyle(color: Colors.black87),
                  ),
                )
,
                const SizedBox(height: 2),
                if (lastMOS == "Multi settlement" || lastMOS == "UPI Online" || lastMOS == "PayPal")
                  Center(
                    child: QrImageView(
                      data: "upi://pay?pa=mab.037325021710017@axisbank&pn=DGPOS LLP&am=${sttl.toStringAsFixed(3)}&cu=INR&aid=uGICAgIDVt_7-dw",
                      size: 100,
                      embeddedImageStyle: const QrEmbeddedImageStyle(
                        size: Size(100, 100),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        )
            : const SizedBox.shrink(),


         /*ColorFiltered(
               colorFilter: ColorFilter.mode(
                 Color(0xFFFFFFFF),
                 BlendMode.srcIn,
              ),
               child: SizedBox(
                 width: 400.0,
                 child: Image.asset(
                   'assets/images/Lines.png',
                   fit: BoxFit.fill,
                 ),
               ),
             ),*/
        // Main Card Content2

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        RepaintBoundary(
          key: _receiptKey,
          child: Container(
            width: 400,
            color: Color(0xFFFFFFFF),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/reddpos.png',
                          height: 70,
                        ),
                        if (DuplicatePrint == 'Y')
                          Text('[Duplicate]', style: TextStyle(color: Colors.black87)),

                        Text(
                          brandName,
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        Text(Addresslineone, style: TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 17)),
                        Text(Addresslinetwo, style: TextStyle(color: Colors.black87,fontWeight: FontWeight.bold,fontSize: 17)),
                        Text(Addresslinethree, style: TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 17)),
                        Text('Tel No.: $brandmobile', style: TextStyle(color:Colors.black87,fontWeight: FontWeight.bold,fontSize: 17)),
                        Text('Email: $emailid', style: TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 17)),

                      ],
                    ),
                  ),
                  SizedBox(height: 2),
                  Divider(thickness: 2, color:Colors.black87),

                  Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          gReciptViewStrings['orderType'] ?? '',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),



                  if (gReciptViewStrings['custname'].toString().isNotEmpty)
                    Divider(thickness: 2, color: Colors.black),

                  if (gReciptViewStrings['custname'].toString().isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Guest Name',
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold,fontSize: 16), // Increased font size
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                        ),
                        SizedBox(
                          width: 10,
                          child: Text(
                            ':',
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold,fontSize: 16), // Increased font size
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            gReciptViewStrings['custname'].toString(),
                            textAlign: TextAlign.left,
                            style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 16), // Increased font size
                          ),
                        ),

                      ],
                    ),
                  if (gReciptViewStrings['custmobile'].toString().isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Mobile no',
                            style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 16), // Increased font size
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                        ),
                        SizedBox(
                          width: 10,
                          child: Text(
                            ':',
                            style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 16), // Increased font size
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            gReciptViewStrings['custmobile'].toString(),
                            textAlign: TextAlign.left,
                            style: const TextStyle(color: Colors.black87, fontSize: 16),
                          ),
                        ),
                      ],
                    ),

                  if (gReciptViewStrings['custgst'].toString().isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            'GSTIN',
                            style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                        ),
                        SizedBox(
                          width: 10,
                          child: Text(
                            ':',
                            style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            textAlign: TextAlign.left,
                            gReciptViewStrings['custgst'].toString(),
                            style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),

                  if (gReciptViewStrings['CustomerAddress']?.toString()?.isNotEmpty ?? false)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Address',
                            style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                        ),
                        SizedBox(
                          width: 10,
                          child: Text(
                            ':',
                            style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            textAlign: TextAlign.left,
                            gReciptViewStrings['CustomerAddress'].toString(),
                            style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),

                  Divider(thickness: 2, color: Colors.black),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Bill No',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 10,
                        child: Text(
                          ':',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              remainingString,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lastThreeDigits,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 90),

                      // ✅ Show only for Dine
                      if (gReciptViewStrings['orderType'] == 'Dine')
                        Text(
                          'Pax: ${gReciptViewStrings['pax'] ?? ''}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),


                  if (gReciptViewStrings['orderType'] == 'Dine' && gReciptViewStrings['tableName'] != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Table Name',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                        ),
                        SizedBox(
                          width: 10,
                          child: Text(
                            ':',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.visible,
                            maxLines: null,
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            gReciptViewStrings['tableName'].toString(),
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),


                  // Conditionally show "Waiter" only if orderType is 'Dine'
                    if (gReciptViewStrings['orderType'] == 'Dine' && gReciptViewStrings['waiter'] != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              'Waiter',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.visible,
                              maxLines: null,
                            ),
                          ),
                          SizedBox(
                            width: 10,
                            child: Text(
                              ':',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.visible,
                              maxLines: null,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              gReciptViewStrings['waiter'].toString(),
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: 100,
                        child: Text(
                          'Date & Time',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                        child: Text(
                          ':',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 170,
                        child: Builder(
                          builder: (context) {
                            final billTimeRaw = gReciptViewStrings['billTime'] ?? '';
                            final posDateRaw = gReciptViewStrings['DNT'] ?? '';

                            String formattedDate = '';
                            String formattedTime = '';

                            // Format DNT (posDate) to dd-MM-yyyy
                            if (posDateRaw.isNotEmpty) {
                              try {
                                final parsedPosDate = DateTime.parse(posDateRaw);
                                formattedDate = DateFormat('dd-MM-yyyy').format(parsedPosDate);
                              } catch (e) {
                                formattedDate = posDateRaw; // fallback
                              }
                            }

                            // Format billTime to hh:mm a
                            if (billTimeRaw.isNotEmpty) {
                              try {
                                final parsedBillTime = DateTime.parse(billTimeRaw).toLocal();
                                formattedTime = DateFormat('hh:mm a').format(parsedBillTime);
                              } catch (e) {
                                formattedTime = billTimeRaw; // fallback
                              }
                            }

                            final displayDateTime = '$formattedDate ${formattedTime.isNotEmpty ? formattedTime : ''}';
                            print('DISPLAY DateTime: $displayDateTime');

                            return Text(
                              displayDateTime,
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            );
                          },
                        ),
                      ),

                    ],


                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Bill By',
                          style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 10,
                        child: Text(
                          ':',
                          style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.visible,
                          maxLines: null,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          textAlign: TextAlign.left,
                          gReciptViewStrings['user'].toString(),
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold,fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  Divider(thickness: 2, color: Colors.black),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Item Name",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                              overflow: TextOverflow.visible,
                              maxLines: null,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "اسم العنصر",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                              overflow: TextOverflow.visible,
                              maxLines: null,
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.only(left: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Qty",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                overflow: TextOverflow.visible,
                                maxLines: null,
                              ),
                              SizedBox(height: 4),
                              Text(
                                "الكمية",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                overflow: TextOverflow.visible,
                                maxLines: null,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Price
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Price",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                              overflow: TextOverflow.visible,
                              maxLines: null,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "سعر",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                              overflow: TextOverflow.visible,
                              maxLines: null,
                            ),
                          ],
                        ),
                      ),

                      // Amount
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Amount",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                              overflow: TextOverflow.visible,
                              maxLines: null,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "كمية",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                              overflow: TextOverflow.visible,
                              maxLines: null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                  ,
                  Divider(thickness: 2, color: Colors.black),
                  // Items
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: combinedItems.length,
                    itemBuilder: (context, index) {
                      final groupedItem = combinedItems[index];
                      final billItem = groupedItem['item'];
                      final int combinedQuantity = groupedItem['quantity'];
                      final double combinedPrice = groupedItem['price'];
                      final matchedProduct = widget.productList.firstWhere(
                            (product) => product.productCode == int.tryParse(billItem.productCode),
                        orElse: () => Product(
                          productCode: int.tryParse(billItem.productCode) ?? 0,
                          productName: '',
                          productImage: '',
                          productType: ProductType.EMPTY,
                          categoryCode: 0,
                          productDescription: '',
                          costcenterCode: '',
                          dietary: '',
                          displayName: '',
                        ),
                      );
                      final itemModifiers = combinedModiferItem
                          .where((modifier) => modifier['product_code'] == billItem.productCode)
                          .toList();

                      return Column(
                        children: [
                          ReceiptItem(
                            itemName: billItem.itemName,
                            displayName: matchedProduct.displayName,
                            quantity: combinedQuantity,
                            price: combinedPrice,
                          ),
                          // Nested ListView for item modifiers
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(), // Prevent nested scrolling
                            itemCount: itemModifiers.length,
                            itemBuilder: (context, modIndex) {
                              final modi = itemModifiers[modIndex];

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4), // Adjust vertical padding
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, // Aligns the column to the start
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          child: Text(
                                            modi['price_per_unit'] > 0.0 ? '>> ' + modi['name'] : '> ' + modi['name'],
                                            style: const TextStyle(color: Colors.black87, fontSize: 16,fontWeight: FontWeight.bold), // Increased font size
                                            overflow: TextOverflow.visible,
                                            maxLines: null,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 70,
                                          child: Text(
                                            modi['quantity'].toString(),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.black87, fontSize: 14,fontWeight: FontWeight.bold), // Increased font size
                                          ),
                                        ),
                                        SizedBox(
                                          width: 60,
                                          child: Padding(
                                            padding: const EdgeInsets.only(left: 7.0), // Adjust this value as needed
                                            child: Text(
                                              '${modi['price_per_unit'].toStringAsFixed(3)}',
                                              textAlign: TextAlign.left,
                                              style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold, fontSize: 14), // Keep existing styling
                                            ),
                                          ),
                                        ),

                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            '${modi['totalAmount'].toStringAsFixed(3)}',
                                            textAlign: TextAlign.left,
                                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold,fontSize: 14), // Increased font size
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      );

                    },
                  ),

                  Divider(thickness: 2, color: Colors.black),
                  SizedBox(height: 2),
                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      SizedBox(
                        width: 100,
                        child: const Text(
                          'Sub Total',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                      Text(
                        "x"+finalQuantity.toString(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        "",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        st.toStringAsFixed(3),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),


                  if (discount > 0.0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Discount ' + discountper.toStringAsFixed(0) + '%',
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          discount.toStringAsFixed(3),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  if (discount > 0.0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Remark(' + discountremark + ')',
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  if (discount > 0.0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bill Amount',
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          billamt.toStringAsFixed(3),
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),

                  if ((double.tryParse(gReciptViewStrings['homeDeliveryCharge'].toString()) ?? 0.0) > 0.0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Delivery Charge',
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          (double.tryParse(gReciptViewStrings['homeDeliveryCharge'].toString()) ?? 0.0).toStringAsFixed(3),
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),


                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: localtaxes.length,
                    itemBuilder: (context, index) {
                      final taxItem = localtaxes[index];
                      return TaxItem(
                        amt: taxItem.amount,
                        taxName: taxItem.name,
                        percent: taxItem.percent,
                      );
                    },
                  ),

               /*   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Round Off',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,

                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        (() {
                          double roundOff = sttl - sttl.toInt(); // Get the decimal part
                          String sign = roundOff <= 0.50 ? '-' : '+';
                          double roundValue = roundOff <= 0.50 ? roundOff : (1 - roundOff);
                          return "$sign${roundValue.toStringAsFixed(3)}";
                        })(),

                      ),
                    ],
                  ),*/

                  Divider(thickness: 2, color: Colors.black),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic, // Important for baseline alignment
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Total OMR',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'المجموع',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        (double.tryParse(gReciptViewStrings['GrandTotal'] ?? '0') ?? 0.0).toStringAsFixed(3),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  if ((gReciptViewStrings['settlementMode'] ?? '').isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Settle In: ${gReciptViewStrings['settlementMode']}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),


                  const SizedBox(height: 2),
                  Container(
                    width: double.infinity,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [

                        SizedBox(height: 4),
                        Text(
                          'VAT No: xxxxxxxxxxxx', // replace with actual VAT
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight:FontWeight.w500
                            ,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'CR No: xxxxxxxxxx', // replace with actual CR
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500
                            ,
                          ),
                        ),
                        Text(
                          'Thank you Visit Us Again!',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500
                            ,
                          ),
                        ),
                      ],
                    ),
                  )
,

                  const SizedBox(height: 2),
                  if (lastMOS == "Multi settlement" || lastMOS == "UPI Online" || lastMOS == "PayPal")
                    Center(
                      child: QrImageView(
                        data: "upi://pay?pa=mab.037325021710017@axisbank&pn=DGPOS LLP&am=${sttl.toStringAsFixed(3)}&cu=INR&aid=uGICAgIDVt_7-dw",
                        size: 100,
                        embeddedImageStyle: const QrEmbeddedImageStyle(
                          size: Size(100, 100),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),)
        ,      ColorFiltered(
          colorFilter: ColorFilter.mode(
            Color(0xFFFFFFFF),
            BlendMode.srcIn,
          ),
          child: SizedBox(
            width: 400.0,
            child: Image.asset(
              'assets/images/Lines.png',
              fit: BoxFit.fill,
            ),
          ),
        ),
      ],
    );
  }

  Future<List<Costcenter>> fetchCostcentersWindows() async {
    try {
      final response = await http.get(Uri.parse('${apiUrl}costcenter/getAll?DB=$CLIENTCODE'));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData is List) {
          return jsonData.map((item) => Costcenter.fromMap(item as Map<String, dynamic>)).toList();
        } else if (jsonData is Map<String, dynamic>) {
          return [Costcenter.fromMap(jsonData)];
        } else {
          throw Exception("Unexpected JSON format: ${jsonData.runtimeType}");
        }
      } else {
        throw Exception("API Error: ${response.statusCode}, Response: ${response.body}");
      }
    } catch (e, stackTrace) {
      print("Exception: $e");
      print("StackTrace: $stackTrace");
      throw Exception('Failed to load Cost Centers');
    }
  }


  Future<String> getCostCenterJson() async {
    try {
      List<Costcenter> costCenters = await fetchCostcentersWindows();

      // Find the cost center with name "Bill"
      Costcenter? billCostCenter = costCenters.firstWhere(
            (center) => center.name == "Bill",
        orElse: () => Costcenter(
          name: "Bill",
          id: -1,  // Use -1 to indicate "not found" dynamically
          code: "",
          printername: "",
          printerip1: "",
          printerip2: "",
          printerip3: "",
        ),
      );

      // Create JSON with all dynamic values
      Map<String, dynamic> jsonData = {
        "name": billCostCenter.name,
        "id": billCostCenter.id,
        "code": billCostCenter.code,
        "printername": billCostCenter.printername,
        "printerip1": billCostCenter.printerip1,
        "printerip2": billCostCenter.printerip2,
        "printerip3": billCostCenter.printerip3,
      };

      return json.encode(jsonData);
    } catch (e) {
      print("Error fetching cost center JSON: $e");
      return "{}"; // Return empty JSON if an error occurs
    }
  }


}

class ReceiptItem extends StatelessWidget {
  final String itemName;
  final String? displayName;
  final int quantity;
  final double price;
  final int? index;

  const ReceiptItem({
    required this.itemName,
    this.displayName,
    required this.quantity,
    required this.price,
    this.index,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const darkGrey = Color(0xFF424242);
    double amt = price * quantity;

    return Padding(
      padding: EdgeInsets.only(
        top: index == 0 ? 0.0 : 8.0, // Added 8.0 spacing between items
        bottom: 4.0,  // Keep some space between the bottom of items
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  itemName,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.0, // Normal height
                  ),
                  overflow: TextOverflow.visible,
                  maxLines: null,
                ),
                if (displayName != null && displayName!.isNotEmpty)
                  Text(
                    displayName!,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.0, // Normal height for displayName
                    ),
                    overflow: TextOverflow.visible,
                    maxLines: null,
                  ),
              ],
            ),
          ),

          // Quantity Column (Moved right)
          Padding(
            padding: const EdgeInsets.only(left: 25), // Move "Qty" to the right
            child: SizedBox(
              width: 40,
              child: Text(
                quantity.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          // Price Column (Moved right)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: SizedBox(
              width: 60,
              child: Text(
                '${price.toStringAsFixed(3)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          // Amount Column (Unchanged)
          SizedBox(
            width: 70, // Fixed width for Amount
            child: Text(
              '${amt.toStringAsFixed(3)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class TaxItem extends StatelessWidget {
  final String taxName;
  final String percent;
  final double amt;

  const TaxItem({
    required this.taxName,
    required this.percent,
    required this.amt,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Log tax details
    debugPrint("Rendering TaxItem -> Name: $taxName, Percent: $percent%, Amount: ${amt.toStringAsFixed(3)}");

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$taxName $percent%',
                  style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                if (taxName == 'Vat')
                  const Text(
                    'ضريبة',
                    style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  )
                else if (taxName == 'Muncipality Tax')
                  const Text(
                    'ضريبة بلدية',
                    style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
              ],
            ),
          ),
          Text(
            '${amt.toStringAsFixed(3)}',
            style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 15),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class BillItem {
  // Existing properties
  String itemName;
  String productCode;
  int quantity;
  String notes;
  double price;
  double totalPrice;
  bool isComp;
  double pricebckp;
  final double gst;         // Total GST amount
  final double gstPercent;

  // New properties for bill-level details
  String billNo; // Bill number
  double grandTotal; // Grand total for the bill
  double billDiscount; // Discount amount for the bill
  double billDiscountPercent; // Discount percentage
  String billDiscountRemark; // Discount remark
  String settlementModeName; // Settlement mode
  String billDate; // Bill date
  String billTime; // Bill time
  List<BillItem> billItems; // Items in the bill
  List<dynamic> billModifiers; // Modifiers in the bill
  List<dynamic> billTaxes; // Taxes applied to the bill
  final List<dynamic> taxes;

  // New waiter field
  String? waiter; // Added waiter field

  BillItem({
    // Existing properties
    required this.itemName,
    required this.productCode,
    required this.quantity,
    this.notes = '',
    required this.price,
    required this.totalPrice,
    this.isComp = false,
    this.pricebckp = 0.0,
    this.gst = 0.0,
    this.gstPercent = 0.0,
    this.taxes = const [],
    this.billNo = '',
    this.grandTotal = 0.0,
    this.billDiscount = 0.0,
    this.billDiscountPercent = 0.0,
    this.billDiscountRemark = '',
    this.settlementModeName = '',
    this.billDate = '',
    this.billTime = '',
    this.billItems = const [],
    this.billModifiers = const [],
    this.billTaxes = const [],
    this.waiter, // Initialize waiter here
  });

  void updateValues(int newQuantity, double newPricePerUnit) {
    quantity = newQuantity;
    price = newPricePerUnit;
    totalPrice = price * quantity;
  }

  Map<String, dynamic> toJson() {
    return {
      'productName': itemName,
      'productCode': productCode,
      'quantity': quantity,
      'notes': notes,
      'pricePerUnit': price,
      'totalPrice': totalPrice,
      'isComp': isComp,
      'pricebckp': pricebckp,
      'billNo': billNo,
      'grandTotal': grandTotal,
      'billDiscount': billDiscount,
      'billDiscountPercent': billDiscountPercent,
      'billDiscountRemark': billDiscountRemark,
      'settlementModeName': settlementModeName,
      'billDate': billDate,
      'billTime': billTime,
      'billItems': billItems.map((item) => item.toJson()).toList(),
      'billModifiers': billModifiers,
      'billTaxes': billTaxes,
      'waiter': waiter, // Include waiter in the JSON serialization
    };
  }
}



class LocalTax {
  String code;
  String name;
  String percent;
  double amount;

  LocalTax(this.code, this.name, this.percent, this.amount);

  @override
  String toString() {
    return 'Tax(name: $name, amount: $amount)';
  }

  Map<String, dynamic> toJson() {
    return {
      "tax_code": code,
      "tax_name": name,
      "tax_percent": percent,
      "tax_amount": amount.toStringAsFixed(3),
    };
  }
}