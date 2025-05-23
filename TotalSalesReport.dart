class TotalSalesReport {
  final String occupiedTables;
  final String onlineSales;
  final String billDiscount;
  final String endDate;
  final String counterTotal;
  final String netSales;
  final String totalSales;
  final String roundOffTotal;
  final String onlineOrders;
  final String homeDeliveryChargeTotal;
  final String totalKotEntries;
  final String homeDeliveryTotal;
  final String billTimes;
  final String cashSales;
  final String cardSales;
  final String upiSales;
  final String othersSales;
  final String billTax;
  final String dineTotal;
  final String takeAwayTotal;
  final String onlineTotal;
  final String homeDeliverySales;
  final String counterSales;
  final String occupiedTableCount;
  final String startDate;

  TotalSalesReport({
    required this.occupiedTables,
    required this.onlineSales,
    required this.billDiscount,
    required this.endDate,
    required this.counterTotal,
    required this.netSales,
    required this.totalSales,
    required this.roundOffTotal,
    required this.onlineOrders,
    required this.homeDeliveryChargeTotal,
    required this.totalKotEntries,
    required this.homeDeliveryTotal,
    required this.billTimes,
    required this.cashSales,
    required this.cardSales,
    required this.upiSales,
    required this.othersSales,
    required this.billTax,
    required this.dineTotal,
    required this.takeAwayTotal,
    required this.onlineTotal,
    required this.homeDeliverySales,
    required this.counterSales,
    required this.occupiedTableCount,
    required this.startDate,
  });

  factory TotalSalesReport.fromJson(Map<String, dynamic> json) {
    return TotalSalesReport(
      occupiedTables: json['occupiedTables']?.toString() ?? "",
      onlineSales: json['onlineSales']?.toString() ?? "",
      billDiscount: json['billDiscount']?.toString() ?? "",
      endDate: json['endDate']?.toString() ?? "",
      counterTotal: json['counterTotal']?.toString() ?? "",
      netSales: json['netTotal']?.toString() ?? json['netSales']?.toString() ?? "",
      totalSales: json['grandTotal']?.toString() ?? json['totalSales']?.toString() ?? "",
      roundOffTotal: json['roundOffTotal']?.toString() ?? "",
      onlineOrders: json['onlineOrders']?.toString() ?? "",
      homeDeliveryChargeTotal: json['homeDeliveryChargeTotal']?.toString() ?? "",
      totalKotEntries: json['totalKotEntries']?.toString() ?? "",
      homeDeliveryTotal: json['homeDeliveryTotal']?.toString() ?? "",
      billTimes: json['billTimes']?.toString() ?? "",
      cashSales: json['cashSales']?.toString() ?? "",
      cardSales: json['cardSales']?.toString() ?? "",
      upiSales: json['upiSales']?.toString() ?? "",
      othersSales: json['othersSales']?.toString() ?? "",
      billTax: json['billTax']?.toString() ?? "",
      dineTotal: json['dineInSales']?.toString() ?? json['dineTotal']?.toString() ?? "",
      takeAwayTotal: json['takeAwaySales']?.toString() ?? json['takeAwayTotal']?.toString() ?? "",
      onlineTotal: json['onlineSales']?.toString() ?? "",
      homeDeliverySales: json['homeDeliverySales']?.toString() ?? "",
      counterSales: json['counterSales']?.toString() ?? "",
      occupiedTableCount: json['occupiedTableCount']?.toString() ?? "",
      startDate: json['startDate']?.toString() ?? "",
    );
  }

  /// Helper to support Dashboard's field mapping
  String getField(String key, {String fallback = "0.00"}) {
    switch (key) {
      case "occupiedTables":
        return occupiedTables.isNotEmpty ? occupiedTables : fallback;
      case "occupiedTableCount":
        return occupiedTableCount.isNotEmpty
            ? occupiedTableCount
            : (occupiedTables.isNotEmpty ? occupiedTables : fallback);
      case "onlineSales":
        return onlineSales.isNotEmpty ? onlineSales : fallback;
      case "billDiscount":
        return billDiscount.isNotEmpty ? billDiscount : fallback;
      case "endDate":
        return endDate.isNotEmpty ? endDate : fallback;
      case "counterTotal":
      case "counterSales":
        return counterTotal.isNotEmpty
            ? counterTotal
            : (counterSales.isNotEmpty ? counterSales : fallback);
      case "netSales":
      case "netTotal":
        return netSales.isNotEmpty ? netSales : fallback;
      case "totalSales":
      case "grandTotal":
        return totalSales.isNotEmpty ? totalSales : fallback;
      case "roundOffTotal":
        return roundOffTotal.isNotEmpty ? roundOffTotal : fallback;
      case "onlineOrders":
        return onlineOrders.isNotEmpty ? onlineOrders : fallback;
      case "homeDeliveryChargeTotal":
        return homeDeliveryChargeTotal.isNotEmpty ? homeDeliveryChargeTotal : fallback;
      case "totalKotEntries":
        return totalKotEntries.isNotEmpty ? totalKotEntries : fallback;
      case "homeDeliveryTotal":
        return homeDeliveryTotal.isNotEmpty ? homeDeliveryTotal : fallback;
      case "homeDeliverySales":
        return homeDeliverySales.isNotEmpty ? homeDeliverySales : fallback;
      case "billTimes":
        return billTimes.isNotEmpty ? billTimes : fallback;
      case "cashSales":
        return cashSales.isNotEmpty ? cashSales : fallback;
      case "cardSales":
        return cardSales.isNotEmpty ? cardSales : fallback;
      case "upiSales":
        return upiSales.isNotEmpty ? upiSales : fallback;
      case "othersSales":
        return othersSales.isNotEmpty ? othersSales : fallback;
      case "billTax":
        return billTax.isNotEmpty ? billTax : fallback;
      case "dineTotal":
      case "dineInSales":
        return dineTotal.isNotEmpty ? dineTotal : fallback;
      case "takeAwayTotal":
      case "takeAwaySales":
        return takeAwayTotal.isNotEmpty ? takeAwayTotal : fallback;
      case "startDate":
        return startDate.isNotEmpty ? startDate : fallback;
      default:
        return fallback;
    }
  }
}



class TimeslotSales {
  final String timeslot;
  final double dineInSales;
  final double takeAwaySales;
  final double deliverySales;
  final double onlineSales;

  TimeslotSales({
    required this.timeslot,
    required this.dineInSales,
    required this.takeAwaySales,
    required this.deliverySales,
    required this.onlineSales,
  });

  factory TimeslotSales.fromJson(Map<String, dynamic> json) {
    return TimeslotSales(
      timeslot: json['timeslot']?.toString() ?? "",
      dineInSales: (json['dineInSales'] is num)
          ? (json['dineInSales'] as num).toDouble()
          : double.tryParse(json['dineInSales']?.toString() ?? "0") ?? 0,
      takeAwaySales: (json['takeAwaySales'] is num)
          ? (json['takeAwaySales'] as num).toDouble()
          : double.tryParse(json['takeAwaySales']?.toString() ?? "0") ?? 0,
      deliverySales: (json['deliverySales'] is num)
          ? (json['deliverySales'] as num).toDouble()
          : double.tryParse(json['deliverySales']?.toString() ?? "0") ?? 0,
      onlineSales: (json['onlineSales'] is num)
          ? (json['onlineSales'] as num).toDouble()
          : double.tryParse(json['onlineSales']?.toString() ?? "0") ?? 0,
    );
  }
}