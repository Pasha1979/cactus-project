import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // Адаптивные размеры для Android
  static double photoHeaderHeight(BuildContext context) =>
      isMobile(context) ? 220 : 300;

  static int galleryCrossAxisCount(BuildContext context) =>
      isMobile(context) ? 2 : 3;

  static double defaultPadding(BuildContext context) =>
      isMobile(context) ? 12 : 16;

  static double cardElevation(BuildContext context) =>
      isMobile(context) ? 2 : 4;

  static double summaryCardWidth(BuildContext context) =>
      isMobile(context) ? 150 : 180;

  static double chartAspectRatio(BuildContext context) =>
      isMobile(context) ? 1.4 : 1.8;
  // Количество колонок в диалоге выбора взрослого фото с Llifle
  static int adultImageGridCount(BuildContext context) =>
      isMobile(context) ? 3 : 5;
}
