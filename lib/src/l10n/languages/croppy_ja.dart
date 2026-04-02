import 'package:croppy/src/l10n/croppy_localizations.dart';

class CroppyLocalizationsJa extends CroppyLocalizations {
  CroppyLocalizationsJa() : super('ja');

  @override
  String get cancelLabel => 'キャンセル';

  @override
  String get cupertinoFreeformAspectRatioLabel => '自由';

  @override
  String get cupertinoOriginalAspectRatioLabel => '元の比率';

  @override
  String get cupertinoResetLabel => 'リセット';

  @override
  String get cupertinoSquareAspectRatioLabel => '正方形';

  @override
  String get doneLabel => '完了';

  @override
  String get materialFreeformAspectRatioLabel => '自由';

  @override
  String materialGetFlipLabel(LocalizationDirection direction) =>
      direction == LocalizationDirection.vertical
          ? '縦に反転'
          : '横に反転';

  @override
  String get materialOriginalAspectRatioLabel => '元の比率';

  @override
  String get materialResetLabel => 'リセット';

  @override
  String get materialSquareAspectRatioLabel => '正方形';

  @override
  String get saveLabel => '保存';

  @override
  String get circle => '円';

  @override
  String get square => '四角';

  @override
  String get freeCrop => '自由切り抜き';
}